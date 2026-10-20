import '../../data/database.dart';
import 'calendar_schedule.dart';

/// Civil dates avoid DST and time-of-day rounding in day counters.
int calendarDdayDifference(DateTime target, DateTime today) => DateTime.utc(
  target.year,
  target.month,
  target.day,
).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

String calendarDdayLabel(DateTime target, {DateTime? today}) {
  final days = calendarDdayDifference(target, today ?? DateTime.now());
  return days == 0
      ? 'D-day'
      : days > 0
      ? 'D-$days'
      : 'D+${-days}';
}

List<CalendarEvent> calendarDdayEvents(
  List<CalendarEvent> events, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final selected = events
      .where(
        (event) =>
            event.deletedAt == null &&
            CalendarScheduleSettings.fromEvent(event).isDday,
      )
      .toList();
  selected.sort((a, b) {
    final left = calendarDdayDifference(calendarEventStart(a), now);
    final right = calendarDdayDifference(calendarEventStart(b), now);
    final group = (left < 0 ? 1 : 0).compareTo(right < 0 ? 1 : 0);
    if (group != 0) return group;
    final days = left >= 0 ? left.compareTo(right) : right.compareTo(left);
    return days != 0 ? days : a.id.compareTo(b.id);
  });
  return selected;
}
