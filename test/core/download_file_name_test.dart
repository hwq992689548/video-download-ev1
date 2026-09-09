import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/download_file_name.dart';

void main() {
  test('fromSuggestion uses the typed name and media extension', () {
    const url =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.mp4?t=1';
    expect(
      DownloadFileName.fromSuggestion(url: url, suggested: '自定义名称'),
      '自定义名称.mp4',
    );
    expect(
      DownloadFileName.fromSuggestion(url: url, suggested: '已有后缀.mp4'),
      '已有后缀.mp4',
    );
  });

  test('uniquePath adds a suffix when the file already exists', () async {
    final dir = await Directory.systemTemp.createTemp('download_file_name');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final first = File(p.join(dir.path, '课.mp4'));
    await first.writeAsBytes([1]);

    expect(
      await DownloadFileName.uniquePath(dir.path, fileName: '课.mp4'),
      p.join(dir.path, '课 (1).mp4'),
    );
    expect(
      await DownloadFileName.uniquePath(
        dir.path,
        fileName: '课.mp4',
        ignorePath: first.path,
      ),
      first.path,
    );
  });
}
