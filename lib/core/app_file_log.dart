import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes diagnostic lines under Documents/log, one file per day.
class AppFileLog {
  static const folderName = 'log';
  static const filePrefix = 'sniff_';

  static final List<String> _pending = [];
  static var _flushing = false;
  static Future<Directory> Function()? documentsDir;

  static Future<Directory> resolveLogDir({
    Future<Directory> Function()? documentsDir,
  }) async {
    final docs = documentsDir != null
        ? await documentsDir()
        : AppFileLog.documentsDir != null
            ? await AppFileLog.documentsDir!()
            : await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, folderName));
    await dir.create(recursive: true);
    return dir;
  }

  static String fileNameFor(DateTime time) {
    return '$filePrefix${DateFormat('yyyy-MM-dd').format(time)}.txt';
  }

  static void write(String tag, String message) {
    debugPrint('[$tag] $message');
    final line =
        '${DateTime.now().toIso8601String()} [$tag] ${message.replaceAll('\n', '\n  ')}';
    _pending.add(line);
    _flush();
  }

  static Future<List<File>> listLogFiles() async {
    final dir = await resolveLogDir();
    if (!await dir.exists()) return const [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(filePrefix))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  static Future<void> shareLogs() async {
    final files = await listLogFiles();
    if (files.isEmpty) {
      throw StateError('empty');
    }
    await Share.shareXFiles(
      [
        for (final file in files)
          XFile(file.path, mimeType: 'text/plain', name: p.basename(file.path)),
      ],
      subject: '嗅探日志',
    );
  }

  static Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        final batch = List<String>.from(_pending);
        _pending.clear();
        final dir = await resolveLogDir();
        final file = File(p.join(dir.path, fileNameFor(DateTime.now())));
        await file.writeAsString(
          '${batch.join('\n')}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (e) {
      debugPrint('[AppFileLog] write failed: $e');
    } finally {
      _flushing = false;
      if (_pending.isNotEmpty) {
        await _flush();
      }
    }
  }
}
