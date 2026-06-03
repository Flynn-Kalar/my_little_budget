import '../../core/validation.dart';

/// SPEC §5.4 — 자산 입력 검증.

const _accountKinds = {'cash', 'bank', 'card', 'other'};

class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.kind,
    required this.initialBalance,
    required this.color,
    required this.excludeFromTotal,
    required this.isInvestment,
  });

  final String name;
  final String kind;
  final int initialBalance;
  final String color;
  final bool excludeFromTotal;
  final bool isInvestment;
}

ValidationResult<AccountDraft> validateAccount({
  required String name,
  required String kind,
  int initialBalance = 0,
  String color = '#94a3b8',
  bool excludeFromTotal = false,
  bool isInvestment = false,
}) {
  final errors = <String, String>{};

  final cleanedName = name.trim();
  if (cleanedName.isEmpty || cleanedName.length > 40) {
    errors['name'] = '이름은 1~40자여야 합니다';
  }
  if (!_accountKinds.contains(kind)) {
    errors['kind'] = '자산 종류가 올바르지 않습니다';
  }
  if (!isHexColor(color)) {
    errors['color'] = '색상은 #RRGGBB 형식이어야 합니다';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  return ValidationResult.ok(AccountDraft(
    name: cleanedName,
    kind: kind,
    initialBalance: initialBalance,
    color: color,
    excludeFromTotal: excludeFromTotal,
    isInvestment: isInvestment,
  ));
}
