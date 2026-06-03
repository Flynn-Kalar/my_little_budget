import 'dart:math';

/// SPEC §3.4 / §4.4 — 예산 계산 순수 산식. DB·UI 의존 없음.

/// 카테고리 기반 그룹의 유효 예산 = max(0, base + adjustment).
int effectiveBudget({required int base, required int adjustment}) =>
    max(0, base + adjustment);

/// % 모드 base = round(예상 소득 × percentage / 100).
int percentageBase({required int expectedIncome, required int percentage}) =>
    (expectedIncome * percentage / 100).round();

/// 사용률(%) = round(spent / budget × 100). budget 0 이면 0.
int usagePercent({required int spent, required int budget}) =>
    budget > 0 ? (spent / budget * 100).round() : 0;

/// 자산 연동 예산. SPEC §4.4.
///   available = max(0, 월초 잔액) + 이번 달 입금
///   spent     = 이번 달 출금
({int available, int spent}) accountBudgetFlow({
  required int startBalance,
  required int monthInflow,
  required int monthOutflow,
}) =>
    (available: max(0, startBalance) + monthInflow, spent: monthOutflow);

/// 다음 달 복사 시 이월 조정액. carryForward 면 (예산 − 사용액), 아니면 0. 음수 가능.
int carryForwardAdjustment({
  required bool carryForward,
  required int budget,
  required int spent,
}) =>
    carryForward ? budget - spent : 0;
