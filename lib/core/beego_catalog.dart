import 'dart:convert';

import 'ev1_url.dart';

/// Parses Beego course catalog API and maps video id → lesson title.
class BeegoCatalog {
  final Map<String, String> _vidToTitle = {};
  String? _lastPlayVid;

  Map<String, String> get titles => Map.unmodifiable(_vidToTitle);

  String? get lastPlayVid => _lastPlayVid;

  void putVidTitle(String vid, String name) {
    _putVidTitle(vid, name, depth: 3);
  }

  static bool looksLikeCatalogJson(String text) {
    return text.contains('pvideoId') ||
        text.contains('catName') ||
        text.contains('videoName') ||
        text.contains('videoname') ||
        text.contains('pptName');
  }

  void ingestCatalogJson(String responseText) {
    final decoded = _decodeJson(responseText);
    if (decoded == null) return;
    if (decoded is Map) {
      final data = decoded['data'];
      if (data is List) {
        _walkCatalog(data);
      }
    }
    _walkAny(decoded);
  }

  void ingestVidTitleMap(String jsonMap) {
    final decoded = _decodeJson(jsonMap);
    if (decoded is! Map) return;
    decoded.forEach((key, value) {
      _putVidTitle(key.toString(), value?.toString() ?? '', depth: 3);
    });
  }

  static Object? _decodeJson(String responseText) {
    final trimmed = responseText.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      final start = trimmed.indexOf('{');
      final startArr = trimmed.indexOf('[');
      var from = start;
      if (from < 0 || (startArr >= 0 && startArr < from)) from = startArr;
      final end = trimmed.lastIndexOf(from >= 0 && trimmed[from] == '[' ? ']' : '}');
      if (from < 0 || end <= from) return null;
      try {
        return jsonDecode(trimmed.substring(from, end + 1));
      } catch (_) {
        return null;
      }
    }
  }

  void _walkCatalog(List<dynamic> nodes) {
    for (final node in nodes) {
      if (node is! Map) continue;
      final map = Map<String, dynamic>.from(node);
      final vid = map['pvideoId']?.toString().trim() ?? '';
      final name = map['catName']?.toString().trim() ?? '';
      final level = map['level'];
      final depth = level is int ? level : int.tryParse('$level') ?? 0;
      _putVidTitle(vid, name, depth: depth);
      final children = map['childList'];
      if (children is List) {
        _walkCatalog(children);
      }
    }
  }

  void _walkAny(Object? node) {
    if (node is List) {
      for (final item in node) {
        _walkAny(item);
      }
      return;
    }
    if (node is! Map) return;
    final map = Map<String, dynamic>.from(node);
    final vid = _vidFrom(map);
    final name = _nameFrom(map);
    if (vid.isNotEmpty && name.isNotEmpty) {
      _putVidTitle(vid, name, depth: 3);
    }
    for (final value in map.values) {
      if (value is Map || value is List) {
        _walkAny(value);
      }
    }
  }

  void _putVidTitle(String vid, String name, {int depth = 0}) {
    if (!RegExp(r'^\d{6,}$').hasMatch(vid) || name.isEmpty) return;
    final normalized = normalizeLessonTitle(name);
    if (!isValidLessonTitle(normalized)) return;
    final existing = _vidToTitle[vid];
    if (existing == null || depth >= 3 || normalized.length >= existing.length) {
      _vidToTitle[vid] = normalized;
    }
  }

  static String _vidFrom(Map<String, dynamic> map) {
    const keys = [
      'pvideoId',
      'pVideoId',
      'videoid',
      'videoId',
      'video_id',
      'vid',
    ];
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (RegExp(r'^\d{6,}$').hasMatch(value)) return value;
    }
    return '';
  }

  static String _nameFrom(Map<String, dynamic> map) {
    const keys = [
      'catName',
      'videoName',
      'videoname',
      'pptName',
      'lessonName',
      'title',
      'name',
    ];
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && _hasCjk(value)) return value;
    }
    return '';
  }

  static bool _hasCjk(String text) =>
      RegExp(r'[\u4e00-\u9fff]').hasMatch(text);

  void trackPlayVid(String url) {
    final uri = Uri.tryParse(url);
    final vid = uri?.queryParameters['vid'];
    if (vid != null && RegExp(r'^\d+$').hasMatch(vid)) {
      _lastPlayVid = vid;
    }
  }

  String? lookupTitleForUrl(String videoUrl) {
    final vid = extractVidFromUrl(videoUrl) ?? _lastPlayVid;
    if (vid == null) return null;
    return _vidToTitle[vid];
  }

  static String? extractVidFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final fromQuery = uri?.queryParameters['vid'];
    if (fromQuery != null && RegExp(r'^\d+$').hasMatch(fromQuery)) {
      return fromQuery;
    }
    final pathMatch = RegExp(r'/(\d{6,})_').firstMatch(url);
    if (pathMatch != null) return pathMatch.group(1);
    final fileMatch =
        RegExp(r'/(\d{6,})\.ev[12]', caseSensitive: false).firstMatch(url);
    if (fileMatch != null) return fileMatch.group(1);
    return null;
  }

  /// Filename stem from CDN path, e.g. `198409541_c34f0e3e..._eocoQLcR`.
  static String? resourceStemFromUrl(String url) => Ev1Url.resourceStem(url);

  static String normalizeLessonTitle(String raw) {
    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = text.replaceFirst(
      RegExp(r'^第[0-9一二三四五六七八九十百千万]+[章节讲]\s*'),
      '',
    );
    return text.trim();
  }

  static bool isValidLessonTitle(String title) {
    if (title.length < 2 || title.length > 80) return false;
    if (RegExp(r'^[￥¥]\s*\d').hasMatch(title)) return false;
    if (RegExp(r'^线路\s*\d+$').hasMatch(title)) return false;
    if (title.contains('必过学习平台')) return false;
    if (title.contains('单科基础班') || RegExp(r'班$').hasMatch(title)) {
      return false;
    }
    const ignored = {
      '首页',
      '必过',
      '录播',
      '直播',
      '正在播放',
      '商品详情',
      '课程详情',
      '试看',
      '预览',
      '高清',
      '超清',
      '标清',
      '流畅',
      'loading',
      'Loading...',
    };
    if (ignored.contains(title)) return false;
    return true;
  }
}
