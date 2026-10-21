import 'package:intl/intl.dart';

import '../../data/database.dart';

const maxNoteGoalAmount = 999999999999999;

class NoteAmountGoal {
  const NoteAmountGoal({
    required this.targetAmount,
    required this.currentAmount,
    required this.startDate,
    this.dueDate,
  });

  final int targetAmount;
  final int currentAmount;
  final DateTime startDate;
  final DateTime? dueDate;

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

int? parseNoteAmount(String text) {
  final normalized = text.trim().replaceAll(',', '');
  if (!RegExp(r'^[+-]?\d+$').hasMatch(normalized)) return null;
  return int.tryParse(normalized);
}
