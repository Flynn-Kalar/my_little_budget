import 'package:korean_lunar_utils/korean_lunar_utils.dart';

import '../../core/date.dart';

class KoreanHoliday {
  const KoreanHoliday({required this.date, required this.name});

  final DateTime date;
  final String name;

  String get dateKey => toDateKey(date);
}

Map<String, KoreanHoliday> koreanHolidaysForMonth(String monthKey) {
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  return {
    for (final holiday in koreanHolidaysForYear(year))
      if (holiday.date.month == month) holiday.dateKey: holiday,
  };
}

List<KoreanHoliday> koreanHolidaysForYear(int year) {
  final holidays = <String, KoreanHoliday>{};

  void add(DateTime date, String name) {
    final normalized = DateTime(date.year, date.month, date.day);
    final key = toDateKey(normalized);
    final existing = holidays[key];
    holidays[key] = KoreanHoliday(
      date: normalized,
      name: existing == null ? name : '${existing.name} · $name',
    );
  }

  add(DateTime(year, 1, 1), '신정');
  add(DateTime(year, 3, 1), '삼일절');
  add(DateTime(year, 5, 5), '어린이날');
  add(DateTime(year, 6, 6), '현충일');
  add(DateTime(year, 8, 15), '광복절');
  add(DateTime(year, 10, 3), '개천절');
  add(DateTime(year, 10, 9), '한글날');
  add(DateTime(year, 12, 25), '성탄절');

  DateTime? lunarNewYear;
  DateTime? buddhasBirthday;
  DateTime? chuseok;
  if (year >= 1901 && year <= 2040) {
    lunarNewYear = LunarSolarConverter.convertLunarToSolar(
      DateTime(year, 1, 1),
    );
    buddhasBirthday = LunarSolarConverter.convertLunarToSolar(
      DateTime(year, 4, 8),
    );
    chuseok = LunarSolarConverter.convertLunarToSolar(DateTime(year, 8, 15));

    add(lunarNewYear.subtract(const Duration(days: 1)), '설날 연휴');
    add(lunarNewYear, '설날');
    add(lunarNewYear.add(const Duration(days: 1)), '설날 연휴');
    add(buddhasBirthday, '부처님오신날');
    add(chuseok.subtract(const Duration(days: 1)), '추석 연휴');
    add(chuseok, '추석');
    add(chuseok.add(const Duration(days: 1)), '추석 연휴');
  }

  for (final holiday in _oneOffHolidays[year] ?? const []) {
    add(holiday.date, holiday.name);
  }

  DateTime nextAvailableAfter(DateTime date) {
    var candidate = date.add(const Duration(days: 1));
    while (candidate.weekday == DateTime.saturday ||
        candidate.weekday == DateTime.sunday ||
        holidays.containsKey(toDateKey(candidate))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  bool isWeekend(DateTime date) =>
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

  if (year >= 2014) {
    final children = DateTime(year, 5, 5);
    if (isWeekend(children)) {
      add(nextAvailableAfter(children), '어린이날 대체공휴일');
    }

    void addLunarSubstitute(DateTime center, String name) {
      final period = [
        center.subtract(const Duration(days: 1)),
        center,
        center.add(const Duration(days: 1)),
      ];
      if (period.any((date) => date.weekday == DateTime.sunday)) {
        add(nextAvailableAfter(period.last), '$name 대체공휴일');
      }
    }

    if (lunarNewYear != null) addLunarSubstitute(lunarNewYear, '설날');
    if (chuseok != null) addLunarSubstitute(chuseok, '추석');
  }

  void addWeekendSubstitute(DateTime date, String name, int firstYear) {
    if (year >= firstYear && isWeekend(date)) {
      add(nextAvailableAfter(date), '$name 대체공휴일');
    }
  }

  addWeekendSubstitute(DateTime(year, 3, 1), '삼일절', 2021);
  addWeekendSubstitute(DateTime(year, 8, 15), '광복절', 2021);
  addWeekendSubstitute(DateTime(year, 10, 3), '개천절', 2021);
  addWeekendSubstitute(DateTime(year, 10, 9), '한글날', 2021);
  if (buddhasBirthday != null) {
    addWeekendSubstitute(buddhasBirthday, '부처님오신날', 2023);
  }
  addWeekendSubstitute(DateTime(year, 12, 25), '성탄절', 2023);

  final result = holidays.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  return result;
}

final _oneOffHolidays = <int, List<KoreanHoliday>>{
  2024: [
    KoreanHoliday(date: DateTime(2024, 4, 10), name: '국회의원선거'),
    KoreanHoliday(date: DateTime(2024, 10, 1), name: '국군의날 임시공휴일'),
  ],
  2025: [
    KoreanHoliday(date: DateTime(2025, 1, 27), name: '임시공휴일'),
    KoreanHoliday(date: DateTime(2025, 6, 3), name: '대통령선거'),
  ],
  2026: [KoreanHoliday(date: DateTime(2026, 6, 3), name: '전국동시지방선거')],
};
