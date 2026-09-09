import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/download_manager.dart';
import '../../core/providers.dart';
import '../../core/sniff_registry.dart';
import '../../data/database.dart';
import '../../theme/app_theme.dart';
import '../downloads/video_player_screen.dart';

/// Fixed tab id for the test page sniff registry bucket.
const kTestDownloadTabId = '__download_test__';

const _ev1TestUrl =
    'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/207233243_a8f1dae214f353a566ee392390c1d7f7_yQgUFTXm_mp4/207233243_a8f1dae214f353a566ee392390c1d7f7_yQgUFTXm.ev1?t=6a9f15c8&sign=d1afdff06b69494edb077db832846356&fid=198401516&uuid=7b8fc57f-f63d-5f36-b584-5056301f44d9';

const _ev2TestUrl =
    'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/185726408_977a448fe8060560f94b0d9e741f2752_VDmS8In1_mp4/185726408_977a448fe8060560f94b0d9e741f2752_VDmS8In1.ev2?t=6a9f4223&sign=72c006a8ee5a3a95403783dd10cbc1e9&uuid=3dedea7a-b262-f27e-a995-afb1da12e77c';

class TestDownloadPage extends ConsumerStatefulWidget {
  const TestDownloadPage({super.key});

  @override
  ConsumerState<TestDownloadPage> createState() => _TestDownloadPageState();
}

class _TestDownloadPageState extends ConsumerState<TestDownloadPage> {
  final _urlController = TextEditingController(text: _ev1TestUrl);
  final _logs = <String>[];

  bool _probing = false;
  String? _probeError;
  int? _headStatus;
  String? _contentLength;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _log(String message) {
    final line = '${DateTime.now().toString().substring(11, 19)} $message';
    setState(() => _logs.insert(0, line));
  }

