import 'dart:convert';

/// Lesson headings as shown on Beego, e.g. `第一节 政治经济学的产生和发展`.
final lessonHeadingPattern = RegExp(
  r'第[0-9一二三四五六七八九十百千万]+[章节讲]\s*\S.{0,40}',
);

bool looksLikeLessonTitle(String? text) {
  if (text == null) return false;
  final t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.length < 4 || t.length > 80) return false;
  if (t.contains('必过学习平台') || t.contains('商品详情')) return false;
  if (t.contains('单科基础班') || RegExp(r'班$').hasMatch(t)) return false;
  if (lessonHeadingPattern.hasMatch(t)) return true;
  return RegExp(r'[\u4e00-\u9fff]').hasMatch(t);
}

String? pickLessonTitle({
  String? trial,
  String? playing,
  List<String> matches = const [],
}) {
  final mergedTrial = mergeTrialWithSection(trial, [
    if (playing != null && playing.trim().isNotEmpty) playing,
    ...matches,
  ]);
  if (mergedTrial != null) return mergedTrial;
  if (looksLikeLessonTitle(playing)) {
    return playing!.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  for (final item in matches) {
    if (looksLikeLessonTitle(item)) {
      return item.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
  }
  return null;
}

/// Prefer `第3节 政治经济学的研究任务` when the trial bar only has the short name.
String? mergeTrialWithSection(String? trial, List<String> matches) {
  if (trial == null) return null;
  final t = trial.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  for (final item in matches) {
    final m = item.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (m.contains(t) && lessonHeadingPattern.hasMatch(m)) return m;
  }
  return looksLikeLessonTitle(t) ? t : null;
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.value != null && entry.value.toString().trim().isNotEmpty)
        entry.key.toString(): entry.value.toString().trim(),
  };
}

class DomLessonScrape {
  const DomLessonScrape({
    this.chosen,
    this.trial,
    this.byVid = const {},
    this.byStem = const {},
    this.debug = const {},
  });

  final String? chosen;
  final String? trial;
  final Map<String, String> byVid;
  final Map<String, String> byStem;
  final Map<String, dynamic> debug;
}

DomLessonScrape parseDomLessonScrape(Object? raw) {
  if (raw == null) return const DomLessonScrape();
  Object? decoded = raw;
  if (decoded is String) {
    var text = decoded.trim();
    if (text.isEmpty || text == 'null') return const DomLessonScrape();
    if (text.startsWith('"') || text.startsWith('{')) {
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = text;
      }
    }
  }
  if (decoded is String && decoded.trim().startsWith('{')) {
    try {
      decoded = jsonDecode(decoded);
    } catch (_) {
      /* keep string */
    }
  }
  if (decoded is! Map) {
    return DomLessonScrape(debug: {'raw': raw.toString()});
  }
  final map = Map<String, dynamic>.from(decoded);
  final matches = <String>[
    if (map['matches'] is List)
      for (final item in map['matches'] as List)
        if (item != null) item.toString(),
  ];
  final trial = map['trial']?.toString();
  return DomLessonScrape(
    trial: trial,
    chosen: pickLessonTitle(
      trial: trial,
      playing: map['playing']?.toString(),
      matches: matches,
    ),
    byVid: _stringMap(map['byVid']),
    byStem: _stringMap(map['byStem']),
    debug: map,
  );
}

