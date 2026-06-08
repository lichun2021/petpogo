/// ════════════════════════════════════════════════════════════
///  通用文档阅读页 — DocReaderPage
///
///  用途：
///    • 显示 assets/docs/ 下的 HTML 文件（协议、帮助、关于等）
///    • 支持 http:// / https:// 网页 URL（WebView 渲染）
///
///  用法（两种模式自动判断）：
///    // ① 本地 asset
///    DocReaderPage(title: '隐私政策', src: 'assets/docs/隐私政策.html')
///
///    // ② 远程网页
///    DocReaderPage(title: '帮助中心', src: 'https://example.com/help')
/// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

class DocReaderPage extends StatefulWidget {
  /// AppBar 标题，如 "隐私政策"
  final String title;

  /// 数据来源：
  ///   - asset 路径：'assets/docs/隐私政策.html'（不以 http 开头）
  ///   - 网页 URL ：'https://example.com/help'（以 http 开头）
  final String src;

  /// 兼容旧参数名 assetPath（只传一个即可）
  final String? assetPath;

  const DocReaderPage({
    super.key,
    required this.title,
    String? src,
    this.assetPath,
  }) : src = src ?? assetPath ?? '';

  bool get _isUrl => src.startsWith('http://') || src.startsWith('https://');

  @override
  State<DocReaderPage> createState() => _DocReaderPageState();
}

class _DocReaderPageState extends State<DocReaderPage> {
  // ── Asset 模式 ────────────────────────────────────────
  String? _htmlContent;
  bool _assetLoading = true;
  String? _assetError;

  // ── WebView 模式 ──────────────────────────────────────
  late final WebViewController _webCtrl;
  bool _webLoading = true;
  int _webProgress = 0;

  @override
  void initState() {
    super.initState();
    if (widget._isUrl) {
      _initWebView();
    } else {
      _loadAsset();
    }
  }

  // ── WebView 初始化 ────────────────────────────────────
  void _initWebView() {
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.surface)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _webProgress = p),
          onPageStarted: (_) => setState(() => _webLoading = true),
          onPageFinished: (_) => setState(() => _webLoading = false),
          onWebResourceError: (err) {
            debugPrint('[DocReader] WebView error: ${err.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.src));
  }

  // ── Asset HTML 加载 ───────────────────────────────────
  Future<void> _loadAsset() async {
    try {
      final raw = await rootBundle.loadString(widget.src);
      // 提取 <body> 内容，去掉外部 CSS 引用等
      final bodyMatch = RegExp(
        r'<body[^>]*>([\s\S]*)<\/body>',
        caseSensitive: false,
      ).firstMatch(raw);
      final body = bodyMatch != null ? bodyMatch.group(1)! : raw;

      final styled = '''
<div style="font-family: system-ui, -apple-system, sans-serif;
            font-size: 14px;
            line-height: 1.75;
            color: #1a1a2e;">
$body
</div>
''';
      if (mounted) setState(() { _htmlContent = styled; _assetLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _assetError = '文档加载失败：$e'; _assetLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.outline.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          color: AppColors.onSurface,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        centerTitle: true,
        // WebView 模式：顶部加载进度条
        bottom: widget._isUrl && _webLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _webProgress > 0 ? _webProgress / 100 : null,
                  backgroundColor: AppColors.surfaceContainerLow,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: widget._isUrl ? _buildWebView() : _buildAssetView(),
    );
  }

  // ── WebView 渲染 ──────────────────────────────────────
  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _webCtrl),
        // 首次加载骨架
        if (_webLoading && _webProgress == 0)
          Container(
            color: AppColors.surface,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
      ],
    );
  }

  // ── Asset HTML 渲染 ───────────────────────────────────
  Widget _buildAssetView() {
    if (_assetLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    if (_assetError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
              const SizedBox(height: 12),
              Text(_assetError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  )),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() { _assetLoading = true; _assetError = null; });
                  _loadAsset();
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: HtmlWidget(
        _htmlContent!,
        customStylesBuilder: (element) {
          switch (element.localName) {
            case 'h1':
              return {
                'font-size': '22px',
                'font-weight': '800',
                'margin-bottom': '12px',
                'color': _hex(AppColors.onSurface),
              };
            case 'h2':
              return {
                'font-size': '16px',
                'font-weight': '700',
                'margin-top': '20px',
                'margin-bottom': '8px',
                'color': _hex(AppColors.onSurface),
              };
            case 'p':
              return {
                'color': _hex(AppColors.onSurfaceVariant),
                'margin-bottom': '8px',
              };
            case 'li':
              return {
                'color': _hex(AppColors.onSurfaceVariant),
                'margin-bottom': '4px',
              };
            case 'a':
              return {
                'color': _hex(AppColors.primary),
                'text-decoration': 'none',
              };
            case 'strong':
              return {'color': _hex(AppColors.onSurface)};
            case 'footer':
              return {'display': 'none'};
          }
          if (element.classes.contains('docs-footer')) {
            return {'display': 'none'};
          }
          return null;
        },
        onTapUrl: (_) async => true,
      ),
    );
  }

  /// Color → CSS hex（flutter_widget_from_html 需要字符串）
  String _hex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }
}
