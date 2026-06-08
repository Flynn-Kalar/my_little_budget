import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/investments/cost_basis.dart';

InvestmentEntry _e({
  required int id,
  required InvestmentSide side,
  required String on,
  String time = '00:00',
  String ticker = 'AAPL',
  double qty = 0,
  required int total,
  int? accountId = 1,
}) => InvestmentEntry(
  id: id,
  side: side,
  occurredOn: on,
  occurredTime: time,
  ticker: ticker,
  quantity: qty,
  totalAmount: total,
  accountId: accountId,
);

void main() {
  group('computeInvestmentEvents — 평단가 (SPEC §3.10)', () {
    test('매수는 잔액 영향 0, 평단만 누적', () {
      final events = computeInvestmentEvents([
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
        ),
      ]);
      expect(events.single.balanceImpact, 0);
      expect(events.single.costBasis, 0);
      expect(events.single.quantity, 10);
    });

    test('부분 매도: 실현손익 = 매도금 - 평단원가', () {
      // 매수 10주 1000원(평단 100) → 4주 매도 600원
      final events = computeInvestmentEvents([
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
        ),
        _e(
          id: 2,
          side: InvestmentSide.sell,
          on: '2025-01-02',
          qty: 4,
          total: 600,
        ),
      ]);
      final sell = events.firstWhere((e) => e.side == InvestmentSide.sell);
      expect(sell.costBasis, 400); // 100 * 4
      expect(sell.balanceImpact, 200); // 600 - 400
      expect(sell.quantity, 4);
    });

    test('여러 매수의 가중 평단', () {
      // 10주@1000(평단100) + 10주@2000 → 총 20주 3000, 평단 150
      // 10주 매도 2000원 → 원가 1500, 손익 +500
      final events = computeInvestmentEvents([
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
        ),
        _e(
          id: 2,
          side: InvestmentSide.buy,
          on: '2025-01-02',
          qty: 10,
          total: 2000,
        ),
        _e(
          id: 3,
          side: InvestmentSide.sell,
          on: '2025-01-03',
          qty: 10,
          total: 2000,
        ),
      ]);
      final sell = events.firstWhere((e) => e.side == InvestmentSide.sell);
      expect(sell.costBasis, 1500);
      expect(sell.balanceImpact, 500);
    });

    test('보유수량보다 많이 매도하면 보유분까지만 원가 계산', () {
      // 5주@500(평단100) 보유, 10주 매도 1500원 → sellQty=5, 원가500, 손익1000
      final events = computeInvestmentEvents([
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 5,
          total: 500,
        ),
        _e(
          id: 2,
          side: InvestmentSide.sell,
          on: '2025-01-02',
          qty: 10,
          total: 1500,
        ),
      ]);
      final sell = events.firstWhere((e) => e.side == InvestmentSide.sell);
      expect(sell.costBasis, 500);
      expect(sell.balanceImpact, 1000);
      expect(sell.quantity, 10); // 요청 수량 그대로 표시
    });

    test('배당은 전액 잔액 증가', () {
      final events = computeInvestmentEvents([
        _e(
          id: 1,
          side: InvestmentSide.dividend,
          on: '2025-01-05',
          qty: 0,
          total: 300,
        ),
      ]);
      expect(events.single.balanceImpact, 300);
      expect(events.single.costBasis, 0);
      expect(events.single.quantity, 0);
    });

    test('입력 순서가 뒤섞여도 시간순으로 정렬해 계산', () {
      final events = computeInvestmentEvents([
        _e(
          id: 2,
          side: InvestmentSide.sell,
          on: '2025-01-02',
          qty: 4,
          total: 600,
        ),
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
        ),
      ]);
      final sell = events.firstWhere((e) => e.side == InvestmentSide.sell);
      expect(sell.balanceImpact, 200);
    });
  });

  group('eventsForAccount / investmentBalanceImpact', () {
    test('지정 자산의 이벤트만, 잔액 영향 합산', () {
      final all = [
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
          accountId: 1,
        ),
        _e(
          id: 2,
          side: InvestmentSide.sell,
          on: '2025-01-02',
          qty: 4,
          total: 600,
          accountId: 1,
        ),
        _e(
          id: 3,
          side: InvestmentSide.dividend,
          on: '2025-01-03',
          qty: 0,
          total: 300,
          accountId: 2,
        ),
      ];
      final acc1 = eventsForAccount(all, 1);
      expect(acc1.length, 2);
      expect(investmentBalanceImpact(all, 1), 200); // buy 0 + sell 200
      expect(investmentBalanceImpact(all, 2), 300); // dividend
    });

    test('최신순 정렬 (occurredOn DESC)', () {
      final all = [
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
        ),
        _e(
          id: 2,
          side: InvestmentSide.dividend,
          on: '2025-03-01',
          qty: 0,
          total: 50,
        ),
      ];
      final events = eventsForAccount(all, 1);
      expect(events.first.occurredOn, '2025-03-01');
      expect(events.last.occurredOn, '2025-01-01');
    });
  });

  group('realizedPnL', () {
    final all = [
      _e(
        id: 1,
        side: InvestmentSide.buy,
        on: '2025-01-01',
        qty: 10,
        total: 1000,
      ),
      _e(
        id: 2,
        side: InvestmentSide.sell,
        on: '2025-02-10',
        qty: 5,
        total: 700,
      ),
      _e(
        id: 3,
        side: InvestmentSide.dividend,
        on: '2025-02-15',
        qty: 0,
        total: 100,
      ),
      _e(
        id: 4,
        side: InvestmentSide.sell,
        on: '2025-03-20',
        qty: 5,
        total: 400,
      ),
    ];

    test('기간 내 매도·배당만, 매수 제외', () {
      final rows = realizedPnL(all, from: '2025-02-01', to: '2025-02-28');
      expect(rows.length, 2);
      expect(
        rows.every((r) => r.kind != RealizedKind.dividend || r.pnl == 100),
        true,
      );
    });

    test('매도 수익률 계산: pnl / costBasis', () {
      // 2월 매도: 평단 100, 5주 → 원가 500, 매도 700 → 손익 200, 수익률 0.4
      final rows = realizedPnL(all, from: '2025-02-01', to: '2025-02-28');
      final sell = rows.firstWhere((r) => r.kind == RealizedKind.sell);
      expect(sell.costBasis, 500);
      expect(sell.pnl, 200);
      expect(sell.returnRate, closeTo(0.4, 1e-9));
    });

    test('배당 수익률은 0', () {
      final rows = realizedPnL(all, from: '2025-02-01', to: '2025-02-28');
      final div = rows.firstWhere((r) => r.kind == RealizedKind.dividend);
      expect(div.returnRate, 0.0);
      expect(div.pnl, 100);
    });
  });

  group('realizedPnL requirements', () {
    test('BUY만 있으면 realizedPnL 합계는 0', () {
      final rows = realizedPnL(
        [
          _e(
            id: 1,
            side: InvestmentSide.buy,
            on: '2025-01-01',
            qty: 10,
            total: 1000,
          ),
        ],
        from: '2025-01-01',
        to: '2025-01-31',
      );
      expect(rows, isEmpty);
      expect(rows.fold<int>(0, (sum, row) => sum + row.pnl), 0);
    });

    test('BUY 후 SELL은 SELL 시점에만 realizedPnL을 만든다', () {
      final rows = realizedPnL(
        [
          _e(
            id: 1,
            side: InvestmentSide.buy,
            on: '2025-01-01',
            qty: 10,
            total: 1000,
          ),
          _e(
            id: 2,
            side: InvestmentSide.sell,
            on: '2025-02-01',
            qty: 4,
            total: 600,
          ),
        ],
        from: '2025-01-01',
        to: '2025-02-28',
      );
      expect(rows.length, 1);
      expect(rows.single.kind, RealizedKind.sell);
      expect(rows.single.pnl, 200);
    });

    test('DIVIDEND는 realized income으로 양수 반영된다', () {
      final rows = realizedPnL(
        [
          _e(
            id: 1,
            side: InvestmentSide.dividend,
            on: '2025-01-01',
            qty: 0,
            total: 300,
          ),
        ],
        from: '2025-01-01',
        to: '2025-01-31',
      );
      expect(rows.length, 1);
      expect(rows.single.kind, RealizedKind.dividend);
      expect(rows.single.pnl, 300);
    });
  });

  group('heldTickers', () {
    test('보유수량 > 0 인 종목만 정렬 반환', () {
      final all = [
        _e(
          id: 1,
          side: InvestmentSide.buy,
          on: '2025-01-01',
          qty: 10,
          total: 1000,
          ticker: 'TSLA',
        ),
        _e(
          id: 2,
          side: InvestmentSide.sell,
          on: '2025-01-02',
          qty: 4,
          total: 600,
          ticker: 'TSLA',
        ),
        _e(
          id: 3,
          side: InvestmentSide.buy,
          on: '2025-01-03',
          qty: 5,
          total: 500,
          ticker: 'AAPL',
        ),
        _e(
          id: 4,
          side: InvestmentSide.sell,
          on: '2025-01-04',
          qty: 5,
          total: 700,
          ticker: 'AAPL',
        ),
      ];
      // TSLA: 10-4=6 보유, AAPL: 5-5=0 청산
      expect(heldTickers(all), ['TSLA']);
    });
  });
}
