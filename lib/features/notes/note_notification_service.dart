import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/database.dart';
import '../../data/daos/notes_dao.dart';
import 'checklist.dart';
import 'note_alarm.dart';
import 'note_schedule.dart';

class NoteNotificationPermission {
  const NoteNotificationPermission({
    required this.notifications,
    required this.exactAlarms,
    this.fullScreenIntents = false,
  });

  final bool notifications;
  final bool exactAlarms;
  final bool fullScreenIntents;

  bool get granted => notifications && exactAlarms;
  bool get canShowAlarmScreen => granted && fullScreenIntents;
}

class NoteNotificationService {
  NoteNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel? alarmChannel,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _alarmChannel = alarmChannel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.my_little_budget/note_alarms';
  static const _firstNotificationId = 740000;
  static const _maxScheduledNotifications = 400;

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _alarmChannel;
  bool _initialized = false;
  void Function(int noteId)? _onNoteTap;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize({
    required void Function(int noteId) onNoteTap,
  }) async {
    _onNoteTap = onNoteTap;
    if (!isSupported) return;
    _alarmChannel.setMethodCallHandler((call) async {
      if (call.method == 'openNote') {
        final id = (call.arguments as num?)?.toInt();
        if (id != null) _onNoteTap?.call(id);
      }
    });
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
      );
    } catch (_) {
      // Widget/unit tests and unsupported embedders don't register the plugin.
    }
    _initialized = true;
    int? launchId;
    try {
      launchId = await _alarmChannel.invokeMethod<int>('getLaunchNoteId');
    } on MissingPluginException {
      launchId = null;
    }
    if (launchId != null) _onNoteTap?.call(launchId);
  }

  Future<NoteNotificationPermission> permissionStatus() async {
    if (!isSupported) {
      return const NoteNotificationPermission(
        notifications: false,
        exactAlarms: false,
        fullScreenIntents: false,
      );
    }
    final android = _android;
    var fullScreenIntents = false;
    try {
      fullScreenIntents =
          await _alarmChannel.invokeMethod<bool>('canUseFullScreenIntent') ??
          false;
    } on MissingPluginException {
      fullScreenIntents = false;
    }
    return NoteNotificationPermission(
      notifications: await android?.areNotificationsEnabled() ?? false,
      exactAlarms: await android?.canScheduleExactNotifications() ?? false,
      fullScreenIntents: fullScreenIntents,
    );
  }

  Future<NoteNotificationPermission> requestPermissions() async {
    if (!isSupported) return permissionStatus();
    final android = _android;
    await android?.requestNotificationsPermission();
    if (!(await android?.canScheduleExactNotifications() ?? false)) {
      await android?.requestExactAlarmsPermission();
    }
    try {
      if (!(await _alarmChannel.invokeMethod<bool>('canUseFullScreenIntent') ??
          false)) {
        await _alarmChannel.invokeMethod<void>(
          'requestFullScreenIntentPermission',
        );
      }
    } on MissingPluginException {
      // Widget tests and unsupported embedders have no native alarm bridge.
    }
    return permissionStatus();
  }

  Future<void> rebuild(List<NoteWithChecklist> entries, {DateTime? now}) async {
    if (!isSupported || !_initialized) return;
    final permission = await permissionStatus();
    if (!permission.granted) return;

    final start = (now ?? DateTime.now()).toLocal();
    final horizon = start.add(const Duration(days: 90));
    final jobs = <_NotificationJob>[];
    for (final entry in entries) {
      if (entry.isChecklistComplete) continue;
      final note = entry.note;
      if (!note.notificationEnabled) continue;
      final schedule = noteScheduleFromNote(note);
      if (schedule.type == NoteScheduleType.once) {
        for (final at in oneTimeNotificationOccurrences(
          schedule,
          from: start,
        )) {
          jobs.add(_NotificationJob(note: note, at: at));
        }
      } else {
        for (final at in noteNotificationOccurrences(
          schedule,
          from: start,
          until: horizon,
          limit: _maxScheduledNotifications,
        )) {
          jobs.add(_NotificationJob(note: note, at: at));
        }
      }
    }
    jobs.sort((a, b) => a.at.compareTo(b.at));
    final payload = <Map<String, Object?>>[];
    for (
      var index = 0;
      index < jobs.length && index < _maxScheduledNotifications;
      index++
    ) {
      payload.add(jobs[index].toMap(_firstNotificationId + index));
    }
    try {
      await _alarmChannel.invokeMethod<void>('replaceAlarms', payload);
    } on MissingPluginException {
      // Non-Android embedders and widget tests have no native alarm bridge.
    }
  }

  Future<PickedAlarmSound?> pickSystemAlarmSound() async {
    if (!isSupported) return null;
    final value = await _alarmChannel.invokeMapMethod<String, Object?>(
      'pickSystemSound',
    );
    final uri = value?['uri'] as String?;
    if (uri == null) return null;
    return PickedAlarmSound(
      uri: uri,
      name: value?['name'] as String? ?? '시스템 알람음',
      durationMs: (value?['durationMs'] as num?)?.toInt(),
    );
  }

  Future<int?> audioDuration(String uri) async {
    if (!isSupported) return null;
    return _alarmChannel.invokeMethod<int>('audioDuration', uri);
  }

  Future<bool> preview(NoteAlarmSettings settings) async {
    if (!isSupported) return false;
    return await _alarmChannel.invokeMethod<bool>(
          'preview',
          _soundMap(settings),
        ) ??
        false;
  }

  Future<void> stopPreview() async {
    if (!isSupported) return;
    await _alarmChannel.invokeMethod<void>('stopPreview');
  }

  Future<void> cleanupUnusedAudio(List<Note> notes) async {
    if (!isSupported) return;
    final retained = notes
        .where((note) => note.alarmSoundKind == NoteAlarmSoundKind.custom.name)
        .map((note) => note.alarmSoundUri)
        .whereType<String>()
        .toList();
    try {
      await _alarmChannel.invokeMethod<void>('cleanupAudio', retained);
    } on MissingPluginException {
      // Non-Android embedders and widget tests have no native alarm bridge.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android {
    try {
      return _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
    } catch (_) {
      return null;
    }
  }
}

class _NotificationJob {
  const _NotificationJob({required this.note, required this.at});

  final Note note;
  final DateTime at;

  Map<String, Object?> toMap(int id) {
    final alarm = noteAlarmSettingsFromNote(note);
    return {
      'id': id,
      'noteId': note.id,
      'title': note.title,
      'triggerAt': at.millisecondsSinceEpoch,
      ..._soundMap(alarm),
    };
  }
}

Map<String, Object?> _soundMap(NoteAlarmSettings settings) => {
  'soundKind': settings.soundKind.name,
  'soundUri': settings.soundUri,
  'soundName': settings.soundName,
  'clipStartMs': settings.clipStartMs,
  'clipEndMs': settings.clipEndMs,
  'vibrationEnabled': settings.vibrationEnabled,
  'snoozeMinutes': settings.snoozeMinutes,
};
