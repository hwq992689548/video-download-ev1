import 'package:drift/drift.dart';

import '../../core/ev1_url.dart';
import '../database.dart';

class VideoRepository {
  VideoRepository(this._db);

  final AppDatabase _db;

  Stream<List<VideoRecord>> watchAll() {
    return (_db.select(_db.videoRecords)
          ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)]))
        .watch();
  }

  Stream<List<VideoRecord>> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return watchAll();
    return (_db.select(_db.videoRecords)
          ..where((t) => t.displayName.lower().contains(q))
          ..orderBy([(t) => OrderingTerm.desc(t.downloadedAt)]))
        .watch();
  }

  Future<void> insert(VideoRecordsCompanion row) =>
      _db.into(_db.videoRecords).insert(row);

  Future<void> rename(String id, String name) => (_db.update(_db.videoRecords)
        ..where((t) => t.id.equals(id)))
      .write(VideoRecordsCompanion(displayName: Value(name)));

  Future<VideoRecord?> getById(String id) => (_db.select(_db.videoRecords)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();

  /// Match by normalized .ev1 path (ignores changing sign/t/uuid query params).
  Future<VideoRecord?> findByEv1Url(String url) async {
    final key = Ev1Url.normalizeKey(url);
    final rows = await _db.select(_db.videoRecords).get();
    for (final row in rows) {
      if (Ev1Url.normalizeKey(row.sourceUrl) == key) return row;
    }
    return null;
  }

  VideoRecord? findByEv1UrlIn(List<VideoRecord> videos, String url) {
    final key = Ev1Url.normalizeKey(url);
    for (final row in videos) {
      if (Ev1Url.normalizeKey(row.sourceUrl) == key) return row;
    }
    return null;
  }

  Future<void> deleteById(String id) => (_db.delete(_db.videoRecords)
        ..where((t) => t.id.equals(id)))
      .go();
}

class BookmarkRepository {
  BookmarkRepository(this._db);

  final AppDatabase _db;

  Stream<List<Bookmark>> watchAll() {
    return (_db.select(_db.bookmarks)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<void> insert(BookmarksCompanion row) =>
      _db.into(_db.bookmarks).insert(row);

  Future<void> deleteById(String id) => (_db.delete(_db.bookmarks)
        ..where((t) => t.id.equals(id)))
      .go();
}

class DownloadTaskRepository {
  DownloadTaskRepository(this._db);

  final AppDatabase _db;

  Stream<List<DownloadTask>> watchPending() {
    return (_db.select(_db.downloadTasks)
          ..where((t) => t.status.isNotIn(['completed']))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<List<DownloadTask>> getResumable() {
    return (_db.select(_db.downloadTasks)
          ..where((t) => t.status.isIn(['queued', 'downloading', 'converting'])))
        .get();
  }

  Future<void> insert(DownloadTasksCompanion row) =>
      _db.into(_db.downloadTasks).insert(row);

  Future<void> updateProgress({
    required String id,
    required int bytesDownloaded,
    int? totalBytes,
    required String status,
    String? error,
  }) {
    return (_db.update(_db.downloadTasks)..where((t) => t.id.equals(id))).write(
      DownloadTasksCompanion(
        bytesDownloaded: Value(bytesDownloaded),
        totalBytes: totalBytes != null ? Value(totalBytes) : const Value.absent(),
        status: Value(status),
        error: error != null ? Value(error) : const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteById(String id) => (_db.delete(_db.downloadTasks)
        ..where((t) => t.id.equals(id)))
      .go();

  Future<DownloadTask?> getById(String id) => (_db.select(_db.downloadTasks)
        ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
}
