import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../core/money.dart';

const maxNoteGoalAmount = 999999999999999;

class NoteAmountGoal {
  const NoteAmountGoal({
    required this.targetAmount,
    required this.currentAmount,
    required this.startDate,
    this.dueDate,
    this.source = 'manual',
    this.accountUuid,
    this.tagUuid,
  });

  final int targetAmount;
  final int currentAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final String source;
  final String? accountUuid;
  final String? tagUuid;
  bool get isLinked => source != 'manual';

  NoteAmountGoal withCurrentAmount(int amount) => NoteAmountGoal(
    targetAmount: targetAmount,
    currentAmount: amount,
    startDate: startDate,
    dueDate: dueDate,
    source: source,
    accountUuid: accountUuid,
    tagUuid: tagUuid,
  );

  /// Remaining calendar months include this month. Linked goals subtract the
  /// actual net contribution already made this month from the month's quota.
  int? monthlyNeeded(DateTime today, {int? monthStartAmount}) {
    if (remaining == 0) return 0;
    final due = dueDate;
    if (due == null) return null;
    final month = DateTime(today.year, today.month);
    if (month.isBefore(DateTime(startDate.year, startDate.month))) return 0;
    final months = (due.year - today.year) * 12 + due.month - today.month + 1;
    if (months <= 1) return remaining;
    final base = monthStartAmount ?? currentAmount;
    final baseRemaining = withCurrentAmount(base).remaining;
    final quota = (baseRemaining + months - 1) ~/ months;
    final direction = targetAmount < 0 ? -1 : 1;
    final contributed = (currentAmount - base) * direction;
    final needed = quota - contributed;
    return needed.clamp(0, remaining);
  }

  @override
  bool operator ==(Object other) =>
      other is NoteAmountGoal &&
      targetAmount == other.targetAmount &&
      currentAmount == other.currentAmount &&
      startDate == other.startDate &&
      dueDate == other.dueDate &&
      source == other.source &&
      accountUuid == other.accountUuid &&
      tagUuid == other.tagUuid;
  @override
  int get hashCode => Object.hash(
    targetAmount,
    currentAmount,
    startDate,
    dueDate,
    source,
    accountUuid,
    tagUuid,
  );

  static NoteAmountGoal? fromNote(Note note) {
    if (note.goalTargetAmount == null) return null;
    return NoteAmountGoal(
      targetAmount: note.goalTargetAmount!,
      currentAmount: note.goalCurrentAmount ?? 0,
      startDate: DateTime.parse(note.goalStartDate!),
      dueDate: note.goalDueDate == null
          ? null
          : DateTime.parse(note.goalDueDate!),
    );
  }

  double get progress =>
      targetAmount == 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0);
  int get remaining {
    final difference = targetAmount < 0
        ? currentAmount - targetAmount
        : targetAmount - currentAmount;
    return difference < 0 ? 0 : difference;
  }

  String get percentage => '${(progress * 100).toStringAsFixed(1)}%';

  String? get validationError {
    if (!const {'manual', 'account', 'transactions'}.contains(source)) {
      return '집계 방식을 확인해주세요.';
    }
    if (isLinked && (accountUuid == null || accountUuid!.isEmpty)) {
      return '연결할 계좌를 선택해주세요.';
    }
    if (source != 'transactions' && tagUuid != null) {
      return '태그는 거래 집계에서만 사용할 수 있습니다.';
    }
    if (isLinked && targetAmount <= 0) {
      return '자동 적립 목표 금액은 1원 이상이어야 합니다.';
    }
    if (targetAmount == 0 || targetAmount.abs() > maxNoteGoalAmount) {
      return '목표 금액은 -999,999,999,999,999원부터 999,999,999,999,999원까지 0원을 제외하고 입력하세요.';
    }
    if (currentAmount.abs() > maxNoteGoalAmount) {
      return '현재 금액은 -999,999,999,999,999원부터 999,999,999,999,999원까지 입력하세요.';
    }
    if (dueDate != null && dueDate!.isBefore(startDate)) {
      return '목표일은 시작일 이후로 선택하세요.';
    }
    return null;
  }
}

String formatNoteAmount(int amount) =>
    NumberFormat('#,##0', 'ko_KR').format(amount);
String formatGoalDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

int? parseNoteAmount(String text) => tryParseKRW(text);
