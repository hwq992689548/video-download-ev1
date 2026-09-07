import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/providers.dart';
import '../../core/reveal_in_file_manager.dart';
import '../../data/database.dart';
import '../../data/repositories/repositories.dart';
import '../test/recorded_links_page.dart';
import '../test/test_download_page.dart';
import 'rename_dialog.dart';
import 'video_player_screen.dart';

class DownloadsTab extends ConsumerStatefulWidget {
  const DownloadsTab({super.key});

  @override
  ConsumerState<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends ConsumerState<DownloadsTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDownloadDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    final videosDir = p.join(docDir.path, 'videos');
    final ok = await RevealInFileManager.openDirectory(videosDir);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载目录')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(videoRepositoryProvider);
    final taskRepo = ref.watch(downloadTaskRepositoryProvider);
    final managerAsync = ref.watch(downloadManagerProvider);
    final videosStream =
        _query.isEmpty ? repo.watchAll() : repo.search(_query);
    final pendingStream = taskRepo.watchPending();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '视频列表',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecordedLinksPage(),
                      ),
                    );
                  },
                  child: const Text('链接记录'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TestDownloadPage(),
                      ),
                    );
                  },
                  child: const Text('下载测试'),
                ),
                TextButton(
                  onPressed: _openDownloadDirectory,
                  child: const Text('下载目录'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索视频名称',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<DownloadTask>>(
              stream: pendingStream,
              builder: (context, pendingSnapshot) {
                final pending = pendingSnapshot.data ?? [];
                return StreamBuilder<List<VideoRecord>>(
                  stream: videosStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        pendingSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final videos = snapshot.data ?? [];
                    if (pending.isEmpty && videos.isEmpty) {
                      return Center(
                        child: Text(
                          _query.isEmpty
                              ? '暂无视频，去浏览器 Tab 嗅探 .ev1 链接'
                              : '没有匹配的视频',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: pending.length + videos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        if (index < pending.length) {
                          final task = pending[index];
                          return PendingDownloadTile(
                            task: task,
                            onRetry: managerAsync.value == null
                                ? null
                                : () => managerAsync.value!.retry(task.id),
                            onRetryConvert: managerAsync.value == null
                                ? null
                                : () =>
                                    managerAsync.value!.retryConvert(task.id),
                            onCancel: managerAsync.value == null
                                ? null
                                : () => managerAsync.value!.cancel(task.id),
                          );
                        }
                        final video = videos[index - pending.length];
                        return VideoListTile(video: video);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class PendingDownloadTile extends StatelessWidget {
  const PendingDownloadTile({
    super.key,
    required this.task,
    this.onRetry,
    this.onRetryConvert,
    this.onCancel,
  });

  final DownloadTask task;
  final VoidCallback? onRetry;
  final VoidCallback? onRetryConvert;
  final VoidCallback? onCancel;

  bool get _isDownloadFailed => task.status == 'failed';
  bool get _isConvertFailed => task.status == 'convert_failed';

  bool get _isDownloadComplete {
    if (task.totalBytes == null || task.totalBytes! <= 0) {
      return task.bytesDownloaded > 0;
    }
    return task.bytesDownloaded >= task.totalBytes!;
  }

  String _statusLabel() {
    return switch (task.status) {
      'queued' => '排队中',
      'downloading' => '下载中',
      'converting' => '转换中',
      'failed' => '下载失败',
      'convert_failed' =>
        _isDownloadComplete ? '转换失败' : '下载未完成',
      _ => task.status,
    };
  }

  double _progress() {
    if (task.status == 'converting') {
      return 1;
    }
    if (task.status == 'convert_failed' && _isDownloadComplete) {
      return 1;
    }
    if (task.totalBytes != null && task.totalBytes! > 0) {
      return task.bytesDownloaded / task.totalBytes!;
    }
    return 0;
  }

  String _title() {
    if (task.suggestedName != null && task.suggestedName!.trim().isNotEmpty) {
      return task.suggestedName!.trim();
    }
    final uri = Uri.tryParse(task.sourceUrl);
    final segment = uri?.pathSegments.isNotEmpty == true
        ? uri!.pathSegments.last
        : 'video';
    return segment.replaceAll(RegExp(r'\.ev[12]$', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    final showProgress = task.status == 'downloading' ||
        task.status == 'converting' ||
        (task.status == 'convert_failed' && _isDownloadComplete) ||
        (_isDownloadFailed && progress > 0) ||
        (task.status == 'convert_failed' && !_isDownloadComplete);
    final isFailed = _isDownloadFailed || _isConvertFailed;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isFailed
            ? (_isConvertFailed ? Colors.orange.shade100 : Colors.red.shade100)
            : Colors.blue.shade100,
        child: Icon(
          isFailed ? Icons.error_outline : Icons.downloading,
          color: isFailed
              ? (_isConvertFailed ? Colors.orange : Colors.red)
              : Colors.blue,
        ),
      ),
      title: Text(_title(), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFailed && task.error != null
                ? '${_statusLabel()} · ${task.error}'
                : _statusLabel(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            if (task.status == 'downloading' &&
                task.totalBytes != null &&
                task.totalBytes! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (task.status == 'convert_failed' &&
                !_isDownloadComplete &&
                task.totalBytes != null &&
                task.totalBytes! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}% · 需继续下载后再转换',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isConvertFailed && _isDownloadComplete)
            FilledButton.tonal(
              onPressed: onRetryConvert,
              child: const Text('重新转换'),
            ),
          if (_isConvertFailed && !_isDownloadComplete)
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('继续下载'),
            ),
          if (_isDownloadFailed)
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('继续'),
            ),
          if (isFailed) const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

class VideoListTile extends ConsumerWidget {
  const VideoListTile({super.key, required this.video});

  final VideoRecord video;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _share(BuildContext context) async {
    await VideoPlayerScreen.shareVideo(context, video);
  }

  Future<void> _delete(BuildContext context, VideoRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除「${video.displayName}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await VideoPlayerScreen.deleteVideo(video, repo);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(videoRepositoryProvider);
    final date = DateFormat('yyyy-MM-dd HH:mm').format(video.downloadedAt);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade100,
        child: Icon(Icons.movie, color: Colors.green.shade700),
      ),
      title: Text(video.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('下载成功 · ${_formatSize(video.fileSizeBytes)} · $date'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(video: video),
          ),
        );
      },
      onLongPress: () async {
        final newName = await showRenameDialog(
          context,
          initialName: video.displayName,
        );
        if (newName != null && newName.trim().isNotEmpty) {
          await repo.rename(video.id, newName.trim());
        }
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: () =>
                VideoPlayerScreen.revealInFileManager(context, video),
            child: const Text('目录'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _share(context),
            child: const Text('分享'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () => _delete(context, repo),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
