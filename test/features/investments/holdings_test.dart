import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/investments/cost_basis.dart';

InvestmentEntry e({
  required int id,
  required InvestmentSide side,
  required String on,
  String ticker = 'AAPL',
  double qty = 0,
  required int total,
}) =>
    InvestmentEntry(
      id: id,
      side: side,
      occurredOn: on,
      occurredTime: '00:00',
      ticker: ticker,
      quantity: qty,
      totalAmount: total,
    );

void main() {
  group('currentHoldings (SPEC §3.10)', () {
    test('보유수량 0 이하 종목 제외, totalCost 내림차순', () {
      // AAPL: buy 10@1000 → sell 4 → 잔량 6, 평단 100, 잔여원가 600
      // TSLA: buy 5@500 → sell 5 → 잔량 0 → 제외
      // NVDA: buy 2@2000 → 잔량 2, 잔여원가 2000
      final all = [
        e(id: 1, side: InvestmentSide.buy, on: '2026-01-01', ticker: 'AAPL', qty: 10, total: 1000),
        e(id: 2, side: InvestmentSide.sell, on: '2026-01-05', ticker: 'AAPL', qty: 4, total: 500),
        e(id: 3, side: InvestmentSide.buy, on: '2026-01-02', ticker: 'TSLA', qty: 5, total: 500),
        e(id: 4, side: InvestmentSide.sell, on: '2026-01-06', ticker: 'TSLA', qty: 5, total: 700),
        e(id: 5, side: InvestmentSide.buy, on: '2026-01-03', ticker: 'NVDA', qty: 2, total: 2000),
      ];
      final holdings = currentHoldings(all);
      expect(holdings.map((h) => h.ticker).toList(), ['NVDA', 'AAPL']);

      final nvda = holdings.first;
      expect(nvda.quantity, 2);
      expect(nvda.totalCost, 2000);
      expect(nvda.avgCost, 1000.0);

      final aapl = holdings.last;
      expect(aapl.quantity, 6);
      expect(aapl.totalCost, 600);
      expect(aapl.avgCost, closeTo(100.0, 1e-9));
    });

    test('소수점 수량 정상 처리', () {
      // 0.5 매수 1000, 0.25 매도 600 → 잔량 0.25, 잔여원가 500
      final all = [
        e(id: 1, side: InvestmentSide.buy, on: '2026-01-01', qty: 0.5, total: 1000),
        e(id: 2, side: InvestmentSide.sell, on: '2026-01-02', qty: 0.25, total: 600),
      ];
      final h = currentHoldings(all).single;
      expect(h.quantity, closeTo(0.25, 1e-9));
      expect(h.totalCost, 500); // basis = 1000 - (2000 * 0.25) = 500
    });
  });

  group('heldTickers — 소수점 수량', () {
    test('소수점 잔량도 > 0 면 포함', () {
      final all = [
        e(id: 1, side: InvestmentSide.buy, on: '2026-01-01', qty: 1.5, total: 100),
        e(id: 2, side: InvestmentSide.sell, on: '2026-01-02', qty: 1.0, total: 80),
      ];
      expect(heldTickers(all), ['AAPL']);
    });
  });
}
