import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../theme/app_theme.dart';

class DownloadFolderPage extends StatefulWidget {
  const DownloadFolderPage({
    super.key,
    required this.directory,
    this.title,
  });

  final Directory directory;
  final String? title;

  @override
  State<DownloadFolderPage> createState() => _DownloadFolderPageState();
}

class _DownloadFolderPageState extends State<DownloadFolderPage> {
  String? _error;
  List<FileSystemEntity> _entries = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    try {
      final dir = widget.directory;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final entries = dir.listSync(followLinks: false);
      entries.sort(_compareEntries);
      _entries = entries;
      _error = null;
    } catch (e) {
      _error = '$e';
      _entries = const [];
    }
  }

  void _openDirectory(Directory directory) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DownloadFolderPage(directory: directory),
      ),
    );
  }

  Future<void> _openFile(File file) async {
    final result = await OpenFilex.open(file.path);
    if (!mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开文件：${p.basename(file.path)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title ?? p.basename(widget.directory.path)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '无法读取目录：$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text(
          '这个文件夹是空的',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        final isDir = entry is Directory;
        final name = p.basename(entry.path);
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            tileColor: Colors.transparent,
            leading: Icon(
              isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined,
            ),
            title: Text(name),
            subtitle: Text(
              isDir ? '文件夹' : _fileSizeLabel(entry as File),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            trailing: isDir ? const Icon(Icons.chevron_right) : null,
            onTap: () {
              if (isDir) {
                _openDirectory(entry);
              } else {
                _openFile(entry as File);
              }
            },
          ),
        );
      },
    );
  }
}

int _compareEntries(FileSystemEntity a, FileSystemEntity b) {
  final aDir = a is Directory;
  final bDir = b is Directory;
  if (aDir != bDir) return aDir ? -1 : 1;
  return p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase());
}

String _fileSizeLabel(File file) {
  try {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } catch (_) {
    return '文件';
  }
}
