import '../../core/date.dart';
import '../../data/database.dart';
import '../../features/notes/note_schedule.dart';
import '../../features/calendar/calendar_schedule.dart';

class CalendarOccurrence {
  const CalendarOccurrence({
    required this.event,
    required this.start,
    this.occurrenceKey,
    this.titleOverride,
  });

  final CalendarEvent event;
  final DateTime start;
  final String? occurrenceKey;
  final String? titleOverride;
  String get originalDate => occurrenceKey ?? noteDateKey(start);
  String get title => titleOverride ?? event.title;

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

  for (final event in events) {
    for (final instance in calendarInstances(event, start, end)) {
      final key = instance.dateKey;
      (result[key] ??= []).add(
        CalendarOccurrence(
          event: event,
          start: instance.start,
          occurrenceKey: instance.originalDate,
          titleOverride: instance.title,
        ),
      );
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
  final start = calendarEventStart(event);
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

Set<int> calendarVisibleEventIds(List<CalendarEvent> events, String monthKey) {
  final days = calendarVisibleDays(monthKey);
  final last = days.last;
  final until = DateTime(last.year, last.month, last.day + 1);
  return {
    for (final event in events)
      if (calendarInstances(event, days.first, until).isNotEmpty) event.id,
  };
}

String calendarDayLabel(DateTime date) {
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  return '${date.month}.${date.day} (${weekdays[date.weekday % 7]})';
}

String calendarTimeLabel(DateTime date) {
  return noteTimeKey(date);
}
