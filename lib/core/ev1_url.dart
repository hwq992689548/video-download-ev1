/// Stable identity for Baijiayun .ev1 URLs (path stays same; sign/t/uuid change).
class Ev1Url {
  Ev1Url._();

  static String normalizeKey(String url) {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed.toLowerCase();
    return uri.path.toLowerCase();
  }

  static bool sameResource(String a, String b) =>
      normalizeKey(a) == normalizeKey(b);

  /// Mobile H5 asks Baijiayun for m3u8/mp4. Rewrite so it returns .ev1/.ev2.
  static String rewritePlayUrl(String url) {
    if (!url.contains('getPlayUrl')) return url;
    var next = url.replaceAllMapped(
      RegExp(r'([?&]client_type=)h5\b', caseSensitive: false),
      (match) => '${match[1]}pc',
    );
    next = next.replaceAllMapped(
      RegExp(r'([?&]supports_format=)([^&]*)', caseSensitive: false),
      (match) {
        final current = Uri.decodeQueryComponent(match[2] ?? '');
        if (RegExp(r'ev[12]?', caseSensitive: false).hasMatch(current)) {
          return match[0]!;
        }
        return '${match[1]}ev1,ev2,$current';
      },
    );
    return next;
  }
}
