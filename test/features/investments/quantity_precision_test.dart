import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/investments/cost_basis.dart';
import 'package:my_little_budget/features/investments/quantity_precision.dart';
import 'package:my_little_budget/features/investments/validation.dart';

InvestmentEntry _entry({
  required int id,
  required InvestmentSide side,
  required String on,
  double qty = 0,
  required int total,
}) {
  return InvestmentEntry(
    id: id,
    side: side,
    occurredOn: on,
    occurredTime: '00:00',
    ticker: 'AAPL',
    quantity: qty,
    totalAmount: total,
  );
}

void main() {
  group('investment quantity precision', () {
    test('rounds to 4 decimal places at the 5th decimal', () {
      expect(normalizeQuantity(0.12344), closeTo(0.1234, 0.00001));
      expect(normalizeQuantity(0.12345), closeTo(0.1235, 0.00001));
      expect(normalizeQuantity(1.99995), closeTo(2.0, 0.00001));
    });

    test('validation stores rounded quantity', () {
      final result = validateInvestment(
        side: 'buy',
        occurredOn: '2026-06-01',
        occurredTime: '09:00',
        ticker: 'AAPL',
        quantity: 0.123456,
        totalAmount: 1000,
      );

      expect(result.isOk, true);
      expect(result.value!.quantity, closeTo(0.1235, 0.00001));
    });

    test('buy 0.3333 then sell 0.1111 leaves 0.2222 holding', () {
      final holdings = currentHoldings([
        _entry(
          id: 1,
          side: InvestmentSide.buy,
          on: '2026-06-01',
          qty: 0.3333,
          total: 3333,
        ),
        _entry(
          id: 2,
          side: InvestmentSide.sell,
          on: '2026-06-02',
          qty: 0.1111,
          total: 1500,
        ),
      ]);

      expect(holdings.single.quantity, closeTo(0.2222, 0.00001));
      expect(formatInvestmentQuantity(holdings.single.quantity), '0.2222');
    });

    test('holdings and PnL use rounded quantities consistently', () {
      final entries = [
        _entry(
          id: 1,
          side: InvestmentSide.buy,
          on: '2026-06-01',
          qty: 0.123456,
          total: 1235,
        ),
        _entry(
          id: 2,
          side: InvestmentSide.sell,
          on: '2026-06-02',
          qty: 0.023456,
          total: 500,
        ),
      ];

      final holdings = currentHoldings(entries);
      final pnl = realizedPnL(
        entries,
        from: '2026-06-01',
        to: '2026-06-30',
      ).single;

      expect(holdings.single.quantity, closeTo(0.1, 0.00001));
      expect(pnl.quantity, closeTo(0.0235, 0.00001));
      expect(pnl.costBasis, 235);
      expect(pnl.pnl, 265);
    });
  });
}
