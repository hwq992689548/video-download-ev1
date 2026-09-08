import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const downloadPathConfigFileName = 'download_path.txt';

class DownloadStoragePaths {
  const DownloadStoragePaths({
    required this.videosDir,
    required this.tempDir,
    this.customRoot,
  });

  final Directory videosDir;
  final Directory tempDir;
  final String? customRoot;
}

/// First non-empty, non-comment line is the custom download root.
String? parseCustomDownloadRoot(String contents) {
  var text = contents;
  if (text.startsWith('\uFEFF')) {
    text = text.substring(1);
  }

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    var path = trimmed;
    if (path.length >= 2 &&
        ((path.startsWith('"') && path.endsWith('"')) ||
            (path.startsWith("'") && path.endsWith("'")))) {
      path = path.substring(1, path.length - 1).trim();
    }
    if (path.isNotEmpty) return path;
  }
  return null;
}

Future<DownloadStoragePaths> resolveDownloadStoragePaths({
  String? executableDir,
  Future<Directory> Function()? documentsDir,
  Future<Directory> Function()? temporaryDir,
}) async {
  final exeDir = executableDir ?? p.dirname(Platform.resolvedExecutable);
  final customRoot = await _readCustomRoot(exeDir);

  if (customRoot != null) {
    final videosDir = Directory(p.join(customRoot, 'videos'));
    final tempDir = Directory(p.join(customRoot, 'tmp'));
    try {
      await videosDir.create(recursive: true);
      await tempDir.create(recursive: true);
      return DownloadStoragePaths(
        videosDir: videosDir,
        tempDir: tempDir,
        customRoot: customRoot,
      );
    } catch (_) {
      // Fall back to the default locations if the custom path is unusable.
    }
  }

  final docDir = documentsDir != null
      ? await documentsDir()
      : await getApplicationDocumentsDirectory();
  final tempBase = temporaryDir != null
      ? await temporaryDir()
      : await getTemporaryDirectory();

  final videosDir = Directory(p.join(docDir.path, 'videos'));
  final tempDir = Directory(p.join(tempBase.path, 'downloads'));
  await videosDir.create(recursive: true);
  await tempDir.create(recursive: true);
  return DownloadStoragePaths(videosDir: videosDir, tempDir: tempDir);
}

Future<String?> _readCustomRoot(String executableDir) async {
  final file = File(p.join(executableDir, downloadPathConfigFileName));
  if (!await file.exists()) return null;
  return parseCustomDownloadRoot(await file.readAsString());
}
