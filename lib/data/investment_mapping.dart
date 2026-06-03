import '../features/investments/cost_basis.dart';
import '../features/investments/quantity_precision.dart';
import 'database.dart';

/// Drift Investment row → 순수 평단가 walker 입력으로 변환.
/// 데이터 레이어 글루: cost_basis.dart 는 drift 를 모르고, DAO 들은 이걸 공유.
InvestmentEntry toInvestmentEntry(Investment r) => InvestmentEntry(
  id: r.id,
  side: switch (r.side) {
    'buy' => InvestmentSide.buy,
    'sell' => InvestmentSide.sell,
    _ => InvestmentSide.dividend,
  },
  occurredOn: r.occurredOn,
  occurredTime: r.occurredTime,
  ticker: r.ticker,
  quantity: normalizeQuantity(r.quantity),
  totalAmount: r.totalAmount,
  accountId: r.accountId,
);
