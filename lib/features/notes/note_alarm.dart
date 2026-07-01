import '../../data/database.dart';

enum NoteAlarmSoundKind { system, custom }

class NoteAlarmSettings {
  const NoteAlarmSettings({
    this.soundKind = NoteAlarmSoundKind.system,
    this.soundUri,
    this.soundName,
    this.clipStartMs = 0,
    this.clipEndMs,
    this.vibrationEnabled = true,
    this.snoozeMinutes = 0,
  });

  final NoteAlarmSoundKind soundKind;
  final String? soundUri;
  final String? soundName;
  final int clipStartMs;
  final int? clipEndMs;
  final bool vibrationEnabled;
  final int snoozeMinutes;

  bool get hasValidClip =>
      clipEndMs == null || clipEndMs! - clipStartMs >= 1000;

  NoteAlarmSettings copyWith({
    NoteAlarmSoundKind? soundKind,
    String? soundUri,
    String? soundName,
    int? clipStartMs,
    int? clipEndMs,
    bool clearClipEnd = false,
    bool? vibrationEnabled,
    int? snoozeMinutes,
  }) {
    return NoteAlarmSettings(
      soundKind: soundKind ?? this.soundKind,
      soundUri: soundUri ?? this.soundUri,
      soundName: soundName ?? this.soundName,
      clipStartMs: clipStartMs ?? this.clipStartMs,
      clipEndMs: clearClipEnd ? null : clipEndMs ?? this.clipEndMs,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    );
  }
}

class PickedAlarmSound {
  const PickedAlarmSound({
    required this.uri,
    required this.name,
    this.durationMs,
  });

  final String uri;
  final String name;
  final int? durationMs;
}

NoteAlarmSettings noteAlarmSettingsFromNote(Note note) {
  return NoteAlarmSettings(
    soundKind: NoteAlarmSoundKind.values.firstWhere(
      (kind) => kind.name == note.alarmSoundKind,
      orElse: () => NoteAlarmSoundKind.system,
    ),
    soundUri: note.alarmSoundUri,
    soundName: note.alarmSoundName,
    clipStartMs: note.alarmClipStartMs,
    clipEndMs: note.alarmClipEndMs,
    vibrationEnabled: note.alarmVibrationEnabled,
    snoozeMinutes: note.snoozeMinutes,
  );
}
