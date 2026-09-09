import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/sniff_registry.dart';
import '../../theme/app_theme.dart';
import 'address_bar.dart';
import 'browser_tab_bar.dart';
import 'sniff_panel.dart';
import 'webview_page.dart';

class BrowserTabScreen extends ConsumerStatefulWidget {
  const BrowserTabScreen({super.key});

  @override
  ConsumerState<BrowserTabScreen> createState() => _BrowserTabScreenState();
}

class _BrowserTabScreenState extends ConsumerState<BrowserTabScreen> {
  final _webViewKeys = <String, GlobalKey<WebViewPageState>>{};
  bool _showSniffPanel = false;

  GlobalKey<WebViewPageState> _keyFor(String tabId) =>
      _webViewKeys.putIfAbsent(tabId, GlobalKey<WebViewPageState>.new);

  WebViewPageState? get _activeWebView {
    final tab = ref.read(browserTabStoreProvider).activeTab;
    return _webViewKeys[tab.id]?.currentState;
  }

  void _navigate(String url) {
    final store = ref.read(browserTabStoreProvider);
    store.updateTab(store.activeTab.id, url: url);
    _activeWebView?.loadUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(browserTabStoreProvider);
    final sniffRegistry = ref.watch(sniffRegistryProvider);
    final videos = ref.watch(allVideosStreamProvider).value ?? [];
    final videoRepo = ref.watch(videoRepositoryProvider);
    final activeTab = store.activeTab;
    final webView = _activeWebView;
    final sniffCount = sniffRegistry.entriesFor(activeTab.id).where((e) {
      if (e.status != SniffStatus.pending) return false;
      return videoRepo.findByEv1UrlIn(videos, e.url) == null;
    }).length;

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        children: [
          ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: BrowserTabBar(
                sniffCount: sniffCount,
                onSniff: () =>
                    setState(() => _showSniffPanel = !_showSniffPanel),
              ),
            ),
          ),
          AddressBar(
            currentUrl: activeTab.url == 'about:blank' ? '' : activeTab.url,
            canGoBack: webView?.canGoBack ?? false,
            canGoForward: webView?.canGoForward ?? false,
            onBack: () => webView?.goBack(),
            onForward: () => webView?.goForward(),
            onRefresh: () => webView?.reload(),
            onSubmit: _navigate,
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                IndexedStack(
                  index: store.activeIndex,
                  children: [
                    for (final tab in store.tabs)
                      WebViewPage(
                        key: _keyFor(tab.id),
                        tabId: tab.id,
                        initialUrl: tab.url,
                        sniffRegistry: sniffRegistry,
                        onUrlChanged: (url) => ref.read(browserTabStoreProvider).updateTab(
                              tab.id,
                              url: url.isEmpty ? 'about:blank' : url,
                            ),
                        onTitleChanged: (title) =>
                            ref.read(browserTabStoreProvider).updateTab(tab.id, title: title),
                        controllerReady: (_) {},
                      ),
                  ],
                ),
                if (_showSniffPanel)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SniffPanel(
                      tabId: activeTab.id,
                      onClose: () => setState(() => _showSniffPanel = false),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
