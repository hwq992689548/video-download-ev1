import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/download_paths.dart';
import '../../core/providers.dart';
import '../../core/reveal_in_file_manager.dart';
import '../../data/database.dart';
import '../../data/repositories/repositories.dart';
import '../../theme/app_theme.dart';
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
    final paths = await resolveDownloadStoragePaths();
    final ok = await RevealInFileManager.openDirectory(paths.videosDir.path);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载目录')),
      );
    }
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(videoRepositoryProvider);
    final taskRepo = ref.watch(downloadTaskRepositoryProvider);
    final managerAsync = ref.watch(downloadManagerProvider);
    final videosStream =
        _query.isEmpty ? repo.watchAll() : repo.search(_query);
    final pendingStream = taskRepo.watchPending();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: AppColors.surface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      '视频列表',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).appBarTheme.titleTextStyle,
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: '更多',
                    onSelected: (value) {
                      switch (value) {
                        case 'links':
                          _openPage(const RecordedLinksPage());
                        case 'test':
                          _openPage(const TestDownloadPage());
                        case 'folder':
                          _openDownloadDirectory();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'links', child: Text('链接记录')),
                      PopupMenuItem(value: 'test', child: Text('下载测试')),
                      PopupMenuItem(value: 'folder', child: Text('下载目录')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '搜索视频名称',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
            ),
          ),
        ),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: pending.length + videos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index < pending.length) {
                        final task = pending[index];
                        return AppGroup(
                          margin: EdgeInsets.zero,
                          child: PendingDownloadTile(
                            task: task,
                            onRetry: managerAsync.value == null
                                ? null
                                : () => managerAsync.value!.retry(task.id),
                            onRetryConvert: managerAsync.value == null
                                ? null
                                : () => managerAsync.value!
                                    .retryConvert(task.id),
                            onCancel: managerAsync.value == null
                                ? null
                                : () => managerAsync.value!.cancel(task.id),
                          ),
                        );
                      }
                      final video = videos[index - pending.length];
                      return AppGroup(
                        margin: EdgeInsets.zero,
                        child: VideoListTile(video: video),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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

  Color get _accent {
    if (_isConvertFailed) return AppColors.warning;
    if (_isDownloadFailed) return AppColors.error;
    return AppColors.tip;
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
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      leading: CircleAvatar(
        backgroundColor: _accent.withValues(alpha: 0.12),
        child: Icon(
          isFailed ? Icons.error_outline : Icons.downloading,
          color: _accent,
        ),
      ),
      title: Text(
        _title(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            isFailed && task.error != null
                ? '${_statusLabel()} · ${task.error}'
                : _statusLabel(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 3,
              ),
            ),
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
            FilledButton(
              onPressed: onRetryConvert,
              child: const Text('重新转换'),
            ),
          if (_isConvertFailed && !_isDownloadComplete)
            FilledButton(
              onPressed: onRetry,
              child: const Text('继续下载'),
            ),
          if (_isDownloadFailed)
            FilledButton(
              onPressed: onRetry,
              child: const Text('继续'),
            ),
          if (isFailed) const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
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

  Future<void> _rename(BuildContext context, VideoRepository repo) async {
    final newName = await showRenameDialog(
      context,
      initialName: video.displayName,
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await repo.rename(video.id, newName.trim());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(videoRepositoryProvider);
    final date = DateFormat('yyyy-MM-dd HH:mm').format(video.downloadedAt);

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.success.withValues(alpha: 0.12),
        child: const Icon(Icons.movie, color: AppColors.success),
      ),
      title: Text(
        video.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        '下载成功 · ${_formatSize(video.fileSizeBytes)} · $date',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(video: video),
          ),
        );
      },
      onLongPress: () => _rename(context, repo),
      trailing: PopupMenuButton<String>(
        tooltip: '操作',
        onSelected: (value) {
          switch (value) {
            case 'folder':
              VideoPlayerScreen.revealInFileManager(context, video);
            case 'share':
              _share(context);
            case 'rename':
              _rename(context, repo);
            case 'delete':
              _delete(context, repo);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'folder', child: Text('目录')),
          PopupMenuItem(value: 'share', child: Text('分享')),
          PopupMenuItem(value: 'rename', child: Text('重命名')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
