import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/money.dart';

void main() {
  group('formatAmountInput', () {
    test('adds separators to plain, signed, and decimal amounts', () {
      expect(formatAmountInput('1234567'), '1,234,567');
      expect(formatAmountInput('-1234567'), '-1,234,567');
      expect(formatAmountInput('1234.56'), '1,234.56');
      expect(formatAmountInput('1,234,567'), '1,234,567');
    });

    test('formats every number in an arithmetic expression', () {
      expect(formatAmountInput('1000+2000×3'), '1,000+2,000×3');
      expect(
        formatAmountInput('(1000 + 2000) * 3000'),
        '(1,000 + 2,000) * 3,000',
      );
    });
  });

  group('parseKRW', () {
    test('parses plain and formatted amounts', () {
      expect(parseKRW('12000'), 12000);
      expect(parseKRW('₩ 12,000원'), 12000);
      expect(parseKRW('-5,000'), -5000);
      expect(parseKRW(''), 0);
    });

    test('evaluates arithmetic expressions with precedence', () {
      expect(parseKRW('1,000 + 2,500'), 3500);
      expect(parseKRW('10,000 - 2,500'), 7500);
      expect(parseKRW('1,200 * 3'), 3600);
      expect(parseKRW('10,000 / 4'), 2500);
      expect(parseKRW('1,000 + 2,000 * 3'), 7000);
      expect(parseKRW('(1,000 + 2,000) * 3'), 9000);
    });

    test('supports unary signs and alternate operator glyphs', () {
      expect(parseKRW('-1000 + 250'), -750);
      expect(parseKRW('1,000 × 3'), 3000);
      expect(parseKRW('9,000 ÷ 3'), 3000);
      expect(parseKRW('2,000 x 4'), 8000);
    });

    test('returns zero for invalid expressions', () {
      expect(parseKRW('1,000 +'), 0);
      expect(parseKRW('1,000 / 0'), 0);
      expect(parseKRW('abc'), 0);
    });
  });
}
