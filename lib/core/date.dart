import 'package:intl/intl.dart';

/// SPEC §2.3. 모든 날짜·시각은 텍스트 기반.
///   dateKey  = YYYY-MM-DD
///   monthKey = YYYY-MM
///   timeKey  = HH:MM (24h)
final DateFormat _date = DateFormat('yyyy-MM-dd');
final DateFormat _month = DateFormat('yyyy-MM');

String toDateKey(DateTime d) => _date.format(d);
String toMonthKey(DateTime d) => _month.format(d);

String currentMonthKey() => toMonthKey(DateTime.now());
String currentDateKey() => toDateKey(DateTime.now());

DateTime parseMonthKey(String monthKey) => _month.parseStrict(monthKey);
DateTime parseDateKey(String dateKey) => _date.parseStrict(dateKey);

/// 월의 [시작일, 종료일] dateKey 튜플.
({String start, String end}) monthRange(String monthKey) {
  final d = parseMonthKey(monthKey);
  final start = DateTime(d.year, d.month, 1);
  final end = DateTime(d.year, d.month + 1, 0); // 다음달 0일 = 이번달 말일
  return (start: toDateKey(start), end: toDateKey(end));
}

/// 월 키에 delta 더하기. 예: shiftMonth('2025-12', 1) == '2026-01'
String shiftMonth(String monthKey, int delta) {
  final d = parseMonthKey(monthKey);
  return toMonthKey(DateTime(d.year, d.month + delta, 1));
}

/// 현재 시각 HH:MM
String nowTime() {
  final d = DateTime.now();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// SQLite 의 datetime('now') 와 같은 포맷의 UTC 타임스탬프 (YYYY-MM-DD HH:MM:SS).
/// created_at/updated_at 을 Dart 쪽에서 채울 때 사용. 백업 JSON 라운드트립 호환.
String sqlNow() {
  final d = DateTime.now().toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} '
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// SPEC §2.3 의 시간 입력 파서.
///   "20"    → "20:00"
///   "2030"  → "20:30"
///   "20:30" → "20:30"
/// 그 외 null.
String? parseTimeInput(String input) {
  final s = input.trim();
  if (RegExp(r'^\d{2}:\d{2}$').hasMatch(s)) {
    final h = int.parse(s.substring(0, 2));
    final m = int.parse(s.substring(3, 5));
    if (h <= 23 && m <= 59) return s;
  }
  if (RegExp(r'^\d{4}$').hasMatch(s)) {
    final hh = s.substring(0, 2);
    final mm = s.substring(2, 4);
    if (int.parse(hh) <= 23 && int.parse(mm) <= 59) return '$hh:$mm';
  }
  if (RegExp(r'^\d{1,2}$').hasMatch(s)) {
    final h = int.parse(s);
    if (h <= 23) return '${h.toString().padLeft(2, '0')}:00';
  }
  return null;
}
