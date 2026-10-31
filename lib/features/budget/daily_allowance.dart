import '../../core/date.dart';

class DailyAllowance {
  const DailyAllowance(this.remaining, this.days);
  final int remaining;
  final int days;
  int get daily => remaining > 0 ? remaining ~/ days : 0;
}

/// Future transactions already included in spent remain reserved. Floor division
/// prevents recommending more than the remaining group budget.
DailyAllowance? dailyAllowance({
  required String month,
  required int budget,
  required int spent,
  required DateTime now,
  ({String start, String end})? period,
}) {
  final parts = month.split('-');
  final year = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final today = DateTime(now.year, now.month, now.day);
  final last = period == null
      ? DateTime(year, m + 1, 0)
      : parseDateKey(period.end);
  if (last.isBefore(today)) return null;
  final first = period == null
      ? DateTime(year, m, 1)
      : parseDateKey(period.start);
  final start = first.isAfter(today) ? first : today;
  // Calendar dates, independent of local daylight-saving hour changes.
  final days =
      DateTime.utc(
        last.year,
        last.month,
        last.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      1;
  return DailyAllowance(budget - spent, days);
}