  String _formatBytes(String? raw) {
    final n = int.tryParse(raw ?? '');
    if (n == null) return raw ?? '未知';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _probe() async {
    final url = _urlController.text.trim();
    setState(() {
      _probeError = null;
      _headStatus = null;
      _contentLength = null;
    });

    if (!SniffRegistry.isEv1Url(url)) {
      setState(() => _probeError = '不是有效的 .ev1 / .ev2 链接');
      _log('探测失败：URL 格式不对');
      return;
    }

    // 格式正确就先加入嗅探列表，网络探测失败也不影响显示
    ref.read(sniffRegistryProvider).register(kTestDownloadTabId, url);
    _log('已识别视频链接，加入嗅探列表');

    setState(() => _probing = true);
    _log('验证链接可达性…');

    try {
      final dio = ref.read(dioProvider);
      Response<dynamic> resp;
      try {
        resp = await dio.head(url);
      } catch (_) {
        // 部分 CDN 不支持 HEAD，改用 Range GET
        resp = await dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Range': 'bytes=0-0'},
          ),
        );
      }
      final length = resp.headers.value('content-length');

      setState(() {
        _headStatus = resp.statusCode;
        _contentLength = length;
      });
      _log('链接可用 HTTP ${resp.statusCode}，大小 ${_formatBytes(length)}');
    } catch (e) {
      setState(() => _probeError = '链接已识别，但网络验证失败：$e');
      _log('网络验证失败（仍可尝试下载）：$e');
    } finally {
      setState(() => _probing = false);
    }
  }

  Future<void> _download(SniffEntry entry) async {
    final registry = ref.read(sniffRegistryProvider);
    final manager = ref.read(downloadManagerProvider).value;
    if (manager == null) {
      _log('下载失败：DownloadManager 尚未就绪');
      return;
    }

    registry.updateEntry(kTestDownloadTabId, entry.url, status: SniffStatus.downloading);
    _log('开始下载流程…');

    await manager.enqueue(
      entry.url,
      suggestedName: 'test_flow',
      onUpdate: (state) {
        switch (state.status) {
          case DownloadJobStatus.queued:
            _log('排队中');
          case DownloadJobStatus.downloading:
            registry.updateEntry(
              kTestDownloadTabId,
              entry.url,
              status: SniffStatus.downloading,
              progress: state.progress,
            );
            if (state.progress > 0) {
              _log('下载中 ${(state.progress * 100).toStringAsFixed(0)}%');
            }
          case DownloadJobStatus.converting:
            registry.updateEntry(
              kTestDownloadTabId,
              entry.url,
              status: SniffStatus.downloading,
              progress: 1,
            );
            _log('EV1/EV2 → FLV 转换中…');
          case DownloadJobStatus.completed:
            registry.updateEntry(
              kTestDownloadTabId,
              entry.url,
              status: SniffStatus.done,
              progress: 1,
            );
            _log('✓ 下载完成，已写入 Documents/videos/');
          case DownloadJobStatus.failed:
          case DownloadJobStatus.convertFailed:
            registry.updateEntry(
              kTestDownloadTabId,
              entry.url,
              status: SniffStatus.failed,
              error: state.error,
            );
            _log('✗ 失败：${state.error}');
        }
      },
    );
  }

  void _useSampleUrl(String url, String label) {
    _urlController.text = url;
    setState(() {
      _probeError = null;
      _headStatus = null;
      _contentLength = null;
    });
    _log('已填入 $label 样例链接');
  }

  @override
  Widget build(BuildContext context) {
    final registry = ref.watch(sniffRegistryProvider);
    final entries = registry.entriesFor(kTestDownloadTabId);
    final managerReady = ref.watch(downloadManagerProvider).hasValue;
    final videos = ref.watch(allVideosStreamProvider).value ?? [];
    final videoRepo = ref.watch(videoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载流程测试'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppGroup(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _urlController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '.ev1 / .ev2 链接',
                  hintText: '粘贴猫抓嗅探到的链接',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => _useSampleUrl(_ev1TestUrl, 'EV1'),
                    child: const Text('EV1 样例'),
                  ),
                  OutlinedButton(
                    onPressed: () => _useSampleUrl(_ev2TestUrl, 'EV2'),
                    child: const Text('EV2 样例'),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilledButton(
                  onPressed: _probing ? null : _probe,
                  child: _probing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('探测链接'),
                ),
                const SizedBox(width: 12),
                if (!managerReady)
                  const Text('DownloadManager 初始化中…')
                else if (_headStatus != null)
                  Text(
                    'HTTP $_headStatus · ${_formatBytes(_contentLength)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (_probeError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _probeError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '嗅探结果',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('点击「探测链接」后在此显示，再点「下载」走完整流程'),
            )
          else
            ...entries.map(
              (entry) => _TestSniffTile(
                entry: entry,
                existing: videoRepo.findByEv1UrlIn(videos, entry.url),
                onDownload: () => _download(entry),
                managerReady: managerReady,
              ),
            ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('流程日志', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: _logs.isEmpty ? null : () => setState(() => _logs.clear()),
                  child: const Text('清空'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      '日志会显示：探测 → 下载 → 转换 → 完成',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _logs[i],
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _TestSniffTile extends StatelessWidget {
  const _TestSniffTile({
    required this.entry,
    required this.existing,
    required this.onDownload,
    required this.managerReady,
  });

  final SniffEntry entry;
  final VideoRecord? existing;
  final VoidCallback onDownload;
  final bool managerReady;

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (existing != null) {
      trailing = OutlinedButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(video: existing!),
            ),
          );
        },
        child: const Text('播放'),
      );
    } else {
      switch (entry.status) {
        case SniffStatus.done:
          trailing = const Icon(Icons.check_circle, color: AppColors.success);
        case SniffStatus.downloading:
          trailing = SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(value: entry.progress > 0 ? entry.progress : null),
          );
        case SniffStatus.failed:
          trailing = IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: managerReady ? onDownload : null,
          );
        case SniffStatus.pending:
          trailing = FilledButton(
            onPressed: managerReady ? onDownload : null,
            child: const Text('下载'),
          );
      }
    }

    final subtitle = existing != null
        ? '已下载 · ${existing!.displayName}'
        : switch (entry.status) {
            SniffStatus.pending => '待下载',
            SniffStatus.downloading => entry.progress > 0
                ? '下载/转换 ${(entry.progress * 100).toStringAsFixed(0)}%'
                : '处理中…',
            SniffStatus.done => '已完成 · 去「视频列表」Tab 播放',
            SniffStatus.failed => '失败: ${entry.error ?? ''}',
          };

    return ListTile(
      leading: Icon(
        existing != null ? Icons.check_circle_outline : switch (entry.status) {
          SniffStatus.done => Icons.check_circle_outline,
          SniffStatus.failed => Icons.error_outline,
          _ => Icons.link,
        },
        color: existing != null ? AppColors.success : AppColors.textSecondary,
      ),
      title: Text(
        entry.url,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
