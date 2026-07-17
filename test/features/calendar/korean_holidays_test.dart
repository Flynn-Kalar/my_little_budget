import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/calendar/korean_holidays.dart';

void main() {
  test('2026년 대한민국 공휴일과 대체공휴일을 계산한다', () {
    final holidays = {
      for (final holiday in koreanHolidaysForYear(2026))
        holiday.dateKey: holiday.name,
    };

    expect(holidays['2026-01-01'], '신정');
    expect(holidays['2026-02-16'], '설날 연휴');
    expect(holidays['2026-02-17'], '설날');
    expect(holidays['2026-02-18'], '설날 연휴');
    expect(holidays['2026-03-02'], '삼일절 대체공휴일');
    expect(holidays['2026-05-24'], '부처님오신날');
    expect(holidays['2026-05-25'], '부처님오신날 대체공휴일');
    expect(holidays['2026-06-03'], '전국동시지방선거');
    expect(holidays['2026-08-17'], '광복절 대체공휴일');
    expect(holidays['2026-10-05'], '개천절 대체공휴일');
  });

  test('월별 조회는 해당 월 공휴일만 반환한다', () {
    final holidays = koreanHolidaysForMonth('2026-06');

    expect(holidays.keys, containsAll(['2026-06-03', '2026-06-06']));
    expect(holidays.values.every((holiday) => holiday.date.month == 6), isTrue);
  });
}
