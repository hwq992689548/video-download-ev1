import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';

void main() {
  late AppDatabase db;
  late DownloadTaskRepository tasks;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    tasks = DownloadTaskRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('updateSuggestedName keeps the new title for an in-progress download', () async {
    final now = DateTime(2026, 9, 9);
    await tasks.insert(
      DownloadTasksCompanion.insert(
        id: 'job-1',
        sourceUrl: 'https://example.com/video/198409541_abc.mp4',
        suggestedName: const Value('政治经济学的研究任务'),
        rawPath: '/tmp/job-1.ev1.raw',
        videoId: 'vid-1',
        status: 'downloading',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await tasks.updateSuggestedName('job-1', '第3节 自定义名');
    final updated = await tasks.getById('job-1');
    expect(updated?.suggestedName, '第3节 自定义名');
    expect(updated?.status, 'downloading');
  });
}
