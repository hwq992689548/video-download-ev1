import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class VideoRecords extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get filePath => text()();
  TextColumn get sourceUrl => text()();
  IntColumn get fileSizeBytes => integer()();
  DateTimeColumn get downloadedAt => dateTime()();
  IntColumn get durationMs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Persisted in-progress download for resume after interruption or app restart.
class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get suggestedName => text().nullable()();
  TextColumn get rawPath => text()();
  TextColumn get videoId => text()();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  TextColumn get status => text()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// User-saved .ev1 links from the sniff panel (for later copy/download).
class RecordedLinks extends Table {
  TextColumn get id => text()();
  TextColumn get url => text()();
  DateTimeColumn get recordedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [VideoRecords, Bookmarks, DownloadTasks, RecordedLinks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.connect(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(downloadTasks);
          }
          if (from < 4) {
            await m.createTable(recordedLinks);
          }
        },
        beforeOpen: (details) async {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS recorded_links (
              id TEXT NOT NULL PRIMARY KEY,
              url TEXT NOT NULL,
              recorded_at INTEGER NOT NULL
            )
          ''');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'app.db'));
    return NativeDatabase.createInBackground(file);
  });
}
