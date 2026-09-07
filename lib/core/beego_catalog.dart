import 'dart:convert';

/// Parses Beego course catalog API and maps video id → lesson title.
class BeegoCatalog {
  final Map<String, String> _vidToTitle = {};
  String? _lastPlayVid;

  Map<String, String> get titles => Map.unmodifiable(_vidToTitle);

  void ingestCatalogJson(String responseText) {
    if (responseText.trim().isEmpty) return;
    try {
      final json = jsonDecode(responseText);
      if (json is! Map<String, dynamic>) return;
      final data = json['data'];
      if (data is! List) return;
      _walkCatalog(data);
    } catch (_) {
      /* ignore malformed payloads */
    }
  }

  void _walkCatalog(List<dynamic> nodes) {
    for (final node in nodes) {
      if (node is! Map) continue;
      final map = Map<String, dynamic>.from(node);
      final vid = map['pvideoId']?.toString().trim() ?? '';
      final name = map['catName']?.toString().trim() ?? '';
      final level = map['level'];
      if (RegExp(r'^\d+$').hasMatch(vid) && name.isNotEmpty) {
        final normalized = normalizeLessonTitle(name);
        if (isValidLessonTitle(normalized)) {
          final depth = level is int ? level : int.tryParse('$level') ?? 0;
          final existing = _vidToTitle[vid];
          if (existing == null || depth >= 3) {
            _vidToTitle[vid] = normalized;
          }
        }
      }
      final children = map['childList'];
      if (children is List) {
        _walkCatalog(children);
      }
    }
  }

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
      'loading',
      'Loading...',
    };
    if (ignored.contains(title)) return false;
    return true;
  }
}
