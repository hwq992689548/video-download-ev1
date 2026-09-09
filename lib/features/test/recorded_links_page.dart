import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/download_manager.dart';
import '../../core/providers.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';

class RecordedLinksPage extends ConsumerWidget {
  const RecordedLinksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linksAsync = ref.watch(recordedLinksStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('链接记录'),
        actions: [
          linksAsync.when(
            data: (links) => TextButton(
              onPressed: links.isEmpty ? null : () => _copyAll(context, links),
              child: const Text('复制全部'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
          linksAsync.when(
            data: (links) => TextButton(
              onPressed: links.isEmpty
                  ? null
                  : () => _clearAll(context, ref, links.length),
              child: const Text('清空'),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: linksAsync.when(
        data: (links) {
          if (links.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '暂无记录。\n在浏览器「嗅探到的 .ev1 资源」列表中点「记录」保存链接。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: links.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => AppGroup(
              margin: EdgeInsets.zero,
              child: _RecordedLinkTile(link: links[index]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  Future<void> _copyAll(BuildContext context, List<RecordedLink> links) async {
    final text = links.map((e) => e.url).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制 ${links.length} 条链接')),
      );
    }
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: Text('删除全部 $count 条记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(recordedLinkRepositoryProvider).deleteAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清空全部记录')),
      );
    }
  }
}

class _RecordedLinkTile extends ConsumerStatefulWidget {
  const _RecordedLinkTile({required this.link});

  final RecordedLink link;

  @override
  ConsumerState<_RecordedLinkTile> createState() => _RecordedLinkTileState();
}

class _RecordedLinkTileState extends ConsumerState<_RecordedLinkTile> {
  bool _downloading = false;

  String get _recordedAtLabel =>
      DateFormat('yyyy-MM-dd HH:mm').format(widget.link.recordedAt);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link.url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制链接')),
      );
    }
  }

  Future<void> _download() async {
    final manager = ref.read(downloadManagerProvider).value;
    if (manager == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('DownloadManager 尚未就绪')),
        );
      }
      return;
    }

    setState(() => _downloading = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('开始下载…')),
      );
    }

    await manager.enqueue(
      widget.link.url,
      onUpdate: (state) {
        if (!mounted) return;
        switch (state.status) {
          case DownloadJobStatus.completed:
            setState(() => _downloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('下载完成')),
            );
          case DownloadJobStatus.failed:
            setState(() => _downloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('下载失败：${state.error ?? ''}')),
            );
          case DownloadJobStatus.convertFailed:
            setState(() => _downloading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('转换失败：${state.error ?? ''}')),
            );
          case DownloadJobStatus.queued:
          case DownloadJobStatus.downloading:
          case DownloadJobStatus.converting:
            break;
        }
      },
    );
  }

  Future<void> _delete() async {
    await ref.read(recordedLinkRepositoryProvider).deleteById(widget.link.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已删除记录')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.link.url,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '记录于 $_recordedAtLabel',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (_downloading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _copy,
                  child: const Text('复制'),
                ),
                FilledButton(
                  onPressed: _download,
                  child: const Text('下载'),
                ),
                OutlinedButton(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('删除'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Inserts [url] into link history if not already present. Returns true if inserted.
Future<bool> ensureEv1LinkRecorded(WidgetRef ref, String url) async {
  final repo = ref.read(recordedLinkRepositoryProvider);
  if (await repo.existsByUrl(url)) return false;

  const uuid = Uuid();
  await repo.insert(
    RecordedLinksCompanion.insert(
      id: uuid.v4(),
      url: url,
      recordedAt: DateTime.now(),
    ),
  );
  return true;
}

Future<void> recordEv1Link(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final inserted = await ensureEv1LinkRecorded(ref, url);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(inserted ? '已记录链接' : '该链接已在记录中'),
    ),
  );
}
