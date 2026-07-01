import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../../features/investments/cost_basis.dart';
import '../../features/investments/validation.dart';
import '../database.dart';
import '../investment_mapping.dart';
import '../sync_metadata.dart';
import '../tables/accounts.dart';
import '../tables/investments.dart';

part 'investments_dao.g.dart';

/// SPEC §3.6 / §3.10 / §4.7 — 투자 조회·평단 손익·CRUD.

class InvestmentSummary {
  const InvestmentSummary(
    this.buy,
    this.sell,
    this.dividend, {
    this.realizedPnl = 0,
  });
  final int buy;
  final int sell;
  final int dividend;
  final int realizedPnl;
  int get net => realizedPnl;
}

@DriftAccessor(tables: [Investments, Accounts])
class InvestmentsDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentsDaoMixin {
  InvestmentsDao(super.db);

  Future<List<Investment>> listInvestmentsByMonth(String month) {
    final b = monthRange(month);
    return (select(investments)
          ..where((i) => i.occurredOn.isBetweenValues(b.start, b.end))
          ..orderBy([
            (i) =>
                OrderingTerm(expression: i.occurredOn, mode: OrderingMode.desc),
            (i) => OrderingTerm(
              expression: i.occurredTime,
              mode: OrderingMode.desc,
            ),
            (i) => OrderingTerm(expression: i.id, mode: OrderingMode.desc),
          ]))
        .get();
  }

  Future<InvestmentSummary> investmentMonthlySummary(String month) async {
    final b = monthRange(month);
    return _sumBySide(b.start, b.end);
  }

  /// 연 단위 투자 목록. = Tauri listInvestmentsByYear.
  Future<List<Investment>> listInvestmentsByYear(int year) {
    return (select(investments)
          ..where(
            (i) => i.occurredOn.isBetweenValues('$year-01-01', '$year-12-31'),
          )
          ..orderBy([
            (i) =>
                OrderingTerm(expression: i.occurredOn, mode: OrderingMode.desc),
            (i) => OrderingTerm(
              expression: i.occurredTime,
              mode: OrderingMode.desc,
            ),
            (i) => OrderingTerm(expression: i.id, mode: OrderingMode.desc),
          ]))
        .get();
  }

  /// 연 단위 매수/매도/배당 요약. = Tauri investmentYearlySummary.
  Future<InvestmentSummary> investmentYearlySummary(int year) {
    return _sumBySide('$year-01-01', '$year-12-31');
  }

  /// 투자 기록이 있는 연도. = Tauri availableInvestmentYears.
  Future<List<int>> availableInvestmentYears() async {
    final rows = await customSelect(
      'SELECT DISTINCT substr(occurred_on, 1, 4) AS y FROM investments ORDER BY y',
      readsFrom: {investments},
    ).get();
    return rows.map((r) => int.parse(r.read<String>('y'))).toList();
  }

  /// 종목별 잔량/원가 스냅샷. = Tauri listCurrentHoldings. 순수 walker 재사용.
  Future<List<CurrentHolding>> listCurrentHoldings() async {
    final all = await select(investments).get();
    return currentHoldings(all.map(toInvestmentEntry).toList());
  }

  Future<InvestmentSummary> _sumBySide(String start, String end) async {
    final rows = await customSelect(
      'SELECT side, COALESCE(SUM(total_amount), 0) AS total FROM investments '
      'WHERE occurred_on BETWEEN ? AND ? GROUP BY side',
      variables: [Variable<String>(start), Variable<String>(end)],
      readsFrom: {investments},
    ).get();
    var buy = 0, sell = 0, dividend = 0;
    for (final r in rows) {
      final total = r.read<int>('total');
      switch (r.read<String>('side')) {
        case 'buy':
          buy = total;
        case 'sell':
          sell = total;
        case 'dividend':
          dividend = total;
      }
    }
    final realizedRows = await getRealizedPnL(start, end);
    final realizedPnl = realizedRows.fold<int>(0, (sum, row) => sum + row.pnl);
    return InvestmentSummary(buy, sell, dividend, realizedPnl: realizedPnl);
  }

