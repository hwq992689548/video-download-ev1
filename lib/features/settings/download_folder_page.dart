import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../common/selection_mode.dart';

class DownloadFolderPage extends ConsumerStatefulWidget {
  const DownloadFolderPage({super.key, required this.directory, this.title});

  final Directory directory;
  final String? title;

  @override
  ConsumerState<DownloadFolderPage> createState() => _DownloadFolderPageState();
}

class _DownloadFolderPageState extends ConsumerState<DownloadFolderPage> {
  String? _error;
  List<FileSystemEntity> _entries = const [];
  var _selecting = false;
  final _selectedPaths = <String>{};

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
      final entries = dir
          .listSync(followLinks: false)
          .where((entry) => !p.basename(entry.path).startsWith('.'))
          .toList();
      entries.sort(_compareEntries);
      _entries = entries;
      _error = null;
      _selectedPaths.removeWhere(
        (path) => !_entries.any((entry) => entry.path == path),
      );
    } catch (e) {
      _error = '$e';
      _entries = const [];
      _selectedPaths.clear();
    }
  }

  bool get _allSelected =>
      _entries.isNotEmpty && _selectedPaths.length == _entries.length;

  void _enterSelect() => setState(() => _selecting = true);

  void _exitSelect() {
    setState(() {
      _selecting = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedPaths.clear();
      } else {
        _selectedPaths
          ..clear()
          ..addAll(_entries.map((e) => e.path));
      }
    });
  }

  void _togglePath(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
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

  Future<void> _deleteSelected() async {
    final paths = _entries
        .map((e) => e.path)
        .where(_selectedPaths.contains)
        .toList();
    if (paths.isEmpty) return;
    if (!await confirmDeleteSelected(context, paths.length)) return;
    if (!mounted) return;

    var failed = 0;
    final selected = _entries.where((e) => paths.contains(e.path)).toList();
    for (final entry in selected) {
      try {
        if (entry is Directory) {
          entry.deleteSync(recursive: true);
        } else {
          File(entry.path).deleteSync();
        }
      } catch (_) {
        failed++;
      }
    }
    ref.invalidate(videoLibrarySyncProvider);
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedPaths.clear();
      _reload();
    });
    if (failed > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$failed 项删除失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: !_selecting,
        leading: _selecting
            ? TextButton(onPressed: _exitSelect, child: const Text('取消'))
            : null,
        leadingWidth: _selecting ? 72 : null,
        title: Text(
          _selecting
              ? '已选 ${_selectedPaths.length} 项'
              : (widget.title ?? p.basename(widget.directory.path)),
        ),
        actions: [
          SelectionModeButtons(
            selecting: _selecting,
            canSelect: _entries.isNotEmpty,
            allSelected: _allSelected,
            hasSelection: _selectedPaths.isNotEmpty,
            onEnter: _enterSelect,
            onSelectAll: _toggleSelectAll,
            onDelete: _deleteSelected,
          ),
        ],
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
        final selected = _selectedPaths.contains(entry.path);
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            tileColor: Colors.transparent,
            selected: _selecting && selected,
            leading: _selecting
                ? Checkbox(
                    value: selected,
                    onChanged: (_) => _togglePath(entry.path),
                  )
                : Icon(
                    isDir
                        ? Icons.folder_outlined
                        : Icons.insert_drive_file_outlined,
                  ),
            title: Text(name),
            subtitle: Text(
              isDir ? _folderSubtitle(entry) : _fileSubtitle(entry as File),
            ),
            trailing: !_selecting && isDir
                ? const Icon(Icons.chevron_right)
                : null,
            onTap: () {
              if (_selecting) {
                _togglePath(entry.path);
                return;
              }
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
  final aTime = _modifiedAt(a);
  final bTime = _modifiedAt(b);
  if (aTime != null && bTime != null) {
    final byTime = bTime.compareTo(aTime);
    if (byTime != 0) return byTime;
  } else if (aTime != null) {
    return -1;
  } else if (bTime != null) {
    return 1;
  }
  return p
      .basename(a.path)
      .toLowerCase()
      .compareTo(p.basename(b.path).toLowerCase());
}

DateTime? _modifiedAt(FileSystemEntity entity) {
  try {
    return entity.statSync().modified;
  } catch (_) {
    return null;
  }
}

String _timeLabel(FileSystemEntity entity) {
  final time = _modifiedAt(entity);
  if (time == null) return '';
  return DateFormat('yyyy-MM-dd HH:mm').format(time);
}

String _folderSubtitle(FileSystemEntity entity) {
  final time = _timeLabel(entity);
  return time.isEmpty ? '文件夹' : '文件夹 · $time';
}

String _fileSubtitle(File file) {
  final parts = <String>[
    _timeLabel(file),
    _fileSizeLabel(file),
    _fileTypeLabel(file.path),
  ].where((part) => part.isNotEmpty).toList();
  return parts.join(' · ');
}

String _fileTypeLabel(String path) {
  final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
  if (ext.isEmpty) return '';
  return ext;
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
