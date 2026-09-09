import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/data/repositories/repositories.dart';

void main() {
  test('adds display_name when recorded_links already exists without it', () async {
    final db = AppDatabase.connect(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('''
              CREATE TABLE recorded_links (
                id TEXT NOT NULL PRIMARY KEY,
                url TEXT NOT NULL,
                recorded_at INTEGER NOT NULL
              )
            ''')
            ..execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(db.close);

    await db.into(db.recordedLinks).insert(
      RecordedLinksCompanion.insert(
        id: '1',
        url: 'https://cdn.example.com/video/foo.ev1',
        displayName: const Value('政治经济学的研究对象'),
        recordedAt: DateTime(2026, 9, 9),
      ),
    );

    final rows = await db.select(db.recordedLinks).get();
    expect(rows, hasLength(1));
    expect(rows.single.displayName, '政治经济学的研究对象');
  });

  test('repository insert patches display_name on an already-open old table', () async {
    final db = AppDatabase.connect(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('''
              CREATE TABLE recorded_links (
                id TEXT NOT NULL PRIMARY KEY,
                url TEXT NOT NULL,
                recorded_at INTEGER NOT NULL
              )
            ''')
            ..execute('PRAGMA user_version = 5');
        },
      ),
    );
    addTearDown(db.close);
    final repo = RecordedLinkRepository(db);

    await repo.insert(
      RecordedLinksCompanion.insert(
        id: '2',
        url: 'https://cdn.example.com/video/bar.ev1',
        displayName: const Value('加密课'),
        recordedAt: DateTime(2026, 9, 9),
      ),
    );

    final found = await repo.findByUrl('https://cdn.example.com/video/bar.ev1');
    expect(found?.displayName, '加密课');
  });
}
