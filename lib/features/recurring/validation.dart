import '../../core/validation.dart';

/// SPEC §3.7 / §4.8.2 / §5.4 — 반복 거래 입력 검증.
///   income/expense: accountId + categoryId 필수
///   transfer:       fromAccountId + toAccountId 필수 (서로 다름)
///   monthly: dayOfMonth 1~31 필수 / weekly: dayOfWeek 0~6 필수

class RecurringDraft {
  const RecurringDraft({
    required this.name,
    required this.type,
    required this.amount,
    required this.frequency,
    required this.occurredTime,
    required this.startDate,
    this.dayOfMonth,
    this.dayOfWeek,
    this.endDate,
    this.memo,
    this.accountId,
    this.categoryId,
    this.fromAccountId,
    this.toAccountId,
    this.tagNames = const [],
  });

  final String name;
  final String type; // income | expense | transfer
  final int amount;
  final String frequency; // monthly | weekly
  final String occurredTime;
  final String startDate;
  final int? dayOfMonth;
  final int? dayOfWeek;
  final String? endDate;
  final String? memo;
  final int? accountId;
  final int? categoryId;
  final int? fromAccountId;
  final int? toAccountId;
  final List<String> tagNames;
}

ValidationResult<RecurringDraft> validateRecurring({
  required String type,
  required String name,
  required int? amount,
  required String frequency,
  required String occurredTime,
  required String startDate,
  int? dayOfMonth,
  int? dayOfWeek,
  String? endDate,
  String? memo,
  int? accountId,
  int? categoryId,
  int? fromAccountId,
  int? toAccountId,
  List<String> tagNames = const [],
}) {
  final errors = <String, String>{};

  final cleanedName = name.trim();
  if (cleanedName.isEmpty || cleanedName.length > 40) {
    errors['name'] = '이름은 1~40자여야 합니다';
  }
  if (amount == null || amount <= 0) errors['amount'] = '금액은 0보다 커야 합니다';
  if (!isTimeKey(occurredTime)) errors['occurredTime'] = 'HH:MM 형식이어야 합니다';
  if (!isDateKey(startDate)) errors['startDate'] = 'YYYY-MM-DD 형식이어야 합니다';
  if (endDate != null && !isDateKey(endDate)) {
    errors['endDate'] = 'YYYY-MM-DD 형식이어야 합니다';
  }

  final cleanedMemo =
      (memo != null && memo.trim().isNotEmpty) ? memo.trim() : null;
  if (cleanedMemo != null && cleanedMemo.length > 200) {
    errors['memo'] = '메모는 200자 이하여야 합니다';
  }

  // cadence
  if (frequency == 'monthly') {
    if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
      errors['dayOfMonth'] = '월 반복일(1~31)을 선택해주세요';
    }
  } else if (frequency == 'weekly') {
    if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) {
      errors['dayOfWeek'] = '요일을 선택해주세요';
    }
  } else {
    errors['frequency'] = '반복 주기가 올바르지 않습니다';
  }

  // shape
  switch (type) {
    case 'income':
    case 'expense':
      if (accountId == null) errors['accountId'] = '자산을 선택해주세요';
      if (categoryId == null) errors['categoryId'] = '카테고리를 선택해주세요';
    case 'transfer':
      if (fromAccountId == null) errors['fromAccountId'] = '출금 자산을 선택해주세요';
      if (toAccountId == null) errors['toAccountId'] = '입금 자산을 선택해주세요';
      if (fromAccountId != null &&
          toAccountId != null &&
          fromAccountId == toAccountId) {
        errors['toAccountId'] = '출금/입금 자산이 같을 수 없습니다';
      }
    default:
      errors['type'] = '거래 종류가 올바르지 않습니다';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  final isTransfer = type == 'transfer';
  final isMonthly = frequency == 'monthly';
  final cleanedTags = <String>{
    for (final n in tagNames)
      if (n.trim().isNotEmpty) n.trim(),
  }.toList();

  return ValidationResult.ok(RecurringDraft(
    name: cleanedName,
    type: type,
    amount: amount!,
    frequency: frequency,
    occurredTime: occurredTime,
    startDate: startDate,
    dayOfMonth: isMonthly ? dayOfMonth : null,
    dayOfWeek: isMonthly ? null : dayOfWeek,
    endDate: endDate,
    memo: cleanedMemo,
    accountId: isTransfer ? null : accountId,
    categoryId: isTransfer ? null : categoryId,
    fromAccountId: isTransfer ? fromAccountId : null,
    toAccountId: isTransfer ? toAccountId : null,
    tagNames: cleanedTags,
  ));
}
