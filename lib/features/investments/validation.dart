import '../../core/validation.dart';

/// SPEC §3.6 / §4.7 / §5.4 — 투자 입력 검증.
///   buy/sell: quantity > 0 (소수점 허용 — 마이그 0015)
///   dividend: quantity == 0 (입력값 무시하고 0 으로 정규화)
///   totalAmount ≥ 1, ticker 1~40자

const _sides = {'buy', 'sell', 'dividend'};

class InvestmentDraft {
  const InvestmentDraft({
    required this.side,
    required this.occurredOn,
    required this.occurredTime,
    required this.ticker,
    required this.quantity,
    required this.totalAmount,
    this.memo,
  });

  final String side;
  final String occurredOn;
  final String occurredTime;
  final String ticker;
  final double quantity;
  final int totalAmount;
  final String? memo;
}

ValidationResult<InvestmentDraft> validateInvestment({
  required String side,
  required String occurredOn,
  required String occurredTime,
  required String ticker,
  required double? quantity,
  required int? totalAmount,
  String? memo,
}) {
  final errors = <String, String>{};

  if (!_sides.contains(side)) errors['side'] = '거래 종류가 올바르지 않습니다';
  if (!isDateKey(occurredOn)) errors['occurredOn'] = 'YYYY-MM-DD 형식이어야 합니다';
  if (!isTimeKey(occurredTime)) errors['occurredTime'] = 'HH:MM 형식이어야 합니다';

  final cleanedTicker = ticker.trim();
  if (cleanedTicker.isEmpty || cleanedTicker.length > 40) {
    errors['ticker'] = '종목명은 1~40자여야 합니다';
  }

  final isDividend = side == 'dividend';
  final normalizedQty = isDividend ? 0.0 : quantity;
  if (!isDividend &&
      (normalizedQty == null || !normalizedQty.isFinite || normalizedQty <= 0)) {
    errors['quantity'] = '수량은 0보다 커야 합니다';
  }

  if (totalAmount == null || totalAmount < 1) {
    errors['totalAmount'] = '금액은 1원 이상이어야 합니다';
  }

  final cleanedMemo =
      (memo != null && memo.trim().isNotEmpty) ? memo.trim() : null;
  if (cleanedMemo != null && cleanedMemo.length > 200) {
    errors['memo'] = '메모는 200자 이하여야 합니다';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  return ValidationResult.ok(InvestmentDraft(
    side: side,
    occurredOn: occurredOn,
    occurredTime: occurredTime,
    ticker: cleanedTicker,
    quantity: normalizedQty ?? 0,
    totalAmount: totalAmount!,
    memo: cleanedMemo,
  ));
}

/// 매도·배당은 현재 보유 종목에만 허용. 단, 같은 ticker 의 기존 행을 수정 중이면 통과.
/// SPEC §4.7. 통과하면 null, 막히면 에러 메시지 반환.
String? checkTradableTicker({
  required String side,
  required String ticker,
  required Set<String> heldTickers,
  String? existingTicker,
}) {
  if (side != 'sell' && side != 'dividend') return null;
  if (existingTicker == ticker) return null;
  if (heldTickers.contains(ticker)) return null;
  return side == 'sell'
      ? '보유하지 않은 종목은 매도할 수 없습니다'
      : '보유하지 않은 종목은 배당금을 입력할 수 없습니다';
}
