import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_download_ev1/app.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
  });

  testWidgets('App loads downloads tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VideoDownloadEv1App()));
    await tester.pumpAndSettle();
    expect(find.text('视频列表'), findsOneWidget);
  });
}
