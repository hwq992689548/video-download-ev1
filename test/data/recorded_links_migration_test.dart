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

  test('upgrades schema 3 (no recorded_links) to 5 without duplicate column', () async {
    final db = AppDatabase.connect(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(db.close);

    await db.into(db.recordedLinks).insert(
      RecordedLinksCompanion.insert(
        id: '3',
        url: 'https://cdn.example.com/video/from-v3.ev1',
        displayName: const Value('从旧库升上来'),
        recordedAt: DateTime(2026, 9, 9),
      ),
    );

    final rows = await db.select(db.recordedLinks).get();
    expect(rows, hasLength(1));
    expect(rows.single.displayName, '从旧库升上来');
  });

  test('upgrades schema 4 recorded_links by adding display_name', () async {
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
            ..execute('''
              INSERT INTO recorded_links (id, url, recorded_at)
              VALUES ('4', 'https://cdn.example.com/video/from-v4.ev1', 0)
            ''')
            ..execute('PRAGMA user_version = 4');
        },
      ),
    );
    addTearDown(db.close);

    final rows = await db.select(db.recordedLinks).get();
    expect(rows, hasLength(1));
    expect(rows.single.url, 'https://cdn.example.com/video/from-v4.ev1');
    expect(rows.single.displayName, equals(null));

    await db.into(db.recordedLinks).insert(
      RecordedLinksCompanion.insert(
        id: '4b',
        url: 'https://cdn.example.com/video/named.ev1',
        displayName: const Value('有名字'),
        recordedAt: DateTime(2026, 9, 9),
      ),
    );
    final named = await (db.select(db.recordedLinks)
          ..where((t) => t.id.equals('4b')))
        .getSingle();
    expect(named.displayName, '有名字');
  });
}
