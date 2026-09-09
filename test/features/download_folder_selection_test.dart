import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_download_ev1/core/providers.dart';
import 'package:video_download_ev1/features/settings/download_folder_page.dart';
import 'package:video_download_ev1/theme/app_theme.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('download-folder-select-');
    File('${dir.path}/a.mp4').writeAsStringSync('a');
    File('${dir.path}/b.mp4').writeAsStringSync('b');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [videoLibrarySyncProvider.overrideWith((ref) async {})],
        child: MaterialApp(
          theme: buildLightTheme().copyWith(
            splashFactory: NoSplash.splashFactory,
          ),
          home: DownloadFolderPage(directory: dir, title: '下载目录'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('下载目录可多选全选并删除文件', (tester) async {
    await pumpPage(tester);

    expect(find.text('下载目录'), findsOneWidget);
    expect(find.text('选择'), findsOneWidget);
    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('b.mp4'), findsOneWidget);

    await tester.tap(find.text('选择'));
    await tester.pump();
    expect(find.text('全选'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '删除'), findsOneWidget);

    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(find.text('已选 2 项'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pump();
    expect(find.text('确认删除'), findsOneWidget);
    expect(find.text('删除选中的 2 项？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pump();
    await tester.pump();

    expect(
      dir.listSync().where((e) => !p.basename(e.path).startsWith('.')),
      isEmpty,
    );
    expect(find.text('a.mp4'), findsNothing);
    expect(find.text('b.mp4'), findsNothing);
    expect(find.text('这个文件夹是空的'), findsOneWidget);
  });
}
