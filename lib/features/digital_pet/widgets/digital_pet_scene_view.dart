/// 数字宠 3D 场景（WebView 承载）。
///
/// 只做「加载场景 + 转发指令 + 监听场景事件」，不含业务规则。
/// 模型 URL / 背景 URL / 动作 clip 名称全部由调用方（DigitalPetController）
/// 从业务后端数据里取得后传入，本文件不内置任何品种/动作常量表。
library;

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 场景事件回调；对应 scene.js 里 notifyFlutter 上报的事件名。
typedef DigitalPetEventCallback = void Function(
    String event, Map<String, dynamic> data);

class DigitalPetSceneView extends StatefulWidget {
  final DigitalPetEventCallback onEvent;

  const DigitalPetSceneView({super.key, required this.onEvent});

  @override
  State<DigitalPetSceneView> createState() => DigitalPetSceneViewState();
}

class DigitalPetSceneViewState extends State<DigitalPetSceneView> {
  late final WebViewController _webCtrl;
  bool _webReady = false;
  Timer? _startupTimer;
  Timer? _modelTimer;
  int _commandSequence = 0;

  // `loadModel`/`setBackground` 常常在 WebView 还没加载完 scene.html
  // （Chromium 启动 + Three.js/GLTFLoader 初始化通常比一次 status 接口
  // 请求慢）时就被调用一次——之前这种情况下命令被直接丢弃，且调用方
  // （digital_pet_page.dart 的 _syncSceneWithState）用"目标 URL 是否变化"
  // 做去重，同一个 URL 不会重新下发，导致模型永远不出现、"加载中…"
  // 一直卡住。这里改成记下"最后一次想要的值"，等 onPageFinished 之后
  // 统一补发一次。
  String? _pendingModelUrl;
  String? _pendingModelCacheKey;
  bool _hasPendingBackground = false;
  String? _pendingBackgroundUrl;

  @override
  void initState() {
    super.initState();
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: _onSceneMessage,
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _initializeScene(),
        onWebResourceError: (error) {
          if (error.isForMainFrame == true) _reportFailure('场景初始化失败');
        },
      ))
      ..loadFlutterAsset('assets/digital_pet/scene.html');
    _watchStartup();
  }

  void _watchStartup() {
    _startupTimer?.cancel();
    _startupTimer =
        Timer(const Duration(seconds: 20), () => _reportFailure('场景初始化超时'));
  }

  Future<void> _initializeScene() async {
    if (!mounted) return;
    try {
      final ready = await _webCtrl.runJavaScriptReturningResult(
          'typeof window.DigitalPet === "object"');
      if (!mounted) return;
      if (ready != true && ready.toString() != 'true') {
        _reportFailure('场景初始化失败');
        return;
      }
      _startupTimer?.cancel();
      _webReady = true;
      _flushPending();
    } catch (_) {
      _reportFailure('场景初始化失败');
    }
  }

  void _reportFailure(String message) {
    if (!mounted) return;
    _startupTimer?.cancel();
    _modelTimer?.cancel();
    widget.onEvent('petError', {'message': message});
  }

  Future<void> reloadScene() async {
    _webReady = false;
    _commandSequence++;
    _modelTimer?.cancel();
    _watchStartup();
    try {
      await _webCtrl.loadFlutterAsset('assets/digital_pet/scene.html');
    } catch (_) {
      _reportFailure('场景初始化失败');
    }
  }

  void _flushPending() {
    if (_pendingModelUrl != null) {
      _sendLoadModel(_pendingModelUrl!, _pendingModelCacheKey!);
      _pendingModelUrl = null;
      _pendingModelCacheKey = null;
    }
    if (_hasPendingBackground) {
      _sendSetBackground(_pendingBackgroundUrl);
      _hasPendingBackground = false;
      _pendingBackgroundUrl = null;
    }
  }

  void _onSceneMessage(JavaScriptMessage message) {
    try {
      final map = jsonDecode(message.message) as Map<String, dynamic>;
      final event = map['event'] as String? ?? 'unknown';
      final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      if (!mounted) return;
      if (event == 'petReady' || event == 'petError') _modelTimer?.cancel();
      widget.onEvent(event, data);
    } catch (_) {
      // 场景侧消息格式异常时静默丢弃，不影响渲染。
    }
  }

  /// 加载任意远程 GLB 模型。[url] 是完整下载地址，[cacheKey] 是
  /// IndexedDB 缓存键（约定传后端资源 id，保证不同形象各自独立缓存）。
  ///
  /// [url]/[cacheKey] 来自后端动态数据，用 jsonEncode 转成安全的 JS 字符串
  /// 字面量再拼进 runJavaScript 调用，避免里面出现的引号/特殊字符破坏
  /// 生成的 JS 语句（不能像旧版那样直接裸拼接受信任的枚举名）。
  void loadModel(String url, String cacheKey) {
    if (!_webReady) {
      _pendingModelUrl = url;
      _pendingModelCacheKey = cacheKey;
      return;
    }
    _sendLoadModel(url, cacheKey);
  }

  Future<void> _sendLoadModel(String url, String cacheKey) async {
    final command = ++_commandSequence;
    _modelTimer?.cancel();
    _modelTimer =
        Timer(const Duration(seconds: 130), () => _reportFailure('模型加载超时'));
    final args = '${jsonEncode(url)}, ${jsonEncode(cacheKey)}';
    try {
      await _webCtrl.runJavaScript('window.DigitalPet.loadModel($args)');
    } catch (_) {
      if (command == _commandSequence) _reportFailure('模型加载启动失败');
    }
  }

  /// 按 clip 名字播放动画；模型没有该名字的片段时场景侧静默忽略。
  void playAction(String clipName) {
    if (!_webReady) return;
    _webCtrl
        .runJavaScript('window.DigitalPet.playAction(${jsonEncode(clipName)})');
  }

  /// 设置背景图为任意远程/本地 URL；传 null 清空背景。
  void setBackground(String? url) {
    if (!_webReady) {
      _hasPendingBackground = true;
      _pendingBackgroundUrl = url;
      return;
    }
    _sendSetBackground(url);
  }

  void _sendSetBackground(String? url) {
    final arg = url == null ? 'null' : jsonEncode(url);
    _webCtrl.runJavaScript('window.DigitalPet.setBackground($arg)');
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _modelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webCtrl);
  }
}
