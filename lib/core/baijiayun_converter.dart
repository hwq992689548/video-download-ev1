import 'ev1_converter.dart';
import 'ev2_converter.dart';

/// Converts downloaded Baijiayun encrypted videos (.ev1 / .ev2) to playable FLV.
class BaijiayunConverter {
  BaijiayunConverter({
    Ev1Converter? ev1,
    Ev2Converter? ev2,
  })  : _ev1 = ev1 ?? Ev1Converter(),
        _ev2 = ev2 ?? Ev2Converter();

  final Ev1Converter _ev1;
  final Ev2Converter _ev2;

  static bool isEv2Source(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) return false;
    return sourceUrl.toLowerCase().contains('.ev2');
  }

  Future<void> convert({
    required String inputPath,
    required String outputPath,
    String? sourceUrl,
  }) async {
    if (isEv2Source(sourceUrl)) {
      await _ev2.convert(inputPath: inputPath, outputPath: outputPath);
      return;
    }
    await _ev1.convert(inputPath: inputPath, outputPath: outputPath);
  }
}
