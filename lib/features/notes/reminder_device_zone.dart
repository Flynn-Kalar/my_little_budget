import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

Future<String> reminderDeviceZone({
  MethodChannel channel = const MethodChannel(
    'com.my_little_budget/note_alarms',
  ),
}) async {
  try {
    final name = await channel.invokeMethod<String>('getTimeZone');
    if (name != null && name.isNotEmpty) return name == 'GMT' ? 'UTC' : name;
  } on MissingPluginException {
    /* Test/unsupported embedder. */
  } on PlatformException {
    // Other platforms use the shared timezone plugin below.
  }
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    if (info.identifier.isNotEmpty) {
      return info.identifier == 'GMT' ? 'UTC' : info.identifier;
    }
  } on MissingPluginException {
    // Unit tests and embedders without a timezone plugin retain the offset fallback.
  } on PlatformException {
    // A failed platform lookup must not prevent opening a schedule.
  }
  final hours = DateTime.now().timeZoneOffset.inHours;
  return hours == 0 ? 'UTC' : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}
