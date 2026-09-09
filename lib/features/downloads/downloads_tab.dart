import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../core/directory_picker.dart';
import '../../core/download_file_name.dart';
import '../../core/download_manager.dart';
import '../../core/providers.dart';
import '../../data/database.dart';
import '../../data/repositories/repositories.dart';
import '../../theme/app_theme.dart';
import '../common/selection_mode.dart';
import '../settings/download_folder_page.dart';
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
  var _selecting = false;
  final _selectedVideoIds = <String>{};
  final _selectedPendingIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _selectedCount(List<DownloadTask> pending, List<VideoRecord> videos) {
    final pendingIds = pending.map((e) => e.id).toSet();
    final videoIds = videos.map((e) => e.id).toSet();
    return _selectedPendingIds.intersection(pendingIds).length +
        _selectedVideoIds.intersection(videoIds).length;
  }

  bool _allSelected(List<DownloadTask> pending, List<VideoRecord> videos) {
    final total = pending.length + videos.length;
    return total > 0 && _selectedCount(pending, videos) == total;
  }

  void _enterSelect() => setState(() => _selecting = true);

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selectedVideoIds.clear();
      _selectedPendingIds.clear();
    });
  }

  void _toggleSelectAll(List<DownloadTask> pending, List<VideoRecord> videos) {
    setState(() {
      if (_allSelected(pending, videos)) {
        _selectedVideoIds.clear();
        _selectedPendingIds.clear();
      } else {
        _selectedVideoIds
          ..clear()
          ..addAll(videos.map((e) => e.id));
        _selectedPendingIds
          ..clear()
          ..addAll(pending.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected({
    required List<DownloadTask> pending,
    required List<VideoRecord> videos,
  }) async {
    final pendingIds = pending.map((e) => e.id).toSet();
    final videoIds = videos.map((e) => e.id).toSet();
    final selectedPending = _selectedPendingIds.intersection(pendingIds);
    final selectedVideos = videos
        .where(
          (video) =>
              _selectedVideoIds.intersection(videoIds).contains(video.id),
        )
        .toList();
    final count = selectedPending.length + selectedVideos.length;
    if (count == 0) return;
    if (!await confirmDeleteSelected(context, count)) return;
    if (!mounted) return;

    final manager = ref.read(downloadManagerProvider).asData?.value;
    final repo = ref.read(videoRepositoryProvider);
    for (final id in selectedPending) {
      await manager?.cancel(id);
    }
    for (final video in selectedVideos) {
      await VideoPlayerScreen.deleteVideo(video, repo);
    }
    if (!mounted) return;
    _exitSelect();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(videoRepositoryProvider);
    final managerAsync = ref.watch(downloadManagerProvider);
    final sync = ref.watch(videoLibrarySyncProvider);
    final pendingAsync = ref.watch(pendingDownloadsStreamProvider);
    final videosAsync = _query.isEmpty
        ? ref.watch(allVideosStreamProvider)
        : ref.watch(videoSearchStreamProvider(_query));
    final pending = pendingAsync.value ?? const <DownloadTask>[];
    final videos = videosAsync.value ?? const <VideoRecord>[];
    final waitingForFirstList =
        !pendingAsync.hasValue &&
        !videosAsync.hasValue &&
        pending.isEmpty &&
        videos.isEmpty;
    final firstSync = sync.isLoading && !sync.hasValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: AppColors.surface,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: kToolbarHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                child: Row(
                  children: [
                    if (_selecting)
                      TextButton(
                        onPressed: _exitSelect,
                        child: const Text('取消'),
                      )
                    else
                      const SizedBox(width: 56),
                    Expanded(
                      child: Text(
                        _selecting
                            ? '已选 ${_selectedCount(pending, videos)} 项'
                            : '视频列表',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).appBarTheme.titleTextStyle,
                      ),
                    ),
                    SelectionModeButtons(
                      selecting: _selecting,
                      canSelect: pending.isNotEmpty || videos.isNotEmpty,
                      allSelected: _allSelected(pending, videos),
                      hasSelection: _selectedCount(pending, videos) > 0,
                      onEnter: _enterSelect,
                      onSelectAll: () => _toggleSelectAll(pending, videos),
                      onDelete: () =>
                          _deleteSelected(pending: pending, videos: videos),
                    ),
                  ],
                ),
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
          child: _buildList(
            context: context,
            repo: repo,
            managerAsync: managerAsync,
            pending: pending,
            videos: videos,
            showSpinner:
                (waitingForFirstList && firstSync) ||
                (waitingForFirstList &&
                    (pendingAsync.isLoading || videosAsync.isLoading)),
          ),
        ),
      ],
    );
  }

  Widget _buildList({
    required BuildContext context,
    required VideoRepository repo,
    required AsyncValue<DownloadManager> managerAsync,
    required List<DownloadTask> pending,
    required List<VideoRecord> videos,
    required bool showSpinner,
  }) {
    if (showSpinner) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pending.isEmpty && videos.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? '暂无视频，去浏览器 Tab 嗅探 .ev1 链接' : '没有匹配的视频',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
              selecting: _selecting,
              selected: _selectedPendingIds.contains(task.id),
              onToggleSelect: () => setState(() {
                if (_selectedPendingIds.contains(task.id)) {
                  _selectedPendingIds.remove(task.id);
                } else {
                  _selectedPendingIds.add(task.id);
                }
              }),
              onRetry: managerAsync.asData?.value == null
                  ? null
                  : () => managerAsync.asData!.value.retry(task.id),
              onRetryConvert: managerAsync.asData?.value == null
                  ? null
                  : () => managerAsync.asData!.value.retryConvert(task.id),
              onCancel: managerAsync.asData?.value == null
                  ? null
                  : () => managerAsync.asData!.value.cancel(task.id),
            ),
          );
        }
        final video = videos[index - pending.length];
        return AppGroup(
          margin: EdgeInsets.zero,
          child: VideoListTile(
            video: video,
            selecting: _selecting,
            selected: _selectedVideoIds.contains(video.id),
            onToggleSelect: () => setState(() {
              if (_selectedVideoIds.contains(video.id)) {
                _selectedVideoIds.remove(video.id);
              } else {
                _selectedVideoIds.add(video.id);
              }
            }),
          ),
        );
      },
    );
  }
}

