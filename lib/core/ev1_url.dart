/// Stable identity for Baijiayun media URLs.
///
/// Query `t` / `sign` / `uuid` change on every play. CDN host and
/// `.mp4` / `.ev1` / `.ev2` / `.m3u8` can also differ. The filename stem
/// `vid_hash_token` is the same object, so that is the identity when present.
class Ev1Url {
  Ev1Url._();

  static final _mediaExt = RegExp(
    r'\.(mp4|m3u8|ev[12])$',
    caseSensitive: false,
  );
  static final _stemPattern = RegExp(r'^\d{6,}_[A-Za-z0-9_]+$');

  /// CDN filename without extension, e.g. `198599077_a41ffdbc…_Qf7U5d89`.
  static String? resourceStem(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final name = uri.pathSegments.last;
    final stem = name.replaceFirst(_mediaExt, '');
    if (!_stemPattern.hasMatch(stem)) return null;
    return stem;
  }

  static String normalizeKey(String url) {
    final trimmed = url.trim();
    final stem = resourceStem(trimmed);
    if (stem != null) return 'stem:${stem.toLowerCase()}';
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
