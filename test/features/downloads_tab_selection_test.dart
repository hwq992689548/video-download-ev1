import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/providers.dart';
import 'package:video_download_ev1/data/database.dart';
import 'package:video_download_ev1/features/downloads/downloads_tab.dart';
import 'package:video_download_ev1/theme/app_theme.dart';

void main() {
  late AppDatabase db;
  late StreamController<List<VideoRecord>> videos;

  setUp(() {
    db = AppDatabase.connect(NativeDatabase.memory());
    videos = StreamController<List<VideoRecord>>.broadcast();
  });

  tearDown(() async {
    await videos.close();
    await db.close();
  });

  Future<void> emitVideos() async {
    videos.add(await db.select(db.videoRecords).get());
  }

  Future<void> pumpTab(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allVideosStreamProvider.overrideWith((ref) => videos.stream),
          pendingDownloadsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          videoLibrarySyncProvider.overrideWith((ref) async {}),
          downloadManagerProvider.overrideWith(
            (ref) => Future.error(StateError('unused')),
          ),
        ],
        child: MaterialApp(
          theme: buildLightTheme().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: const Scaffold(body: DownloadsTab()),
        ),
      ),
    );
    await emitVideos();
    await tester.pump();
  }

  Future<void> insertVideo({required String id, required String name}) {
    return db
        .into(db.videoRecords)
        .insert(
          VideoRecordsCompanion.insert(
            id: id,
            displayName: name,
            filePath: '/tmp/video-download-ev1-missing-$id.mp4',
            sourceUrl: 'https://cdn.example.com/video/${id}_hash_token.mp4',
            fileSizeBytes: 1024,
            downloadedAt: DateTime(2026, 9, 9),
          ),
        );
  }

  testWidgets('选择后可全选并批量删除视频', (tester) async {
    await insertVideo(id: 'v1', name: '政治经济学的产生和发展');
    await insertVideo(id: 'v2', name: '政治经济学的研究对象');
    await pumpTab(tester);

    expect(find.text('选择'), findsOneWidget);
    expect(find.text('政治经济学的产生和发展.mp4'), findsOneWidget);
    expect(find.text('政治经济学的研究对象.mp4'), findsOneWidget);

    await tester.tap(find.text('选择'));
    await tester.pump();

    expect(find.text('全选'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '删除'), findsOneWidget);
    expect(find.text('已选 0 项'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(find.text('已选 2 项'), findsOneWidget);
    expect(find.text('取消全选'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump();
    expect(find.text('确认删除'), findsOneWidget);
    expect(find.text('删除选中的 2 项？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump();
    await emitVideos();
    await tester.pump();

    expect(await db.select(db.videoRecords).get(), isEmpty);
    expect(find.text('暂无视频，去浏览器 Tab 嗅探 .ev1 链接'), findsOneWidget);
  });

  testWidgets('选择单条后再删除', (tester) async {
    await insertVideo(id: 'v1', name: '课一');
    await insertVideo(id: 'v2', name: '课二');
    await pumpTab(tester);

    await tester.tap(find.text('选择'));
    await tester.pump();
    await tester.tap(find.text('课一.mp4'));
    await tester.pump();
    expect(find.text('已选 1 项'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump();
    await emitVideos();
    await tester.pump();

    expect(find.text('课一.mp4'), findsNothing);
    expect(find.text('课二.mp4'), findsOneWidget);
  });

  testWidgets('选择模式下删除按钮不贴导航栏右缘', (tester) async {
    await insertVideo(id: 'v1', name: '课一');
    await pumpTab(tester);

    await tester.tap(find.text('选择'));
    await tester.pump();

    final delete = tester.getRect(find.widgetWithText(TextButton, '删除'));
    final screen = tester.getSize(find.byType(Scaffold));
    expect(screen.width - delete.right, greaterThanOrEqualTo(16));

    final selectAll = tester.getRect(find.widgetWithText(TextButton, '全选'));
    expect(delete.left - selectAll.right, greaterThanOrEqualTo(8));
  });
}
