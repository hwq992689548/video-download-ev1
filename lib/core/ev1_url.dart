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
}
