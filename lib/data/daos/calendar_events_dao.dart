import 'package:drift/drift.dart';

import '../../features/notes/note_schedule.dart';
import '../database.dart';
import '../sync_metadata.dart';
import '../tables/calendar_events.dart';

part 'calendar_events_dao.g.dart';

@DriftAccessor(tables: [CalendarEvents])
class CalendarEventsDao extends DatabaseAccessor<AppDatabase>
    with _$CalendarEventsDaoMixin {
  CalendarEventsDao(super.db);

  Stream<List<CalendarEvent>> watchEvents() {
    return (select(calendarEvents)..orderBy([
          (event) => OrderingTerm(expression: event.startAt),
          (event) => OrderingTerm(expression: event.title),
        ]))
        .watch();
  }

  Future<List<CalendarEvent>> listEvents() => select(calendarEvents).get();

  Future<CalendarEvent?> getEvent(int id) {
    return (select(
      calendarEvents,
    )..where((event) => event.id.equals(id))).getSingleOrNull();
  }

  Future<int> saveEvent({
    int? id,
    required String title,
    String description = '',
    required DateTime startAt,
    DateTime? endAt,
    bool allDay = false,
    String color = '#2563eb',
    String? location,
    String? linkUrl,
    NoteScheduleDraft? schedule,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Enter an event title.');
    }
    if (endAt != null && endAt.isBefore(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'End must be after start.');
    }

    final effectiveSchedule = schedule ?? const NoteScheduleDraft();
    final error = _validateEventSchedule(effectiveSchedule);
    if (error != null) throw ArgumentError(error, 'schedule');

    final now = DateTime.now().toUtc().toIso8601String();
    final companion = CalendarEventsCompanion(
      title: Value(normalizedTitle),
      description: Value(description.trim()),
      startAt: Value(startAt.toUtc().toIso8601String()),
      endAt: Value(endAt?.toUtc().toIso8601String()),
      allDay: Value(allDay),
      color: Value(color),
      location: Value(_blankToNull(location)),
      linkUrl: Value(_blankToNull(linkUrl)),
      scheduleType: Value(effectiveSchedule.type.storageValue),
      notificationEnabled: Value(effectiveSchedule.notificationEnabled),
      notificationLeadMinutes: Value(
        effectiveSchedule.notificationEnabled
            ? encodeNoteIntList(effectiveSchedule.notificationLeadMinutes)
            : '',
      ),
      updatedAt: Value(now),
      syncStatus: const Value(syncStatusPending),
    );

    if (id == null) {
      return into(calendarEvents).insert(companion);
    }
    await (update(
      calendarEvents,
    )..where((event) => event.id.equals(id))).write(companion);
    return id;
  }

  Future<int> deleteEvent(int id) {
    return (delete(calendarEvents)..where((event) => event.id.equals(id))).go();
  }
}

String? _validateEventSchedule(NoteScheduleDraft schedule) {
  if (schedule.type == NoteScheduleType.once) {
    return 'Calendar events do not use one-time memo schedules.';
  }
  if (schedule.type == NoteScheduleType.interval) {
    return 'Interval repeats are not supported for calendar events yet.';
  }
  if (schedule.notificationLeadMinutes.any(
    (value) => value < 0 || value > 525600,
  )) {
    return 'Lead notifications must be between 0 minutes and 365 days.';
  }
  return null;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