/// Function({stems, playVid}) — bind 当前试听 to CDN vid/stem prefix.
const domLessonTitleScrapeJs = r'''
function (opts) {
  function clean(s) {
    return String(s || '').replace(/\u00a0/g, ' ').replace(/\s+/g, ' ').trim();
  }
  opts = opts || {};
  var stems = Array.isArray(opts) ? opts : (opts.stems || []);
  var playVid = Array.isArray(opts) ? '' : String(opts.playVid || '');
  var headingRe = /第[0-9一二三四五六七八九十百千万]+[章节讲]\s*\S.{0,40}/;
  var found = [];
  function add(text) {
    var t = clean(text).split('\n')[0];
    if (!t || t.length > 50) return;
    if (!headingRe.test(t)) return;
    if (found.indexOf(t) < 0) found.push(t);
  }
  function scrapeTrial() {
    try {
      var nodes = document.querySelectorAll('div,span,p,li,label,em,strong,h1,h2,h3,h4,h5');
      for (var i = 0; i < nodes.length; i++) {
        var raw = String(nodes[i].innerText || nodes[i].textContent || '');
        if (raw.length > 120) continue;
        var block = clean(raw);
        var m = block.match(/^当前试听[：:]?\s*(.*)$/);
        if (!m) continue;
        var t = clean(m[1]).split('\n')[0];
        if (t.length >= 2 && t.length <= 40 && t.indexOf('当前试听') < 0) return t;
        var next = nodes[i].nextElementSibling;
        if (next) {
          t = clean(next.innerText || next.textContent || '').split('\n')[0];
          if (t.length >= 2 && t.length <= 40) return t;
        }
        var parent = nodes[i].parentElement;
        if (parent) {
          var pm = String(parent.innerText || '').match(/当前试听[：:][\s\u00a0]*\n?\s*([^\n]{2,40})/);
          if (pm) {
            t = clean(pm[1]);
            if (t.length >= 2 && t.length <= 40) return t;
          }
        }
      }
    } catch (_t) {}
    try {
      var body = String((document.body && document.body.innerText) || '');
      var bm = body.match(/当前试听[：:][\s\u00a0]*\n?\s*([^\n]{2,40})/);
      if (bm) {
        var bt = clean(bm[1]);
        if (bt.length >= 2 && bt.length <= 40) return bt;
      }
    } catch (_b) {}
    return '';
  }
  var trial = scrapeTrial();
  try {
    var nodes = document.querySelectorAll('div,span,p,li,a,h1,h2,h3,h4,h5,label,td,button,em,strong');
    for (var n = 0; n < nodes.length && found.length < 20; n++) {
      if (nodes[n].childElementCount > 2) continue;
      add(nodes[n].textContent);
    }
  } catch (_e) {}
  var playing = '';
  if (trial) {
    for (var fi = 0; fi < found.length; fi++) {
      if (found[fi].indexOf(trial) >= 0) {
        playing = found[fi];
        break;
      }
    }
  }
  var title = playing || trial;
  var byVid = {};
  var byStem = {};
  function vidFrom(obj) {
    if (!obj || typeof obj !== 'object') return '';
    var keys = ['pvideoId', 'pVideoId', 'videoid', 'videoId', 'video_id', 'vid'];
    for (var i = 0; i < keys.length; i++) {
      var v = String(obj[keys[i]] || '').trim();
      if (/^\d{6,}$/.test(v)) return v;
    }
    return '';
  }
  function nameFrom(obj) {
    if (!obj || typeof obj !== 'object') return '';
    var keys = ['catName', 'videoName', 'videoname', 'pptName', 'lessonName', 'title', 'name'];
    for (var i = 0; i < keys.length; i++) {
      var t = clean(obj[keys[i]]);
      if (t.length < 2 || t.length > 50) continue;
      if (t.indexOf('班') >= 0 || t.indexOf('必过') >= 0) continue;
      if (!/[\u4e00-\u9fff]/.test(t)) continue;
      return t;
    }
    return '';
  }
  function walkCatalog(node, depth) {
    if (!node || typeof node !== 'object' || depth > 14) return;
    if (Array.isArray(node)) {
      for (var i = 0; i < node.length && i < 300; i++) walkCatalog(node[i], depth + 1);
      return;
    }
    var vid = vidFrom(node);
    var name = nameFrom(node);
    if (vid && name) byVid[vid] = name;
    var kids = node.childList || node.catList;
    if (kids) {
      walkCatalog(kids, depth + 1);
      return;
    }
    if (depth < 6) {
      var keys = Object.keys(node);
      for (var k = 0; k < keys.length && k < 30; k++) {
        var val = node[keys[k]];
        if (val && typeof val === 'object') walkCatalog(val, depth + 1);
      }
    }
  }
  function walkVueEl(el, depth) {
    if (!el || depth > 8) return;
    var inst = el.__vue__ || el.__vueParentComponent;
    if (inst) {
      walkCatalog(inst.$data, 0);
      walkCatalog(inst.ctx, 0);
      walkCatalog(inst.setupState, 0);
      walkCatalog(inst.childList, 0);
      walkCatalog(inst.catList, 0);
    }
    var children = el.children || [];
    for (var j = 0; j < children.length && j < 24; j++) walkVueEl(children[j], depth + 1);
  }
  try { if (document.body) walkVueEl(document.body, 0); } catch (_v) {}
  try {
    var attrs = ['data-vid', 'data-videoid', 'data-pvid', 'data-pvideoid', 'vid'];
    var nodes = document.querySelectorAll('[data-vid],[data-videoid],[data-pvid],[data-pvideoid],[vid]');
    for (var n = 0; n < nodes.length; n++) {
      var el = nodes[n];
      var vid = '';
      for (var a = 0; a < attrs.length; a++) {
        var v = String(el.getAttribute(attrs[a]) || '').trim();
        if (/^\d{6,}$/.test(v)) { vid = v; break; }
      }
      if (!vid) continue;
      var text = clean(el.getAttribute('title') || el.getAttribute('data-name') || el.getAttribute('data-title') || el.innerText || el.textContent).split('\n')[0];
      if (text.length >= 2 && text.length <= 50 && /[\u4e00-\u9fff]/.test(text) && text.indexOf('班') < 0) {
        byVid[vid] = text;
      }
    }
  } catch (_d) {}
  if (playVid && title) byVid[playVid] = title;
  for (var s = 0; s < stems.length; s++) {
    var stem = String(stems[s] || '');
    if (!stem) continue;
    var vid = (stem.match(/^(\d{6,})/) || [])[1] || '';
    if (vid && byVid[vid]) byStem[stem] = byVid[vid];
    if (playVid && vid === playVid && title) {
      byStem[stem] = title;
      byVid[vid] = title;
    }
  }
  return JSON.stringify({
    v: 7,
    trial: trial,
    playing: playing,
    playVid: playVid,
    matches: found.slice(0, 12),
    byVid: byVid,
    byStem: byStem,
    title: document.title || ''
  });
}
''';