class PendingDownloadTile extends ConsumerWidget {
  const PendingDownloadTile({
    super.key,
    required this.task,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
    this.onRetry,
    this.onRetryConvert,
    this.onCancel,
  });

  final DownloadTask task;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;
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
      'convert_failed' => _isDownloadComplete ? '转换失败' : '下载未完成',
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

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(downloadManagerProvider).asData?.value;
    if (manager == null) return;
    final newName = await showRenameDialog(
      context,
      initialName: DownloadFileName.forDisplay(_title()),
    );
    if (newName == null || newName.trim().isEmpty) return;
    await manager.renamePending(task.id, newName.trim());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = _progress();
    final showProgress =
        task.status == 'downloading' ||
        task.status == 'converting' ||
        (task.status == 'convert_failed' && _isDownloadComplete) ||
        (_isDownloadFailed && progress > 0) ||
        (task.status == 'convert_failed' && !_isDownloadComplete);
    final isFailed = _isDownloadFailed || _isConvertFailed;

    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      selected: selecting && selected,
      onTap: selecting ? onToggleSelect : null,
      onLongPress: selecting ? null : () => _rename(context, ref),
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelect?.call())
          : CircleAvatar(
              backgroundColor: _accent.withValues(alpha: 0.12),
              child: Icon(
                isFailed ? Icons.error_outline : Icons.downloading,
                color: _accent,
              ),
            ),
      title: Text(
        DownloadFileName.forList(name: _title(), url: task.sourceUrl),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
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
                child: Text('${(progress * 100).toStringAsFixed(0)}%'),
              ),
            if (task.status == 'convert_failed' &&
                !_isDownloadComplete &&
                task.totalBytes != null &&
                task.totalBytes! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}% · 需继续下载后再转换',
                ),
              ),
          ],
          if (!selecting) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isConvertFailed && _isDownloadComplete)
                  FilledButton(
                    onPressed: onRetryConvert,
                    child: const Text('重新转换'),
                  ),
                if (_isConvertFailed && !_isDownloadComplete)
                  FilledButton(onPressed: onRetry, child: const Text('继续下载')),
                if (_isDownloadFailed)
                  FilledButton(onPressed: onRetry, child: const Text('继续')),
                OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: selecting
          ? null
          : PopupMenuButton<String>(
              tooltip: '操作',
              onSelected: (value) async {
                await Future<void>.delayed(const Duration(milliseconds: 150));
                if (!context.mounted) return;
                if (value == 'rename') await _rename(context, ref);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
              ],
            ),
    );
  }
}

class VideoListTile extends ConsumerWidget {
  const VideoListTile({
    super.key,
    required this.video,
    this.selecting = false,
    this.selected = false,
    this.onToggleSelect,
  });

  final VideoRecord video;
  final bool selecting;
  final bool selected;
  final VoidCallback? onToggleSelect;

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

  Future<void> _openFolder(BuildContext context) async {
    final file = File(video.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('文件不存在，可能已被删除')));
      }
      return;
    }
    if (!context.mounted) return;
    if (!isDesktopPlatform) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DownloadFolderPage(
            directory: Directory(p.dirname(video.filePath)),
            title: '下载目录',
          ),
        ),
      );
      return;
    }
    await VideoPlayerScreen.revealInFileManager(context, video);
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
      initialName: DownloadFileName.forDisplay(video.displayName),
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
      selected: selecting && selected,
      leading: selecting
          ? Checkbox(value: selected, onChanged: (_) => onToggleSelect?.call())
          : CircleAvatar(
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              child: const Icon(Icons.movie, color: AppColors.success),
            ),
      title: Text(
        DownloadFileName.forList(
          name: video.displayName,
          url: video.sourceUrl,
          filePath: video.filePath,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text('下载成功 · ${_formatSize(video.fileSizeBytes)} · $date'),
      onTap: selecting
          ? onToggleSelect
          : () => VideoPlayerScreen.playWithSystemPlayer(context, video),
      onLongPress: selecting ? null : () => _rename(context, repo),
      trailing: selecting
          ? null
          : PopupMenuButton<String>(
              tooltip: '操作',
              onSelected: (value) async {
                // iOS 必须等菜单关闭后再 present 分享/跳转，否则会没反应。
                await Future<void>.delayed(const Duration(milliseconds: 150));
                if (!context.mounted) return;
                switch (value) {
                  case 'folder':
                    await _openFolder(context);
                  case 'share':
                    await _share(context);
                  case 'rename':
                    await _rename(context, repo);
                  case 'delete':
                    await _delete(context, repo);
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
