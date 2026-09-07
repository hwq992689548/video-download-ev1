/// Pure helpers for HTTP Range resume progress calculation.
class ResumableDownloadProgress {
  const ResumableDownloadProgress({
    required this.startByte,
    required this.received,
    required this.total,
    this.knownTotalBytes,
  });

  final int startByte;
  final int received;
  final int total;
  final int? knownTotalBytes;

  int get downloadedBytes => startByte + received;

  int? get fullTotalBytes {
    if (total > 0) return startByte + total;
    if (knownTotalBytes != null && knownTotalBytes! > 0) return knownTotalBytes;
    return null;
  }

  double? get fraction {
    final full = fullTotalBytes;
    if (full == null || full <= 0) return null;
    return downloadedBytes / full;
  }
}

String? rangeHeaderFor(int startByte) {
  if (startByte <= 0) return null;
  return 'bytes=$startByte-';
}

bool isRetryableDownloadError(Object error) {
  if (error is! Exception) return false;
  final message = error.toString().toLowerCase();
  return message.contains('socket') ||
      message.contains('connection') ||
      message.contains('timeout') ||
      message.contains('network') ||
      message.contains('connection reset') ||
      message.contains('connection closed');
}
