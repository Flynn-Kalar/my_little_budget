import 'dart:math' as math;

import 'quantity_precision.dart';

/// SPEC §3.10 — 투자 평단가(average-cost) 계산.
///
/// 전체 투자 기록을 시간 오름차순으로 훑으며 종목별 (보유수량, 원가) 를 유지하고,
/// 각 이벤트가 자산 잔액에 미치는 영향과 매도 시 실현손익을 계산한다.
/// **순수 함수** — DB·UI 의존 없음. 입력 리스트만 보고 결정적으로 동작.

enum InvestmentSide { buy, sell, dividend }

/// walker 입력. DB 의 investments row 에서 추려 넣는다.
/// 마이그 0015 부터 quantity 는 소수점 가능(REAL).
class InvestmentEntry {
  const InvestmentEntry({
    required this.id,
    required this.side,
    required this.occurredOn,
    required this.occurredTime,
    required this.ticker,
    required this.quantity,
    required this.totalAmount,
    this.accountId,
  });

  final int id;
  final InvestmentSide side;
  final String occurredOn; // YYYY-MM-DD
  final String occurredTime; // HH:MM
  final String ticker;
  final double quantity; // buy/sell > 0, dividend == 0
  final int totalAmount; // > 0
  final int? accountId;
}

/// walker 출력. 각 거래에 평단 원가·잔액 영향을 붙인 형태.
///   buy:      balanceImpact = 0          (현금 → 주식 자산 전환)
///   sell:     balanceImpact = 매도금 - 평단원가  (실현손익)
///   dividend: balanceImpact = 받은 금액 전액
class InvestmentEvent {
  const InvestmentEvent({
    required this.id,
    required this.side,
    required this.occurredOn,
    required this.occurredTime,
    required this.ticker,
    required this.quantity,
    required this.originalAmount,
    required this.costBasis,
    required this.balanceImpact,
    this.accountId,
  });

  final int id;
  final InvestmentSide side;
  final String occurredOn;
  final String occurredTime;
  final String ticker;

  /// 매도/매수는 거래 수량(매도 요청 수량 그대로), 배당은 0.
  final double quantity;

  /// 원래 totalAmount.
  final int originalAmount;

  /// 매도 원가(평단 × 매도수량). buy/dividend 는 0.
  final int costBasis;

  /// 잔액 영향. SPEC §3.10.
  final int balanceImpact;

  final int? accountId;
}

class _Position {
  _Position(this.units, this.basis);
  int units;
  int basis; // 정수 원가 누적 (sell 시 round 한 costBasis 차감)
}

