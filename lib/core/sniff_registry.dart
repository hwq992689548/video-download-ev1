import 'package:flutter/foundation.dart';

import 'ev1_url.dart';

enum SniffStatus { pending, downloading, done, failed }

class SniffEntry {
  SniffEntry({
    required this.url,
    required this.detectedAt,
    this.status = SniffStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String url;
  final DateTime detectedAt;
  SniffStatus status;
  double progress;
  String? error;

  SniffEntry copyWith({
    SniffStatus? status,
    double? progress,
    String? error,
  }) {
    return SniffEntry(
      url: url,
      detectedAt: detectedAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class SniffRegistry extends ChangeNotifier {
  final Map<String, List<SniffEntry>> _entriesByTab = {};

  static bool isEv1Url(String url) {
    final normalized = url.trim();
    if (normalized.isEmpty) return false;
    // 路径含 .ev1，或整段 URL 任意位置出现 .ev1? / .ev1#
    if (RegExp(r'\.ev1(\?|#|$|/)', caseSensitive: false).hasMatch(normalized)) {
      return true;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    return uri.path.toLowerCase().contains('.ev1');
  }

  List<SniffEntry> entriesFor(String tabId) =>
      List.unmodifiable(_entriesByTab[tabId] ?? const []);

  int pendingCount(String tabId) =>
      entriesFor(tabId).where((e) => e.status == SniffStatus.pending).length;

  void register(String tabId, String url) {
    if (!isEv1Url(url)) return;
    final normalized = url.trim();
    final list = _entriesByTab.putIfAbsent(tabId, () => []);
    final index = list.indexWhere((e) => Ev1Url.sameResource(e.url, normalized));
    if (index >= 0) {
      // Refresh signed URL while keeping download state.
      final existing = list[index];
      list[index] = SniffEntry(
        url: normalized,
        detectedAt: DateTime.now(),
        status: existing.status,
        progress: existing.progress,
        error: existing.error,
      );
      notifyListeners();
      return;
    }
    list.insert(0, SniffEntry(url: normalized, detectedAt: DateTime.now()));
    notifyListeners();
  }

  void updateEntry(
    String tabId,
    String url, {
    SniffStatus? status,
    double? progress,
    String? error,
  }) {
    final list = _entriesByTab[tabId];
    if (list == null) return;
    final index = list.indexWhere((e) => e.url == url);
    if (index < 0) return;
    final current = list[index];
    list[index] = current.copyWith(
      status: status,
      progress: progress,
      error: error,
    );
    notifyListeners();
  }

  void clear(String tabId) {
    _entriesByTab.remove(tabId);
    notifyListeners();
  }
}
