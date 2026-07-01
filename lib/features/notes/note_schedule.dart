enum NoteScheduleType {
  none,
  once,
  daily,
  weekly,
  weekdays,
  weekends,
  monthly,
  yearly,
  interval,
}

extension NoteScheduleTypeStorage on NoteScheduleType {
  String get storageValue => name;

  bool get isRepeating => switch (this) {
    NoteScheduleType.daily ||
    NoteScheduleType.weekly ||
    NoteScheduleType.weekdays ||
    NoteScheduleType.weekends ||
    NoteScheduleType.monthly ||
    NoteScheduleType.yearly ||
    NoteScheduleType.interval => true,
    _ => false,
  };

  static NoteScheduleType parse(String value) {
    return NoteScheduleType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => NoteScheduleType.none,
    );
  }
}

class NoteScheduleDraft {
  const NoteScheduleDraft({
    this.type = NoteScheduleType.none,
    this.oneTimeAt,
    this.resetTime,
    this.notificationEnabled = false,
    this.notificationTime,
    this.notificationDaysBefore = 0,
    this.notificationExtraDaysBefore = const [],
    this.notificationLeadMinutes = const [],
    this.weekday,
    this.weekdays = const [],
    this.dayOfMonth,
    this.intervalDays,
    this.anchorDate,
    this.snoozeMinutes = 0,
  });

  final NoteScheduleType type;
  final DateTime? oneTimeAt;
  final String? resetTime;
  final bool notificationEnabled;
  final String? notificationTime;
  final int notificationDaysBefore;
  final List<int> notificationExtraDaysBefore;
  final List<int> notificationLeadMinutes;
  final int? weekday;
  final List<int> weekdays;
  final int? dayOfMonth;
  final int? intervalDays;
  final String? anchorDate;
  final int snoozeMinutes;

  bool get isRepeating => type.isRepeating;

  List<int> get effectiveWeekdays {
    final values = switch (type) {
      NoteScheduleType.weekly => weekdays.isNotEmpty ? weekdays : [?weekday],
      NoteScheduleType.weekdays => const [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      ],
      NoteScheduleType.weekends => const [DateTime.saturday, DateTime.sunday],
      _ => const <int>[],
    };
    return values
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
  }

  List<int> get notificationDaysBeforeValues {
    final values = <int>{notificationDaysBefore, ...notificationExtraDaysBefore}
        .where((value) => value >= 0 && value <= 365)
        .toList()
      ..sort();
    return values;
  }

  List<int> get notificationLeadMinuteValues {
    final values = <int>{0, ...notificationLeadMinutes}
        .where((value) => value >= 0 && value <= 525600)
        .toList()
      ..sort();
    return values;
  }
}

String? validateNoteSchedule(NoteScheduleDraft schedule) {
  if (schedule.snoozeMinutes < 0 || schedule.snoozeMinutes > 1440) {
    return 'Snooze must be between 0 and 1440 minutes.';
  }
  if (schedule.notificationExtraDaysBefore.any(
    (value) => value < 0 || value > 365,
  )) {
    return 'Extra notification days must be between 0 and 365.';
  }
  if (schedule.notificationLeadMinutes.any(
    (value) => value < 0 || value > 525600,
  )) {
    return 'Lead notifications must be between 0 minutes and 365 days.';
  }

  if (schedule.type == NoteScheduleType.none) return null;
  if (schedule.type == NoteScheduleType.once) {
    return schedule.oneTimeAt == null ? 'Choose a reminder date and time.' : null;
  }

  final reset = parseNoteTime(schedule.resetTime);
  if (reset == null) return 'Choose a reset time.';
  if (schedule.notificationEnabled) {
    final notification = parseNoteTime(schedule.notificationTime);
    if (notification == null) return 'Choose a notification time.';
    if (schedule.notificationDaysBefore < 0 ||
        schedule.notificationDaysBefore > 365) {
      return 'Notification days must be between 0 and 365.';
    }
    if (schedule.type == NoteScheduleType.daily &&
        schedule.notificationDaysBeforeValues.any((value) => value != 0)) {
      return 'Daily notifications can only be on the reset day.';
    }
    if (schedule.notificationDaysBeforeValues.contains(0) &&
        notification.$1 * 60 + notification.$2 < reset.$1 * 60 + reset.$2) {
      return '알림 시각은 리셋 시각 이후여야 합니다.';
    }
  }

  switch (schedule.type) {
    case NoteScheduleType.weekly:
      if (schedule.effectiveWeekdays.isEmpty) return 'Choose at least one weekday.';
      break;
    case NoteScheduleType.weekdays:
    case NoteScheduleType.weekends:
      break;
    case NoteScheduleType.monthly:
    case NoteScheduleType.yearly:
      if (schedule.dayOfMonth == null ||
          schedule.dayOfMonth! < 1 ||
          schedule.dayOfMonth! > 31) {
        return 'Day of month must be between 1 and 31.';
      }
      if (schedule.type == NoteScheduleType.yearly &&
          parseNoteDate(schedule.anchorDate) == null) {
        return 'Choose a yearly base date.';
      }
      break;
    case NoteScheduleType.interval:
      if (schedule.intervalDays == null ||
          schedule.intervalDays! < 2 ||
          schedule.intervalDays! > 365) {
        return 'Interval must be between 2 and 365 days.';
      }
      if (parseNoteDate(schedule.anchorDate) == null) {
        return 'Choose an interval base date.';
      }
      break;
    case NoteScheduleType.none:
    case NoteScheduleType.once:
    case NoteScheduleType.daily:
      break;
  }
  return null;
}

