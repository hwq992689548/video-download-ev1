import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../data/database.dart';
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
            child: Text(
              '已下载视频',
              style: Theme.of(context).textTheme.headlineSmall,
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
                              ? '暂无下载，去浏览器 Tab 嗅探 .ev1 链接'
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
  });

  final DownloadTask task;
  final VoidCallback? onRetry;

  String _statusLabel() {
    return switch (task.status) {
      'queued' => '排队中',
      'downloading' => '下载中',
      'converting' => '转换中',
      'failed' => '下载失败',
      _ => task.status,
    };
  }

  double _progress() {
    if (task.status == 'converting') return 1;
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
    return segment.replaceAll(RegExp(r'\.ev1$', caseSensitive: false), '');
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress();
    final showProgress = task.status == 'downloading' ||
        task.status == 'converting' ||
        (task.status == 'failed' && progress > 0);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: task.status == 'failed'
            ? Colors.red.shade100
            : Colors.blue.shade100,
        child: Icon(
          task.status == 'failed' ? Icons.error_outline : Icons.downloading,
          color: task.status == 'failed' ? Colors.red : Colors.blue,
        ),
      ),
      title: Text(_title(), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.status == 'failed' && task.error != null
                ? '${_statusLabel()} · ${task.error}'
                : _statusLabel(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress > 0 ? progress : null),
            if (task.totalBytes != null && task.totalBytes! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
      trailing: task.status == 'failed'
          ? FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('继续'),
            )
          : const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(videoRepositoryProvider);
    final date = DateFormat('yyyy-MM-dd HH:mm').format(video.downloadedAt);

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.movie)),
      title: Text(video.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${_formatSize(video.fileSizeBytes)} · $date'),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(video: video),
          ),
        );
      },
      onLongPress: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('重命名'),
                  onTap: () => Navigator.pop(context, 'rename'),
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('分享 / 导出'),
                  onTap: () => Navigator.pop(context, 'share'),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('删除', style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ),
          ),
        );

        if (!context.mounted || action == null) return;

        switch (action) {
          case 'rename':
            final newName = await showRenameDialog(
              context,
              initialName: video.displayName,
            );
            if (newName != null && newName.trim().isNotEmpty) {
              await repo.rename(video.id, newName.trim());
            }
          case 'share':
            if (context.mounted) {
              await VideoPlayerScreen.shareVideo(context, video);
            }
          case 'delete':
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
      },
    );
  }
}
