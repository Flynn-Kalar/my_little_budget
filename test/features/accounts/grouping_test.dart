import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/accounts/grouping.dart';

void main() {
  group('classifyAccount (SPEC §3.9)', () {
    test('isInvestment 최우선', () {
      expect(
        classifyAccount(kind: 'card', balance: -1000, isInvestment: true),
        AccountGroup.investment,
      );
    });

    test('카드 또는 음수 잔액 → 부채', () {
      expect(
        classifyAccount(kind: 'card', balance: 1000, isInvestment: false),
        AccountGroup.debt,
      );
      expect(
        classifyAccount(kind: 'bank', balance: -500, isInvestment: false),
        AccountGroup.debt,
      );
    });

    test('현금/은행(잔액 ≥ 0) → 현금성', () {
      expect(
        classifyAccount(kind: 'cash', balance: 0, isInvestment: false),
        AccountGroup.cash,
      );
      expect(
        classifyAccount(kind: 'bank', balance: 100, isInvestment: false),
        AccountGroup.cash,
      );
    });

    test('그 외 → 기타', () {
      expect(
        classifyAccount(kind: 'other', balance: 100, isInvestment: false),
        AccountGroup.other,
      );
    });

    test('그룹 메타데이터', () {
      expect(AccountGroup.cash.label, '현금성');
      expect(AccountGroup.investment.colorHex, '#7c3aed');
    });
  });
}
