import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Ev2ConversionException implements Exception {
  Ev2ConversionException(this.message);
  final String message;

  @override
  String toString() => 'Ev2ConversionException: $message';
}

/// Converts Baijiayun EV2 files to FLV via bundled Node.js + ev2-decrypt.wasm.
class Ev2Converter {
  static const _wasmAsset = 'assets/ev2-decrypt.wasm';
  static const _scriptAsset = 'assets/ev2_convert.mjs';
  static String? _toolDir;

  Future<void> convert({
    required String inputPath,
    required String outputPath,
  }) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw Ev2ConversionException('Input not found: $inputPath');
    }

    final fileSize = await input.length();
    if (fileSize < 112) {
      throw Ev2ConversionException('File too small: $fileSize bytes');
    }

    final node = await _findNodeExecutable();
    if (node == null) {
      throw Ev2ConversionException(
        '未找到 Node.js，无法解密 .ev2。请重新构建 macOS 应用以打包内置 Node，或安装 Node.js（https://nodejs.org）后重试。',
      );
    }

    final toolDir = await _ensureToolDir();
    final scriptPath = p.join(toolDir, 'ev2_convert.mjs');

    final result = await Process.run(
      node,
      [scriptPath, inputPath, outputPath],
      workingDirectory: toolDir,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      final detail = stderr.isNotEmpty ? stderr : stdout;
      throw Ev2ConversionException(
        detail.isEmpty ? 'EV2 解密失败 (exit ${result.exitCode})' : detail,
      );
    }

    final output = File(outputPath);
    if (!await output.exists()) {
      throw Ev2ConversionException('EV2 解密未生成输出文件');
    }

    final magic = await output.openRead(0, 4).first;
    if (!_isFlvMagic(magic)) {
      await output.delete();
      throw Ev2ConversionException('解密结果不是有效的 FLV 文件');
    }
  }

  static Future<String> _ensureToolDir() async {
    if (_toolDir != null) return _toolDir!;

    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'ev2_tool'));
    await dir.create(recursive: true);

    await _writeAsset(_wasmAsset, p.join(dir.path, 'ev2-decrypt.wasm'));
    await _writeAsset(_scriptAsset, p.join(dir.path, 'ev2_convert.mjs'));

    _toolDir = dir.path;
    return _toolDir!;
  }

  static Future<void> _writeAsset(String assetPath, String destPath) async {
    final dest = File(destPath);
    final data = await rootBundle.load(assetPath);
    await dest.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
  }

  static Future<String?> _findNodeExecutable() async {
    final candidates = <String>[];

    final bundled = await _bundledNodePath();
    if (bundled != null) {
      candidates.add(bundled);
    }

    candidates.addAll([
      'node',
      '/opt/homebrew/bin/node',
      '/usr/local/bin/node',
      '/usr/bin/node',
    ]);

    final pathEnv = Platform.environment['PATH'];
    if (pathEnv != null) {
      for (final dir in pathEnv.split(':')) {
        final trimmed = dir.trim();
        if (trimmed.isNotEmpty) {
          candidates.add(p.join(trimmed, 'node'));
        }
      }
    }

    if (Platform.isMacOS) {
      await _addMacOsPathCandidates(candidates);
      final shellNode = await _findNodeViaLoginShell();
      if (shellNode != null) {
        candidates.add(shellNode);
      }
    }

    final home = Platform.environment['HOME'];
    if (home != null) {
      candidates.addAll([
        p.join(home, '.fnm/current/bin/node'),
        p.join(home, '.volta/bin/node'),
      ]);
      await _addNvmNodeCandidates(home, candidates);
    }

    for (final cmd in candidates) {
      if (await _isWorkingNode(cmd)) return cmd;
    }
    return null;
  }

  static Future<String?> _bundledNodePath() async {
    if (Platform.isMacOS) {
      final exe = Platform.resolvedExecutable;
      final node = p.join(
        p.dirname(p.dirname(exe)),
        'Resources',
        'node',
        'bin',
        'node',
      );
      if (await File(node).exists()) return node;
    }

    if (Platform.isWindows) {
      final exe = Platform.resolvedExecutable;
      final node = p.join(p.dirname(exe), 'node', 'node.exe');
      if (await File(node).exists()) return node;
    }

    return null;
  }

  static Future<void> _addMacOsPathCandidates(List<String> candidates) async {
    try {
      final etcPaths = File('/etc/paths');
      if (await etcPaths.exists()) {
        for (final line in await etcPaths.readAsLines()) {
          final dir = line.trim();
          if (dir.isNotEmpty) {
            candidates.add(p.join(dir, 'node'));
          }
        }
      }

      final pathsDir = Directory('/etc/paths.d');
      if (await pathsDir.exists()) {
        await for (final entry in pathsDir.list()) {
          if (entry is! File) continue;
          for (final line in await entry.readAsLines()) {
            final dir = line.trim();
            if (dir.isNotEmpty) {
              candidates.add(p.join(dir, 'node'));
            }
          }
        }
      }
    } catch (_) {
      /* best effort */
    }
  }

  static Future<void> _addNvmNodeCandidates(
    String home,
    List<String> candidates,
  ) async {
    final versionsDir = Directory(p.join(home, '.nvm/versions/node'));
    if (!await versionsDir.exists()) return;

    await for (final entry in versionsDir.list()) {
      if (entry is! Directory) continue;
      candidates.add(p.join(entry.path, 'bin/node'));
    }
  }

  static Future<String?> _findNodeViaLoginShell() async {
    for (final shell in ['/bin/zsh', '/bin/bash']) {
      try {
        final result = await Process.run(shell, ['-lc', 'command -v node']);
        if (result.exitCode != 0) continue;
        final path = result.stdout.toString().trim();
        if (path.isNotEmpty) return path;
      } catch (_) {
        /* try next shell */
      }
    }
    return null;
  }

  static Future<bool> _isWorkingNode(String cmd) async {
    if (cmd != 'node') {
      final file = File(cmd);
      if (!await file.exists()) return false;
    }

    try {
      final result = await Process.run(cmd, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static bool _isFlvMagic(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x46 &&
      bytes[1] == 0x4C &&
      bytes[2] == 0x56 &&
      bytes[3] == 0x01;
}
