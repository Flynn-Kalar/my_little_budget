import 'package:drift/drift.dart';

@DataClassName('Note')
@TableIndex(name: 'idx_notes_reminder_at', columns: {#reminderAt})
@TableIndex(name: 'idx_notes_pinned', columns: {#pinned})
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get richContent => text().nullable()();
  TextColumn get reminderAt => text().nullable()();
  TextColumn get scheduleType => text().withDefault(const Constant('none'))();
  TextColumn get resetTime => text().nullable()();
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notificationTime => text().nullable()();
  IntColumn get notificationDaysBefore =>
      integer().withDefault(const Constant(0))();
  IntColumn get resetWeekday => integer().nullable()();
  TextColumn get resetWeekdays => text().nullable()();
  IntColumn get resetDayOfMonth => integer().nullable()();
  IntColumn get intervalDays => integer().nullable()();
  TextColumn get anchorDate => text().nullable()();
  TextColumn get nextResetAt => text().nullable()();
  TextColumn get notificationExtraDaysBefore =>
      text().withDefault(const Constant(''))();
  TextColumn get notificationLeadMinutes =>
      text().withDefault(const Constant(''))();
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(0))();
  TextColumn get alarmSoundKind =>
      text().withDefault(const Constant('system'))();
  TextColumn get alarmSoundUri => text().nullable()();
  TextColumn get alarmSoundName => text().nullable()();
  IntColumn get alarmClipStartMs => integer().withDefault(const Constant(0))();
  IntColumn get alarmClipEndMs => integer().nullable()();
  BoolColumn get alarmVibrationEnabled =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get showOnCalendar =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
}
