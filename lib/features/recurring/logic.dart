import '../../core/date.dart';
import '../calendar/korean_holidays.dart';

/// SPEC §5.1 — 반복 거래 발생일 계산. **순수 함수** (DB·UI 의존 없음).
///   monthly: day_of_month 1~31. 그 달에 없는 날(예: 2월 31일)은 그 달 마지막 날로 폴백.
///   weekly:  day_of_week 0(일) ~ 6(토).
///   daily:   매일. 선택에 따라 주말·대한민국 공휴일 제외.

enum RecurFrequency { monthly, weekly, daily }

enum MonthlyRecurrenceMode { day, nthWeekday }

enum NonBusinessDayAdjustment { same, previous, next }

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    required this.startDate,
    this.dayOfMonth,
    this.dayOfWeek,
    this.monthlyMode = MonthlyRecurrenceMode.day,
    this.weekOfMonth,
    this.nonBusinessDayAdjustment = NonBusinessDayAdjustment.same,
    this.includeNonBusinessDays = true,
  });

  final RecurFrequency frequency;
  final String startDate; // YYYY-MM-DD
  final int? dayOfMonth; // monthly: 1~31
  final int? dayOfWeek; // weekly: 0(Sun)~6(Sat)
  final MonthlyRecurrenceMode monthlyMode;
  final int? weekOfMonth;
  final NonBusinessDayAdjustment nonBusinessDayAdjustment;
  final bool includeNonBusinessDays; // daily only
}

/// anchor(마지막 발생일) 다음에 발생할 occurredOn. anchor 가 null 이면 startDate 기준 첫 발생.
/// 규칙에 맞지 않으면 null.
String? nextOccurrence(RecurrenceRule r, String? anchor) {
  switch (r.frequency) {
    case RecurFrequency.monthly:
      return _nextMonthlyOccurrence(r, anchor);

    case RecurFrequency.weekly:
      final dow = r.dayOfWeek;
      if (dow == null) return null;

      if (anchor == null) {
        final sd = parseDateKey(r.startDate);
        final diff = (dow - _sundayBased(sd) + 7) % 7;
        return toDateKey(DateTime(sd.year, sd.month, sd.day + diff));
      }

      final a = parseDateKey(anchor);
      return toDateKey(DateTime(a.year, a.month, a.day + 7));

    case RecurFrequency.daily:
      var candidate = anchor == null
          ? parseDateKey(r.startDate)
          : parseDateKey(anchor).add(const Duration(days: 1));
      if (!r.includeNonBusinessDays) {
        while (_isNonBusinessDay(candidate)) {
          candidate = candidate.add(const Duration(days: 1));
        }
      }
      return toDateKey(candidate);
  }
}

/// lastGeneratedOn(anchor) 이후 ~ horizon 까지 발생할 날짜 목록 (horizon 포함).
/// endDate 가 있으면 그 이후는 제외. 최대 100년치까지 생성. SPEC §5.1.
/// 이 함수는 순수 계산만. 실제 transactions INSERT 와 lastGeneratedOn 갱신은 DAO 가 담당.
List<String> dueOccurrences(
  RecurrenceRule r, {
  String? lastGeneratedOn,
  required String horizon,
  String? endDate,
}) {
  final result = <String>[];
  String? anchor = lastGeneratedOn;

  for (var i = 0; i < 36600; i++) {
    final next = nextOccurrence(r, anchor);
    if (next == null) break;
    if (next.compareTo(horizon) > 0) break;
    if (endDate != null && next.compareTo(endDate) > 0) break;
    result.add(next);
    anchor = next;
  }

  return result;
}

/// 해당 월에 dayOfMonth 가 없으면 그 달 마지막 날로 폴백.
int _clampDay(int year, int month, int dayOfMonth) {
  final dim = DateTime(year, month + 1, 0).day; // 다음달 0일 = 이번달 말일
  return dayOfMonth < dim ? dayOfMonth : dim;
}

/// Dart weekday(1=월 ~ 7=일) → SPEC 의 0=일 ~ 6=토 체계.
int _sundayBased(DateTime d) => d.weekday % 7;

bool _isNonBusinessDay(DateTime date) {
  if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
    return true;
  }
  return isKoreanHoliday(date);
}

String? _nextMonthlyOccurrence(RecurrenceRule rule, String? anchor) {
  final start = parseDateKey(rule.startDate);
  final after = anchor == null ? null : parseDateKey(anchor);
  var month = after == null
      ? DateTime(start.year, start.month)
      : DateTime(after.year, after.month - 1);

  for (var i = 0; i < 2400; i++) {
    final scheduled = _monthlyScheduledDate(rule, month.year, month.month);
    if (scheduled != null) {
      final candidate = rule.monthlyMode == MonthlyRecurrenceMode.day
          ? _adjustNonBusinessDay(scheduled, rule.nonBusinessDayAdjustment)
          : scheduled;
      if (!candidate.isBefore(start) &&
          (after == null || candidate.isAfter(after))) {
        return toDateKey(candidate);
      }
    }
    month = DateTime(month.year, month.month + 1);
  }
  return null;
}

DateTime? _monthlyScheduledDate(RecurrenceRule rule, int year, int month) {
  if (rule.monthlyMode == MonthlyRecurrenceMode.day) {
    final day = rule.dayOfMonth;
    if (day == null) return null;
    return DateTime(year, month, _clampDay(year, month, day));
  }

  final week = rule.weekOfMonth;
  final weekday = rule.dayOfWeek;
  if (week == null || week < 1 || week > 5 || weekday == null) return null;
  final first = DateTime(year, month, 1);
  final offset = (weekday - _sundayBased(first) + 7) % 7;
  final day = 1 + offset + (week - 1) * 7;
  if (day > DateTime(year, month + 1, 0).day) return null;
  return DateTime(year, month, day);
}

DateTime _adjustNonBusinessDay(
  DateTime date,
  NonBusinessDayAdjustment adjustment,
) {
  if (adjustment == NonBusinessDayAdjustment.same || !_isNonBusinessDay(date)) {
    return date;
  }
  final step = adjustment == NonBusinessDayAdjustment.previous ? -1 : 1;
  var candidate = date;
  do {
    candidate = candidate.add(Duration(days: step));
  } while (_isNonBusinessDay(candidate));
  return candidate;
}
