import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/directory_picker.dart';
import 'package:video_download_ev1/core/download_paths.dart';
import 'package:video_download_ev1/core/providers.dart';
import 'package:video_download_ev1/features/settings/settings_tab.dart';

void main() {
  testWidgets('Settings tab lists tools and download path', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadStoragePathsProvider.overrideWith(
            (ref) async => DownloadStoragePaths(
              videosDir: Directory('/tmp/videos'),
              tempDir: Directory('/tmp/tmp'),
              customRoot: '/tmp',
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsTab())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('链接记录'), findsOneWidget);
    expect(find.text('可以查看记录下的链接'), findsOneWidget);
    expect(find.text('下载测试'), findsOneWidget);
    expect(find.text('导出日志'), findsOneWidget);
    expect(find.text('查看下载目录'), findsOneWidget);
    expect(
      find.text('修改下载目录'),
      isDesktopPlatform ? findsOneWidget : findsNothing,
    );
    expect(find.text('/tmp'), findsWidgets);
  });
}
