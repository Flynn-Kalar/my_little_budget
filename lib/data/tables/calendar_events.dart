import 'package:drift/drift.dart';

import '../sync_metadata.dart';

@DataClassName('CalendarEvent')
@TableIndex(name: 'idx_calendar_events_start_at', columns: {#startAt})
@TableIndex(name: 'idx_calendar_events_schedule_type', columns: {#scheduleType})
class CalendarEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get startAt => text()();
  TextColumn get endAt => text().nullable()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().withDefault(const Constant('#2563eb'))();
  TextColumn get location => text().nullable()();
  TextColumn get linkUrl => text().nullable()();
  TextColumn get scheduleType => text().withDefault(const Constant('none'))();
  TextColumn get notificationLeadMinutes =>
      text().withDefault(const Constant(''))();
  BoolColumn get notificationEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();
}
