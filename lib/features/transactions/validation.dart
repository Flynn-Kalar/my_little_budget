import '../../core/validation.dart';

/// SPEC §3.3 / §5.4 — 거래 입력 검증. type 별 형상 + 금액 부호 규칙.

/// 검증을 통과한 거래 입력. DB Companion 으로 그대로 매핑 가능.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.occurredOn,
    required this.occurredTime,
    this.memo,
    this.accountId,
    this.categoryId,
    this.fromAccountId,
    this.toAccountId,
  });

  final String type; // income | expense | transfer | adjustment
  final int amount; // adjustment 만 signed(≠0), 그 외 > 0
  final String occurredOn;
  final String occurredTime;
  final String? memo;
  final int? accountId;
  final int? categoryId;
  final int? fromAccountId;
  final int? toAccountId;
}

ValidationResult<TransactionDraft> validateTransaction({
  required String type,
  required int? amount,
  required String occurredOn,
  required String occurredTime,
  String? memo,
  int? accountId,
  int? categoryId,
  int? fromAccountId,
  int? toAccountId,
}) {
  final errors = <String, String>{};

  if (!isDateKey(occurredOn)) errors['occurredOn'] = 'YYYY-MM-DD 형식이어야 합니다';
  if (!isTimeKey(occurredTime)) errors['occurredTime'] = 'HH:MM 형식이어야 합니다';

  final cleanedMemo =
      (memo != null && memo.trim().isNotEmpty) ? memo.trim() : null;
  if (cleanedMemo != null && cleanedMemo.length > 200) {
    errors['memo'] = '메모는 200자 이하여야 합니다';
  }
  if (amount == null) errors['amount'] = '금액을 입력해주세요';

  switch (type) {
    case 'income':
    case 'expense':
      if (accountId == null) errors['accountId'] = '자산을 선택해주세요';
      if (categoryId == null) errors['categoryId'] = '카테고리를 선택해주세요';
      if (amount != null && amount <= 0) errors['amount'] = '금액은 0보다 커야 합니다';
      if (errors.isEmpty) {
        return ValidationResult.ok(TransactionDraft(
          type: type,
          amount: amount!,
          occurredOn: occurredOn,
          occurredTime: occurredTime,
          memo: cleanedMemo,
          accountId: accountId,
          categoryId: categoryId,
        ));
      }
    case 'transfer':
      if (fromAccountId == null) errors['fromAccountId'] = '출금 자산을 선택해주세요';
      if (toAccountId == null) errors['toAccountId'] = '입금 자산을 선택해주세요';
      if (fromAccountId != null &&
          toAccountId != null &&
          fromAccountId == toAccountId) {
        errors['toAccountId'] = '출금/입금 계좌가 같을 수 없습니다';
      }
      if (amount != null && amount <= 0) errors['amount'] = '금액은 0보다 커야 합니다';
      if (errors.isEmpty) {
        return ValidationResult.ok(TransactionDraft(
          type: 'transfer',
          amount: amount!,
          occurredOn: occurredOn,
          occurredTime: occurredTime,
          memo: cleanedMemo,
          fromAccountId: fromAccountId,
          toAccountId: toAccountId,
        ));
      }
    case 'adjustment':
      if (accountId == null) errors['accountId'] = '자산을 선택해주세요';
      if (amount != null && amount == 0) errors['amount'] = '0 은 입력할 수 없습니다';
      if (errors.isEmpty) {
        return ValidationResult.ok(TransactionDraft(
          type: 'adjustment',
          amount: amount!,
          occurredOn: occurredOn,
          occurredTime: occurredTime,
          memo: cleanedMemo,
          accountId: accountId,
        ));
      }
    default:
      errors['type'] = '거래 종류를 선택해주세요';
  }

  return ValidationResult.fail(errors);
}
