import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/ev1_url.dart';
import 'package:video_download_ev1/core/sniff_registry.dart';

void main() {
  test('Ev1Url.sameResource ignores query params', () {
    const a =
        'https://cdn.example.com/video/foo.ev1?t=1&sign=aaa';
    const b =
        'https://cdn.example.com/video/foo.ev1?t=2&sign=bbb';
    expect(Ev1Url.sameResource(a, b), isTrue);
    expect(Ev1Url.normalizeKey(a), '/video/foo.ev1');
  });

  test('SniffRegistry deduplicates by ev1 path', () {
    final r = SniffRegistry();
    r.register('t', 'https://x.com/a.ev1?sign=1');
    r.register('t', 'https://x.com/a.ev1?sign=2');
    expect(r.entriesFor('t').length, 1);
    expect(r.entriesFor('t').first.url, contains('sign=2'));
  });
}