/// 모든 투자 기록 → 평단 계산이 적용된 이벤트 목록.
/// 입력 순서와 무관하게 내부에서 (occurredOn, occurredTime, id) 오름차순으로 정렬 후 처리한다.
/// 출력은 입력과 같은 1:1 (모든 entry 가 event 가 됨), **정렬은 하지 않음**(입력 처리순).
List<InvestmentEvent> computeInvestmentEvents(List<InvestmentEntry> entries) {
  final sorted = [...entries]
    ..sort(
      (a, b) => _cmp(
        a.occurredOn,
        a.occurredTime,
        a.id,
        b.occurredOn,
        b.occurredTime,
        b.id,
      ),
    );
  final positions = <String, _Position>{};
  final result = <InvestmentEvent>[];

  for (final r in sorted) {
    final pos = positions[r.ticker] ?? _Position(0, 0);

    switch (r.side) {
      case InvestmentSide.buy:
        final buyUnits = quantityUnits(r.quantity);
        pos.units += buyUnits;
        pos.basis += r.totalAmount;
        positions[r.ticker] = pos;
        result.add(
          InvestmentEvent(
            id: r.id,
            side: InvestmentSide.buy,
            occurredOn: r.occurredOn,
            occurredTime: r.occurredTime,
            ticker: r.ticker,
            quantity: buyUnits / investmentQuantityScale,
            originalAmount: r.totalAmount,
            costBasis: 0,
            balanceImpact: 0,
            accountId: r.accountId,
          ),
        );

      case InvestmentSide.dividend:
        result.add(
          InvestmentEvent(
            id: r.id,
            side: InvestmentSide.dividend,
            occurredOn: r.occurredOn,
            occurredTime: r.occurredTime,
            ticker: r.ticker,
            quantity: 0,
            originalAmount: r.totalAmount,
            costBasis: 0,
            balanceImpact: r.totalAmount,
            accountId: r.accountId,
          ),
        );

      case InvestmentSide.sell:
        final requestedUnits = quantityUnits(r.quantity);
        final sellUnits = math.min(requestedUnits, pos.units);
        final costBasis = pos.units > 0
            ? (pos.basis * sellUnits / pos.units).round()
            : 0;
        pos.units -= sellUnits;
        pos.basis = math.max(0, pos.basis - costBasis);
        positions[r.ticker] = pos;
        result.add(
          InvestmentEvent(
            id: r.id,
            side: InvestmentSide.sell,
            occurredOn: r.occurredOn,
            occurredTime: r.occurredTime,
            ticker: r.ticker,
            quantity: requestedUnits / investmentQuantityScale,
            originalAmount: r.totalAmount,
            costBasis: costBasis,
            balanceImpact: r.totalAmount - costBasis,
            accountId: r.accountId,
          ),
        );
    }
  }

  return result;
}

/// 특정 자산에 귀속된 이벤트만, 최신순(occurredOn/time/id DESC).
/// = Tauri listInvestmentEventsByAccount.
List<InvestmentEvent> eventsForAccount(
  List<InvestmentEntry> all,
  int accountId,
) {
  return computeInvestmentEvents(
    all,
  ).where((e) => e.accountId == accountId).toList()..sort(
    (a, b) => _cmp(
      b.occurredOn,
      b.occurredTime,
      b.id,
      a.occurredOn,
      a.occurredTime,
      a.id,
    ),
  );
}

/// 자산 잔액에 더해질 투자 손익 합계 = Σ balanceImpact.
int investmentBalanceImpact(List<InvestmentEntry> all, int accountId) {
  return eventsForAccount(
    all,
    accountId,
  ).fold(0, (sum, e) => sum + e.balanceImpact);
}

enum RealizedKind { sell, dividend }

/// 실현손익 한 줄. = Tauri RealizedPnLRow.
class RealizedPnL {
  const RealizedPnL({
    required this.id,
    required this.kind,
    required this.occurredOn,
    required this.occurredTime,
    required this.ticker,
    required this.quantity,
    required this.sellAmount,
    required this.costBasis,
    required this.pnl,
    required this.returnRate,
  });

  final int id;
  final RealizedKind kind;
  final String occurredOn;
  final String occurredTime;
  final String ticker;
  final double quantity;
  final int sellAmount;
  final int costBasis;
  final int pnl;
  final double returnRate;
}

/// [from, to] 기간 안의 매도·배당 실현손익. 매수는 제외. 최신순.
/// = Tauri listRealizedPnL.
List<RealizedPnL> realizedPnL(
  List<InvestmentEntry> all, {
  required String from,
  required String to,
}) {
  final events = computeInvestmentEvents(all);
  final rows = <RealizedPnL>[];

  for (final e in events) {
    if (e.side == InvestmentSide.buy) continue;
    if (e.occurredOn.compareTo(from) < 0 || e.occurredOn.compareTo(to) > 0) {
      continue;
    }
    final isSell = e.side == InvestmentSide.sell;
    rows.add(
      RealizedPnL(
        id: e.id,
        kind: isSell ? RealizedKind.sell : RealizedKind.dividend,
        occurredOn: e.occurredOn,
        occurredTime: e.occurredTime,
        ticker: e.ticker,
        quantity: e.quantity,
        sellAmount: e.originalAmount,
        costBasis: e.costBasis,
        pnl: e.balanceImpact,
        returnRate: isSell && e.costBasis > 0
            ? e.balanceImpact / e.costBasis
            : 0.0,
      ),
    );
  }

  return rows..sort(
    (a, b) => _cmp(
      b.occurredOn,
      b.occurredTime,
      b.id,
      a.occurredOn,
      a.occurredTime,
      a.id,
    ),
  );
}

