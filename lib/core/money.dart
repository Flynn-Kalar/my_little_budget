import 'package:intl/intl.dart';

/// SPEC §2.3. 정수 원(KRW) 입력만 받는다.
final NumberFormat _krw = NumberFormat.currency(
  locale: 'ko_KR',
  symbol: '₩',
  decimalDigits: 0,
);

String formatKRW(int amount) => _krw.format(amount);

/// 숫자·마이너스 외 모두 제거 후 int. 빈 입력은 0.
int parseKRW(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d-]'), '');
  if (digits.isEmpty || digits == '-') return 0;
  return int.parse(digits);
}
