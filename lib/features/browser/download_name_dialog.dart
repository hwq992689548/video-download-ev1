import 'package:flutter/material.dart';

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _controller.text.trim();
    Navigator.pop(context, name.isEmpty ? widget.defaultName : name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载文件名'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: widget.defaultName,
        ),
        onSubmitted: (_) => _confirm(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
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
