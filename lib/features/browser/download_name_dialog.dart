import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Returns the file name to use, or null if the user cancelled.
Future<String?> showDownloadNameDialog(
  BuildContext context, {
  required String defaultName,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _DownloadNameDialog(defaultName: defaultName),
  );
}

class _DownloadNameDialog extends StatefulWidget {
  const _DownloadNameDialog({required this.defaultName});

  final String defaultName;

  @override
  State<_DownloadNameDialog> createState() => _DownloadNameDialogState();
}

class _DownloadNameDialogState extends State<_DownloadNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.defaultName);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _clear() {
    _controller.clear();
  }

  void _confirm() {
    final name = _controller.text.trim();
    Navigator.pop(context, name.isEmpty ? widget.defaultName : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('保存文件名称'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.defaultName,
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除',
                  icon: const Icon(Icons.clear),
                  onPressed: _clear,
                ),
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.fillRegular,
            foregroundColor: AppColors.textPrimary,
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('立即下载'),
        ),
      ],
    );
  }
}
