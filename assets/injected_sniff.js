(function () {
  if (window.__ev1SniffInstalled) return;
  window.__ev1SniffInstalled = true;

  const urlTitles = new Map();
  const vidTitles = {};
  const seenUrls = [];
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
      try {
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('playVid', lastPlayVid);
        }
      } catch (_e) {}
    }
  }

  const WEAK_TITLES = {
    '商品详情': 1, '课程详情': 1, '首页': 1, '必过': 1, '录播': 1, '直播': 1,
    '正在播放': 1, '试看': 1, '预览': 1, '高清': 1, '超清': 1, '标清': 1,
    '流畅': 1, 'loading': 1, 'Loading...': 1, '新标签页': 1,
  };

  function hasCjk(text) {
    return /[\u4e00-\u9fff]/.test(text);
  }

  function isWeakTitle(text) {
    const t = cleanText(text);
    if (!t || t.length < 2 || t.length > 80) return true;
    if (WEAK_TITLES[t]) return true;
    if (/必过学习平台/.test(t)) return true;
    if (/单科基础班/.test(t) || /班$/.test(t)) return true;
    if (/^[￥¥]/.test(t)) return true;
    if (/^线路\s*\d*$/.test(t)) return true;
    if (!hasCjk(t)) return true;
    return false;
  }

  function titleScore(text) {
    const t = cleanText(text);
    if (isWeakTitle(t)) return 0;
    var score = Math.min(t.length, 80);
    if (/第[0-9一二三四五六七八九十百千万]+[章节讲]/.test(t)) score += 80;
    if (t.length >= 4 && t.length <= 40) score += 40;
    return score;
  }

  function firstSelectorText(selectors) {
    for (var i = 0; i < selectors.length; i++) {
      try {
        const el = document.querySelector(selectors[i]);
        if (!el) continue;
        const text = cleanText(el.getAttribute('title') || el.innerText || el.textContent);
        if (!isWeakTitle(text)) return text.slice(0, 80);
      } catch (_e) {}
    }
    return '';
  }

  function titleFromVidAttr(vid) {
    if (!vid) return '';
    const selectors = [
      '[data-vid="' + vid + '"]',
      '[data-videoid="' + vid + '"]',
      '[data-pvid="' + vid + '"]',
      '[data-pvideoid="' + vid + '"]',
      '[vid="' + vid + '"]',
    ];
    for (var i = 0; i < selectors.length; i++) {
      try {
        const el = document.querySelector(selectors[i]);
        if (!el) continue;
        const text = cleanText(
          el.getAttribute('title') ||
          el.getAttribute('data-name') ||
          el.getAttribute('data-title') ||
          el.innerText ||
          el.textContent,
        );
        if (!isWeakTitle(text)) return text.slice(0, 80);
      } catch (_e) {}
    }
    return '';
  }

  function videoLabel() {
    try {
      const el = document.querySelector('video');
      if (!el) return '';
      const text = cleanText(
        el.getAttribute('title') ||
        el.getAttribute('aria-label') ||
        (el.parentElement && el.parentElement.getAttribute('title')) ||
        '',
      );
      return isWeakTitle(text) ? '' : text.slice(0, 80);
    } catch (_e) {
      return '';
    }
  }

  function collectFromVue() {
    const names = [];
    const seen = [];
    function readName(obj) {
      if (!obj || typeof obj !== 'object') return '';
      return cleanText(obj.catName || obj.videoName || obj.videoname || obj.name || obj.title || '');
    }
    function consider(obj) {
      const text = readName(obj);
      if (text && !isWeakTitle(text)) names.push(text.slice(0, 80));
    }
    function walkEl(el, depth) {
      if (!el || depth > 6 || names.length >= 8 || seen.length > 30) return;
      const inst = el.__vue__ || el.__vueParentComponent;
      if (inst && seen.indexOf(inst) < 0) {
        seen.push(inst);
        const data = inst.$data || inst.ctx || inst.setupState || {};
        const keys = ['currentCat', 'currentNode', 'playingCat', 'currentVideo', 'curCat', 'selectCat', 'activeCat'];
        for (var i = 0; i < keys.length; i++) {
          consider(inst[keys[i]]);
          consider(data[keys[i]]);
        }
      }
      const children = el.children || [];
      for (var j = 0; j < children.length && j < 12; j++) walkEl(children[j], depth + 1);
    }
    try {
      if (document.body) walkEl(document.body, 0);
    } catch (_e) {}
    return names[0] || '';
  }

  function pickBest(values) {
    var chosen = '';
    var best = 0;
    for (var i = 0; i < values.length; i++) {
      const score = titleScore(values[i]);
      if (score > best) {
        best = score;
        chosen = cleanText(values[i]);
      }
    }
    return chosen;
  }

  function scrapeTrialTitle() {
    try {
      const nodes = document.querySelectorAll('div,span,p,li,label,em,strong,h1,h2,h3,h4,h5');
      for (var i = 0; i < nodes.length; i++) {
        const raw = String(nodes[i].innerText || nodes[i].textContent || '');
        if (raw.length > 120) continue;
        const block = cleanText(raw);
        const m = block.match(/^当前试听[：:]?\s*(.*)$/);
        if (!m) continue;
        var t = cleanText(m[1]).split('\n')[0];
        if (t.length >= 2 && t.length <= 40 && t.indexOf('当前试听') < 0 && !isWeakTitle(t)) {
          return t;
        }
        const next = nodes[i].nextElementSibling;
        if (next) {
          t = cleanText(next.innerText || next.textContent || '').split('\n')[0];
          if (t.length >= 2 && t.length <= 40 && !isWeakTitle(t)) return t;
        }
        const parent = nodes[i].parentElement;
        if (parent) {
          const pm = String(parent.innerText || '').match(/当前试听[：:][\s\u00a0]*\n?\s*([^\n]{2,40})/);
          if (pm) {
            t = cleanText(pm[1]);
            if (t.length >= 2 && t.length <= 40 && !isWeakTitle(t)) return t;
          }
        }
      }
    } catch (_e) {}
    try {
      const body = String((document.body && document.body.innerText) || '');
      const bm = body.match(/当前试听[：:][\s\u00a0]*\n?\s*([^\n]{2,40})/);
      if (bm) {
        const t = cleanText(bm[1]);
        if (t.length >= 2 && t.length <= 40 && !isWeakTitle(t)) return t;
      }
    } catch (_b) {}
    return '';
  }

  function scanLessonTitles() {
    const headingRe = /第[0-9一二三四五六七八九十百千万]+[章节讲]\s*\S.{0,40}/;
    const found = [];
    function add(text) {
      const t = cleanText(text).split('\n')[0];
      if (!t || t.length > 50 || !headingRe.test(t)) return;
      if (found.indexOf(t) < 0) found.push(t);
    }
    try {
      document.querySelectorAll('div,span,p,li,a,h1,h2,h3,h4,h5,label,td,em,strong').forEach(function (el) {
        if (found.length >= 12) return;
        if (el.childElementCount > 2) return;
        add(el.textContent);
      });
    } catch (_e) {}
    var playing = '';
    try {
      document.querySelectorAll('[class*="play"],[class*="active"],[class*="current"],[class*="select"],[class*="on"]').forEach(function (el) {
        if (playing) return;
        const t = cleanText((el.innerText || el.textContent || '').split('\n')[0]);
        if (headingRe.test(t) && t.length <= 50) playing = t;
      });
    } catch (_e2) {}
    return { playing: playing, matches: found };
  }

  function collectTitleInfo(forUrl) {
    const playVid = extractVidFromUrl(forUrl || '') || lastPlayVid;
    const trial = scrapeTrialTitle();
    const lesson = scanLessonTitles();
    var mergedTrial = trial;
    if (trial) {
      for (var i = 0; i < lesson.matches.length; i++) {
        if (lesson.matches[i].indexOf(trial) >= 0) {
          mergedTrial = lesson.matches[i];
          break;
        }
      }
      if (playVid) vidTitles[playVid] = mergedTrial;
    }
    const candidates = {
      mapped: (playVid && vidTitles[playVid]) || '',
      dataVid: titleFromVidAttr(playVid),
      trial: mergedTrial || '',
      vue: collectFromVue(),
      videoEl: videoLabel(),
    };
    return {
      playVid: playVid,
      chosen: pickBest([
        candidates.mapped,
        candidates.dataVid,
        candidates.trial,
        candidates.vue,
        candidates.videoEl,
      ]),
      candidates: candidates,
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

    if (seenUrls.indexOf(url) < 0) seenUrls.push(url);

    const titleInfo = collectTitleInfo(url);
    const chosen = titleInfo.chosen || '';
    const prev = urlTitles.get(url);
    if (prev !== undefined && chosen === prev) return;
    urlTitles.set(url, chosen);
    jsLog(kind + ' detected ' + url);

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

  function tryParseJson(text) {
    const trimmed = String(text || '').trim();
    if (!trimmed) return null;
    try { return JSON.parse(trimmed); } catch (_e) {}
    const startObj = trimmed.indexOf('{');
    const startArr = trimmed.indexOf('[');
    var from = startObj;
    if (from < 0 || (startArr >= 0 && startArr < from)) from = startArr;
    if (from < 0) return null;
    const endChar = trimmed.charAt(from) === '[' ? ']' : '}';
    const end = trimmed.lastIndexOf(endChar);
    if (end <= from) return null;
    try { return JSON.parse(trimmed.slice(from, end + 1)); } catch (_e2) {
      return null;
    }
  }

  function vidFromNode(node) {
    if (!node || typeof node !== 'object') return '';
    const keys = ['pvideoId', 'pVideoId', 'videoid', 'videoId', 'video_id', 'vid'];
    for (var i = 0; i < keys.length; i++) {
      const value = String(node[keys[i]] || '').trim();
      if (/^\d{6,}$/.test(value)) return value;
    }
    return '';
  }

  function nameFromNode(node) {
    if (!node || typeof node !== 'object') return '';
    const keys = ['catName', 'videoName', 'videoname', 'pptName', 'lessonName', 'title', 'name'];
    for (var i = 0; i < keys.length; i++) {
      const value = cleanText(node[keys[i]]);
      if (value && !isWeakTitle(value)) return value.slice(0, 80);
    }
    return '';
  }

  function walkCatalog(node, out) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length; i++) walkCatalog(node[i], out);
      return;
    }
    const vid = vidFromNode(node);
    const name = nameFromNode(node);
    if (vid && name) out[vid] = name;
    const keys = Object.keys(node);
    for (var j = 0; j < keys.length; j++) {
      const value = node[keys[j]];
      if (value && typeof value === 'object') walkCatalog(value, out);
    }
  }

  function postCatalogMap(map) {
    const keys = Object.keys(map);
    if (!keys.length) return;
    var added = 0;
    for (var i = 0; i < keys.length; i++) {
      const vid = keys[i];
      if (vidTitles[vid] === map[vid]) continue;
      vidTitles[vid] = map[vid];
      added++;
    }
    if (!added) return;
    try {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('catalogMap', JSON.stringify(map));
      }
    } catch (_e) {}
    const urls = seenUrls.slice(-20);
    for (var k = 0; k < urls.length; k++) notify(urls[k]);
  }

  function collectPageCatalog() {
    const map = {};
    const seen = [];
    function walkValue(obj, depth) {
      if (!obj || typeof obj !== 'object' || depth > 10) return;
      if (seen.indexOf(obj) >= 0) return;
      seen.push(obj);
      walkCatalog(obj, map);
    }
    function walkEl(el, depth) {
      if (!el || depth > 8) return;
      const inst = el.__vue__ || el.__vueParentComponent;
      if (inst) {
        walkValue(inst.$data, 0);
        walkValue(inst.ctx, 0);
        walkValue(inst.setupState, 0);
        walkValue(inst.childList, 0);
        walkValue(inst.catList, 0);
      }
      const children = el.children || [];
      for (var j = 0; j < children.length && j < 20; j++) walkEl(children[j], depth + 1);
    }
    try { if (document.body) walkEl(document.body, 0); } catch (_e) {}
    try {
      document.querySelectorAll('[data-vid],[data-videoid],[data-pvid],[data-pvideoid],[vid]').forEach(function (el) {
        const attrs = ['data-vid', 'data-videoid', 'data-pvid', 'data-pvideoid', 'vid'];
        var vid = '';
        for (var i = 0; i < attrs.length; i++) {
          const value = String(el.getAttribute(attrs[i]) || '').trim();
          if (/^\d{6,}$/.test(value)) { vid = value; break; }
        }
        if (!vid) return;
        const text = cleanText(
          el.getAttribute('title') ||
          el.getAttribute('data-name') ||
          el.getAttribute('data-title') ||
          el.innerText ||
          el.textContent,
        ).split('\n')[0];
        if (!isWeakTitle(text)) map[vid] = text.slice(0, 80);
      });
    } catch (_d) {}
    postCatalogMap(map);
  }

  function extractFromText(text) {
    if (!text || typeof text !== 'string' || text.length > 2000000) return;
    const decoded = text.replace(/\\\//g, '/');
    EV_URL_RE.lastIndex = 0;
    let match;
    while ((match = EV_URL_RE.exec(decoded))) {
      check(match[0]);
    }
    if (/pvideoId|catName|videoName|videoname|pptName/.test(decoded)) {
      const json = tryParseJson(decoded);
      if (json) {
        const map = {};
        walkCatalog(json, map);
        postCatalogMap(map);
      }
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
  collectPageCatalog();
  setInterval(function () {
    scanDom();
    scanPerformance();
    collectPageCatalog();
  }, 2000);
})();
