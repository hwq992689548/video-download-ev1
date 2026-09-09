import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get isDesktopPlatform {
  if (kIsWeb) return false;
  return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}

Future<String?> pickDirectory({String? initialDirectory}) async {
  try {
    final path = await getDirectoryPath(
      confirmButtonText: '选择',
      initialDirectory: initialDirectory,
    );
    if (path != null && path.isNotEmpty) return path;
  } on MissingPluginException {
    // App was hot-reloaded after adding the plugin; use the OS picker.
  } catch (_) {}

  return _pickDirectoryNatively(initialDirectory: initialDirectory);
}

Future<String?> _pickDirectoryNatively({String? initialDirectory}) async {
  if (Platform.isMacOS) {
    final script = StringBuffer(
      'POSIX path of (choose folder with prompt "选择下载目录"',
    );
    if (initialDirectory != null && initialDirectory.isNotEmpty) {
      script.write(
        ' default location POSIX file "${_escapeAppleScript(initialDirectory)}"',
      );
    }
    script.write(')');
    final result = await Process.run('osascript', ['-e', script.toString()]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  if (Platform.isWindows) {
    final initial = initialDirectory == null || initialDirectory.isEmpty
        ? ''
        : "\$d.SelectedPath = '${initialDirectory.replaceAll("'", "''")}'; ";
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'Add-Type -AssemblyName System.Windows.Forms; '
          '\$d = New-Object System.Windows.Forms.FolderBrowserDialog; '
          '\$d.Description = "选择下载目录"; '
          '$initial'
          'if (\$d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { \$d.SelectedPath }',
    ]);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  if (Platform.isLinux) {
    final args = <String>['--file-selection', '--directory', '--title=选择下载目录'];
    if (initialDirectory != null && initialDirectory.isNotEmpty) {
      args.add('--filename=$initialDirectory/');
    }
    final result = await Process.run('zenity', args);
    if (result.exitCode != 0) return null;
    final path = result.stdout.toString().trim();
    return path.isEmpty ? null : path;
  }

  return null;
}

String _escapeAppleScript(String value) {
  return value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
}
