import 'package:timezone/timezone.dart' as tz;

import 'note_schedule.dart';

/// Resolve a wall-clock time explicitly: first fold, next valid minute for gaps.
tz.TZDateTime reminderWallTime(tz.Location zone, DateTime date, int h, int m) {
  final civil = DateTime.utc(date.year, date.month, date.day, h, m);
  final offsets = [-2, 0, 2]
      .map(
        (d) => tz.TZDateTime.from(
          civil.add(Duration(days: d)),
          zone,
        ).timeZoneOffset.inMilliseconds,
      )
      .toSet();
  for (var minute = 0; minute <= 2880; minute++) {
    final target = civil.add(Duration(minutes: minute));
    final matches = <tz.TZDateTime>[];
    for (final offset in offsets) {
      final candidate = tz.TZDateTime.fromMillisecondsSinceEpoch(
        zone,
        target.millisecondsSinceEpoch - offset,
      );
      if (candidate.year == target.year &&
          candidate.month == target.month &&
          candidate.day == target.day &&
          candidate.hour == target.hour &&
          candidate.minute == target.minute) {
        matches.add(candidate);
      }
    }
    if (matches.isNotEmpty) {
      matches.sort();
      return matches.first;
    }
  }
  throw StateError('No valid local time in ${zone.name}');
}

/// Includes the current occurrence and the next [count] occurrences. Calendar
/// arithmetic uses UTC *as civil dates*, never elapsed 24-hour days in a zone.
List<tz.TZDateTime> reminderResets(
  NoteScheduleDraft schedule,
  tz.Location zone,
  DateTime now, {
  required DateTime anchor,
  int count = 30,
  int every = 1,
  DateTime? until,
}) {
  if (every < 1 || every > 365) throw ArgumentError.value(every, 'every');
  final time = parseNoteTime(schedule.resetTime);
  if (!schedule.isRepeating || time == null) return [];
  final local = tz.TZDateTime.from(now, zone);
  final today = DateTime.utc(local.year, local.month, local.day);
  final base = DateTime.utc(anchor.year, anchor.month, anchor.day);
  final dates = <DateTime>[];
  if (schedule.type == NoteScheduleType.monthly ||
      schedule.type == NoteScheduleType.yearly) {
    final monthly = schedule.type == NoteScheduleType.monthly;
    final elapsed = monthly
        ? (local.year - anchor.year) * 12 + local.month - anchor.month
        : local.year - anchor.year;
    final cycle = elapsed ~/ every;
    for (var i = cycle - 1; i <= cycle + count + 1; i++) {
      final month = monthly ? anchor.month + i * every : anchor.month;
      final year = monthly ? anchor.year : anchor.year + i * every;
      final first = DateTime.utc(year, month);
      final last = DateTime.utc(first.year, first.month + 1, 0).day;
      final day = schedule.dayOfMonth ?? anchor.day;
      dates.add(DateTime.utc(first.year, first.month, day > last ? last : day));
    }
  } else if (schedule.type == NoteScheduleType.interval) {
    final interval = schedule.intervalDays ?? 1;
    if (interval < 1) return [];
    final cycle = today.difference(base).inDays ~/ interval;
    for (var i = cycle - 1; i <= cycle + count + 1; i++) {
      if (i >= 0) dates.add(base.add(Duration(days: i * interval)));
    }
  } else {
    final weekBase = base.subtract(Duration(days: base.weekday - 1));
    for (var d = -every * 7; d <= count * every * 7 + 7; d++) {
      final date = today.add(Duration(days: d));
      final eligible = schedule.type == NoteScheduleType.daily
          ? date.difference(base).inDays % every == 0
          : schedule.effectiveWeekdays.contains(date.weekday) &&
                (date.difference(weekBase).inDays / 7).floor() % every == 0;
      if (eligible) {
        dates.add(date);
        if (d >= 0 && dates.length >= count + 10) break;
      }
    }
  }
  final resets =
      dates
          .where(
            (d) =>
                ![
                  NoteScheduleType.interval,
                  NoteScheduleType.yearly,
                ].contains(schedule.type) ||
                !d.isBefore(base),
          )
          .where(
            (d) =>
                until == null ||
                !d.isAfter(DateTime.utc(until.year, until.month, until.day)),
          )
          .map((d) => reminderWallTime(zone, d, time.$1, time.$2))
          .toList()
        ..sort();
  final past = resets.where((d) => !d.isAfter(now)).lastOrNull;
  return [?past, ...resets.where((d) => d.isAfter(now)).take(count)];
}
