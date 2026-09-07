import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/ev1_converter.dart';
import 'package:video_download_ev1/core/sniff_registry.dart';

void main() {
  group('Ev1Converter', () {
    late Directory tmp;

    setUp(() async => tmp = await Directory.systemTemp.createTemp('ev1_test'));
    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    test('transformHeader XOR produces FLV magic', () {
      final converter = Ev1Converter();
      final encrypted = Uint8List.fromList([
        0x46 ^ 0xFF, 0x4C ^ 0xFF, 0x56 ^ 0xFF, 0x01 ^ 0xFF,
        ...List.filled(96, 0xAB),
      ]);
      final out = converter.transformHeader(encrypted);
      expect(out.sublist(0, 4), [0x46, 0x4C, 0x56, 0x01]);
    });

    test('convert writes valid FLV file', () async {
      final converter = Ev1Converter();
      final input = File('${tmp.path}/in.ev1');
      final output = File('${tmp.path}/out.flv');
      await input.writeAsBytes(Uint8List.fromList([
        0x46 ^ 0xFF, 0x4C ^ 0xFF, 0x56 ^ 0xFF, 0x01 ^ 0xFF,
        ...List.filled(96, 0), ...List.filled(16, 0x11),
      ]));
      await converter.convert(inputPath: input.path, outputPath: output.path);
      expect(await output.openRead(0, 4).first, [0x46, 0x4C, 0x56, 0x01]);
    });
  });

  test('SniffRegistry deduplicates ev1 urls', () {
    final r = SniffRegistry();
    r.register('t', 'https://x.com/a.ev1');
    r.register('t', 'https://x.com/a.ev1');
    expect(r.entriesFor('t').length, 1);
    expect(SniffRegistry.isEv1Url('https://x.com/a.EV1?q=1'), isTrue);
  });
}
