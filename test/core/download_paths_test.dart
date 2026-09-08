import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/download_paths.dart';

void main() {
  group('parseCustomDownloadRoot', () {
    test('returns null when file is empty or comments only', () {
      expect(parseCustomDownloadRoot(''), isNull);
      expect(
        parseCustomDownloadRoot('# D:\\Videos\n\n  \n# another'),
        isNull,
      );
    });

    test('reads first non-comment path', () {
      const contents = '''
# 改成你想保存视频的文件夹
# D:\\skip-this

D:\\EV1Downloads
C:\\should-not-use
''';
      expect(parseCustomDownloadRoot(contents), r'D:\EV1Downloads');
    });

    test('strips BOM, quotes, and whitespace', () {
      expect(
        parseCustomDownloadRoot('\uFEFF  "E:\\课程视频"  \r\n'),
        r'E:\课程视频',
      );
    });
  });

  group('resolveDownloadStoragePaths', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('download_paths_test');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('uses sidecar download_path.txt next to the exe', () async {
      final exeDir = Directory(p.join(tmp.path, 'bundle'));
      await exeDir.create(recursive: true);
      await File(p.join(exeDir.path, 'download_path.txt')).writeAsString(
        '# comment\n${p.join(tmp.path, 'custom')}\n',
      );

      final docs = Directory(p.join(tmp.path, 'Documents'));
      final systemTemp = Directory(p.join(tmp.path, 'Temp'));

      final paths = await resolveDownloadStoragePaths(
        executableDir: exeDir.path,
        documentsDir: () async => docs,
        temporaryDir: () async => systemTemp,
      );

      expect(paths.videosDir.path, p.join(tmp.path, 'custom', 'videos'));
      expect(paths.tempDir.path, p.join(tmp.path, 'custom', 'tmp'));
      expect(paths.customRoot, p.join(tmp.path, 'custom'));
      expect(await paths.videosDir.exists(), isTrue);
      expect(await paths.tempDir.exists(), isTrue);
    });

    test('falls back to Documents/videos and system temp', () async {
      final exeDir = Directory(p.join(tmp.path, 'bundle'));
      await exeDir.create(recursive: true);
      final docs = Directory(p.join(tmp.path, 'Documents'));
      final systemTemp = Directory(p.join(tmp.path, 'Temp'));

      final paths = await resolveDownloadStoragePaths(
        executableDir: exeDir.path,
        documentsDir: () async => docs,
        temporaryDir: () async => systemTemp,
      );

      expect(paths.videosDir.path, p.join(docs.path, 'videos'));
      expect(paths.tempDir.path, p.join(systemTemp.path, 'downloads'));
      expect(paths.customRoot, isNull);
    });
  });
}
