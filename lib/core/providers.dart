import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/repositories/repositories.dart';
import 'download_manager.dart';
import 'ev1_converter.dart';
import 'sniff_registry.dart';

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

final sniffRegistryProvider = ChangeNotifierProvider<SniffRegistry>((ref) {
  return SniffRegistry();
});

final dioProvider = Provider<Dio>((ref) => Dio());

final ev1ConverterProvider = Provider<Ev1Converter>((ref) => Ev1Converter());

final downloadTaskRepositoryProvider = Provider<DownloadTaskRepository>((ref) {
  return DownloadTaskRepository(ref.watch(databaseProvider));
});

final downloadManagerProvider = FutureProvider<DownloadManager>((ref) async {
  return createDownloadManager(
    dio: ref.watch(dioProvider),
    converter: ref.watch(ev1ConverterProvider),
    videos: ref.watch(videoRepositoryProvider),
    tasks: ref.watch(downloadTaskRepositoryProvider),
  );
});

final allVideosStreamProvider = StreamProvider<List<VideoRecord>>((ref) {
  return ref.watch(videoRepositoryProvider).watchAll();
});
