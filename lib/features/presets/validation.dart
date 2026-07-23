import '../../core/date.dart';
import '../../core/validation.dart';
import '../transactions/validation.dart';

class TransactionPresetDraft {
  const TransactionPresetDraft({
    required this.type,
    required this.amount,
    this.name,
    this.memo,
    this.accountId,
    this.categoryId,
    this.fromAccountId,
    this.toAccountId,
    this.tagNames = const [],
  });

  final String? name;
  final String type;
  final int amount;
  final String? memo;
  final int? accountId;
  final int? categoryId;
  final int? fromAccountId;
  final int? toAccountId;
  final List<String> tagNames;

  TransactionDraft toTransactionDraft(DateTime now) => TransactionDraft(
    type: type,
    amount: amount,
    occurredOn: toDateKey(now),
    occurredTime:
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}',
    memo: memo,
    accountId: accountId,
    categoryId: categoryId,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
  );
}

ValidationResult<TransactionPresetDraft> validateTransactionPreset({
  String? name,
  required String type,
  required int? amount,
  String? memo,
  int? accountId,
  int? categoryId,
  int? fromAccountId,
  int? toAccountId,
  List<String> tagNames = const [],
}) {
  final result = validateTransaction(
    type: type,
    amount: amount,
    occurredOn: '2000-01-01',
    occurredTime: '00:00',
    memo: memo,
    accountId: accountId,
    categoryId: categoryId,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
  );
  if (result.isFail || type == 'adjustment') {
    final errors = Map<String, String>.from(result.errors);
    if (type == 'adjustment') {
      errors['type'] = '프리셋은 수입, 지출, 이체만 지원합니다.';
    }
    return ValidationResult.fail(errors);
  }

  final tx = result.value!;
  final cleanedName = name?.trim();
  final cleanedTags = <String>{
    for (final tag in tagNames)
      if (tag.trim().isNotEmpty && tag.trim().length <= 20) tag.trim(),
  }.toList();
  return ValidationResult.ok(
    TransactionPresetDraft(
      name: cleanedName == null || cleanedName.isEmpty ? null : cleanedName,
      type: tx.type,
      amount: tx.amount,
      memo: tx.memo,
      accountId: tx.accountId,
      categoryId: tx.categoryId,
      fromAccountId: tx.fromAccountId,
      toAccountId: tx.toAccountId,
      tagNames: cleanedTags,
    ),
  );
}
