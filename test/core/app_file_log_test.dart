import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/app_file_log.dart';

void main() {
  test('names daily sniff log files by date', () {
    expect(
      AppFileLog.fileNameFor(DateTime(2026, 9, 9, 10, 35)),
      'sniff_2026-09-09.txt',
    );
  });

  test('writes lines under Documents/log', () async {
    final tmp = await Directory.systemTemp.createTemp('app_file_log');
    addTearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    AppFileLog.documentsDir = () async => tmp;
    addTearDown(() => AppFileLog.documentsDir = null);

    AppFileLog.write('test', 'hello');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final dir = Directory(p.join(tmp.path, 'log'));
    expect(await dir.exists(), isTrue);
    final files = await AppFileLog.listLogFiles();
    expect(files, isNotEmpty);
    expect(await files.first.readAsString(), contains('[test] hello'));
  });
}
