import '../../core/date.dart';
import '../../data/database.dart';
import '../../features/notes/note_schedule.dart';

class CalendarOccurrence {
  const CalendarOccurrence({required this.event, required this.start});

  final CalendarEvent event;
  final DateTime start;

  String get dateKey => toDateKey(start);
}

Map<String, List<CalendarOccurrence>> calendarOccurrencesByDate(
  List<CalendarEvent> events,
  String monthKey,
) {
  final month = parseMonthKey(monthKey);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final result = <String, List<CalendarOccurrence>>{};

  void add(CalendarEvent event, DateTime date) {
    final local = date.toLocal();
    if (local.isBefore(start) || !local.isBefore(end)) return;
    (result[toDateKey(local)] ??= []).add(
      CalendarOccurrence(event: event, start: local),
    );
  }

  for (final event in events) {
    final type = NoteScheduleTypeStorage.parse(event.scheduleType);
    final startAt = DateTime.parse(event.startAt).toLocal();
    if (!type.isRepeating) {
      add(event, startAt);
      continue;
    }

    final schedule = calendarScheduleFromEvent(event);
    var cursor = start.subtract(const Duration(minutes: 1));
    for (var i = 0; i < 120; i++) {
      final next = nextNoteResetAfter(schedule, cursor);
      if (next == null || !next.isBefore(end)) break;
      if (!next.isBefore(startAt)) add(event, next);
      cursor = next.add(const Duration(minutes: 1));
    }
  }

  for (final entries in result.values) {
    entries.sort((a, b) {
      final time = a.start.compareTo(b.start);
      if (time != 0) return time;
      return a.event.title.compareTo(b.event.title);
    });
  }
  return result;
}

NoteScheduleDraft calendarScheduleFromEvent(CalendarEvent event) {
  final start = DateTime.parse(event.startAt).toLocal();
  final type = NoteScheduleTypeStorage.parse(event.scheduleType);
  return NoteScheduleDraft(
    type: type,
    resetTime: noteTimeKey(start),
    notificationEnabled: event.notificationEnabled,
    notificationLeadMinutes: parseNoteIntList(event.notificationLeadMinutes),
    weekday: start.weekday,
    weekdays: [start.weekday],
    dayOfMonth: start.day,
    anchorDate: noteDateKey(start),
  );
}

List<DateTime> calendarVisibleDays(String monthKey) {
  final month = parseMonthKey(monthKey);
  final first = DateTime(month.year, month.month, 1);
  final leading = first.weekday % 7;
  final gridStart = first.subtract(Duration(days: leading));
  return List.generate(
    42,
    (index) => DateTime(gridStart.year, gridStart.month, gridStart.day + index),
  );
}

String calendarMonthLabel(String monthKey) {
  final month = parseMonthKey(monthKey);
  return '${month.year}년 ${month.month}월';
}

String calendarDayLabel(DateTime date) {
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  return '${date.month}.${date.day} (${weekdays[date.weekday % 7]})';
}

String calendarTimeLabel(DateTime date) {
  return noteTimeKey(date);
}
