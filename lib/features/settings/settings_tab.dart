import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/app_file_log.dart';
import '../../core/directory_picker.dart';
import '../../core/download_paths.dart';
import '../../core/providers.dart';
import '../../core/reveal_in_file_manager.dart';
import '../../theme/app_theme.dart';
import '../test/recorded_links_page.dart';
import '../test/test_download_page.dart';
import 'download_folder_page.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _exportLogs(BuildContext context) async {
    try {
      final files = await AppFileLog.listLogFiles();
      if (files.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('还没有日志，先去浏览器播放再试')),
        );
        return;
      }
      await AppFileLog.shareLogs();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出日志失败')),
      );
    }
  }

  Future<void> _openDownloadDirectory(BuildContext context) async {
    final paths = await resolveDownloadStoragePaths();
    if (!context.mounted) return;
    if (!isDesktopPlatform) {
      final directory = paths.customRoot != null
          ? Directory(paths.customRoot!)
          : paths.videosDir;
      _openPage(
        context,
        DownloadFolderPage(directory: directory, title: '下载目录'),
      );
      return;
    }
    final ok = await RevealInFileManager.openDirectory(paths.videosDir.path);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开下载目录')),
      );
    }
  }

  Future<void> _pickDownloadPath(BuildContext context, WidgetRef ref) async {
    final paths = await resolveDownloadStoragePaths();
    final String? selected;
    try {
      selected = await pickDirectory(
        initialDirectory: paths.customRoot ?? paths.videosDir.parent.path,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开目录选择，请完全重启应用后再试')),
      );
      return;
    }
    if (selected == null) return;
    if (!context.mounted) return;
    await _applyDownloadRoot(context, ref, selected);
  }

  Future<void> _applyDownloadRoot(
    BuildContext context,
    WidgetRef ref,
    String? root,
  ) async {
    if (root != null) {
      try {
        await Directory(root).create(recursive: true);
        await Directory(p.join(root, 'videos')).create(recursive: true);
        await Directory(p.join(root, 'tmp')).create(recursive: true);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法使用该路径，请换一个可写目录')),
        );
        return;
      }
    }

    await saveCustomDownloadRoot(root);
    ref.invalidate(downloadStoragePathsProvider);
    ref.invalidate(downloadManagerProvider);
    ref.invalidate(videoLibrarySyncProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(root == null ? '已恢复默认下载路径' : '下载路径已更新'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(downloadStoragePathsProvider);

    return ColoredBox(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: AppColors.surface,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Center(
                  child: Text(
                    '设置',
                    style: Theme.of(context).appBarTheme.titleTextStyle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _SettingsGroup(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: const Text('链接记录'),
                      subtitle: const Text(
                        '可以查看记录下的链接',
                        style: _subtitleStyle,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPage(context, const RecordedLinksPage()),
                    ),
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      leading: const Icon(Icons.science_outlined),
                      title: const Text('下载测试'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openPage(context, const TestDownloadPage()),
                    ),
                    const Divider(height: 1, indent: 16),
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: const Text('导出日志'),
                      subtitle: const Text(
                        '分享 Documents/log 下的嗅探日志',
                        style: _subtitleStyle,
                      ),
                      trailing: const Icon(Icons.ios_share),
                      onTap: () => _exportLogs(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsGroup(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: const Text('查看下载目录'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDownloadDirectory(context),
                    ),
                    if (isDesktopPlatform) ...[
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        leading: const Icon(Icons.drive_file_move_outlined),
                        title: const Text('修改下载目录'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _pickDownloadPath(context, ref),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: pathsAsync.when(
                    data: (paths) => Text(
                      paths.customRoot ?? paths.videosDir.parent.path,
                      style: _subtitleStyle,
                    ),
                    loading: () => const Text('加载中…', style: _subtitleStyle),
                    error: (_, _) => const Text('无法读取路径', style: _subtitleStyle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _subtitleStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: AppColors.textTertiary,
);

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
