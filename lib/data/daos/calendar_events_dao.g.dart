// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_events_dao.dart';

// ignore_for_file: type=lint
mixin _$CalendarEventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CalendarEventsTable get calendarEvents => attachedDatabase.calendarEvents;
  CalendarEventsDaoManager get managers => CalendarEventsDaoManager(this);
}

class CalendarEventsDaoManager {
  final _$CalendarEventsDaoMixin _db;
  CalendarEventsDaoManager(this._db);
  $$CalendarEventsTableTableManager get calendarEvents =>
      $$CalendarEventsTableTableManager(
        _db.attachedDatabase,
        _db.calendarEvents,
      );
}
