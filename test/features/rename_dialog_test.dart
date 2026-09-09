import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/features/downloads/rename_dialog.dart';

void main() {
  Future<String?> openDialog(
    WidgetTester tester, {
    String name = '第1讲 绪论',
  }) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRenameDialog(
                context,
                initialName: name,
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

  testWidgets('shows current name and actions', (tester) async {
    await openDialog(tester);
    expect(find.text('重命名'), findsOneWidget);
    expect(find.text('第1讲 绪论'), findsWidgets);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    expect(find.byTooltip('清除'), findsOneWidget);
  });

  testWidgets('cancel does not return a name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRenameDialog(
                context,
                initialName: '第1讲 绪论',
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

  testWidgets('保存 returns edited name', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRenameDialog(
                context,
                initialName: '第1讲 绪论',
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(result, '自定义名称');
  });

  testWidgets('clear button empties the name field', (tester) async {
    await openDialog(tester);
    expect(find.text('第1讲 绪论'), findsWidgets);
    await tester.tap(find.byTooltip('清除'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      isEmpty,
    );
    expect(find.byTooltip('清除'), findsNothing);
  });
}
