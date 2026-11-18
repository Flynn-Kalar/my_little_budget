import '../notes/note_amount_goal.dart';

class LinkedGoalProgress {
  const LinkedGoalProgress({
    required this.goal,
    this.monthStartAmount,
    this.accountName,
    this.tagName,
    this.fundPurpose = 'living',
    this.archived = false,
    this.issue,
  });
  final NoteAmountGoal goal;
  final int? monthStartAmount;
  final String? accountName;
  final String? tagName;
  final String fundPurpose;
  final bool archived;
  final String? issue;
}
