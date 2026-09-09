import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';

void main() {
  late AppDatabase db;
  late VideoRepository videos;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    videos = VideoRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('findByEv1UrlIn treats reload signed mp4 as the downloaded file', () async {
    const downloaded =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4'
        '?t=6aa16a56&sign=aaa&uuid=old';
    const replayed =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.mp4'
        '?t=6aa16ac1&sign=bbb&uuid=new';
    const ev2 =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198599077_a41ffdbc5f739978647a2273bc9cbe33_Qf7U5d89.ev2?t=9';
    const other =
        'https://dws4jd-video-bak.baijiayun.com/00-x-upload/video/'
        '318761433_b33beda1dc128af4b64f9ba0c0e93fa2_qANuKKA9.mp4?t=1';

    await videos.insert(
      VideoRecordsCompanion.insert(
        id: 'v1',
        displayName: '政治经济学的产生和发展.mp4',
        filePath: '/tmp/政治经济学的产生和发展.mp4',
        sourceUrl: downloaded,
        fileSizeBytes: 10,
        downloadedAt: DateTime(2026, 9, 9),
      ),
    );
    final rows = await videos.getAll();

    expect(videos.findByEv1UrlIn(rows, replayed)?.id, 'v1');
    expect(videos.findByEv1UrlIn(rows, ev2)?.id, 'v1');
    expect(videos.findByEv1UrlIn(rows, other), isNull);
  });
}
