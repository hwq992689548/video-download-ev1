import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/sniff_registry.dart';
import 'mobile_browser_config.dart';

class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.tabId,
    required this.initialUrl,
    required this.sniffRegistry,
    required this.onUrlChanged,
    required this.onTitleChanged,
    required this.controllerReady,
  });

  final String tabId;
  final String initialUrl;
  final SniffRegistry sniffRegistry;
  final ValueChanged<String> onUrlChanged;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<InAppWebViewController> controllerReady;

  @override
  State<WebViewPage> createState() => WebViewPageState();
}

class WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? _controller;
  bool _canGoBack = false;
  bool _canGoForward = false;

  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;

  Future<void> loadUrl(String url) async {
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
  }

  Future<void> goBack() async {
    if (await _controller?.canGoBack() ?? false) await _controller?.goBack();
  }

  Future<void> goForward() async {
    if (await _controller?.canGoForward() ?? false) await _controller?.goForward();
  }

  Future<void> reload() async => _controller?.reload();

  Future<void> _updateNavState() async {
    final back = await _controller?.canGoBack() ?? false;
    final forward = await _controller?.canGoForward() ?? false;
    if (mounted) setState(() { _canGoBack = back; _canGoForward = forward; });
  }

  void _registerUrl(String? url) {
    if (url == null || url.isEmpty || url == 'about:blank') return;
    if (SniffRegistry.isEv1Url(url)) widget.sniffRegistry.register(widget.tabId, url);
  }

  @override
  Widget build(BuildContext context) {
    final useMobileMode = shouldUseMobileBrowserMode(context);

    return InAppWebView(
      initialUrlRequest: widget.initialUrl == 'about:blank'
          ? null
          : URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: browserWebViewSettings(useMobileMode: useMobileMode),
      onWebViewCreated: (controller) async {
        _controller = controller;
        widget.controllerReady(controller);
        if (useMobileMode) {
          await controller.addUserScript(
            userScript: UserScript(
              source: mobileViewportScript,
              injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
            ),
          );
        }
        final sniffJs = await rootBundle.loadString('assets/injected_sniff.js');
        await controller.addUserScript(
          userScript: UserScript(
            source: sniffJs,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
        controller.addJavaScriptHandler(
          handlerName: 'ev1Detected',
          callback: (args) {
            if (args.isNotEmpty) widget.sniffRegistry.register(widget.tabId, args.first.toString());
            return null;
          },
        );
      },
      shouldInterceptRequest: (controller, request) async {
        _registerUrl(request.url.toString());
        return null;
      },
      shouldInterceptFetchRequest: (controller, request) async {
        _registerUrl(request.url.toString());
        return null;
      },
      shouldInterceptAjaxRequest: (controller, request) async {
        _registerUrl(request.url.toString());
        return null;
      },
      onLoadResource: (controller, resource) => _registerUrl(resource.url?.toString()),
      onLoadStart: (controller, url) {
        widget.onUrlChanged(url?.toString() ?? '');
        _updateNavState();
      },
      onLoadStop: (controller, url) async {
        widget.onUrlChanged(url?.toString() ?? '');
        final title = await controller.getTitle();
        if (title != null && title.isNotEmpty) widget.onTitleChanged(title);
        await _updateNavState();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) widget.onTitleChanged(title);
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        widget.onUrlChanged(url?.toString() ?? '');
        _updateNavState();
      },
    );
  }
}
