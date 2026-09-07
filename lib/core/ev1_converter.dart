import 'dart:io';
import 'dart:typed_data';

class Ev1ConversionException implements Exception {
  Ev1ConversionException(this.message);
  final String message;

  @override
  String toString() => 'Ev1ConversionException: $message';
}

/// Converts Baijiayun-style EV1 files to FLV by XOR-ing the first 100 bytes with 0xFF.
class Ev1Converter {
  static const int headerSize = 100;
  static const int xorKey = 0xFF;

  Uint8List transformHeader(Uint8List encryptedHeader) {
    if (encryptedHeader.length != headerSize) {
      throw Ev1ConversionException('Header must be exactly $headerSize bytes');
    }
    final out = Uint8List(headerSize);
    for (var i = 0; i < headerSize; i++) {
      out[i] = encryptedHeader[i] ^ xorKey;
    }
    return out;
  }

  Future<void> convert({
    required String inputPath,
    required String outputPath,
  }) async {
    final input = File(inputPath);
    if (!await input.exists()) {
      throw Ev1ConversionException('Input not found: $inputPath');
    }

    final length = await input.length();
    if (length < headerSize) {
      throw Ev1ConversionException('File too small: $length bytes');
    }

    final raf = await input.open();
    try {
      final encryptedHeader = Uint8List(headerSize);
      await raf.readInto(encryptedHeader);
      final transformed = transformHeader(encryptedHeader);

      final out = File(outputPath).openSync(mode: FileMode.write);
      try {
        out.writeFromSync(transformed);
        final buffer = Uint8List(64 * 1024);
        while (true) {
          final n = await raf.readInto(buffer);
          if (n == 0) break;
          out.writeFromSync(buffer, 0, n);
        }
      } finally {
        out.closeSync();
      }
    } finally {
      await raf.close();
    }

    final magic = File(outputPath).openSync()..setPositionSync(0);
    try {
      final check = magic.readSync(4);
      if (!_isFlvMagic(check)) {
        await File(outputPath).delete();
        throw Ev1ConversionException('Output is not valid FLV after transform');
      }
    } finally {
      magic.closeSync();
    }
  }

  bool _isFlvMagic(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x46 &&
      bytes[1] == 0x4C &&
      bytes[2] == 0x56 &&
      bytes[3] == 0x01;
}
