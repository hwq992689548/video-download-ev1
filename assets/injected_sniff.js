(function () {
  if (window.__ev1SniffInstalled) return;
  window.__ev1SniffInstalled = true;

  const urlTitles = new Map();
  let lastPlayVid = '';

  function isSniffableVideo(url) {
    if (typeof url !== 'string') return false;
    if (/\.ev[12](\?|#|$)/i.test(url)) return true;
    return /baijiayun\.com/i.test(url) &&
      /\/video\/\d{6,}_[^/?#]+\.(mp4|m3u8)(\?|#|$)/i.test(url);
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

  function jsLog(message) {
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('sniffLog', message);
      }
    } catch (_e) {}
  }

  jsLog('sniff script installed href=' + String(location.href || ''));

  function notify(url) {
    if (!url || !isSniffableVideo(url)) return;
    var kind = 'mp4';
    if (/\.ev[12](\?|#|$)/i.test(url)) kind = 'ev';
    else if (/\.m3u8(\?|#|$)/i.test(url)) kind = 'm3u8';
    jsLog(kind + ' detected ' + url);

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

  function rewritePlayUrl(url) {
    if (typeof url !== 'string' || url.indexOf('getPlayUrl') === -1) return url;
    var next = url.replace(/([?&]client_type=)h5\b/i, '$1pc');
    if (/[?&]supports_format=/i.test(next) && !/[?&]supports_format=[^&]*ev/i.test(next)) {
      next = next.replace(/([?&]supports_format=)([^&]*)/i, '$1ev1,ev2,$2');
    }
    if (next !== url) jsLog('rewrite getPlayUrl -> ' + next);
    wrapJsonpCallback(next);
    probeEvPlayUrl(next);
    return next;
  }

  function wrapJsonpCallback(url) {
    const match = String(url).match(/[?&]callback=([^&]+)/i);
    if (!match) return;
    const name = decodeURIComponent(match[1]);
    if (!name || window['__ev1Wrapped_' + name]) return;
    window['__ev1Wrapped_' + name] = true;
    let current = window[name];
    function wrapped(data) {
      try {
        const text = typeof data === 'string' ? data : JSON.stringify(data);
        jsLog('jsonp ' + name + ' ' + text.slice(0, 1200));
        extractFromText(text);
      } catch (_e) {}
      if (typeof current === 'function') return current.apply(this, arguments);
    }
    try {
      Object.defineProperty(window, name, {
        configurable: true,
        enumerable: true,
        get: function () { return wrapped; },
        set: function (fn) { current = fn; },
      });
    } catch (_e) {
      window[name] = wrapped;
    }
  }

  const probedEv = {};
  function probeEvPlayUrl(url) {
    try {
      const parsed = new URL(url, location.href);
      if (parsed.pathname.indexOf('getPlayUrl') === -1) return;
      const key = parsed.searchParams.get('vid') + '|' + (parsed.searchParams.get('token') || '');
      if (!parsed.searchParams.get('vid') || probedEv[key]) return;
      probedEv[key] = true;
      parsed.searchParams.set('client_type', 'pc');
      parsed.searchParams.set('supports_format', 'ev1,ev2');
      parsed.searchParams.set('render', 'json');
      parsed.searchParams.delete('callback');
      const probe = parsed.toString();
      jsLog('probe ev ' + probe);
      origFetch(probe).then(function (response) {
        return response.text();
      }).then(function (text) {
        jsLog('probe ev body ' + String(text).slice(0, 1200));
        extractFromText(text);
      }).catch(function (err) {
        jsLog('probe ev fail ' + err);
      });
    } catch (err) {
      jsLog('probe ev error ' + err);
    }
  }

  function check(url) {
    if (url == null) return;
    const s = String(url);
    trackPlayVid(s);
    if (/getPlayToken|getPlayUrl|listVideoKeyFrame|\.m3u8|\.mp4|\.ev[12]/i.test(s)) {
      jsLog('check ' + s);
    }
    notify(s);
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
      args[0] = rewritePlayUrl(input);
      check(args[0]);
    } else if (input && input.url) {
      const rewritten = rewritePlayUrl(input.url);
      if (rewritten !== input.url && typeof Request === 'function') {
        try {
          args[0] = new Request(rewritten, input);
        } catch (_e) {}
      }
      check(rewritten);
    }
    return origFetch.apply(this, args).then(function (response) {
      try {
        const clone = response.clone();
        clone.text().then(extractFromText).catch(function () {});
      } catch (_e) {}
      return response;
    });
  };

  const origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function (_method, url) {
    const next = rewritePlayUrl(String(url));
    arguments[1] = next;
    check(next);
    this.addEventListener('load', function () {
      try {
        extractFromText(this.responseText);
      } catch (_e) {}
    });
    return origOpen.apply(this, arguments);
  };

  const origSetAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function (name, value) {
    if (name && String(name).toLowerCase() === 'src') {
      value = rewritePlayUrl(String(value));
      check(value);
    }
    return origSetAttribute.call(this, name, value);
  };

  const scriptSrc = Object.getOwnPropertyDescriptor(HTMLScriptElement.prototype, 'src');
  if (scriptSrc && scriptSrc.set) {
    Object.defineProperty(HTMLScriptElement.prototype, 'src', {
      configurable: true,
      enumerable: scriptSrc.enumerable,
      get: scriptSrc.get,
      set: function (value) {
        const next = rewritePlayUrl(String(value));
        check(next);
        return scriptSrc.set.call(this, next);
      },
    });
  }

  const EV_URL_RE = /https?:\/\/[^\s"'<>\\]+?\.ev[12](?:\?[^\s"'<>\\]*)?/gi;

  function extractFromText(text) {
    if (!text || typeof text !== 'string' || text.length > 2000000) return;
    const decoded = text.replace(/\\\//g, '/');
    EV_URL_RE.lastIndex = 0;
    let match;
    while ((match = EV_URL_RE.exec(decoded))) {
      check(match[0]);
    }
  }

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
