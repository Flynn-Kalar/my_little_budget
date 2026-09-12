import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/recurring/validation.dart';

void main() {
  test(
    'daily recurring accepts non-business-day option and clears cadence days',
    () {
      final result = validateRecurring(
        type: 'expense',
        name: '매일 지출',
        amount: 1000,
        frequency: 'daily',
        occurredTime: '09:00',
        startDate: '2026-01-01',
        dayOfMonth: 1,
        dayOfWeek: 4,
        includeNonBusinessDays: false,
        accountId: 1,
        categoryId: 1,
      );

      expect(result.isOk, isTrue);
      expect(result.value!.frequency, 'daily');
      expect(result.value!.dayOfMonth, isNull);
      expect(result.value!.dayOfWeek, isNull);
      expect(result.value!.includeNonBusinessDays, isFalse);
    },
  );

  test('monthly nth weekday keeps week and weekday while clearing day', () {
    final result = validateRecurring(
      type: 'expense',
      name: '둘째 수요일',
      amount: 1000,
      frequency: 'monthly',
      monthlyMode: 'nth_weekday',
      weekOfMonth: 2,
      dayOfWeek: 3,
      occurredTime: '09:00',
      startDate: '2026-01-01',
      accountId: 1,
      categoryId: 1,
    );

    expect(result.isOk, isTrue);
    expect(result.value!.monthlyMode, 'nth_weekday');
    expect(result.value!.weekOfMonth, 2);
    expect(result.value!.dayOfWeek, 3);
    expect(result.value!.dayOfMonth, isNull);
  });

  test('monthly day keeps non-business-day adjustment', () {
    final result = validateRecurring(
      type: 'expense',
      name: '월말 결제',
      amount: 1000,
      frequency: 'monthly',
      monthlyMode: 'day',
      dayOfMonth: 31,
      nonBusinessDayAdjustment: 'previous',
      occurredTime: '09:00',
      startDate: '2026-01-01',
      accountId: 1,
      categoryId: 1,
    );

    expect(result.isOk, isTrue);
    expect(result.value!.nonBusinessDayAdjustment, 'previous');
    expect(result.value!.weekOfMonth, isNull);
  });
}
