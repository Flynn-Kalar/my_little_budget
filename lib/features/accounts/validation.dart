import '../../core/validation.dart';
import 'fund_purpose.dart';

/// SPEC §5.4 — 자산 입력 검증.

const _accountKinds = {'cash', 'bank', 'card', 'other'};

class AccountDraft {
  const AccountDraft({
    required this.name,
    required this.kind,
    required this.initialBalance,
    this.cardLimit,
    this.cardPaymentDay,
    this.cardClosingDay,
    this.cardPaymentAccountUuid,
    this.fundPurpose = 'living',
    required this.color,
    required this.excludeFromTotal,
    required this.isInvestment,
  });

  final String name;
  final String kind;
  final int initialBalance;
  final int? cardLimit;
  final int? cardPaymentDay;
  final int? cardClosingDay;
  final String? cardPaymentAccountUuid;
  final String fundPurpose;
  final String color;
  final bool excludeFromTotal;
  final bool isInvestment;
}

ValidationResult<AccountDraft> validateAccount({
  required String name,
  required String kind,
  int initialBalance = 0,
  int? cardLimit,
  int? cardPaymentDay,
  int? cardClosingDay,
  String? cardPaymentAccountUuid,
  String fundPurpose = 'living',
  String color = '#94a3b8',
  bool excludeFromTotal = false,
  bool isInvestment = false,
}) {
  final errors = <String, String>{};
  if (!fundPurposeLabels.containsKey(fundPurpose)) {
    errors['fundPurpose'] = '자금 용도를 확인해주세요';
  }
  if (fundPurpose != 'living' &&
      (!(kind == 'cash' || kind == 'bank') || isInvestment)) {
    errors['fundPurpose'] = '준비금은 투자 자산이 아닌 현금·은행 계좌에 지정해주세요';
  }

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
  if (cardLimit != null && cardLimit < 1) {
    errors['cardLimit'] = '카드 한도는 1원 이상이어야 합니다';
  }
  if (kind != 'card' && cardLimit != null) {
    errors['cardLimit'] = '카드 한도는 카드 자산에만 설정할 수 있습니다';
  }
  if (cardPaymentDay != null && (cardPaymentDay < 1 || cardPaymentDay > 31)) {
    errors['cardPaymentDay'] = '결제일은 1~31일이어야 합니다';
  }
  if (cardClosingDay != null && (cardClosingDay < 1 || cardClosingDay > 31)) {
    errors['cardClosingDay'] = '청구 마감일은 1~31일이어야 합니다';
  }
  if ((cardPaymentDay == null) != (cardClosingDay == null)) {
    errors['cardPaymentDay'] = '결제일과 청구 마감일을 함께 선택해주세요';
  }
  if (kind != 'card' &&
      (cardPaymentDay != null ||
          cardClosingDay != null ||
          cardPaymentAccountUuid != null)) {
    errors['cardPaymentDay'] = '결제 설정은 카드 자산에만 사용할 수 있습니다';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  return ValidationResult.ok(
    AccountDraft(
      name: cleanedName,
      kind: kind,
      initialBalance: initialBalance,
      cardLimit: cardLimit,
      cardPaymentDay: cardPaymentDay,
      cardClosingDay: cardClosingDay,
      cardPaymentAccountUuid: cardPaymentAccountUuid,
      fundPurpose: fundPurpose,
      color: color,
      excludeFromTotal: excludeFromTotal,
      isInvestment: isInvestment,
    ),
  );
}
