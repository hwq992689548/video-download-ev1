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

  test('forDisplay strips the media extension for rename fields', () {
    expect(DownloadFileName.forDisplay('绪论.mp4'), '绪论');
    expect(DownloadFileName.forDisplay('课 (1).flv'), '课 (1)');
    expect(DownloadFileName.forDisplay('1.1 引言.mp4'), '1.1 引言');
    expect(DownloadFileName.forDisplay('政治经济学的研究任务'), '政治经济学的研究任务');
  });

  test('withMediaExtension keeps mp4 when the stem contains a dot', () {
    expect(
      DownloadFileName.withMediaExtension(
        '1.1 引言',
        existingPath: '/videos/1.1 引言.mp4',
      ),
      '1.1 引言.mp4',
    );
    expect(
      DownloadFileName.withMediaExtension(
        '1.1 引言.mp4',
        existingPath: '/videos/old.mp4',
      ),
      '1.1 引言.mp4',
    );
    expect(
      DownloadFileName.withMediaExtension(
        '加密课',
        existingPath: r'D:\EV1Downloads\videos\加密课.flv',
      ),
      '加密课.flv',
    );
  });

  test('forList appends mp4, flv or m3u8 when the title has no suffix', () {
    const mp4Url =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599077_abc.mp4?t=1';
    const m3u8Url =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/198599078_abc.m3u8?t=1';
    const ev1Url = 'https://cdn.example.com/video/foo.ev1?sign=1';

    expect(
      DownloadFileName.forList(name: '第一节 政治经济学的产生和发展', url: mp4Url),
      '第一节 政治经济学的产生和发展.mp4',
    );
    expect(
      DownloadFileName.forList(name: 'playlist', url: m3u8Url),
      'playlist.m3u8',
    );
    expect(DownloadFileName.forList(name: '加密课', url: ev1Url), '加密课.flv');
    expect(
      DownloadFileName.forList(name: '绪论.mp4', url: mp4Url),
      '绪论.mp4',
    );
    expect(
      DownloadFileName.forList(
        name: 'lesson',
        filePath: '/videos/lesson.mp4',
      ),
      'lesson.mp4',
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
