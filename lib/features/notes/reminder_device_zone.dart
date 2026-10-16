import 'package:flutter/services.dart';

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
  }
  final hours = DateTime.now().timeZoneOffset.inHours;
  return hours == 0 ? 'UTC' : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
}
