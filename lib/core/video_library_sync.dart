import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../data/repositories/repositories.dart';
import 'app_file_log.dart';

const videoLibrarySyncLogTag = 'VideoSync';

const _videoExtensions = {
  '.flv',
  '.mp4',
  '.m3u8',
  '.mkv',
  '.webm',
  '.mov',
  '.avi',
  '.ts',
};

/// Reconciles [videoRecords] with files under the download videos directory.
class VideoLibrarySync {
  VideoLibrarySync({
    required VideoRepository videos,
    required this.videosDir,
    Set<String> reservedVideoIds = const {},
    void Function(String tag, String message)? log,
    String Function()? newId,
  })  : _videos = videos,
        _reservedVideoIds = reservedVideoIds,
        _log = log ?? AppFileLog.write,
        _newId = newId ?? const Uuid().v4;

  final VideoRepository _videos;
  final Directory videosDir;
  final Set<String> _reservedVideoIds;
  final void Function(String tag, String message) _log;
  final String Function() _newId;

  Future<void> reconcile() async {
    await videosDir.create(recursive: true);
    final records = await _videos.getAll();
    _log(
      videoLibrarySyncLogTag,
      '同步下载目录：dir=${videosDir.path} db=${records.length}',
    );
    final files = await listVideoFiles(videosDir);
    final existingPaths = {
      for (final file in files) _canon(file.path),
    };

    for (final record in records) {
      if (existingPaths.contains(_canon(record.filePath))) continue;
      if (await File(record.filePath).exists()) continue;
      await _videos.deleteById(record.id);
      _log(
        videoLibrarySyncLogTag,
        '数据库有记录但文件不存在，已删除：id=${record.id} '
        'name=${record.displayName} path=${record.filePath}',
      );
    }

    final remaining = await _videos.getAll();
    final knownPaths = {
      for (final record in remaining) _canon(record.filePath),
    };
    final usedIds = {for (final record in remaining) record.id};

    for (final file in files) {
      if (knownPaths.contains(_canon(file.path))) continue;
      final stem = p.basenameWithoutExtension(file.path);
      if (_reservedVideoIds.contains(stem)) continue;

      var id = stem;
      if (id.isEmpty || usedIds.contains(id)) {
        id = _newId();
      }
      usedIds.add(id);

      final size = await file.length();
      final modified = await file.lastModified();
      await _videos.insert(
        VideoRecordsCompanion.insert(
          id: id,
          displayName: stem.isEmpty ? id : stem,
          filePath: file.path,
          sourceUrl: '',
          fileSizeBytes: size,
          downloadedAt: modified,
        ),
      );
      _log(
        videoLibrarySyncLogTag,
        '目录中有视频但数据库无记录，已入库（下载链接为空）：id=$id '
        'path=${file.path}',
      );
    }
  }
}

bool isLibraryVideoFile(String path) {
  final name = p.basename(path);
  if (name.startsWith('.')) return false;
  final ext = p.extension(name).toLowerCase();
  if (ext == '.tmp' || ext == '.part' || ext == '.download') return false;
  return _videoExtensions.contains(ext);
}

Future<List<File>> listVideoFiles(Directory dir) async {
  if (!await dir.exists()) return const [];
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is File && isLibraryVideoFile(entity.path)) {
      files.add(entity);
    }
  }
  return files;
}

String _canon(String path) => p.normalize(path).toLowerCase();
