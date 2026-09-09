import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/theme/app_theme.dart';

void main() {
  testWidgets('AppGroup with ListTile does not hide ink under DecoratedBox', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppGroup(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: const Text('课.mp4'),
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      errors.where(
        (e) => e.exception.toString().contains(
          'ListTile background color or ink splashes may be invisible',
        ),
      ),
      isEmpty,
    );
    expect(find.text('课.mp4'), findsOneWidget);
  });
}
