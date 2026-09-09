import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/video_library_sync.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';

void main() {
  group(
    'VideoLibrarySync',
    () {
      late Directory tmp;
      late Directory videosDir;
      late AppDatabase db;
      late VideoRepository repo;
      late List<String> logs;

      setUp(() async {
        tmp = await Directory.systemTemp.createTemp('video_library_sync');
        videosDir = Directory(p.join(tmp.path, 'videos'));
        await videosDir.create(recursive: true);
        db = AppDatabase.connect(NativeDatabase.memory());
        repo = VideoRepository(db);
        logs = [];
      });

      tearDown(() async {
        await db.close();
        if (await tmp.exists()) await tmp.delete(recursive: true);
      });

      VideoLibrarySync sync({Set<String> reservedVideoIds = const {}}) {
        return VideoLibrarySync(
          videos: repo,
          videosDir: videosDir,
          reservedVideoIds: reservedVideoIds,
          log: (tag, message) => logs.add('[$tag] $message'),
        );
      }

      Future<void> insertRecord({
        required String id,
        required String filePath,
        String name = '已下载',
        String url = 'https://example.com/a.ev1',
      }) {
        return repo.insert(
          VideoRecordsCompanion.insert(
            id: id,
            displayName: name,
            filePath: filePath,
            sourceUrl: url,
            fileSizeBytes: 12,
            downloadedAt: DateTime(2026, 1, 1),
          ),
        );
      }

      test('removes database rows whose files are gone and logs the reason', () async {
        await insertRecord(id: 'gone', filePath: p.join(videosDir.path, 'gone.flv'));

        await sync().reconcile();

        expect(await repo.getAll(), isEmpty);
        expect(logs.join('\n'), contains('gone.flv'));
        expect(logs.join('\n'), contains('文件不存在'));
        expect(logs.join('\n'), contains('已删除'));
      });

      test('imports video files that are not in the database', () async {
        final file = File(p.join(videosDir.path, 'lesson.mp4'));
        await file.writeAsBytes([1, 2, 3, 4]);

        await sync().reconcile();

        final rows = await repo.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'lesson');
        expect(rows.single.displayName, 'lesson');
        expect(rows.single.filePath, file.path);
        expect(rows.single.sourceUrl, isEmpty);
        expect(rows.single.fileSizeBytes, 4);
        expect(logs.join('\n'), contains('lesson.mp4'));
        expect(logs.join('\n'), contains('下载链接为空'));
        expect(logs.join('\n'), contains('已入库'));
      });

      test('keeps matching records and skips reserved in-progress files', () async {
        final kept = File(p.join(videosDir.path, 'kept.flv'));
        await kept.writeAsBytes([9, 9]);
        await insertRecord(id: 'kept', filePath: kept.path);

        final downloading = File(p.join(videosDir.path, 'job.flv'));
        await downloading.writeAsBytes([8]);

        await sync(reservedVideoIds: {'job'}).reconcile();

        final rows = await repo.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'kept');
        expect(logs.join('\n'), isNot(contains('已删除')));
        expect(logs.join('\n'), isNot(contains('已入库')));
      });

      test('ignores non-video files and keeps records whose files still exist', () async {
        await File(p.join(videosDir.path, 'notes.txt')).writeAsString('x');
        await File(p.join(videosDir.path, 'partial.flv.tmp')).writeAsBytes([1]);

        final outside = File(p.join(tmp.path, 'legacy.mp4'));
        await outside.writeAsBytes([1, 2]);
        await insertRecord(id: 'legacy', filePath: outside.path);

        await sync().reconcile();

        final rows = await repo.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, 'legacy');
        expect(logs.join('\n'), isNot(contains('已删除')));
        expect(logs.join('\n'), isNot(contains('已入库')));
      });
    },
    skip: Platform.isWindows
        ? 'sqlite3 is process-linked; flutter test on Windows has no sqlite3.dll'
        : false,
  );
}