DateTime? nextNoteResetAfter(NoteScheduleDraft schedule, DateTime after) {
  if (!schedule.isRepeating) return null;
  final time = parseNoteTime(schedule.resetTime);
  if (time == null) return null;
  final local = after.toLocal();

  DateTime at(DateTime date) =>
      DateTime(date.year, date.month, date.day, time.$1, time.$2);

  switch (schedule.type) {
    case NoteScheduleType.daily:
      var candidate = at(local);
      if (!candidate.isAfter(local)) {
        candidate = at(DateTime(local.year, local.month, local.day + 1));
      }
      return candidate;
    case NoteScheduleType.weekly:
    case NoteScheduleType.weekdays:
    case NoteScheduleType.weekends:
      final weekdays = schedule.effectiveWeekdays;
      if (weekdays.isEmpty) return null;
      DateTime? best;
      for (final weekday in weekdays) {
        final delta = (weekday - local.weekday + 7) % 7;
        var candidate = at(DateTime(local.year, local.month, local.day + delta));
        if (!candidate.isAfter(local)) {
          candidate = at(
            DateTime(candidate.year, candidate.month, candidate.day + 7),
          );
        }
        if (best == null || candidate.isBefore(best)) best = candidate;
      }
      return best;
    case NoteScheduleType.monthly:
      final day = schedule.dayOfMonth;
      if (day == null) return null;
      var candidate = _monthlyCandidate(local.year, local.month, day, time);
      if (!candidate.isAfter(local)) {
        final nextMonth = DateTime(local.year, local.month + 1);
        candidate = _monthlyCandidate(nextMonth.year, nextMonth.month, day, time);
      }
      return candidate;
    case NoteScheduleType.yearly:
      final day = schedule.dayOfMonth;
      final anchor = parseNoteDate(schedule.anchorDate);
      if (day == null || anchor == null) return null;
      var candidate = _monthlyCandidate(local.year, anchor.month, day, time);
      if (!candidate.isAfter(local)) {
        candidate = _monthlyCandidate(local.year + 1, anchor.month, day, time);
      }
      return candidate;
    case NoteScheduleType.interval:
      final days = schedule.intervalDays;
      final anchor = parseNoteDate(schedule.anchorDate);
      if (days == null || anchor == null) return null;
      var candidate = DateTime(
        anchor.year,
        anchor.month,
        anchor.day,
        time.$1,
        time.$2,
      );
      if (candidate.isAfter(local)) return candidate;
      final localDate = DateTime(local.year, local.month, local.day);
      final anchorDate = DateTime(anchor.year, anchor.month, anchor.day);
      final elapsedDays = localDate.difference(anchorDate).inDays;
      final cycles = elapsedDays < 0 ? 0 : elapsedDays ~/ days;
      candidate = DateTime(
        anchor.year,
        anchor.month,
        anchor.day + cycles * days,
        time.$1,
        time.$2,
      );
      while (!candidate.isAfter(local)) {
        candidate = DateTime(
          candidate.year,
          candidate.month,
          candidate.day + days,
          time.$1,
          time.$2,
        );
      }
      return candidate;
    case NoteScheduleType.none:
    case NoteScheduleType.once:
      return null;
  }
}

