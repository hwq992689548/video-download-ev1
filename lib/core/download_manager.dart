import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'ev1_converter.dart';
import 'resumable_download.dart';
import '../data/database.dart';
import '../data/repositories/repositories.dart';

enum DownloadJobStatus { queued, downloading, converting, completed, failed }

class DownloadJobState {
  const DownloadJobState({
    required this.id,
    required this.url,
    required this.status,
    this.progress = 0,
    this.error,
  });

  final String id;
  final String url;
  final DownloadJobStatus status;
  final double progress;
  final String? error;
}

class DownloadManager {
  DownloadManager({
    required Dio dio,
    required Ev1Converter converter,
    required VideoRepository videos,
    required DownloadTaskRepository tasks,
    required Directory videosDir,
    required Directory tempDir,
    this.maxConcurrent = 2,
    this.maxDownloadRetries = 3,
  })  : _dio = dio,
        _converter = converter,
        _videos = videos,
        _tasks = tasks,
        _videosDir = videosDir,
        _tempDir = tempDir;

  final Dio _dio;
  final Ev1Converter _converter;
  final VideoRepository _videos;
  final DownloadTaskRepository _tasks;
  final Directory _videosDir;
  final Directory _tempDir;
  final int maxConcurrent;
  final int maxDownloadRetries;

  final List<_QueuedJob> _queue = [];
  final Set<String> _queuedIds = {};
  int _active = 0;
  final _uuid = const Uuid();

  Future<void> restorePending() async {
    final pending = await _tasks.getResumable();
    for (final task in pending) {
      await _enqueueExisting(task);
    }
  }

