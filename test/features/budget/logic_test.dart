import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/budget/logic.dart';

void main() {
  group('budget 순수 산식 (SPEC §3.4 / §4.4)', () {
    test('effectiveBudget = max(0, base + adjustment)', () {
      expect(effectiveBudget(base: 100000, adjustment: 20000), 120000);
      expect(effectiveBudget(base: 100000, adjustment: -30000), 70000);
      expect(effectiveBudget(base: 50000, adjustment: -80000), 0); // 음수 → 0
    });

    test('percentageBase = round(소득 × % / 100)', () {
      expect(percentageBase(expectedIncome: 3000000, percentage: 30), 900000);
      expect(percentageBase(expectedIncome: 1000, percentage: 33), 330);
      expect(percentageBase(expectedIncome: 1000, percentage: 1), 10);
    });

    test('usagePercent = round(spent / budget × 100), budget 0 이면 0', () {
      expect(usagePercent(spent: 50000, budget: 100000), 50);
      expect(usagePercent(spent: 120000, budget: 100000), 120);
      expect(usagePercent(spent: 5000, budget: 0), 0);
    });

    test('accountBudgetFlow: 월초잔액 음수면 0으로 clamp 후 입금 더함', () {
      final f = accountBudgetFlow(
        startBalance: -10000,
        monthInflow: 50000,
        monthOutflow: 20000,
      );
      expect(f.available, 50000); // max(0, -10000) + 50000
      expect(f.spent, 20000);

      final g = accountBudgetFlow(
        startBalance: 30000,
        monthInflow: 50000,
        monthOutflow: 20000,
      );
      expect(g.available, 80000);
    });

    test('carryForwardAdjustment: on 이면 (예산-사용), off 면 0. 음수 가능', () {
      expect(
        carryForwardAdjustment(carryForward: true, budget: 100000, spent: 70000),
        30000,
      );
      expect(
        carryForwardAdjustment(carryForward: true, budget: 100000, spent: 130000),
        -30000,
      );
      expect(
        carryForwardAdjustment(carryForward: false, budget: 100000, spent: 70000),
        0,
      );
    });
  });
}
