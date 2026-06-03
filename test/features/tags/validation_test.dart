import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/tags/validation.dart';

void main() {
  group('validateTag (SPEC §4.8.3)', () {
    test('정상 + trim', () {
      final r = validateTag(name: '  여행  ', color: '#2563eb');
      expect(r.isOk, true);
      expect(r.value!.name, '여행');
    });

    test('이름 빈/초과 거부', () {
      expect(validateTag(name: '').errors['name'], isNotNull);
      expect(validateTag(name: 'a' * 21).errors['name'], isNotNull);
    });

    test('잘못된 색상 거부', () {
      expect(validateTag(name: 'x', color: 'blue').errors['color'], isNotNull);
    });
  });
}
