import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';
import 'package:video_download_ev1/features/test/recorded_links_page.dart';

void main() {
  late AppDatabase db;
  late RecordedLinkRepository repo;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    repo = RecordedLinkRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('stores and displays a recorded link name', () async {
    const url =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=1';
    await repo.insert(
      RecordedLinksCompanion.insert(
        id: '1',
        url: url,
        displayName: const Value('第3节 政治经济学的研究任务'),
        recordedAt: DateTime(2026, 9, 9),
      ),
    );

    final link = await repo.findByUrl(url);
    expect(recordedLinkDisplayName(link!), '第3节 政治经济学的研究任务.mp4');
  });

  test('falls back to the CDN stem with media suffix when no name was saved', () {
    const url =
        'https://dws4jd-video.baijiayun.com/00-x-upload/video/'
        '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4?t=1';
    final link = RecordedLink(
      id: '1',
      url: url,
      recordedAt: DateTime(2026, 9, 9),
    );
    expect(
      recordedLinkDisplayName(link),
      '198409541_c34f0e3e11b082be55fb8bed41e3d261_eocoQLcR.mp4',
    );
  });

  test('appends .flv for recorded ev1 links', () {
    const url = 'https://cdn.example.com/video/foo.ev1?sign=1';
    final link = RecordedLink(
      id: '2',
      url: url,
      displayName: '加密课',
      recordedAt: DateTime(2026, 9, 9),
    );
    expect(recordedLinkDisplayName(link), '加密课.flv');
  });
}
