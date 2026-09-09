import 'package:flutter/foundation.dart';

import 'beego_catalog.dart';
import 'ev1_url.dart';
import 'sniff_title_log.dart';

enum SniffStatus { pending, downloading, done, failed }

class SniffEntry {
  SniffEntry({
    required this.url,
    required this.detectedAt,
    this.title,
    this.status = SniffStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String url;
  final DateTime detectedAt;
  final String? title;
  SniffStatus status;
  double progress;
  String? error;

  SniffEntry copyWith({
    SniffStatus? status,
    double? progress,
    String? error,
    String? title,
  }) {
    return SniffEntry(
      url: url,
      detectedAt: detectedAt,
      title: title ?? this.title,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class SniffRegistry extends ChangeNotifier {
  final Map<String, List<SniffEntry>> _entriesByTab = {};
  final Map<String, BeegoCatalog> _catalogByTab = {};

  BeegoCatalog _catalogFor(String tabId) =>
      _catalogByTab.putIfAbsent(tabId, () => BeegoCatalog());

  void ingestCatalog(String tabId, String responseText, {String source = 'unknown'}) {
    final catalog = _catalogFor(tabId);
    final before = catalog.titles.length;
    catalog.ingestCatalogJson(responseText);
    final after = catalog.titles.length;
    sniffTitleLog(
      'ingestCatalog [$source] tab=$tabId added=${after - before} total=$after',
    );
    if (after > before) {
      _backfillFromCatalog(tabId, source: source);
    }
  }

  void trackPlayVid(String tabId, String url) {
    _catalogFor(tabId).trackPlayVid(url);
  }

  String? lookupCatalogTitle(String tabId, String videoUrl) {
    final title = _catalogFor(tabId).lookupTitleForUrl(videoUrl);
    return _cleanTitle(title);
  }

  /// Baijiayun encrypted video URLs (.ev1 legacy, .ev2 current).
  static bool isEv1Url(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return false;
    if (RegExp(r'\.ev[12](\?|#|$|/)', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    final path = uri.path.toLowerCase();
    return path.contains('.ev1') || path.contains('.ev2');
  }

  /// H5 playable mp4 / m3u8 from Baijiayun VOD CDN (not ads/thumbnails).
  static bool isBaijiayunDirectUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) return false;
    if (!uri.host.toLowerCase().contains('baijiayun.com')) return false;
    return RegExp(
      r'/video/\d{6,}_[^/?#]+\.(mp4|m3u8)$',
      caseSensitive: false,
    ).hasMatch(uri.path);
  }

  static bool isBaijiayunMp4Url(String url) => isBaijiayunDirectUrl(url);

  static String? directFileExtension(String url) {
    if (!isBaijiayunDirectUrl(url)) return null;
    final path = Uri.tryParse(url.trim())?.path.toLowerCase() ?? '';
    if (path.endsWith('.m3u8')) return 'm3u8';
    return 'mp4';
  }

  static bool isSniffableUrl(String url) =>
      isEv1Url(url) || isBaijiayunDirectUrl(url);

  static final _evUrlInText = RegExp(
    r'''https?://[^\s"'<>\\]+?\.ev[12](?:\?[^\s"'<>\\]*)?''',
    caseSensitive: false,
  );

  /// Pulls .ev1 / .ev2 URLs out of JSON or escaped response bodies.
  static List<String> extractUrlsFromText(String text) {
    if (text.isEmpty) return const [];
    final decoded = text.replaceAll(r'\/', '/');
    final seen = <String>{};
    final urls = <String>[];
    for (final match in _evUrlInText.allMatches(decoded)) {
      final url = match.group(0);
      if (url == null || !seen.add(url)) continue;
      urls.add(url);
    }
    return urls;
  }

  List<SniffEntry> entriesFor(String tabId) =>
      List.unmodifiable(_entriesByTab[tabId] ?? const []);

  int pendingCount(String tabId) =>
      entriesFor(tabId).where((e) => e.status == SniffStatus.pending).length;

  void register(String tabId, String url, {String? title, String source = 'unknown'}) {
    if (!isSniffableUrl(url)) return;
    final normalized = url.trim();
    final cleanedCatalog = lookupCatalogTitle(tabId, normalized);
    final cleanedTitle = _pickBetterTitle(_cleanTitle(title), cleanedCatalog);
    final list = _entriesByTab.putIfAbsent(tabId, () => []);
    final vid = BeegoCatalog.extractVidFromUrl(normalized);
    if (isBaijiayunDirectUrl(normalized) && vid != null) {
      final hasEv = list.any(
        (e) => isEv1Url(e.url) && BeegoCatalog.extractVidFromUrl(e.url) == vid,
      );
      if (hasEv) return;
    }
    if (isEv1Url(normalized) && vid != null) {
      list.removeWhere(
        (e) =>
            isBaijiayunDirectUrl(e.url) &&
            BeegoCatalog.extractVidFromUrl(e.url) == vid &&
            e.status == SniffStatus.pending,
      );
    }
    final index = list.indexWhere((e) => Ev1Url.sameResource(e.url, normalized));
    if (index >= 0) {
      // Refresh signed URL while keeping download state.
      final existing = list[index];
      final mergedTitle = existing.status == SniffStatus.pending
          ? _pickBetterTitle(existing.title, cleanedTitle)
          : (existing.title ?? cleanedTitle);
      sniffTitleLog(
        'register/update [$source] tab=$tabId\n'
        '  rawTitle=${title ?? "(null)"}\n'
        '  catalogTitle=${cleanedCatalog ?? "(null)"}\n'
        '  cleanedTitle=${cleanedTitle ?? "(null)"}\n'
        '  keptTitle=${mergedTitle ?? "(null)"}\n'
        '  url=${_shortUrl(normalized)}',
      );
      list[index] = SniffEntry(
        url: normalized,
        detectedAt: DateTime.now(),
        title: mergedTitle,
        status: existing.status,
        progress: existing.progress,
        error: existing.error,
      );
      notifyListeners();
      return;
    }
    sniffTitleLog(
      'register/new [$source] tab=$tabId\n'
      '  rawTitle=${title ?? "(null)"}\n'
      '  catalogTitle=${cleanedCatalog ?? "(null)"}\n'
      '  cleanedTitle=${cleanedTitle ?? "(null)"}\n'
      '  url=${_shortUrl(normalized)}',
    );
    list.insert(
      0,
      SniffEntry(
        url: normalized,
        detectedAt: DateTime.now(),
        title: cleanedTitle,
      ),
    );
    notifyListeners();
  }

  static String _shortUrl(String url) {
    if (url.length <= 120) return url;
    return '${url.substring(0, 117)}...';
  }

  static String? _cleanTitle(String? title) {
    if (title == null) return null;
    final sanitized = _sanitizeTitle(title.trim());
    if (sanitized == null || sanitized.isEmpty) return null;
    const ignored = {
      '新标签页',
      'about:blank',
      'loading',
      'Loading...',
      '首页',
      '必过',
      '逢考必过',
      'Beeeeego',
      '录播',
      '直播',
      '录播+直播',
      '班级',
      '正在播放',
      '咨询',
      '电话',
      '公众号',
      '搜索课程代码/名称',
    };
    if (ignored.contains(sanitized)) return null;
    if (sanitized.startsWith('搜索')) return null;
    if (sanitized.contains('必过学习平台')) return null;
    if (sanitized.contains('单科基础班') || RegExp(r'班$').hasMatch(sanitized)) {
      return null;
    }
    if (RegExp(r'^[￥¥]').hasMatch(sanitized)) return null;
    if (RegExp(r'^线路\s*\d*$').hasMatch(sanitized)) return null;
    return sanitized;
  }

  static final _sectionPrefix = RegExp(
    r'^第[0-9一二三四五六七八九十百千万]+[章节讲]\s*',
  );

  static String? _sanitizeTitle(String raw) {
    if (raw.isEmpty) return null;

    var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    text = _dedupeRepeatedPrefix(text);
    text = text.replaceAll(RegExp(r'[-–—|]\s*必过学习平台$'), '');
    text = text.replaceFirst(_sectionPrefix, '').trim();

    if (text.contains('必过学习平台')) return null;
    if (text.contains('单科基础班') || RegExp(r'班$').hasMatch(text)) {
      return null;
    }
    if (RegExp(r'^[￥¥]').hasMatch(text)) return null;
    if (RegExp(r'^线路\s*\d*$').hasMatch(text)) return null;

    return text.length <= 80 ? text : null;
  }

  static String _dedupeRepeatedPrefix(String text) {
    var result = text;
    for (var len = 2; len <= result.length ~/ 2; len++) {
      final prefix = result.substring(0, len);
      if (result.startsWith('$prefix$prefix')) {
        result = prefix + result.substring(len * 2);
        break;
      }
    }
    return result.trim();
  }

  static int _titleScore(String? title) {
    if (title == null || title.trim().isEmpty) return 0;
    final t = title.trim();
    var score = t.length.clamp(0, 80);
    if (t.contains('必过') || t.contains('学习平台')) score -= 500;
    if (t.contains('班')) score -= 200;
    if (RegExp(r'^[￥¥]').hasMatch(t)) score -= 500;
    if (RegExp(r'^线路').hasMatch(t)) score -= 500;
    if (_sectionPrefix.hasMatch(t)) score -= 40;
    if (t.length >= 4 && t.length <= 40) score += 40;
    if (t.length > 80) score -= 100;
    if (_cleanTitle(t) == null) score = 0;
    return score;
  }

  void _backfillFromCatalog(String tabId, {String source = 'unknown'}) {
    final list = _entriesByTab[tabId];
    if (list == null || list.isEmpty) return;

    var changed = 0;
    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      final catalogTitle = lookupCatalogTitle(tabId, entry.url);
      if (catalogTitle == null) continue;
      final merged = _pickBetterTitle(entry.title, catalogTitle);
      if (merged != entry.title) {
        list[i] = entry.copyWith(title: merged);
        changed++;
        sniffTitleLog(
          'catalog backfill [$source] url=${_shortUrl(entry.url)} title=$merged',
        );
      }
    }
    if (changed > 0) {
      sniffTitleLog('catalog backfill done count=$changed');
      notifyListeners();
    }
  }

  static String? _pickBetterTitle(String? existing, String? incoming) {
    if (incoming == null || incoming.trim().isEmpty) return existing;
    if (existing == null || existing.trim().isEmpty) return incoming;
    return _titleScore(incoming) >= _titleScore(existing) ? incoming : existing;
  }

  static String displayTitle(SniffEntry entry) {
    final raw = entry.title?.trim();
    final title = raw != null ? (_sanitizeTitle(raw) ?? raw) : null;
    if (title != null && title.isNotEmpty) return title;
    final uri = Uri.tryParse(entry.url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : '未知视频';
    return segment.replaceAll(
      RegExp(r'\.(ev[12]|mp4|m3u8)$', caseSensitive: false),
      '',
    );
  }

  void backfillMissingTitles(String tabId, String? title, {String source = 'unknown'}) {
    final cleaned = _cleanTitle(title);
    sniffTitleLog(
      'backfill [$source] tab=$tabId rawTitle=${title ?? "(null)"} '
      'cleaned=${cleaned ?? "(null)"}',
    );
    if (cleaned == null || _titleScore(cleaned) == 0) return;
    final list = _entriesByTab[tabId];
    if (list == null) return;

    var changed = 0;
    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      final merged = _pickBetterTitle(entry.title, cleaned);
      if (merged != entry.title) {
        list[i] = entry.copyWith(title: merged);
        changed++;
        sniffTitleLog(
          '  -> filled entry url=${_shortUrl(entry.url)} title=$merged',
        );
      }
    }
    if (changed > 0) {
      sniffTitleLog('backfill done count=$changed');
      notifyListeners();
    }
  }

  void updateEntry(
    String tabId,
    String url, {
    SniffStatus? status,
    double? progress,
    String? error,
    String? title,
  }) {
    final list = _entriesByTab[tabId];
    if (list == null) return;
    final index = list.indexWhere((e) => Ev1Url.sameResource(e.url, url));
    if (index < 0) return;
    final current = list[index];
    list[index] = current.copyWith(
      status: status,
      progress: progress,
      error: error,
      title: title,
    );
    notifyListeners();
  }

  void clear(String tabId) {
    _entriesByTab.remove(tabId);
    _catalogByTab.remove(tabId);
    notifyListeners();
  }
}