  Future<void> enqueue(
    String url, {
    String? suggestedName,
    void Function(DownloadJobState state)? onUpdate,
  }) async {
    final jobId = _uuid.v4();
    final videoId = _uuid.v4();
    await _tempDir.create(recursive: true);
    final rawPath = p.join(_tempDir.path, '$jobId.ev1.raw');
    final now = DateTime.now();

    await _tasks.insert(
      DownloadTasksCompanion.insert(
        id: jobId,
        sourceUrl: url,
        suggestedName: Value(suggestedName),
        rawPath: rawPath,
        videoId: videoId,
        status: 'queued',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await _enqueueJob(
      _QueuedJob(
        id: jobId,
        url: url,
        suggestedName: suggestedName,
        videoId: videoId,
        rawPath: rawPath,
        onUpdate: onUpdate,
      ),
    );
  }

  Future<void> retry(String taskId) async {
    final task = await _tasks.getById(taskId);
    if (task == null) return;
    await _tasks.updateProgress(
      id: taskId,
      bytesDownloaded: task.bytesDownloaded,
      totalBytes: task.totalBytes,
      status: 'queued',
    );
    await _enqueueExisting(task);
  }

  Future<void> _enqueueExisting(DownloadTask task) async {
    if (_queuedIds.contains(task.id)) return;
    await _enqueueJob(
      _QueuedJob(
        id: task.id,
        url: task.sourceUrl,
        suggestedName: task.suggestedName,
        videoId: task.videoId,
        rawPath: task.rawPath,
      ),
    );
  }

  Future<void> _enqueueJob(_QueuedJob job) async {
    _queuedIds.add(job.id);
    _queue.add(job);
    job.onUpdate?.call(DownloadJobState(
      id: job.id,
      url: job.url,
      status: DownloadJobStatus.queued,
    ));
    await _pump();
  }

  Future<void> _pump() async {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _active++;
      _runJob(job).whenComplete(() async {
        _active--;
        _queuedIds.remove(job.id);
        await _pump();
      });
    }
  }

  Future<void> _runJob(_QueuedJob job) async {
    final tmpFlvPath = p.join(_tempDir.path, '${job.id}.flv.tmp');
    final finalPath = p.join(_videosDir.path, '${job.videoId}.flv');

    void emit(DownloadJobStatus status, {double progress = 0, String? error}) {
      job.onUpdate?.call(DownloadJobState(
        id: job.id,
        url: job.url,
        status: status,
        progress: progress,
        error: error,
      ));
    }

    try {
      await _tempDir.create(recursive: true);
      await _videosDir.create(recursive: true);

      final existing = await _tasks.getById(job.id);
      final knownTotal = existing?.totalBytes;
      var lastDbUpdate = DateTime.fromMillisecondsSinceEpoch(0);

      if (existing?.status == 'converting' && await File(job.rawPath).exists()) {
        emit(DownloadJobStatus.converting, progress: 1);
      } else {
        emit(DownloadJobStatus.downloading);
        await _tasks.updateProgress(
          id: job.id,
          bytesDownloaded: await _existingBytes(job.rawPath),
          totalBytes: knownTotal,
          status: 'downloading',
        );

        await _downloadWithResume(
          job: job,
          knownTotalBytes: knownTotal,
          onProgress: (progress, bytesDownloaded, totalBytes) {
            emit(DownloadJobStatus.downloading, progress: progress);
            final now = DateTime.now();
            if (now.difference(lastDbUpdate).inMilliseconds >= 1000) {
              lastDbUpdate = now;
              _tasks.updateProgress(
                id: job.id,
                bytesDownloaded: bytesDownloaded,
                totalBytes: totalBytes,
                status: 'downloading',
              );
            }
          },
        );
      }

      await _tasks.updateProgress(
        id: job.id,
        bytesDownloaded: await File(job.rawPath).length(),
        totalBytes: knownTotal,
        status: 'converting',
      );
      emit(DownloadJobStatus.converting, progress: 1);

      await _converter.convert(inputPath: job.rawPath, outputPath: tmpFlvPath);

      await File(tmpFlvPath).copy(finalPath);
      final size = await File(finalPath).length();
      final displayName = _displayName(job.url, job.suggestedName);

      await _videos.insert(
        VideoRecordsCompanion.insert(
          id: job.videoId,
          displayName: displayName,
          filePath: finalPath,
          sourceUrl: job.url,
          fileSizeBytes: size,
          downloadedAt: DateTime.now(),
        ),
      );

      await _tasks.deleteById(job.id);
      emit(DownloadJobStatus.completed, progress: 1);

      for (final path in [job.rawPath, tmpFlvPath]) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      final bytes = await _existingBytes(job.rawPath);
      await _tasks.updateProgress(
        id: job.id,
        bytesDownloaded: bytes,
        status: 'failed',
        error: e.toString(),
      );
      emit(DownloadJobStatus.failed, error: e.toString());
      if (await File(finalPath).exists()) {
        await File(finalPath).delete();
      }
      final tmp = File(tmpFlvPath);
      if (await tmp.exists()) await tmp.delete();
    }
  }

  Future<void> _downloadWithResume({
    required _QueuedJob job,
    required void Function(double progress, int bytesDownloaded, int? totalBytes) onProgress,
    int? knownTotalBytes,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxDownloadRetries; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
      try {
        await _downloadOnce(
          url: job.url,
          savePath: job.rawPath,
          knownTotalBytes: knownTotalBytes,
          onProgress: onProgress,
        );
        return;
      } catch (e) {
        lastError = e;
        if (!_isRetryableDownloadError(e) || attempt == maxDownloadRetries - 1) {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('Download failed');
  }

  Future<void> _downloadOnce({
    required String url,
    required String savePath,
    required void Function(double progress, int bytesDownloaded, int? totalBytes) onProgress,
    int? knownTotalBytes,
  }) async {
    final file = File(savePath);
    final startByte = await _existingBytes(savePath);
    final range = rangeHeaderFor(startByte);

    int? lastTotalBytes = knownTotalBytes;

    await _dio.download(
      url,
      savePath,
      deleteOnError: false,
      options: range != null ? Options(headers: {'Range': range}) : null,
      onReceiveProgress: (received, total) {
        final progress = ResumableDownloadProgress(
          startByte: startByte,
          received: received,
          total: total,
          knownTotalBytes: lastTotalBytes,
        );
        lastTotalBytes = progress.fullTotalBytes ?? lastTotalBytes;

        final fraction = progress.fraction ?? 0;
        onProgress(fraction, progress.downloadedBytes, lastTotalBytes);
      },
    );

    if (!await file.exists() || await file.length() == 0) {
      throw Exception('Download produced empty file');
    }
  }

  Future<int> _existingBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  bool _isRetryableDownloadError(Object error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.connectionError;
    }
    return isRetryableDownloadError(error);
  }

  String _displayName(String url, String? suggested) {
    if (suggested != null && suggested.trim().isNotEmpty) {
      final name = suggested.trim();
      return name.toLowerCase().endsWith('.flv') ? name : '$name.flv';
    }
    final uri = Uri.tryParse(url);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'video';
    final base = segment.replaceAll(RegExp(r'\.ev1$', caseSensitive: false), '');
    return '$base.flv';
  }
}

class _QueuedJob {
  _QueuedJob({
    required this.id,
    required this.url,
    required this.videoId,
    required this.rawPath,
    this.suggestedName,
    this.onUpdate,
  });

  final String id;
  final String url;
  final String videoId;
  final String rawPath;
  final String? suggestedName;
  final void Function(DownloadJobState state)? onUpdate;
}

Future<DownloadManager> createDownloadManager({
  required Dio dio,
  required Ev1Converter converter,
  required VideoRepository videos,
  required DownloadTaskRepository tasks,
}) async {
  final docDir = await getApplicationDocumentsDirectory();
  final tempDir = await getTemporaryDirectory();
  final manager = DownloadManager(
    dio: dio,
    converter: converter,
    videos: videos,
    tasks: tasks,
    videosDir: Directory(p.join(docDir.path, 'videos')),
    tempDir: Directory(p.join(tempDir.path, 'downloads')),
  );
  await manager.restorePending();
  return manager;
}
