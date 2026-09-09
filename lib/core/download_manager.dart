import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'baijiayun_converter.dart';
import 'download_file_name.dart';
import 'download_paths.dart';
import 'resumable_download.dart';
import 'sniff_registry.dart';
import '../data/database.dart';
import '../data/repositories/repositories.dart';

enum DownloadJobStatus {
  queued,
  downloading,
  converting,
  completed,
  failed,
  convertFailed,
}

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
    required BaijiayunConverter converter,
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
  final BaijiayunConverter _converter;
  final VideoRepository _videos;
  final DownloadTaskRepository _tasks;
  final Directory _videosDir;
  final Directory _tempDir;
  final int maxConcurrent;
  final int maxDownloadRetries;

  final List<_QueuedJob> _queue = [];
  final Set<String> _queuedIds = {};
  final Set<String> _cancelledIds = {};
  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _activeJobIds = {};
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
    await _prepareRawFileForResume(task);
    await _tasks.updateProgress(
      id: taskId,
      bytesDownloaded: await _existingBytes(task.rawPath),
      totalBytes: task.totalBytes,
      status: 'queued',
      error: null,
    );
    await _enqueueExisting(task);
  }

  Future<void> retryConvert(String taskId) async {
    final task = await _tasks.getById(taskId);
    if (task == null) return;

    final rawFile = File(task.rawPath);
    if (!await rawFile.exists()) {
      await retry(taskId);
      return;
    }

    await _prepareRawFileForResume(task);
    final rawSize = await rawFile.length();
    if (!_isDownloadComplete(rawSize, task.totalBytes)) {
      await retry(taskId);
      return;
    }

    await _tasks.updateProgress(
      id: taskId,
      bytesDownloaded: rawSize,
      totalBytes: task.totalBytes,
      status: 'converting',
      error: null,
    );
    await _enqueueExisting(task);
  }

  Future<void> renamePending(String taskId, String name) async {
    final cleaned = DownloadFileName.sanitize(name.trim());
    if (cleaned.isEmpty) return;
    final task = await _tasks.getById(taskId);
    if (task == null) return;
    await _tasks.updateSuggestedName(taskId, cleaned);
  }

  Future<void> cancel(String taskId) async {
    _cancelledIds.add(taskId);
    _cancelTokens[taskId]?.cancel('User cancelled');
    _queue.removeWhere((job) => job.id == taskId);
    _queuedIds.remove(taskId);

    final task = await _tasks.getById(taskId);
    if (task == null) {
      _cancelledIds.remove(taskId);
      _cancelTokens.remove(taskId);
      return;
    }

    await _cleanupTaskFiles(
      jobId: task.id,
      rawPath: task.rawPath,
      videoId: task.videoId,
    );
    await _tasks.deleteById(taskId);
    _cancelTokens.remove(taskId);
    if (!_activeJobIds.contains(taskId)) {
      _cancelledIds.remove(taskId);
    }
  }

  Future<void> _cleanupTaskFiles({
    required String jobId,
    required String rawPath,
    required String videoId,
  }) async {
    final tmpFlvPath = p.join(_tempDir.path, '$jobId.flv.tmp');
    final finalFlv = p.join(_videosDir.path, '$videoId.flv');
    final finalMp4 = p.join(_videosDir.path, '$videoId.mp4');
    final finalM3u8 = p.join(_videosDir.path, '$videoId.m3u8');
    for (final path in [rawPath, tmpFlvPath, finalFlv, finalMp4, finalM3u8]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  bool _isCancelled(String jobId) => _cancelledIds.contains(jobId);

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
      if (_isCancelled(job.id)) {
        _queuedIds.remove(job.id);
        continue;
      }
      _active++;
      _activeJobIds.add(job.id);
      _runJob(job).whenComplete(() async {
        _active--;
        _queuedIds.remove(job.id);
        await _pump();
      });
    }
  }

  Future<String> _resolvedDisplayName(_QueuedJob job) async {
    final latest = await _tasks.getById(job.id);
    return DownloadFileName.fromSuggestion(
      url: job.url,
      suggested: latest?.suggestedName ?? job.suggestedName,
    );
  }

  Future<void> _runJob(_QueuedJob job) async {
    final directExt = SniffRegistry.directFileExtension(job.url);
    final isDirect = directExt != null;
    final tmpFlvPath = p.join(_tempDir.path, '${job.id}.flv.tmp');
    var finalPath = p.join(_videosDir.path, '${job.id}.tmpout');
    final cancelToken = CancelToken();

    void emit(DownloadJobStatus status, {double progress = 0, String? error}) {
      if (_isCancelled(job.id)) return;
      job.onUpdate?.call(DownloadJobState(
        id: job.id,
        url: job.url,
        status: status,
        progress: progress,
        error: error,
      ));
    }

    try {
      if (_isCancelled(job.id)) return;
      _cancelTokens[job.id] = cancelToken;

      await _tempDir.create(recursive: true);
      await _videosDir.create(recursive: true);

      if (_isCancelled(job.id)) return;

      final existing = await _tasks.getById(job.id);
      if (existing == null || _isCancelled(job.id)) return;

      final knownTotal = existing.totalBytes;
      var lastDbUpdate = DateTime.fromMillisecondsSinceEpoch(0);

      final rawExists = await File(job.rawPath).exists();
      final rawSize = rawExists ? await File(job.rawPath).length() : 0;
      final downloadComplete =
          _isDownloadComplete(rawSize, existing.totalBytes);
      final skipDownload = rawExists &&
          downloadComplete &&
          (existing.status == 'converting' ||
              existing.status == 'convert_failed');

      if (skipDownload) {
        emit(DownloadJobStatus.converting, progress: 1);
      } else {
        if (rawExists &&
            existing.totalBytes != null &&
            existing.totalBytes! > 0 &&
            rawSize > 0 &&
            rawSize < existing.totalBytes!) {
          emit(DownloadJobStatus.downloading,
              progress: rawSize / existing.totalBytes!);
        } else {
          emit(DownloadJobStatus.downloading);
        }
        await _tasks.updateProgress(
          id: job.id,
          bytesDownloaded: await _existingBytes(job.rawPath),
          totalBytes: knownTotal,
          status: 'downloading',
        );

        try {
          await _downloadWithResume(
            job: job,
            cancelToken: cancelToken,
            knownTotalBytes: knownTotal,
            bytesDownloaded: existing.bytesDownloaded,
            taskStatus: existing.status,
            onProgress: (progress, bytesDownloaded, totalBytes) {
              if (_isCancelled(job.id)) return;
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
        } on DioException catch (e) {
          if (_isCancelled(job.id) || CancelToken.isCancel(e)) return;
          await _markDownloadFailed(job, tmpFlvPath, finalPath, error: e.toString());
          return;
        } catch (e) {
          if (_isCancelled(job.id)) return;
          await _markDownloadFailed(job, tmpFlvPath, finalPath, error: e.toString());
          return;
        }
      }

      if (_isCancelled(job.id) || cancelToken.isCancelled) return;

      final rawSizeAfterDownload = await File(job.rawPath).length();
      if (!_isDownloadComplete(rawSizeAfterDownload, knownTotal)) {
        throw Exception(
          'Download incomplete: $rawSizeAfterDownload/${knownTotal ?? "?"} bytes',
        );
      }

      finalPath = await DownloadFileName.uniquePath(
        _videosDir.path,
        fileName: await _resolvedDisplayName(job),
      );

      if (isDirect) {
        await File(job.rawPath).copy(finalPath);
      } else {
        await _tasks.updateProgress(
          id: job.id,
          bytesDownloaded: rawSizeAfterDownload,
          totalBytes: knownTotal,
          status: 'converting',
        );
        emit(DownloadJobStatus.converting, progress: 1);

        try {
          await _converter.convert(
            inputPath: job.rawPath,
            outputPath: tmpFlvPath,
            sourceUrl: job.url,
          );
        } catch (e) {
          if (_isCancelled(job.id)) return;
          final message = e.toString();
          if (message.contains('not valid FLV') ||
              message.contains('Download incomplete')) {
            await _deleteIfExists(job.rawPath);
            await _tasks.updateProgress(
              id: job.id,
              bytesDownloaded: 0,
              totalBytes: knownTotal,
              status: 'failed',
              error: message.contains('Download incomplete')
                  ? '下载未完成或文件损坏，请点「继续」重新下载'
                  : '解密失败，文件可能已损坏，请点「继续」重新下载',
            );
            job.onUpdate?.call(DownloadJobState(
              id: job.id,
              url: job.url,
              status: DownloadJobStatus.failed,
              error: message.contains('Download incomplete')
                  ? '下载未完成或文件损坏，请点「继续」重新下载'
                  : '解密失败，文件可能已损坏，请点「继续」重新下载',
            ));
            await _deleteIfExists(finalPath);
            await _deleteIfExists(tmpFlvPath);
            return;
          }
          await _markConvertFailed(job, tmpFlvPath, finalPath, error: e.toString());
          return;
        }

        if (_isCancelled(job.id) || cancelToken.isCancelled) return;

        await File(tmpFlvPath).copy(finalPath);
      }
      final size = await File(finalPath).length();
      final savedName = p.basename(finalPath);

      await _videos.insert(
        VideoRecordsCompanion.insert(
          id: job.videoId,
          displayName: savedName,
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
      if (_isCancelled(job.id)) return;
      await _markDownloadFailed(job, tmpFlvPath, finalPath, error: e.toString());
    } finally {
      _cancelTokens.remove(job.id);
      _activeJobIds.remove(job.id);
      _cancelledIds.remove(job.id);
    }
  }

  Future<void> _markDownloadFailed(
    _QueuedJob job,
    String tmpFlvPath,
    String finalPath, {
    String? error,
  }) async {
    final message = error ?? 'Download failed';
    final bytes = await _existingBytes(job.rawPath);
    await _tasks.updateProgress(
      id: job.id,
      bytesDownloaded: bytes,
      status: 'failed',
      error: message,
    );
    job.onUpdate?.call(DownloadJobState(
      id: job.id,
      url: job.url,
      status: DownloadJobStatus.failed,
      error: message,
    ));
    await _deleteIfExists(finalPath);
    await _deleteIfExists(tmpFlvPath);
  }

  Future<void> _markConvertFailed(
    _QueuedJob job,
    String tmpFlvPath,
    String finalPath, {
    String? error,
  }) async {
    final message = error ?? 'Conversion failed';
    final bytes = await _existingBytes(job.rawPath);
    await _tasks.updateProgress(
      id: job.id,
      bytesDownloaded: bytes,
      status: 'convert_failed',
      error: message,
    );
    job.onUpdate?.call(DownloadJobState(
      id: job.id,
      url: job.url,
      status: DownloadJobStatus.convertFailed,
      error: message,
    ));
    await _deleteIfExists(finalPath);
    await _deleteIfExists(tmpFlvPath);
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _downloadWithResume({
    required _QueuedJob job,
    required CancelToken cancelToken,
    required void Function(double progress, int bytesDownloaded, int? totalBytes) onProgress,
    int? knownTotalBytes,
    int bytesDownloaded = 0,
    String? taskStatus,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < maxDownloadRetries; attempt++) {
      if (_isCancelled(job.id) || cancelToken.isCancelled) return;
      if (attempt > 0) {
        await Future<void>.delayed(Duration(seconds: attempt * 2));
      }
      try {
        await _downloadOnce(
          url: job.url,
          savePath: job.rawPath,
          cancelToken: cancelToken,
          knownTotalBytes: knownTotalBytes,
          bytesDownloaded: bytesDownloaded,
          taskStatus: taskStatus,
          onProgress: onProgress,
        );
        return;
      } catch (e) {
        if (_isCancelled(job.id) ||
            (e is DioException && CancelToken.isCancel(e))) {
          return;
        }
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
    required CancelToken cancelToken,
    required void Function(double progress, int bytesDownloaded, int? totalBytes) onProgress,
    int? knownTotalBytes,
    int bytesDownloaded = 0,
    String? taskStatus,
  }) async {
    final file = File(savePath);
    final startByte = await _resumeStartByte(
      savePath,
      bytesDownloaded: bytesDownloaded,
      totalBytes: knownTotalBytes,
      status: taskStatus,
    );
    final range = rangeHeaderFor(startByte);

    int? lastTotalBytes = knownTotalBytes;

    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      deleteOnError: false,
      fileAccessMode:
          startByte > 0 ? FileAccessMode.append : FileAccessMode.write,
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

    if (knownTotalBytes != null &&
        knownTotalBytes > 0 &&
        await file.length() < knownTotalBytes) {
      throw Exception(
        'Download incomplete: ${await file.length()}/$knownTotalBytes bytes',
      );
    }
  }

  bool _isDownloadComplete(int fileSize, int? totalBytes) {
    if (totalBytes == null || totalBytes <= 0) return fileSize > 0;
    return fileSize >= totalBytes;
  }

  Future<void> _prepareRawFileForResume(DownloadTask task) async {
    await _resumeStartByte(
      task.rawPath,
      bytesDownloaded: task.bytesDownloaded,
      totalBytes: task.totalBytes,
      status: task.status,
    );
  }

  /// Returns the byte offset to request for resume. Deletes corrupt partial files.
  Future<int> _resumeStartByte(
    String path, {
    required int bytesDownloaded,
    int? totalBytes,
    String? status,
  }) async {
    final file = File(path);
    if (!await file.exists()) return 0;

    final size = await file.length();
    if (size == 0) return 0;

    if (totalBytes != null && totalBytes > 0) {
      if (size > totalBytes) {
        await file.delete();
        return 0;
      }

      final convertFailed = status == 'convert_failed';
      final downloadFailed = status == 'failed';
      if (size >= totalBytes && (convertFailed || downloadFailed)) {
        await file.delete();
        return 0;
      }

      if (size > bytesDownloaded &&
          bytesDownloaded > 0 &&
          bytesDownloaded < totalBytes) {
        await file.delete();
        return 0;
      }
    }

    return size;
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
  required BaijiayunConverter converter,
  required VideoRepository videos,
  required DownloadTaskRepository tasks,
}) async {
  final paths = await resolveDownloadStoragePaths();
  final manager = DownloadManager(
    dio: dio,
    converter: converter,
    videos: videos,
    tasks: tasks,
    videosDir: paths.videosDir,
    tempDir: paths.tempDir,
  );
  await manager.restorePending();
  return manager;
}
