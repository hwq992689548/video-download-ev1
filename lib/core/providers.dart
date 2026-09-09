import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories/repositories.dart';
import 'download_manager.dart';
import 'download_paths.dart';
import 'baijiayun_converter.dart';
import 'sniff_registry.dart';
import 'video_library_sync.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  return VideoRepository(ref.watch(databaseProvider));
});

final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository(ref.watch(databaseProvider));
});

final recordedLinkRepositoryProvider = Provider<RecordedLinkRepository>((ref) {
  return RecordedLinkRepository(ref.watch(databaseProvider));
});

final sniffRegistryProvider = ChangeNotifierProvider<SniffRegistry>((ref) {
  return SniffRegistry();
});

final dioProvider = Provider<Dio>((ref) => Dio());

final baijiayunConverterProvider =
    Provider<BaijiayunConverter>((ref) => BaijiayunConverter());

final downloadTaskRepositoryProvider = Provider<DownloadTaskRepository>((ref) {
  return DownloadTaskRepository(ref.watch(databaseProvider));
});

final downloadStoragePathsProvider =
    FutureProvider<DownloadStoragePaths>((ref) {
  return resolveDownloadStoragePaths();
});

final downloadManagerProvider = FutureProvider<DownloadManager>((ref) async {
  return createDownloadManager(
    dio: ref.watch(dioProvider),
    converter: ref.watch(baijiayunConverterProvider),
    videos: ref.watch(videoRepositoryProvider),
    tasks: ref.watch(downloadTaskRepositoryProvider),
  );
});

final videoLibrarySyncProvider = FutureProvider<void>((ref) async {
  final paths = await ref.watch(downloadStoragePathsProvider.future);
  final tasks = await ref.watch(downloadTaskRepositoryProvider).getPending();
  await VideoLibrarySync(
    videos: ref.watch(videoRepositoryProvider),
    videosDir: paths.videosDir,
    reservedVideoIds: {for (final task in tasks) task.videoId},
  ).reconcile();
});

final allVideosStreamProvider = StreamProvider<List<VideoRecord>>((ref) {
  return ref.watch(videoRepositoryProvider).watchAll();
});

final recordedLinksStreamProvider = StreamProvider<List<RecordedLink>>((ref) {
  return ref.watch(recordedLinkRepositoryProvider).watchAll();
});
