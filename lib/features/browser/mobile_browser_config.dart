import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Whether the app is running on a phone/tablet target.
bool get isMobileBrowserTarget {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

String mobileUserAgent() {
  if (!kIsWeb && Platform.isIOS) {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1';
  }
  return 'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
}

/// Ensures pages without viewport meta still scale to device width.
const mobileViewportScript = '''
(function () {
  if (document.querySelector('meta[name="viewport"]')) return;
  var meta = document.createElement('meta');
  meta.name = 'viewport';
  meta.content = 'width=device-width, initial-scale=1.0, viewport-fit=cover';
  (document.head || document.documentElement).appendChild(meta);
})();
''';

String desktopChromeUserAgent() {
  return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
}

String browserUserAgent({required bool useMobileMode}) {
  return useMobileMode ? mobileUserAgent() : desktopChromeUserAgent();
}

InAppWebViewSettings browserWebViewSettings({required bool useMobileMode}) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    useOnLoadResource: true,
    useShouldInterceptAjaxRequest: true,
    useShouldInterceptFetchRequest: true,
    useShouldInterceptRequest: true,
    allowsInlineMediaPlayback: true,
    mediaPlaybackRequiresUserGesture: false,
    userAgent: browserUserAgent(useMobileMode: useMobileMode),
    preferredContentMode: useMobileMode
        ? UserPreferredContentMode.MOBILE
        : UserPreferredContentMode.RECOMMENDED,
    useWideViewPort: true,
    loadWithOverviewMode: true,
    supportZoom: true,
    builtInZoomControls: useMobileMode,
    displayZoomControls: false,
    textZoom: 100,
    disableHorizontalScroll: false,
    verticalScrollBarEnabled: true,
    horizontalScrollBarEnabled: false,
  );
}

bool shouldUseMobileBrowserMode(BuildContext context) {
  return isMobileBrowserTarget || MediaQuery.sizeOf(context).width < 600;
}
