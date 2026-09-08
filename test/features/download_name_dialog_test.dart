import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/features/browser/download_name_dialog.dart';

void main() {
  Future<String?> openDialog(WidgetTester tester, {String name = '第1讲 绪论'}) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDownloadNameDialog(
                context,
                defaultName: name,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows current name as text and placeholder', (tester) async {
    await openDialog(tester);
    expect(find.text('下载文件名'), findsOneWidget);
    expect(find.text('第1讲 绪论'), findsWidgets);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('立即下载'), findsOneWidget);
  });

  testWidgets('cancel does not start download', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDownloadNameDialog(
                context,
                defaultName: '第1讲 绪论',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('立即下载 returns edited name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDownloadNameDialog(
                context,
                defaultName: '第1讲 绪论',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '自定义名称');
    await tester.tap(find.text('立即下载'));
    await tester.pumpAndSettle();
    expect(result, '自定义名称');
  });

  testWidgets('empty input falls back to default name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDownloadNameDialog(
                context,
                defaultName: '第1讲 绪论',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('立即下载'));
    await tester.pumpAndSettle();
    expect(result, '第1讲 绪论');
  });
}
