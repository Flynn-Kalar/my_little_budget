import '../../core/validation.dart';

/// SPEC §3.4 / §4.4 — 예산 그룹 생성 검증.
///   - 자산 연동 그룹(accountId NOT NULL) 과 % 모드는 동시 사용 금지
///   - 자산 연동: accountId 양의 정수 필요, carryForward 강제 false
///   - 카테고리 기반: categoryIds 1개 이상 필요
///     - % 모드: percentage 1~1000 정수
///     - 고정: amount ≥ 0

class BudgetGroupDraft {
  const BudgetGroupDraft({
    required this.name,
    required this.month,
    required this.amount,
    this.categoryIds = const [],
    this.accountId,
    this.percentage,
    this.carryForward = false,
  });

  final String name;
  final String month; // YYYY-MM
  final int amount;
  final List<int> categoryIds;
  final int? accountId;
  final int? percentage;
  final bool carryForward;
}

ValidationResult<BudgetGroupDraft> validateBudgetGroup({
  required String name,
  required String month,
  int amount = 0,
  List<int> categoryIds = const [],
  int? accountId,
  int? percentage,
  bool carryForward = false,
}) {
  final errors = <String, String>{};

  final cleaned = name.trim();
  if (cleaned.isEmpty) errors['name'] = '예산 이름을 입력해주세요';
  if (!isMonthKey(month)) errors['month'] = 'YYYY-MM 형식이어야 합니다';

  if (accountId != null) {
    if (accountId <= 0) errors['accountId'] = '자산을 선택해주세요';
    if (percentage != null) {
      errors['percentage'] = '자산 연동과 % 모드는 동시 사용할 수 없습니다';
    }
  } else {
    if (categoryIds.isEmpty) {
      errors['categoryIds'] = '카테고리를 하나 이상 선택해주세요';
    }
    if (percentage != null) {
      if (percentage <= 0 || percentage > 1000) {
        errors['percentage'] = '퍼센트는 1~1000 사이 정수여야 합니다';
      }
    } else if (amount < 0) {
      errors['amount'] = '금액은 0 이상이어야 합니다';
    }
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);

  return ValidationResult.ok(BudgetGroupDraft(
    name: cleaned,
    month: month,
    amount: amount,
    categoryIds: categoryIds,
    accountId: accountId,
    percentage: percentage,
    // SPEC: 자산 연동은 잔금 이월 개념 없음 → 강제 false
    carryForward: accountId != null ? false : carryForward,
  ));
}