/// 보유수량이 남은 종목(정렬됨). = Tauri listHeldTickers (SQL `> 0` 그대로).
List<String> heldTickers(List<InvestmentEntry> all) {
  final held = <String, int>{};
  for (final r in all) {
    if (r.side == InvestmentSide.buy) {
      held[r.ticker] = (held[r.ticker] ?? 0) + quantityUnits(r.quantity);
    } else if (r.side == InvestmentSide.sell) {
      held[r.ticker] = (held[r.ticker] ?? 0) - quantityUnits(r.quantity);
    }
  }
  return held.entries.where((e) => e.value > 0).map((e) => e.key).toList()
    ..sort();
}

/// 현재 보유 스냅샷 = Tauri listCurrentHoldings.
///   - 평단(average-cost) 으로 종목별 잔량/원가 누적.
///   - 매도 시 평단원가 차감(round 하지 않은 float — 원본과 동일하게 정밀도 보존).
///   - 잔여수량 ≤ 1e-9 면 결과에서 제외 (소수점 오차 한도).
///   - totalCost 큰 순으로 정렬.
List<CurrentHolding> currentHoldings(List<InvestmentEntry> all) {
  final sorted = [...all]
    ..sort(
      (a, b) => _cmp(
        a.occurredOn,
        a.occurredTime,
        a.id,
        b.occurredOn,
        b.occurredTime,
        b.id,
      ),
    );

  final positions = <String, ({int units, int basis})>{};
  for (final r in sorted) {
    var pos = positions[r.ticker] ?? (units: 0, basis: 0);
    switch (r.side) {
      case InvestmentSide.buy:
        pos = (
          units: pos.units + quantityUnits(r.quantity),
          basis: pos.basis + r.totalAmount,
        );
      case InvestmentSide.sell:
        final sellUnits = math.min(quantityUnits(r.quantity), pos.units);
        final costBasis = pos.units > 0
            ? (pos.basis * sellUnits / pos.units).round()
            : 0;
        pos = (
          units: pos.units - sellUnits,
          basis: math.max(0, pos.basis - costBasis),
        );
      case InvestmentSide.dividend:
        // 포지션 영향 없음
        break;
    }
    positions[r.ticker] = pos;
  }

  return positions.entries
      .where((e) => e.value.units > 0)
      .map(
        (e) => CurrentHolding(
          ticker: e.key,
          quantity: e.value.units / investmentQuantityScale,
          totalCost: e.value.basis,
          avgCost: e.value.basis / (e.value.units / investmentQuantityScale),
        ),
      )
      .toList()
    ..sort((a, b) => b.totalCost.compareTo(a.totalCost));
}

class CurrentHolding {
  const CurrentHolding({
    required this.ticker,
    required this.quantity,
    required this.totalCost,
    required this.avgCost,
  });
  final String ticker;
  final double quantity;
  final int totalCost; // 잔여 원가 (round 한 KRW)
  final double avgCost; // 평단 = basis / qty
}

/// (occurredOn, occurredTime, id) 사전식 비교. 호출부에서 인자 순서로 asc/desc 결정.
int _cmp(String aOn, String aTime, int aId, String bOn, String bTime, int bId) {
  final d = aOn.compareTo(bOn);
  if (d != 0) return d;
  final t = aTime.compareTo(bTime);
  if (t != 0) return t;
  return aId.compareTo(bId);
}