DateTime? noteNotificationForReset(
  NoteScheduleDraft schedule,
  DateTime reset, {
  int? daysBefore,
}) {
  if (!schedule.notificationEnabled) return null;
  final time = parseNoteTime(schedule.notificationTime);
  if (time == null) return null;
  final local = reset.toLocal().subtract(
    Duration(days: daysBefore ?? schedule.notificationDaysBefore),
  );
  return DateTime(local.year, local.month, local.day, time.$1, time.$2);
}

DateTime? oneTimeNotificationForReminder(
  NoteScheduleDraft schedule,
  DateTime reminder,
  int leadMinutes,
) {
  if (!schedule.notificationEnabled) return null;
  final local = reminder.toLocal().subtract(Duration(minutes: leadMinutes));
  return DateTime(local.year, local.month, local.day, local.hour, local.minute);
}

List<DateTime> oneTimeNotificationOccurrences(
  NoteScheduleDraft schedule, {
  required DateTime from,
}) {
  final reminder = schedule.oneTimeAt;
  if (schedule.type != NoteScheduleType.once ||
      reminder == null ||
      !schedule.notificationEnabled) {
    return const [];
  }
  final result = <DateTime>[];
  for (final lead in schedule.notificationLeadMinuteValues) {
    final at = oneTimeNotificationForReminder(schedule, reminder, lead);
    if (at != null && at.isAfter(from)) result.add(at);
  }
  result.sort();
  return result;
}

List<DateTime> noteNotificationOccurrences(
  NoteScheduleDraft schedule, {
  required DateTime from,
  required DateTime until,
  int limit = 400,
}) {
  if (!schedule.isRepeating || !schedule.notificationEnabled) return const [];
  final result = <DateTime>[];
  var cursor = from;
  while (result.length < limit) {
    final notification = nextNoteNotificationAfter(schedule, cursor);
    if (notification == null || notification.isAfter(until)) break;
    result.add(notification);
    cursor = notification;
  }
  return result;
}

DateTime? nextNoteNotificationAfter(
  NoteScheduleDraft schedule,
  DateTime after,
) {
  if (!schedule.isRepeating || !schedule.notificationEnabled) return null;
  DateTime? best;
  for (final daysBefore in schedule.notificationDaysBeforeValues) {
    final candidate = _nextNoteNotificationAfter(schedule, after, daysBefore);
    if (candidate != null && (best == null || candidate.isBefore(best))) {
      best = candidate;
    }
  }
  return best;
}

DateTime? _nextNoteNotificationAfter(
  NoteScheduleDraft schedule,
  DateTime after,
  int daysBefore,
) {
  if (daysBefore == 0) {
    return nextNoteResetAfter(
      NoteScheduleDraft(
        type: schedule.type,
        resetTime: schedule.notificationTime,
        weekday: schedule.weekday,
        weekdays: schedule.weekdays,
        dayOfMonth: schedule.dayOfMonth,
        intervalDays: schedule.intervalDays,
        anchorDate: schedule.anchorDate,
      ),
      after,
    );
  }
  final lookback = Duration(days: daysBefore + 1);
  var cursor = after.subtract(lookback);
  for (var i = 0; i < 500; i++) {
    final reset = nextNoteResetAfter(schedule, cursor);
    if (reset == null) return null;
    final notification = noteNotificationForReset(
      schedule,
      reset,
      daysBefore: daysBefore,
    );
    if (notification != null && notification.isAfter(after)) {
      return notification;
    }
    cursor = reset;
  }
  return null;
}

(int, int)? parseNoteTime(String? value) {
  if (value == null || !RegExp(r'^\d{2}:\d{2}$').hasMatch(value)) return null;
  final parts = value.split(':');
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return null;
  }
  return (hour, minute);
}

DateTime? parseNoteDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    return null;
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || noteDateKey(parsed) != value) return null;
  return parsed;
}

String noteDateKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

String noteTimeKey(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.hour)}:${two(date.minute)}';
}

String encodeNoteIntList(Iterable<int> values) {
  final normalized = values.toSet().toList()..sort();
  return normalized.join(',');
}

List<int> parseNoteIntList(String? value) {
  if (value == null || value.trim().isEmpty) return const [];
  return value
      .split(',')
      .map((part) => int.tryParse(part.trim()))
      .whereType<int>()
      .toSet()
      .toList()
    ..sort();
}

DateTime _monthlyCandidate(
  int year,
  int month,
  int requestedDay,
  (int, int) time,
) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = requestedDay > lastDay ? lastDay : requestedDay;
  return DateTime(year, month, day, time.$1, time.$2);
}
