import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  group('validateTransaction (SPEC §5.4)', () {
    test('정상 지출', () {
      final r = validateTransaction(
        type: 'expense',
        amount: 5000,
        occurredOn: '2025-05-01',
        occurredTime: '12:30',
        accountId: 1,
        categoryId: 2,
        memo: '  점심  ',
      );
      expect(r.isOk, true);
      expect(r.value!.memo, '점심'); // trim
      expect(r.value!.amount, 5000);
    });

    test('지출에 자산/카테고리 누락', () {
      final r = validateTransaction(
        type: 'expense',
        amount: 5000,
        occurredOn: '2025-05-01',
        occurredTime: '12:30',
      );
      expect(r.isFail, true);
      expect(r.errors.containsKey('accountId'), true);
      expect(r.errors.containsKey('categoryId'), true);
    });

    test('income/expense 금액은 0 이하 불가', () {
      final r = validateTransaction(
        type: 'income',
        amount: 0,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
        accountId: 1,
        categoryId: 2,
      );
      expect(r.errors['amount'], isNotNull);
    });

    test('이체 출금=입금 동일 거부', () {
      final r = validateTransaction(
        type: 'transfer',
        amount: 1000,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
        fromAccountId: 1,
        toAccountId: 1,
      );
      expect(r.errors['toAccountId'], isNotNull);
    });

    test('정상 이체', () {
      final r = validateTransaction(
        type: 'transfer',
        amount: 1000,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
        fromAccountId: 1,
        toAccountId: 2,
      );
      expect(r.isOk, true);
      expect(r.value!.fromAccountId, 1);
      expect(r.value!.toAccountId, 2);
    });

    test('adjustment 0 금지, 음수 허용', () {
      final zero = validateTransaction(
        type: 'adjustment',
        amount: 0,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
        accountId: 1,
      );
      expect(zero.errors['amount'], isNotNull);

      final neg = validateTransaction(
        type: 'adjustment',
        amount: -5000,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
        accountId: 1,
      );
      expect(neg.isOk, true);
      expect(neg.value!.amount, -5000);
    });

    test('잘못된 날짜/시각 형식', () {
      final r = validateTransaction(
        type: 'expense',
        amount: 100,
        occurredOn: '2025/05/01',
        occurredTime: '9시',
        accountId: 1,
        categoryId: 2,
      );
      expect(r.errors['occurredOn'], isNotNull);
      expect(r.errors['occurredTime'], isNotNull);
    });

    test('알 수 없는 type', () {
      final r = validateTransaction(
        type: 'foo',
        amount: 100,
        occurredOn: '2025-05-01',
        occurredTime: '00:00',
      );
      expect(r.errors['type'], isNotNull);
    });
  });
}
