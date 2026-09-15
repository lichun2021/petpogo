/// 数字宠 3D 场景（WebView 承载）。
///
/// 只做「加载场景 + 转发指令 + 监听场景事件」，不含业务规则。
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../controller/digital_pet_controller.dart';

/// 场景事件回调；对应 scene.js 里 notifyFlutter 上报的事件名。
typedef DigitalPetEventCallback = void Function(String event, Map<String, dynamic> data);

class DigitalPetSceneView extends StatefulWidget {
  final DigitalPetEventCallback onEvent;

  const DigitalPetSceneView({super.key, required this.onEvent});

  @override
  State<DigitalPetSceneView> createState() => DigitalPetSceneViewState();
}

class DigitalPetSceneViewState extends State<DigitalPetSceneView> {
  late final WebViewController _webCtrl;
  bool _webReady = false;

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
        onPageFinished: (_) => setState(() => _webReady = true),
      ))
      ..loadFlutterAsset('assets/digital_pet/scene.html');
  }

  void _onSceneMessage(JavaScriptMessage message) {
    try {
      final map = jsonDecode(message.message) as Map<String, dynamic>;
      final event = map['event'] as String? ?? 'unknown';
      final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      widget.onEvent(event, data);
    } catch (_) {
      // 场景侧消息格式异常时静默丢弃，不影响渲染。
    }
  }

  void loadPet(PetKind kind) {
    if (!_webReady) return;
    _webCtrl.runJavaScript("window.DigitalPet.loadPet('${kind.name}')");
  }

  void playAction(PetAction action) {
    if (!_webReady) return;
    _webCtrl.runJavaScript("window.DigitalPet.playAction('${action.name}')");
  }

  void setBackground(PetBackground bg) {
    if (!_webReady) return;
    final file = '${bg.name}.jpg';
    _webCtrl.runJavaScript("window.DigitalPet.setBackground('./bg/$file')");
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webCtrl);
  }
}

