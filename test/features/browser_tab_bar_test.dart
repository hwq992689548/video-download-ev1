import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/features/browser/browser_tab_bar.dart';
import 'package:video_download_ev1/theme/app_theme.dart';

void main() {
  testWidgets('标签关闭按钮与探测链接之间有间距', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: BrowserTabBar(onSniff: () {}),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('新标签页'));
    await tester.pump();

    final closeIcon = tester.getRect(find.byIcon(Icons.close).last);
    final sniff = tester.getRect(find.text('探测链接'));
    expect(sniff.left - closeIcon.right, greaterThanOrEqualTo(24));
  });
}
