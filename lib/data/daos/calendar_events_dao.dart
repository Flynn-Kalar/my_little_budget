import 'package:drift/drift.dart';

import '../../features/notes/note_schedule.dart';
import '../../features/calendar/calendar_schedule.dart';
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
    CalendarScheduleSettings? settings,
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
    final previous = id == null ? null : await getEvent(id);
    final config =
        settings ??
        (previous == null
            ? const CalendarScheduleSettings()
            : CalendarScheduleSettings.fromEvent(previous));
    final effectiveConfig = CalendarScheduleSettings(
      every: config.every,
      until: config.until,
      timeZone: config.timeZone,
      allDayDate: allDay ? noteDateKey(startAt) : null,
      exceptions: config.exceptions,
    );
    if (effectiveConfig.validationError != null) {
      throw ArgumentError(effectiveConfig.validationError);
    }
    if (config.until != null &&
        config.until!.compareTo(noteDateKey(startAt)) < 0) {
      throw ArgumentError('반복 종료일은 시작일 이후로 선택하세요.');
    }
    final companion = CalendarEventsCompanion(
      scheduleData: Value(effectiveConfig.encode()),
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

  Future<void> saveOccurrence(
    int id,
    String originalDate, {
    bool skipped = false,
    DateTime? startAt,
    String? title,
    bool restore = false,
  }) async {
    if (parseNoteDate(originalDate) == null) {
      throw ArgumentError('올바른 회차 날짜가 아닙니다.');
    }
    if (title != null && title.trim().isEmpty) {
      throw ArgumentError('제목을 입력하세요.');
    }
    await transaction(() async {
      final event = await getEvent(id);
      if (event == null) throw StateError('일정이 삭제되었습니다.');
      final config = CalendarScheduleSettings.fromEvent(event);
      final next = config.withException(
        originalDate,
        restore
            ? null
            : {
                'skipped': skipped,
                if (startAt != null)
                  'start': event.allDay
                      ? noteDateKey(startAt)
                      : startAt.toUtc().toIso8601String(),
                if (title != null) 'title': title.trim(),
              },
      );
      await (update(calendarEvents)..where((e) => e.id.equals(id))).write(
        CalendarEventsCompanion(
          scheduleData: Value(next.encode()),
          updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
    });
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
