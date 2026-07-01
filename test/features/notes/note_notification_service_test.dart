import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/notes/checklist.dart';
import 'package:my_little_budget/features/notes/note_alarm.dart';
import 'package:my_little_budget/features/notes/note_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezoneChannel = MethodChannel('flutter_timezone');
  const alarmChannel = MethodChannel('com.my_little_budget/note_alarms');

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(timezoneChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(alarmChannel, null);
  });

  test('사용자 음원 구간은 최소 1초 이상이어야 한다', () {
    expect(
      const NoteAlarmSettings(clipStartMs: 1000, clipEndMs: 1999).hasValidClip,
      isFalse,
    );
    expect(
      const NoteAlarmSettings(clipStartMs: 1000, clipEndMs: 2000).hasValidClip,
      isTrue,
    );
  });

  test('권한 요청 후 정확한 Android 알림을 예약하고 payload를 전달한다', () async {
    final harness = await _startAndroidHarness();
    final now = DateTime.now();

    await harness.service.rebuild([_entry(now: now)], now: now);

    expect(harness.permission.granted, isTrue);
    expect(harness.permission.canShowAlarmScreen, isTrue);
    expect(harness.openedNoteId, 42);
    expect(harness.scheduled, isNotEmpty);
    final arguments = harness.scheduled.first;
    expect(arguments['title'], '일일 미션');
    expect(arguments['noteId'], 42);
    expect(arguments['soundKind'], 'system');
    expect(arguments['vibrationEnabled'], isTrue);
  });

  test('체크리스트가 모두 완료된 메모는 알람 예약에서 제외한다', () async {
    final harness = await _startAndroidHarness();
    final now = DateTime.now();

    await harness.service.rebuild([
      _entry(
        now: now,
        items: [
          _item(noteId: 42, id: 1, checked: true),
          _item(noteId: 42, id: 2, checked: true),
        ],
      ),
    ], now: now);

    expect(harness.scheduled, isEmpty);
  });

  test('체크리스트 완료 후 다시 미완료가 되면 알람을 다시 예약한다', () async {
    final harness = await _startAndroidHarness();
    final now = DateTime.now();

    await harness.service.rebuild([
      _entry(
        now: now,
        items: [
          _item(noteId: 42, id: 1, checked: true),
          _item(noteId: 42, id: 2, checked: false),
        ],
      ),
    ], now: now);

    expect(harness.scheduled, isNotEmpty);
  });

  test(
    'preview sends alarm sound payload and returns native playback result',
    () async {
      final harness = await _startAndroidHarness();

      final played = await harness.service.preview(
        const NoteAlarmSettings(
          soundKind: NoteAlarmSoundKind.system,
          soundUri: 'content://settings/system/alarm_alert',
          clipStartMs: 1200,
          clipEndMs: 3200,
          vibrationEnabled: false,
          snoozeMinutes: 5,
        ),
      );

      expect(played, isTrue);
      expect(harness.previewed.single['soundKind'], 'system');
      expect(
        harness.previewed.single['soundUri'],
        'content://settings/system/alarm_alert',
      );
      expect(harness.previewed.single['clipStartMs'], 1200);
      expect(harness.previewed.single['clipEndMs'], 3200);
      expect(harness.previewed.single['vibrationEnabled'], isFalse);
    },
  );
}

Future<_AndroidHarness> _startAndroidHarness() async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  FlutterLocalNotificationsPlatform.instance =
      AndroidFlutterLocalNotificationsPlugin();
  var notificationsGranted = false;
  var exactGranted = false;
  var fullScreenGranted = false;
  final scheduled = <Map<Object?, Object?>>[];
  final previewed = <Map<Object?, Object?>>[];

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_timezone'),
        (call) async => 'Asia/Seoul',
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dexterous.com/flutter/local_notifications'),
        (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'getNotificationAppLaunchDetails':
              return <String, Object?>{
                'notificationLaunchedApp': true,
                'notificationResponse': <String, Object?>{
                  'notificationId': 1,
                  'actionId': null,
                  'input': null,
                  'notificationResponseType': 0,
                  'payload': 'note:42',
                },
              };
            case 'areNotificationsEnabled':
              return notificationsGranted;
            case 'canScheduleExactNotifications':
              return exactGranted;
            case 'requestNotificationsPermission':
              notificationsGranted = true;
              return true;
            case 'requestExactAlarmsPermission':
              exactGranted = true;
              return true;
            case 'pendingNotificationRequests':
              return <Object?>[];
          }
          return null;
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('com.my_little_budget/note_alarms'),
        (call) async {
          if (call.method == 'getLaunchNoteId') return 42;
          if (call.method == 'canUseFullScreenIntent') {
            return fullScreenGranted;
          }
          if (call.method == 'requestFullScreenIntentPermission') {
            fullScreenGranted = true;
            return null;
          }
          if (call.method == 'replaceAlarms') {
            scheduled
              ..clear()
              ..addAll(
                (call.arguments as List<Object?>).cast<Map<Object?, Object?>>(),
              );
          }
          if (call.method == 'preview') {
            previewed.add(call.arguments as Map<Object?, Object?>);
            return true;
          }
          return null;
        },
      );

  int? openedNoteId;
  final service = NoteNotificationService();
  await service.initialize(onNoteTap: (id) => openedNoteId = id);
  final permission = await service.requestPermissions();
  return _AndroidHarness(
    service: service,
    permission: permission,
    openedNoteId: openedNoteId,
    scheduled: scheduled,
    previewed: previewed,
  );
}

NoteWithChecklist _entry({
  required DateTime now,
  List<NoteChecklistItem> items = const [],
}) {
  return NoteWithChecklist(
    note: Note(
      id: 42,
      title: '일일 미션',
      content: '비공개 내용',
      scheduleType: 'daily',
      resetTime: '00:00',
      notificationEnabled: true,
      notificationTime: '23:59',
      notificationDaysBefore: 0,
      notificationExtraDaysBefore: '',
      notificationLeadMinutes: '',
      nextResetAt: now.add(const Duration(days: 1)).toUtc().toIso8601String(),
      snoozeMinutes: 0,
      alarmSoundKind: 'system',
      alarmClipStartMs: 0,
      alarmVibrationEnabled: true,
      completed: false,
      pinned: false,
      createdAt: now.toUtc().toIso8601String(),
      updatedAt: now.toUtc().toIso8601String(),
    ),
    items: items,
  );
}

NoteChecklistItem _item({
  required int noteId,
  required int id,
  required bool checked,
}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return NoteChecklistItem(
    id: id,
    noteId: noteId,
    itemText: '항목 $id',
    isChecked: checked,
    sortOrder: id,
    createdAt: now,
    updatedAt: now,
  );
}

class _AndroidHarness {
  const _AndroidHarness({
    required this.service,
    required this.permission,
    required this.openedNoteId,
    required this.scheduled,
    required this.previewed,
  });

  final NoteNotificationService service;
  final NoteNotificationPermission permission;
  final int? openedNoteId;
  final List<Map<Object?, Object?>> scheduled;
  final List<Map<Object?, Object?>> previewed;
}
