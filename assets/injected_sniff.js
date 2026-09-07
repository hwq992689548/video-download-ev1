(function () {
  if (window.__ev1SniffInstalled) return;
  window.__ev1SniffInstalled = true;

  const urlTitles = new Map();
  let lastPlayVid = '';

  function isSniffableVideo(url) {
    return typeof url === 'string' && /\.ev[12](\?|#|$)/i.test(url);
  }

  function cleanText(value) {
    return String(value || '')
      .replace(/\u00a0/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function extractVidFromUrl(url) {
    const s = String(url || '');
    const fromQuery = s.match(/[?&]vid=(\d+)/i);
    if (fromQuery) return fromQuery[1];
    const fromPath = s.match(/\/(\d{6,})_/);
    if (fromPath) return fromPath[1];
    const fromFile = s.match(/\/(\d{6,})\.ev[12]/i);
    if (fromFile) return fromFile[1];
    return '';
  }

  function trackPlayVid(url) {
    const s = String(url || '');
    const match = s.match(/[?&]vid=(\d+)/i);
    if (!match) return;
    if (/getPlayToken|getPlayUrl|listVideoKeyFrame/i.test(s)) {
      lastPlayVid = match[1];
    }
  }

  function collectTitleInfo(forUrl) {
    return {
      playVid: extractVidFromUrl(forUrl || '') || lastPlayVid,
      chosen: '',
    };
  }

  function notify(url) {
    if (!url || !isSniffableVideo(url)) return;

    const titleInfo = collectTitleInfo(url);
    const chosen = titleInfo.chosen || '';
    const prev = urlTitles.get(url);
    if (prev !== undefined && chosen === prev) return;
    urlTitles.set(url, chosen);

    function post() {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler(
          'ev1Detected',
          url,
          JSON.stringify(titleInfo),
        );
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
    trackPlayVid(url);
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
