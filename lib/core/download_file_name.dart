import 'dart:io';

import 'package:path/path.dart' as p;

import 'sniff_registry.dart';

/// Sanitizes and resolves on-disk names for downloaded videos.
class DownloadFileName {
  DownloadFileName._();

  static final _mediaExt = RegExp(
    r'\.(mp4|m3u8|flv|ev[12])$',
    caseSensitive: false,
  );

  static String sanitize(String name) {
    var sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sanitized.length > 120) {
      sanitized = sanitized.substring(0, 120).trim();
    }
    return sanitized.isEmpty ? 'video' : sanitized;
  }

  static String fromSuggestion({
    required String url,
    String? suggested,
  }) {
    final ext = '.${SniffRegistry.directFileExtension(url) ?? 'flv'}';
    if (suggested != null && suggested.trim().isNotEmpty) {
      final name = sanitize(suggested.trim());
      final lower = name.toLowerCase();
      if (lower.endsWith('.flv') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.m3u8')) {
        return name;
      }
      return '$name$ext';
    }
    final uri = Uri.tryParse(url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'video';
    final base = segment.replaceAll(
      RegExp(r'\.(ev[12]|mp4|m3u8)$', caseSensitive: false),
      '',
    );
    return '${sanitize(base)}$ext';
  }

  /// Rename-field stem without the on-disk extension, e.g. `绪论.mp4` → `绪论`.
  static String forDisplay(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.replaceFirst(_mediaExt, '');
  }

  /// List label with media suffix, e.g. `绪论` + mp4 url → `绪论.mp4`.
  static String forList({
    required String name,
    String? url,
    String? filePath,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return trimmed;
    if (_mediaExt.hasMatch(trimmed)) return trimmed;
    return '$trimmed.${_inferredExtension(url: url, filePath: filePath)}';
  }

  static String _inferredExtension({String? url, String? filePath}) {
    if (url != null && url.trim().isNotEmpty) {
      final fromUrl = SniffRegistry.directFileExtension(url);
      if (fromUrl != null) return fromUrl;
    }
    if (filePath != null && filePath.trim().isNotEmpty) {
      final ext = p.extension(filePath).toLowerCase().replaceFirst('.', '');
      if (ext == 'mp4' || ext == 'flv' || ext == 'm3u8') return ext;
    }
    return 'flv';
  }

  static Future<String> uniquePath(
    String directory, {
    required String fileName,
    String? ignorePath,
  }) async {
    String canon(String path) => p.normalize(path).toLowerCase();
    final ignore = ignorePath == null ? null : canon(ignorePath);

    var candidate = p.join(directory, fileName);
    if (!await File(candidate).exists() ||
        (ignore != null && canon(candidate) == ignore)) {
      return candidate;
    }

    final ext = p.extension(fileName);
    final stem = p.basenameWithoutExtension(fileName);
    for (var i = 1; i < 1000; i++) {
      candidate = p.join(directory, '$stem ($i)$ext');
      if (!await File(candidate).exists() ||
          (ignore != null && canon(candidate) == ignore)) {
        return candidate;
      }
    }
    return p.join(directory, '$stem-${DateTime.now().millisecondsSinceEpoch}$ext');
  }
}
