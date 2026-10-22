import 'dart:convert';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database.dart';
import '../notes/note_schedule.dart';
import '../notes/reminder_calendar.dart';

bool _zonesReady = false;
tz.Location calendarZone(String? name) {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
  if (name == null) return tz.local;
  if (name == 'UTC' || name == 'GMT' || name == 'Etc/UTC') return tz.UTC;
  return tz.getLocation(name);
}

class CalendarScheduleSettings {
  const CalendarScheduleSettings({
    this.every = 1,
    this.until,
    this.timeZone,
    this.allDayDate,
    this.exceptions = const {},
    this.isDday = false,
  });
  final int every;
  final String? until;
  final String? timeZone;
  final String? allDayDate;
  final bool isDday;

  /// Keys identify the original civil date, even after an occurrence is moved.
  final Map<String, Map<String, dynamic>> exceptions;

  factory CalendarScheduleSettings.fromEvent(CalendarEvent event) =>
      CalendarScheduleSettings.decode(event.scheduleData);
  factory CalendarScheduleSettings.decode(String json) {
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return CalendarScheduleSettings(
        every: map['every'] as int? ?? 1,
        until: map['until'] as String?,
        timeZone: map['zone'] as String?,
        allDayDate: map['date'] as String?,
        isDday: map['dday'] as bool? ?? false,
        exceptions: {
          for (final e in (map['exceptions'] as Map? ?? {}).entries)
            e.key as String: Map<String, dynamic>.from(e.value as Map),
        },
      );
    } catch (_) {
      return const CalendarScheduleSettings();
    }
  }
  String encode() => jsonEncode({
    'every': every,
    'until': until,
    'zone': timeZone,
    'date': allDayDate,
    'dday': isDday,
    'exceptions': exceptions,
  });
  CalendarScheduleSettings withException(
    String key,
    Map<String, dynamic>? exception,
  ) => CalendarScheduleSettings(
    every: every,
    until: until,
    timeZone: timeZone,
    allDayDate: allDayDate,
    isDday: isDday,
    exceptions: {...exceptions}
      ..remove(key)
      ..addAll(exception == null ? {} : {key: exception}),
  );
  String? get validationError {
    if (every < 1 || every > 365) return '반복 간격은 1~365로 입력하세요.';
    if (until != null && parseNoteDate(until) == null) return '반복 종료일을 확인하세요.';
    if (allDayDate != null && parseNoteDate(allDayDate) == null) {
      return '종일 일정 날짜를 확인하세요.';
    }
    try {
      if (timeZone != null) calendarZone(timeZone);
    } catch (_) {
      return '지역명을 검색해 목록에서 시간대를 선택하세요.';
    }
    return null;
  }
}

DateTime calendarEventStart(CalendarEvent event) {
  final settings = CalendarScheduleSettings.fromEvent(event);
  if (event.allDay && settings.allDayDate != null) {
    return DateTime.parse(settings.allDayDate!);
  }
  final instant = DateTime.parse(event.startAt);
  return settings.timeZone == null
      ? instant.toLocal()
      : tz.TZDateTime.from(instant, calendarZone(settings.timeZone));
}

class CalendarInstance {
  const CalendarInstance({
    required this.event,
    required this.originalDate,
    required this.start,
    required this.title,
  });
  final CalendarEvent event;
  final String originalDate;
  final DateTime start;
  final String title;
  String get dateKey => noteDateKey(start);
}

/// The same occurrence expansion is used by calendar rendering and scheduling.
List<CalendarInstance> calendarInstances(
  CalendarEvent event,
  DateTime from,
  DateTime until, {
  int limit = 1500,
}) {
  final settings = CalendarScheduleSettings.fromEvent(event);
  if (settings.validationError != null) return [];
  final anchor = calendarEventStart(event);
  final zone = calendarZone(
    settings.timeZone ??
        (DateTime.now().timeZoneOffset.inHours == 0
            ? 'UTC'
            : 'Etc/GMT${DateTime.now().timeZoneOffset.inHours > 0 ? '-' : '+'}${DateTime.now().timeZoneOffset.inHours.abs()}'),
  );
  DateTime civil(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final lower = civil(from), upper = civil(until);
  final type = NoteScheduleTypeStorage.parse(event.scheduleType);
  final days = upper.difference(lower).inDays;
  final count = switch (type) {
    NoteScheduleType.monthly =>
      ((upper.year - lower.year) * 12 + upper.month - lower.month) ~/
              settings.every +
          3,
    NoteScheduleType.yearly => (upper.year - lower.year) ~/ settings.every + 3,
    NoteScheduleType.weekly => days ~/ (7 * settings.every) + 3,
    NoteScheduleType.daily => days ~/ settings.every + 3,
    _ => days + 3,
  };
  final dates = !type.isRepeating
      ? [anchor]
      : reminderResets(
          NoteScheduleDraft(
            type: type,
            resetTime: noteTimeKey(anchor),
            dayOfMonth: anchor.day,
            weekday: anchor.weekday,
            weekdays: [anchor.weekday],
            anchorDate: noteDateKey(anchor),
          ),
          zone,
          reminderWallTime(
            zone,
            lower,
            0,
            0,
          ).subtract(const Duration(seconds: 1)),
          anchor: anchor,
          every: settings.every,
          until: parseNoteDate(settings.until),
          count: count.clamp(1, limit),
        );
  final found = <String, CalendarInstance>{};
  void add(String key, DateTime date) {
    if (civil(date).isBefore(lower) || !civil(date).isBefore(upper)) return;
    found[key] = CalendarInstance(
      event: event,
      originalDate: key,
      start: date,
      title: settings.exceptions[key]?['title'] as String? ?? event.title,
    );
  }

  for (final date in dates) {
    if (civil(date).isBefore(civil(anchor))) continue;
    final key = noteDateKey(date), exception = settings.exceptions[key];
    if (exception?['skipped'] == true) continue;
    if (exception?['start'] != null) {
      continue; // Handled independently below, including moves across months.
    }
    add(key, event.allDay ? DateTime(date.year, date.month, date.day) : date);
  }
  for (final entry in settings.exceptions.entries) {
    if (entry.value['skipped'] == true || entry.value['start'] == null) {
      continue;
    }
    final date = DateTime.tryParse(entry.value['start'] as String);
    if (date == null) continue;
    add(
      entry.key,
      event.allDay
          ? DateTime(date.year, date.month, date.day)
          : tz.TZDateTime.from(date, zone),
    );
  }
  return found.values.toList()..sort((a, b) => a.start.compareTo(b.start));
}
