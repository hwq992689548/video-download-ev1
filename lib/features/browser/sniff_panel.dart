import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/download_manager.dart';
import '../../core/providers.dart';
import '../../core/sniff_registry.dart';
import '../../data/database.dart';
import '../downloads/video_player_screen.dart';
import 'mobile_browser_config.dart';

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
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: panelHeight,
          child: Column(
            children: [
              ListTile(
                title: const Text('嗅探到的 .ev1 资源'),
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
                            '若未出现：点地址栏右侧雷达图标打开此面板；\n'
                            '或去「测试」Tab 直接粘贴 .ev1 链接。',
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
    final existing = repo.findByEv1UrlIn(videos, entry.url);

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
      trailing = const Icon(Icons.check_circle, color: Colors.green);
    } else if (entry.status == SniffStatus.downloading) {
      trailing = SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(value: entry.progress),
      );
    } else {
      trailing = FilledButton(
        onPressed: manager == null ? null : () => _download(context, registry, manager),
        child: const Text('下载'),
      );
    }

    final subtitle = existing != null
        ? '已下载 · ${existing.displayName}'
        : switch (entry.status) {
            SniffStatus.pending => '待下载',
            SniffStatus.downloading =>
              '下载中 ${(entry.progress * 100).toStringAsFixed(0)}%',
            SniffStatus.done => '已完成',
            SniffStatus.failed => '失败: ${entry.error ?? ''}',
          };

    return ListTile(
      leading: Icon(
        existing != null ? Icons.check_circle_outline : Icons.link,
        color: existing != null ? Colors.green : null,
      ),
      title: Text(
        entry.url,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }

  Future<void> _download(
    BuildContext context,
    SniffRegistry registry,
    DownloadManager manager,
  ) async {
    registry.updateEntry(tabId, entry.url, status: SniffStatus.downloading);
    await manager.enqueue(entry.url, onUpdate: (state) {
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
          registry.updateEntry(
            tabId,
            entry.url,
            status: SniffStatus.failed,
            error: state.error,
          );
        case DownloadJobStatus.queued:
          break;
      }
    });
  }
}
