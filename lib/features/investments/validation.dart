import '../../core/validation.dart';

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

  if (!_sides.contains(side)) errors['side'] = '거래 종류가 올바르지 않습니다.';
  if (!isDateKey(occurredOn)) errors['occurredOn'] = 'YYYY-MM-DD 형식이어야 합니다.';
  if (!isTimeKey(occurredTime)) errors['occurredTime'] = 'HH:MM 형식이어야 합니다.';

  final cleanedTicker = ticker.trim();
  if (cleanedTicker.isEmpty || cleanedTicker.length > 40) {
    errors['ticker'] = '종목코드는 1~40자여야 합니다.';
  }

  final isDividend = side == 'dividend';
  final normalizedQty = isDividend ? 0.0 : quantity;
  if (!isDividend &&
      (normalizedQty == null ||
          !normalizedQty.isFinite ||
          normalizedQty <= 0)) {
    errors['quantity'] = '수량은 0보다 커야 합니다.';
  }

  if (totalAmount == null || totalAmount < 1) {
    errors['totalAmount'] = '금액은 1원 이상이어야 합니다.';
  }

  final cleanedMemo = (memo != null && memo.trim().isNotEmpty)
      ? memo.trim()
      : null;
  if (cleanedMemo != null && cleanedMemo.length > 200) {
    errors['memo'] = '메모는 200자 이하여야 합니다.';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  return ValidationResult.ok(
    InvestmentDraft(
      side: side,
      occurredOn: occurredOn,
      occurredTime: occurredTime,
      ticker: cleanedTicker,
      quantity: normalizedQty ?? 0,
      totalAmount: totalAmount!,
      memo: cleanedMemo,
    ),
  );
}

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
      ? '보유하지 않은 종목은 매도할 수 없습니다.'
      : '보유하지 않은 종목은 배당(諛곕떦)을 입력할 수 없습니다.';
}

String? checkSellQuantity({
  required String side,
  required String ticker,
  required double quantity,
  required Map<String, double> heldQuantities,
}) {
  if (side != 'sell') return null;
  final held = heldQuantities[ticker] ?? 0;
  if (quantity <= held) return null;
  return '보유 수량보다 많이 매도할 수 없습니다.';
}