  /// 단일 투자 자산 (isInvestment=true, 활성). SPEC §3.6.
  Future<Account?> getInvestmentAccount() {
    return (select(accounts)
          ..where((a) => a.isInvestment.equals(true) & a.archivedAt.isNull()))
        .getSingleOrNull();
  }

  Future<Investment?> getInvestmentById(int id) {
    return (select(
      investments,
    )..where((i) => i.id.equals(id))).getSingleOrNull();
  }

  /// 보유수량 > 0 인 종목 (정렬). SPEC §4.7. 순수 walker 재사용.
  Future<List<String>> listHeldTickers() async {
    final all = await select(investments).get();
    return heldTickers(all.map(toInvestmentEntry).toList());
  }

  /// 기간 내 실현손익. SPEC §3.10. 순수 walker 재사용.
  Future<List<RealizedPnL>> getRealizedPnL(String from, String to) async {
    final all = await select(investments).get();
    return realizedPnL(all.map(toInvestmentEntry).toList(), from: from, to: to);
  }

  /// 자산에 귀속된 투자 이벤트 (자산 상세 가상 행용). SPEC §3.10.
  Future<List<InvestmentEvent>> getEventsForAccount(int accountId) async {
    final all = await select(investments).get();
    return eventsForAccount(all.map(toInvestmentEntry).toList(), accountId);
  }

  /// 투자 저장. accountId 는 현재 투자 자산으로 자동 지정. SPEC §4.7.
  /// 호출부 검증과 별개로 DAO 에서도 미보유/과매도 저장을 차단한다.
  Future<int> saveInvestment({int? id, required InvestmentDraft draft}) async {
    await _ensureTradableDraft(id: id, draft: draft);

    final investAccount = await getInvestmentAccount();
    final accountId = investAccount?.id;

    if (id != null) {
      await (update(investments)..where((i) => i.id.equals(id))).write(
        InvestmentsCompanion(
          side: Value(draft.side),
          occurredOn: Value(draft.occurredOn),
          occurredTime: Value(draft.occurredTime),
          ticker: Value(draft.ticker),
          quantity: Value(draft.quantity),
          totalAmount: Value(draft.totalAmount),
          accountId: Value(accountId),
          memo: Value(draft.memo),
          updatedAt: Value(sqlNow()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
      return id;
    }
    return into(investments).insert(
      InvestmentsCompanion.insert(
        side: draft.side,
        occurredOn: draft.occurredOn,
        occurredTime: Value(draft.occurredTime),
        ticker: draft.ticker,
        quantity: Value(draft.quantity),
        totalAmount: draft.totalAmount,
        accountId: Value(accountId),
        memo: Value(draft.memo),
      ),
    );
  }

  Future<void> deleteInvestment(int id) async {
    await (delete(investments)..where((i) => i.id.equals(id))).go();
  }

  Future<void> _ensureTradableDraft({
    required int? id,
    required InvestmentDraft draft,
  }) async {
    if (draft.side != 'sell' && draft.side != 'dividend') return;

    final allRows = await select(investments).get();
    final entries = allRows
        .where((row) => row.id != id)
        .map(toInvestmentEntry)
        .toList();
    final held = currentHoldings(entries);
    final heldTickers = held.map((holding) => holding.ticker).toSet();

    final tickerError = checkTradableTicker(
      side: draft.side,
      ticker: draft.ticker,
      heldTickers: heldTickers,
    );
    if (tickerError != null) {
      throw ArgumentError(tickerError);
    }

    final quantityError = checkSellQuantity(
      side: draft.side,
      ticker: draft.ticker,
      quantity: draft.quantity,
      heldQuantities: {
        for (final holding in held) holding.ticker: holding.quantity,
      },
    );
    if (quantityError != null) {
      throw ArgumentError(quantityError);
    }
  }
}
