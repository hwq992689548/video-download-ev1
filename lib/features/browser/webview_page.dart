import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../core/beego_catalog.dart';
import '../../core/ev1_url.dart';
import '../../core/lesson_title.dart';
import '../../core/sniff_registry.dart';
import '../../core/sniff_title_log.dart';
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
  String? _sniffJs;
  var _domScrapeGen = 0;

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/injected_sniff.js').then((js) {
      if (mounted) setState(() => _sniffJs = js);
    });
  }

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

  void _logTraffic(String source, String? url) {
    if (url == null || url.isEmpty || url == 'about:blank') return;
    final lower = url.toLowerCase();
    if (SniffRegistry.isEv1Url(url) ||
        lower.contains('getplayurl') ||
        lower.contains('getplaytoken') ||
        lower.contains('listvideokeyframe') ||
        lower.contains('.m3u8') ||
        lower.contains('.mp4') ||
        lower.contains('.ev1') ||
        lower.contains('.ev2')) {
      sniffLog('traffic', '[$source] $url');
    }
  }

  void _registerUrl(
    String? url, {
    String? title,
    String source = 'unknown',
    Map<String, dynamic>? titleDebug,
  }) {
    if (url == null || url.isEmpty || url == 'about:blank') return;
    _logTraffic(source, url);
    if (!SniffRegistry.isSniffableUrl(url)) return;

    final catalogTitle = widget.sniffRegistry.lookupCatalogTitle(widget.tabId, url);

    sniffTitleLog(
      '_registerUrl [$source]\n'
      '  jsTitle=${title ?? "(null)"}\n'
      '  catalogTitle=${catalogTitle ?? "(null)"}\n'
      '  titleDebug=${titleDebug ?? "(none)"}\n'
      '  url=${url.length > 120 ? "${url.substring(0, 117)}..." : url}',
    );

    widget.sniffRegistry.register(
      widget.tabId,
      url,
      title: title,
      source: source,
    );
    _scheduleDomTitleScrape();
  }

  void _scheduleDomTitleScrape() {
    final controller = _controller;
    if (controller == null) return;
    final gen = ++_domScrapeGen;
    sniffTitleLog('dom-scrape scheduled gen=$gen');
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted || gen != _domScrapeGen) return;
      _scrapeDomTitle(controller);
    });
    Future<void>.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted || gen != _domScrapeGen) return;
      _scrapeDomTitle(controller);
    });
  }

  Future<void> _scrapeDomTitle(InAppWebViewController controller) async {
    try {
      final stems = widget.sniffRegistry
          .entriesFor(widget.tabId)
          .map((e) => BeegoCatalog.resourceStemFromUrl(e.url))
          .whereType<String>()
          .toSet()
          .toList();
      final playVid = widget.sniffRegistry.lastPlayVid(widget.tabId) ?? '';
      final payload = jsonEncode({'stems': stems, 'playVid': playVid});
      final source = '(${domLessonTitleScrapeJs.trim()})($payload)';
      sniffTitleLog('dom-scrape stems=$stems playVid=$playVid');
      final raw = await controller.evaluateJavascript(source: source);
      final parsed = parseDomLessonScrape(raw);
      sniffTitleLog(
        'dom-scrape chosen=${parsed.chosen ?? "(null)"} '
        'trial=${parsed.trial ?? "(null)"} '
        'byStem=${parsed.byStem} byVid=${parsed.byVid} '
        'debug=${parsed.debug}',
      );
      widget.sniffRegistry.applyDomLessonScrape(
        widget.tabId,
        parsed,
        source: 'dom-scrape',
      );
    } catch (e) {
      sniffTitleLog('dom-scrape failed: $e');
    }
  }

  Future<AjaxRequestAction?> _onAjaxReadyStateChange(
    InAppWebViewController controller,
    AjaxRequest ajaxRequest,
  ) async {
    final url = ajaxRequest.responseURL?.toString() ??
        ajaxRequest.url?.toString() ??
        '';

    if (url.contains('getPlayToken') || url.contains('getPlayUrl')) {
      widget.sniffRegistry.trackPlayVid(widget.tabId, url);
      _scheduleDomTitleScrape();
    }

    if (ajaxRequest.readyState == AjaxRequestReadyState.DONE &&
        ajaxRequest.status == 200) {
      final text = ajaxRequest.responseText;
      if (text != null && text.isNotEmpty) {
        if (BeegoCatalog.looksLikeCatalogJson(text)) {
          widget.sniffRegistry.ingestCatalog(
            widget.tabId,
            text,
            source: url.contains('findCourseCat') ? 'ajax-catalog' : 'ajax-json',
          );
        }
        final found = SniffRegistry.extractUrlsFromText(text);
        sniffLog(
          'ajax',
          'DONE $url status=${ajaxRequest.status} body=${text.length} ev=${found.length}',
        );
        for (final item in found) {
          _registerUrl(item, source: 'ajax-body');
        }
      }
    }

    return AjaxRequestAction.PROCEED;
  }

  @override
  Widget build(BuildContext context) {
    final useMobileMode = shouldUseMobileBrowserMode(context);
    final sniffJs = _sniffJs;
    if (sniffJs == null) {
      return const ColoredBox(
        color: Color(0xFFF2F1F6),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final userScripts = <UserScript>[
      if (useMobileMode)
        UserScript(
          source: mobileViewportScript,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: false,
          contentWorld: ContentWorld.PAGE,
        ),
      UserScript(
        source: sniffJs,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
        contentWorld: ContentWorld.PAGE,
      ),
    ];

    return InAppWebView(
      initialUrlRequest: widget.initialUrl == 'about:blank'
          ? null
          : URLRequest(url: WebUri(widget.initialUrl)),
      initialSettings: browserWebViewSettings(useMobileMode: useMobileMode),
      initialUserScripts: UnmodifiableListView(userScripts),
      onWebViewCreated: (controller) async {
        _controller = controller;
        widget.controllerReady(controller);
        sniffLog(
          'webview',
          'created tab=${widget.tabId} mobile=$useMobileMode '
          'ua=${browserUserAgent(useMobileMode: useMobileMode)} '
          'url=${widget.initialUrl}',
        );
        controller.addJavaScriptHandler(
          handlerName: 'sniffLog',
          callback: (args) {
            if (args.isEmpty) return null;
            sniffLog('js', args.first.toString());
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'playVid',
          callback: (args) {
            if (args.isEmpty) return null;
            final vid = args.first.toString();
            if (!RegExp(r'^\d{6,}$').hasMatch(vid)) return null;
            sniffTitleLog('playVid=$vid');
            widget.sniffRegistry.trackPlayVid(
              widget.tabId,
              'https://m.beegoedu.com/rest/mall/getPlayToken?vid=$vid',
            );
            _scheduleDomTitleScrape();
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'ev1Detected',
          callback: (args) {
            if (args.isEmpty) return null;
            final url = args.first.toString();
            final payload = args.length > 1 ? args[1].toString() : null;
            final parsed = parseSniffTitlePayload(payload);
            if (parsed.debug != null) {
              sniffTitleLog('JS title candidates: ${parsed.debug}');
            }
            _registerUrl(
              url,
              title: parsed.chosen,
              source: 'js-handler',
              titleDebug: parsed.debug,
            );
            _scheduleDomTitleScrape();
            return null;
          },
        );
        controller.addJavaScriptHandler(
          handlerName: 'catalogMap',
          callback: (args) {
            if (args.isEmpty) return null;
            widget.sniffRegistry.ingestVidTitleMap(
              widget.tabId,
              args.first.toString(),
              source: 'js-map',
            );
            return null;
          },
        );
      },
      shouldInterceptRequest: (controller, request) async {
        _registerUrl(request.url.toString(), source: 'intercept-request');
        return null;
      },
      shouldInterceptFetchRequest: (controller, request) async {
        final url = request.url.toString();
        final rewritten = Ev1Url.rewritePlayUrl(url);
        if (url.contains('getPlayToken') || rewritten.contains('getPlayUrl')) {
          widget.sniffRegistry.trackPlayVid(widget.tabId, rewritten);
          _scheduleDomTitleScrape();
        }
        _registerUrl(rewritten, source: 'intercept-fetch');
        if (rewritten != url) {
          sniffLog('rewrite', 'fetch $url -> $rewritten');
          request.url = WebUri(rewritten);
          return request;
        }
        return null;
      },
      shouldInterceptAjaxRequest: (controller, request) async {
        final url = request.url?.toString() ?? '';
        final rewritten = Ev1Url.rewritePlayUrl(url);
        if (url.contains('getPlayToken') || rewritten.contains('getPlayUrl')) {
          widget.sniffRegistry.trackPlayVid(widget.tabId, rewritten);
        }
        _registerUrl(rewritten, source: 'intercept-ajax');
        if (rewritten != url) {
          sniffLog('rewrite', 'ajax $url -> $rewritten');
          request.url = WebUri(rewritten);
          return request;
        }
        return null;
      },
      onAjaxReadyStateChange: _onAjaxReadyStateChange,
      onLoadResource: (controller, resource) =>
          _registerUrl(resource.url?.toString(), source: 'load-resource'),
      onLoadStart: (controller, url) {
        sniffLog('webview', 'loadStart ${url?.toString() ?? ''}');
        widget.onUrlChanged(url?.toString() ?? '');
        _updateNavState();
      },
      onLoadStop: (controller, url) async {
        widget.onUrlChanged(url?.toString() ?? '');
        final title = await controller.getTitle();
        if (title != null && title.isNotEmpty) {
          sniffTitleLog('onLoadStop pageTitle=$title url=${url?.toString() ?? ""}');
          widget.onTitleChanged(title);
          widget.sniffRegistry.backfillMissingTitles(
            widget.tabId,
            title,
            source: 'onLoadStop',
          );
        }
        await _updateNavState();
        _scheduleDomTitleScrape();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          sniffTitleLog('onTitleChanged pageTitle=$title');
          widget.onTitleChanged(title);
          widget.sniffRegistry.backfillMissingTitles(
            widget.tabId,
            title,
            source: 'onTitleChanged',
          );
        }
      },
      onUpdateVisitedHistory: (controller, url, isReload) {
        widget.onUrlChanged(url?.toString() ?? '');
        _updateNavState();
      },
    );
  }
}
