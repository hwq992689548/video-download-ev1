(function () {
  if (window.__ev1SniffInstalled) return;
  window.__ev1SniffInstalled = true;

  const seen = new Set();

  function isEv1(url) {
    return typeof url === 'string' && /\.ev1(\?|#|$)/i.test(url);
  }

  function notify(url) {
    if (!url || !isEv1(url) || seen.has(url)) return;
    seen.add(url);

    function post() {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('ev1Detected', url);
        return true;
      }
      return false;
    }

    if (!post()) {
      window.addEventListener('flutterInAppWebViewPlatformReady', function onReady() {
        window.removeEventListener('flutterInAppWebViewPlatformReady', onReady);
        post();
      });
    }
  }

  function check(url) {
    if (url == null) return;
    notify(String(url));
  }

  function scanDom() {
    document.querySelectorAll('video, source, a, iframe').forEach(function (el) {
      check(el.src || el.currentSrc);
      check(el.getAttribute('href'));
      check(el.getAttribute('data-src'));
      check(el.getAttribute('data-url'));
    });
  }

  function scanPerformance() {
    if (!window.performance || !performance.getEntriesByType) return;
    performance.getEntriesByType('resource').forEach(function (entry) {
      check(entry.name);
    });
  }

  const origFetch = window.fetch;
  window.fetch = function (...args) {
    const input = args[0];
    if (typeof input === 'string') {
      check(input);
    } else if (input && input.url) {
      check(input.url);
    }
    return origFetch.apply(this, args);
  };

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (_method, url) {
    check(String(url));
    return origOpen.apply(this, arguments);
  };

  const srcDescriptor = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'src');
  if (srcDescriptor && srcDescriptor.set) {
    Object.defineProperty(HTMLMediaElement.prototype, 'src', {
      configurable: true,
      enumerable: srcDescriptor.enumerable,
      get: srcDescriptor.get,
      set: function (value) {
        check(value);
        return srcDescriptor.set.call(this, value);
      },
    });
  }

  if (window.PerformanceObserver) {
    try {
      const observer = new PerformanceObserver(function (list) {
        list.getEntries().forEach(function (entry) {
          check(entry.name);
        });
      });
      observer.observe({ type: 'resource', buffered: true });
    } catch (_e) {
      /* ignore */
    }
  }

  const mutationObserver = new MutationObserver(function () {
    scanDom();
  });

  mutationObserver.observe(document.documentElement, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['src', 'href', 'data-src', 'data-url'],
  });

  scanDom();
  scanPerformance();
  setInterval(function () {
    scanDom();
    scanPerformance();
  }, 2000);
})();
