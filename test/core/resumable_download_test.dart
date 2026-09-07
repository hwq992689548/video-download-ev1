import 'package:flutter_test/flutter_test.dart';
import 'package:video_download_ev1/core/resumable_download.dart';

void main() {
  group('ResumableDownloadProgress', () {
    test('computes fraction from range response total', () {
      const p = ResumableDownloadProgress(
        startByte: 1000,
        received: 500,
        total: 1500,
      );
      expect(p.downloadedBytes, 1500);
      expect(p.fullTotalBytes, 2500);
      expect(p.fraction, 0.6);
    });

    test('falls back to known total bytes', () {
      const p = ResumableDownloadProgress(
        startByte: 2000,
        received: 100,
        total: -1,
        knownTotalBytes: 5000,
      );
      expect(p.fraction, 0.42);
    });

    test('returns null fraction when total unknown', () {
      const p = ResumableDownloadProgress(
        startByte: 0,
        received: 100,
        total: -1,
      );
      expect(p.fraction, isNull);
    });
  });

  group('rangeHeaderFor', () {
    test('returns null for fresh download', () {
      expect(rangeHeaderFor(0), isNull);
    });

    test('returns bytes range for resume', () {
      expect(rangeHeaderFor(4096), 'bytes=4096-');
    });
  });

  group('isRetryableDownloadError', () {
    test('matches network errors', () {
      expect(
        isRetryableDownloadError(Exception('SocketException: connection reset')),
        isTrue,
      );
      expect(
        isRetryableDownloadError(Exception('Connection timeout')),
        isTrue,
      );
    });

    test('rejects non-network errors', () {
      expect(
        isRetryableDownloadError(Exception('HTTP 403 Forbidden')),
        isFalse,
      );
    });
  });
}
