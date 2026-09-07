import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/baijiayun_converter.dart';

void main() {
  group('BaijiayunConverter', () {
    test('detects ev2 source urls', () {
      expect(
        BaijiayunConverter.isEv2Source(
          'https://cdn.example.com/video/123.ev2?sign=1',
        ),
        isTrue,
      );
      expect(
        BaijiayunConverter.isEv2Source(
          'https://cdn.example.com/video/123.ev1?sign=1',
        ),
        isFalse,
      );
    });
  });
}
