import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/investments/validation.dart';

void main() {
  group('validateInvestment (SPEC §5.4)', () {
    test('정상 매수', () {
      final r = validateInvestment(
        side: 'buy',
        occurredOn: '2025-05-01',
        occurredTime: '09:00',
        ticker: 'AAPL',
        quantity: 10,
        totalAmount: 100000,
      );
      expect(r.isOk, true);
      expect(r.value!.quantity, 10);
    });

    test('매수/매도 수량 1 미만 거부', () {
      final r = validateInvestment(
        side: 'sell',
        occurredOn: '2025-05-01',
        occurredTime: '09:00',
        ticker: 'AAPL',
        quantity: 0,
        totalAmount: 100000,
      );
      expect(r.errors['quantity'], isNotNull);
    });

    test('배당은 수량 무시하고 0 정규화', () {
      final r = validateInvestment(
        side: 'dividend',
        occurredOn: '2025-05-01',
        occurredTime: '09:00',
        ticker: 'AAPL',
        quantity: 999,
        totalAmount: 5000,
      );
      expect(r.isOk, true);
      expect(r.value!.quantity, 0);
    });

    test('금액 1 미만 거부', () {
      final r = validateInvestment(
        side: 'buy',
        occurredOn: '2025-05-01',
        occurredTime: '09:00',
        ticker: 'AAPL',
        quantity: 1,
        totalAmount: 0,
      );
      expect(r.errors['totalAmount'], isNotNull);
    });

    test('종목명 trim + 빈 값 거부', () {
      final r = validateInvestment(
        side: 'buy',
        occurredOn: '2025-05-01',
        occurredTime: '09:00',
        ticker: '   ',
        quantity: 1,
        totalAmount: 1000,
      );
      expect(r.errors['ticker'], isNotNull);
    });
  });

  group('checkTradableTicker (SPEC §4.7)', () {
    test('매수는 항상 통과', () {
      expect(
        checkTradableTicker(side: 'buy', ticker: 'NEW', heldTickers: {}),
        isNull,
      );
    });

    test('보유 종목 매도 통과, 미보유 거부', () {
      expect(
        checkTradableTicker(side: 'sell', ticker: 'AAPL', heldTickers: {'AAPL'}),
        isNull,
      );
      expect(
        checkTradableTicker(side: 'sell', ticker: 'TSLA', heldTickers: {'AAPL'}),
        isNotNull,
      );
    });

    test('같은 ticker 의 기존 행 수정은 미보유여도 통과', () {
      expect(
        checkTradableTicker(
          side: 'sell',
          ticker: 'TSLA',
          heldTickers: {'AAPL'},
          existingTicker: 'TSLA',
        ),
        isNull,
      );
    });

    test('미보유 배당은 거부', () {
      final msg = checkTradableTicker(
        side: 'dividend',
        ticker: 'TSLA',
        heldTickers: {},
      );
      expect(msg, contains('배당'));
    });
  });
}
