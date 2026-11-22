import 'package:flutter_timezone/flutter_timezone.dart';

/// The device's IANA time zone, e.g. "Asia/Karachi", or null when the
/// platform can't tell us (web, tests, plugin missing).
Future<String?> deviceTimezone() async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    final id = info.identifier.trim();
    return id.isEmpty ? null : id;
  } catch (_) {
    return null;
  }
}
