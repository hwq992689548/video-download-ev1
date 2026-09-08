import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/download_manager.dart';
import '../../core/providers.dart';
import '../../core/sniff_registry.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../downloads/video_player_screen.dart';
import 'mobile_browser_config.dart';
import '../test/recorded_links_page.dart';

class SniffPanel extends ConsumerWidget {
  const SniffPanel({super.key, required this.tabId, required this.onClose});

  final String tabId;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.watch(sniffRegistryProvider);
    final entries = registry.entriesFor(tabId);
    final videosAsync = ref.watch(videoRepositoryProvider).watchAll();
    final panelHeight = shouldUseMobileBrowserMode(context)
        ? MediaQuery.sizeOf(context).height * 0.45
        : 360.0;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      shadowColor: AppColors.mask,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: panelHeight,
          child: Column(
            children: [
              ListTile(
                title: Text(
                  '嗅探到的视频资源',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(onPressed: () => registry.clear(tabId), child: const Text('清空')),
                    IconButton(icon: const Icon(Icons.close), onPressed: onClose),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: entries.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            '播放视频后自动嗅探。\n'
                            '若未出现：点地址栏右侧「探测链接」打开此面板；\n'
                            '或在「视频列表」Tab 右上角使用下载测试。',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : StreamBuilder<List<VideoRecord>>(
                        stream: videosAsync,
                        builder: (context, snapshot) {
                          final videos = snapshot.data ?? [];
                          return ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, i) => _SniffTile(
                              tabId: tabId,
                              entry: entries[i],
                              videos: videos,
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SniffTile extends ConsumerWidget {
  const _SniffTile({
    required this.tabId,
    required this.entry,
    required this.videos,
  });

  final String tabId;
  final SniffEntry entry;
  final List<VideoRecord> videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registry = ref.read(sniffRegistryProvider);
    final manager = ref.watch(downloadManagerProvider).value;
    final repo = ref.watch(videoRepositoryProvider);
    final recordedLinks = ref.watch(recordedLinksStreamProvider).value ?? [];
    final recordedRepo = ref.watch(recordedLinkRepositoryProvider);
    final existing = repo.findByEv1UrlIn(videos, entry.url);
    final isRecorded = recordedRepo.findByUrlIn(recordedLinks, entry.url) != null;
    final displayName = existing?.displayName ?? SniffRegistry.displayTitle(entry);

    Widget trailing;
    if (existing != null) {
      trailing = OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(video: existing),
            ),
          );
        },
        child: const Text('播放'),
      );
    } else if (entry.status == SniffStatus.done) {
      trailing = const Icon(Icons.check_circle, color: AppColors.success);
    } else if (entry.status == SniffStatus.downloading) {
      trailing = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(value: entry.progress),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            onPressed: isRecorded
                ? null
                : () => recordEv1Link(context, ref, entry.url),
            child: Text(isRecorded ? '已记录' : '记录'),
          ),
          const SizedBox(width: 8),
          if (entry.status == SniffStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: manager == null
                  ? null
                  : () => _download(context, ref, registry, manager),
            )
          else
            FilledButton(
              onPressed: manager == null
                  ? null
                  : () => _download(context, ref, registry, manager),
              child: const Text('下载'),
            ),
        ],
      );
    }

    final subtitle = existing != null
        ? '已下载'
        : switch (entry.status) {
            SniffStatus.pending => null,
            SniffStatus.downloading =>
              '下载中 ${(entry.progress * 100).toStringAsFixed(0)}%',
            SniffStatus.done => '已完成',
            SniffStatus.failed => '失败: ${entry.error ?? ''}',
          };

    return ListTile(
      leading: Icon(
        existing != null ? Icons.check_circle_outline : Icons.link,
        color: existing != null ? AppColors.success : AppColors.textSecondary,
      ),
      title: Text(
        displayName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) Text(subtitle),
        ],
      ),
      trailing: trailing,
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    SniffRegistry registry,
    DownloadManager manager,
  ) async {
    await ensureEv1LinkRecorded(ref, entry.url);
    registry.updateEntry(tabId, entry.url, status: SniffStatus.downloading);
    await manager.enqueue(
      entry.url,
      suggestedName: entry.title,
      onUpdate: (state) {
        switch (state.status) {
          case DownloadJobStatus.downloading:
            registry.updateEntry(
              tabId,
              entry.url,
              status: SniffStatus.downloading,
              progress: state.progress,
            );
          case DownloadJobStatus.converting:
            registry.updateEntry(
              tabId,
              entry.url,
              status: SniffStatus.downloading,
              progress: 1,
            );
          case DownloadJobStatus.completed:
            registry.updateEntry(
              tabId,
              entry.url,
              status: SniffStatus.done,
              progress: 1,
            );
          case DownloadJobStatus.failed:
          case DownloadJobStatus.convertFailed:
            registry.updateEntry(
              tabId,
              entry.url,
              status: SniffStatus.failed,
              error: state.error,
            );
          case DownloadJobStatus.queued:
            break;
        }
      },
    );
  }
}
