import 'dart:convert';

import 'app_file_log.dart';

void sniffTitleLog(String message) {
  AppFileLog.write('SniffTitle', message);
}

void sniffLog(String tag, String message) {
  AppFileLog.write(tag, message);
}

/// Parses title payload from injected JS (plain string or JSON debug object).
({String? chosen, Map<String, dynamic>? debug}) parseSniffTitlePayload(
  String? payload,
) {
  if (payload == null || payload.trim().isEmpty) {
    return (chosen: null, debug: null);
  }

  final trimmed = payload.trim();
  if (!trimmed.startsWith('{')) {
    return (chosen: trimmed, debug: null);
  }

  try {
    final debug = jsonDecode(trimmed) as Map<String, dynamic>;
    final chosen = debug['chosen'];
    return (
      chosen: chosen is String && chosen.trim().isNotEmpty ? chosen.trim() : null,
      debug: debug,
    );
  } catch (e) {
    sniffTitleLog('JSON parse failed: $e | raw=$trimmed');
    return (chosen: trimmed, debug: null);
  }
}
