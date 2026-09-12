import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/recurring/logic.dart';

void main() {
  group('nextOccurrence — monthly (SPEC §5.1)', () {
    test('첫 발생: 시작월에 dayOfMonth 가 시작일 이후면 그 날', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-10',
        dayOfMonth: 15,
      );
      expect(nextOccurrence(r, null), '2025-01-15');
    });

    test('첫 발생: dayOfMonth 가 시작일보다 앞이면 다음 달', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-20',
        dayOfMonth: 15,
      );
      expect(nextOccurrence(r, null), '2025-02-15');
    });

    test('31일 지정 → 그 달에 없으면 말일로 폴백 (2월)', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-02-01',
        dayOfMonth: 31,
      );
      expect(nextOccurrence(r, null), '2025-02-28'); // 2025 비윤년
    });

    test('anchor 다음 달의 같은 날', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 15,
      );
      expect(nextOccurrence(r, '2025-01-15'), '2025-02-15');
    });

    test('anchor 가 말일이고 31일 지정 → 다음 달 말일 폴백', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 31,
      );
      expect(nextOccurrence(r, '2025-01-31'), '2025-02-28');
    });

    test('연말 → 연초 롤오버', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 10,
      );
      expect(nextOccurrence(r, '2025-12-10'), '2026-01-10');
    });

    test('N주차 N요일은 해당 월의 N번째 요일을 계산한다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-08-01',
        monthlyMode: MonthlyRecurrenceMode.nthWeekday,
        weekOfMonth: 2,
        dayOfWeek: 3,
      );

      expect(nextOccurrence(r, null), '2026-08-12');
      expect(nextOccurrence(r, '2026-08-12'), '2026-09-09');
    });

    test('해당 요일의 5주차가 없는 달은 건너뛴다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-02-01',
        monthlyMode: MonthlyRecurrenceMode.nthWeekday,
        weekOfMonth: 5,
        dayOfWeek: 0,
      );

      expect(nextOccurrence(r, null), '2026-03-29');
    });

    test('N일이 휴일이면 당일·전 영업일·후 영업일 정책을 적용한다', () {
      const same = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-08-01',
        dayOfMonth: 15,
      );
      const previous = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-08-01',
        dayOfMonth: 15,
        nonBusinessDayAdjustment: NonBusinessDayAdjustment.previous,
      );
      const next = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-08-01',
        dayOfMonth: 15,
        nonBusinessDayAdjustment: NonBusinessDayAdjustment.next,
      );

      expect(nextOccurrence(same, null), '2026-08-15');
      expect(nextOccurrence(previous, null), '2026-08-14');
      expect(nextOccurrence(next, null), '2026-08-18');
    });

    test('전 영업일 조정이 이전 달로 넘어가도 다음 월을 중복하지 않는다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2026-12-01',
        dayOfMonth: 1,
        nonBusinessDayAdjustment: NonBusinessDayAdjustment.previous,
      );

      expect(nextOccurrence(r, '2026-12-01'), '2026-12-31');
      expect(nextOccurrence(r, '2026-12-31'), '2027-02-01');
    });
  });

  group('nextOccurrence — weekly (SPEC §5.1, 0=일~6=토)', () {
    test('첫 발생: 시작일 이후 가장 가까운 dayOfWeek', () {
      // 2025-01-01 = 수요일(일요일기준 3). 금요일(5) 까지 +2일.
      final r = RecurrenceRule(
        frequency: RecurFrequency.weekly,
        startDate: '2025-01-01',
        dayOfWeek: 5,
      );
      expect(nextOccurrence(r, null), '2025-01-03');
    });

    test('첫 발생: 시작일이 곧 dayOfWeek 면 그 날', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.weekly,
        startDate: '2025-01-01', // 수요일=3
        dayOfWeek: 3,
      );
      expect(nextOccurrence(r, null), '2025-01-01');
    });

    test('일요일(0) 처리', () {
      // 2025-01-01 수(3) → 일(0) 까지 (0-3+7)%7 = 4일 → 2025-01-05
      final r = RecurrenceRule(
        frequency: RecurFrequency.weekly,
        startDate: '2025-01-01',
        dayOfWeek: 0,
      );
      expect(nextOccurrence(r, null), '2025-01-05');
    });

    test('anchor + 7일', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.weekly,
        startDate: '2025-01-01',
        dayOfWeek: 5,
      );
      expect(nextOccurrence(r, '2025-01-03'), '2025-01-10');
    });
  });

  group('nextOccurrence — daily', () {
    test('주말·공휴일 포함 시 시작일부터 매일 발생한다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.daily,
        startDate: '2026-08-14',
      );

      expect(nextOccurrence(r, null), '2026-08-14');
      expect(nextOccurrence(r, '2026-08-14'), '2026-08-15');
      expect(nextOccurrence(r, '2026-08-15'), '2026-08-16');
    });

    test('주말·공휴일 제외 시 주말과 대체공휴일을 건너뛴다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.daily,
        startDate: '2026-08-14',
        includeNonBusinessDays: false,
      );

      expect(nextOccurrence(r, null), '2026-08-14');
      // 8/15(토), 8/16(일), 8/17(광복절 대체공휴일) 제외
      expect(nextOccurrence(r, '2026-08-14'), '2026-08-18');
    });

    test('제외 모드에서 시작일이 공휴일이면 다음 영업일부터 시작한다', () {
      const r = RecurrenceRule(
        frequency: RecurFrequency.daily,
        startDate: '2026-06-03',
        includeNonBusinessDays: false,
      );

      expect(nextOccurrence(r, null), '2026-06-04');
    });
  });

  group('dueOccurrences — backfill (SPEC §5.1)', () {
    test('매일 반복은 주말·공휴일 포함 설정을 반영한다', () {
      const included = RecurrenceRule(
        frequency: RecurFrequency.daily,
        startDate: '2026-08-14',
      );
      const excluded = RecurrenceRule(
        frequency: RecurFrequency.daily,
        startDate: '2026-08-14',
        includeNonBusinessDays: false,
      );

      expect(dueOccurrences(included, horizon: '2026-08-18'), [
        '2026-08-14',
        '2026-08-15',
        '2026-08-16',
        '2026-08-17',
        '2026-08-18',
      ]);
      expect(dueOccurrences(excluded, horizon: '2026-08-18'), [
        '2026-08-14',
        '2026-08-18',
      ]);
    });

    test('anchor 없으면 시작월부터 horizon 까지', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 15,
      );
      expect(dueOccurrences(r, horizon: '2025-03-31'), [
        '2025-01-15',
        '2025-02-15',
        '2025-03-15',
      ]);
    });

    test('lastGeneratedOn 이후부터 생성', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 15,
      );
      expect(
        dueOccurrences(r, lastGeneratedOn: '2025-01-15', horizon: '2025-03-31'),
        ['2025-02-15', '2025-03-15'],
      );
    });

    test('endDate 이후는 제외', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-01-01',
        dayOfMonth: 15,
      );
      expect(dueOccurrences(r, horizon: '2025-12-31', endDate: '2025-02-20'), [
        '2025-01-15',
        '2025-02-15',
      ]);
    });

    test('horizon 이 첫 발생보다 앞이면 빈 리스트', () {
      final r = RecurrenceRule(
        frequency: RecurFrequency.monthly,
        startDate: '2025-06-01',
        dayOfMonth: 15,
      );
      expect(dueOccurrences(r, horizon: '2025-03-31'), isEmpty);
    });
  });
}
