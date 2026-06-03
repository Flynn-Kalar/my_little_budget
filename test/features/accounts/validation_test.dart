import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/accounts/validation.dart';

void main() {
  group('validateAccount (SPEC §5.4)', () {
    test('정상', () {
      final r = validateAccount(
        name: '  주거래 통장  ',
        kind: 'bank',
        initialBalance: 50000,
        color: '#2563eb',
      );
      expect(r.isOk, true);
      expect(r.value!.name, '주거래 통장'); // trim
      expect(r.value!.kind, 'bank');
    });

    test('이름 빈 값/초과 거부', () {
      expect(validateAccount(name: '', kind: 'bank').errors['name'], isNotNull);
      expect(
        validateAccount(name: 'a' * 41, kind: 'bank').errors['name'],
        isNotNull,
      );
    });

    test('잘못된 kind 거부', () {
      expect(
        validateAccount(name: '현금', kind: 'wallet').errors['kind'],
        isNotNull,
      );
    });

    test('잘못된 색상 거부', () {
      expect(
        validateAccount(name: '현금', kind: 'cash', color: 'red').errors['color'],
        isNotNull,
      );
    });
  });
}
