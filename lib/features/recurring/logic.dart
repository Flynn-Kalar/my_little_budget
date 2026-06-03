import '../../core/date.dart';

/// SPEC §5.1 — 반복 거래 발생일 계산. **순수 함수** (DB·UI 의존 없음).
///   monthly: day_of_month 1~31. 그 달에 없는 날(예: 2월 31일)은 그 달 마지막 날로 폴백.
///   weekly:  day_of_week 0(일) ~ 6(토).

enum RecurFrequency { monthly, weekly }

class RecurrenceRule {
  const RecurrenceRule({
    required this.frequency,
    required this.startDate,
    this.dayOfMonth,
    this.dayOfWeek,
  });

  final RecurFrequency frequency;
  final String startDate; // YYYY-MM-DD
  final int? dayOfMonth; // monthly: 1~31
  final int? dayOfWeek; // weekly: 0(Sun)~6(Sat)
}

/// anchor(마지막 발생일) 다음에 발생할 occurredOn. anchor 가 null 이면 startDate 기준 첫 발생.
/// 규칙에 맞지 않으면 null.
String? nextOccurrence(RecurrenceRule r, String? anchor) {
  switch (r.frequency) {
    case RecurFrequency.monthly:
      final dom = r.dayOfMonth;
      if (dom == null) return null;

      if (anchor == null) {
        final sd = parseDateKey(r.startDate);
        final day = _clampDay(sd.year, sd.month, dom);
        final candidate = DateTime(sd.year, sd.month, day);
        if (!candidate.isBefore(sd)) return toDateKey(candidate);
        // 시작일보다 앞이면 다음 달로.
        final nm = DateTime(sd.year, sd.month + 1, 1);
        return toDateKey(DateTime(nm.year, nm.month, _clampDay(nm.year, nm.month, dom)));
      }

      final a = parseDateKey(anchor);
      final nm = DateTime(a.year, a.month + 1, 1); // 다음 달
      return toDateKey(DateTime(nm.year, nm.month, _clampDay(nm.year, nm.month, dom)));

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
  }
}

/// lastGeneratedOn(anchor) 이후 ~ horizon 까지 발생할 날짜 목록 (horizon 포함).
/// endDate 가 있으면 그 이후는 제외. 무한루프 방지 가드 120회. SPEC §5.1.
/// 이 함수는 순수 계산만. 실제 transactions INSERT 와 lastGeneratedOn 갱신은 DAO 가 담당.
List<String> dueOccurrences(
  RecurrenceRule r, {
  String? lastGeneratedOn,
  required String horizon,
  String? endDate,
}) {
  final result = <String>[];
  String? anchor = lastGeneratedOn;

  for (var i = 0; i < 120; i++) {
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
