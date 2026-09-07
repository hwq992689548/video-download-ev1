import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;

/// Opens the system file manager and highlights [filePath] when supported.
class RevealInFileManager {
  static Future<bool> openDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final absolutePath = dir.absolute.path;

    if (Platform.isWindows) {
      final result = await Process.run(
        'explorer',
        [absolutePath],
        runInShell: true,
      );
      return result.exitCode == 0;
    }

    if (Platform.isMacOS) {
      final result = await Process.run('open', [absolutePath]);
      return result.exitCode == 0;
    }

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [absolutePath]);
      return result.exitCode == 0;
    }

    await for (final entity in dir.list()) {
      if (entity is File) {
        return reveal(entity.path);
      }
    }
    return false;
  }

  static Future<bool> reveal(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return false;

    final absolutePath = file.absolute.path;

    if (Platform.isWindows) {
      final result = await Process.run(
        'explorer',
        ['/select,', absolutePath],
        runInShell: true,
      );
      return result.exitCode == 0;
    }

    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', absolutePath]);
      return result.exitCode == 0;
    }

    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', [p.dirname(absolutePath)]);
      return result.exitCode == 0;
    }

    final result = await OpenFilex.open(absolutePath);
    return result.type == ResultType.done;
  }
}
