import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/reminder_device_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const alarms = MethodChannel('com.my_little_budget/note_alarms');
  const zones = MethodChannel('flutter_timezone');
  tearDown(() {
    messenger.setMockMethodCallHandler(alarms, null);
    messenger.setMockMethodCallHandler(zones, null);
  });
  test(
    'desktop device IANA zone is used when Android alarm channel is unavailable',
    () async {
      messenger.setMockMethodCallHandler(
        zones,
        (call) async => {'identifier': 'Asia/Kathmandu'},
      );
      expect(await reminderDeviceZone(), 'Asia/Kathmandu');
    },
  );
  test('native Android zone remains preferred', () async {
    messenger.setMockMethodCallHandler(alarms, (call) async => 'Asia/Tokyo');
    messenger.setMockMethodCallHandler(
      zones,
      (call) async => throw StateError('unused'),
    );
    expect(await reminderDeviceZone(), 'Asia/Tokyo');
  });
}
