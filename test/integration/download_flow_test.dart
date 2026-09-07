import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/baijiayun_converter.dart';

/// Mirrors app storage layout:
/// - Documents/videos/  → final .flv (same as getApplicationDocumentsDirectory()/videos)
/// - tmp/downloads/     → transient .ev1.raw / .flv.tmp during job
const _testUrl =
    'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/207233243_a8f1dae214f353a566ee392390c1d7f7_yQgUFTXm_mp4/207233243_a8f1dae214f353a566ee392390c1d7f7_yQgUFTXm.ev1?t=6a9f15c8&sign=d1afdff06b69494edb077db832846356&fid=198401516&uuid=7b8fc57f-f63d-5f36-b584-5056301f44d9';

void main() {
  test(
    'download EV1 → convert → save under Documents/videos',
    () async {
      final root = Directory(p.join(Directory.current.path, '.test_download'));
      final videosDir = Directory(p.join(root.path, 'Documents', 'videos'));
      final tempDir = Directory(p.join(root.path, 'tmp', 'downloads'));
      await videosDir.create(recursive: true);
      await tempDir.create(recursive: true);

      final rawPath = p.join(tempDir.path, 'flow_test.ev1.raw');
      final tmpFlvPath = p.join(tempDir.path, 'flow_test.flv.tmp');
      final finalPath = p.join(videosDir.path, 'flow_test.flv');

      // Step 1: download (same as DownloadManager._dio.download)
      final dio = Dio();
      await dio.download(
        _testUrl,
        rawPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            // ignore: avoid_print
            print('downloading: ${(received / total * 100).toStringAsFixed(1)}%');
          }
        },
      );

      final rawSize = await File(rawPath).length();
      expect(rawSize, greaterThan(100));

      // Step 2: convert (same as DownloadManager._converter.convert)
      await BaijiayunConverter().convert(inputPath: rawPath, outputPath: tmpFlvPath);
      await File(tmpFlvPath).copy(finalPath);

      // Step 3: cleanup temp (same as DownloadManager finally block)
      for (final path in [rawPath, tmpFlvPath]) {
        final f = File(path);
        if (await f.exists()) await f.delete();
      }

      // Step 4: verify final artifact in Documents/videos
      final flv = File(finalPath);
      expect(await flv.exists(), isTrue);
      final magic = await flv.openRead(0, 4).first;
      expect(magic, [0x46, 0x4C, 0x56, 0x01]);
      expect(await flv.length(), rawSize);

      // ignore: avoid_print
      print('OK finalPath=$finalPath size=${await flv.length()}');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
