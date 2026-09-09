import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';

void main() {
  late AppDatabase db;
  late VideoRepository videos;
  late Directory tmp;

  setUp(() async {
    db = AppDatabase.connect(NativeDatabase.memory());
    videos = VideoRepository(db);
    tmp = await Directory.systemTemp.createTemp('video-rename');
  });

  tearDown(() async {
    await db.close();
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('rename keeps .mp4 when the new stem contains a dotted section number', () async {
    final file = File(p.join(tmp.path, '1.1 引言.mp4'));
    await file.writeAsBytes([1, 2, 3]);
    await videos.insert(
      VideoRecordsCompanion.insert(
        id: 'v1',
        displayName: '1.1 引言.mp4',
        filePath: file.path,
        sourceUrl: 'https://cdn.example.com/video/1.mp4',
        fileSizeBytes: 3,
        downloadedAt: DateTime(2026, 9, 9),
      ),
    );

    await videos.rename('v1', '1.1 引言');

    final updated = await videos.getById('v1');
    expect(updated?.displayName, '1.1 引言.mp4');
    expect(updated?.filePath, file.path);
    expect(await file.exists(), isTrue);
    expect(p.extension(updated!.filePath), '.mp4');
  });
}
