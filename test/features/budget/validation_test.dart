import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/budget/validation.dart';

void main() {
  group('validateBudgetGroup (SPEC §3.4 / §4.4)', () {
    test('카테고리 기반 고정 예산 정상', () {
      final r = validateBudgetGroup(
        name: '식비',
        month: '2026-05',
        amount: 100000,
        categoryIds: [1, 2],
      );
      expect(r.isOk, true);
      expect(r.value!.name, '식비');
    });

    test('카테고리 누락 거부 (카테고리 기반)', () {
      final r = validateBudgetGroup(name: 'x', month: '2026-05', amount: 100);
      expect(r.errors['categoryIds'], isNotNull);
    });

    test('% 모드: percentage 1~1000 정수만', () {
      expect(
        validateBudgetGroup(
                name: 'x',
                month: '2026-05',
                categoryIds: [1],
                percentage: 0)
            .errors['percentage'],
        isNotNull,
      );
      expect(
        validateBudgetGroup(
                name: 'x',
                month: '2026-05',
                categoryIds: [1],
                percentage: 1001)
            .errors['percentage'],
        isNotNull,
      );
      final ok = validateBudgetGroup(
          name: 'x', month: '2026-05', categoryIds: [1], percentage: 30);
      expect(ok.isOk, true);
    });

    test('자산 연동 + % 동시 사용 금지', () {
      final r = validateBudgetGroup(
        name: '자산',
        month: '2026-05',
        accountId: 1,
        percentage: 30,
      );
      expect(r.errors['percentage'], isNotNull);
    });

    test('자산 연동은 carryForward 강제 false', () {
      final r = validateBudgetGroup(
        name: '자산',
        month: '2026-05',
        accountId: 1,
        carryForward: true,
      );
      expect(r.isOk, true);
      expect(r.value!.carryForward, false);
    });

    test('잘못된 month 형식', () {
      final r = validateBudgetGroup(name: 'x', month: '2026/05', categoryIds: [1]);
      expect(r.errors['month'], isNotNull);
    });
  });
}
