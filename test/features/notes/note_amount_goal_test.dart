import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/ui/shared/note_amount_goal.dart';

void main() {
  test('calculates the requested amounts and clamps completion', () {
    final goal = NoteAmountGoal(
      targetAmount: 2681630,
      currentAmount: 1400000,
      startDate: DateTime(2026, 10, 2),
    );
    expect(goal.percentage, '52.2%');
    expect(goal.remaining, 1281630);
    expect(formatNoteAmount(goal.targetAmount), '2,681,630');
    final complete = NoteAmountGoal(
      targetAmount: 100,
      currentAmount: 200,
      startDate: DateTime(2026, 10, 2),
    );
    expect(complete.progress, 1);
    expect(complete.remaining, 0);
  });

  test('adds custom and quick amounts and rejects invalid input', () {
    final draft = NoteGoalDraft(null)..enabled = true;
    addTearDown(draft.dispose);
    draft.target.text = '2,681,630';
    draft.current.text = '1,000,000';
    draft.addAmount(parseNoteAmount('400,000'));
    expect(draft.current.text, '1,400,000');
    expect(draft.goal!.percentage, '52.2%');
    draft.addAmount(100000);
    draft.addAmount(200000);
    expect(draft.current.text, '1,700,000');
    for (final value in [null, -10, 0, maxNoteGoalAmount]) {
      draft.addAmount(value);
      expect(draft.current.text, '1,700,000');
      expect(draft.additionError, isNotNull);
    }
    draft.target.text = '0';
    expect(draft.validationError, isNotNull);
    draft.target.text = '10';
    draft.current.text = '-1';
    expect(draft.validationError, isNotNull);
    draft.current.text = '0';
    draft.due = draft.start.subtract(const Duration(days: 1));
    expect(draft.validationError, isNotNull);
    expect(parseNoteAmount('12.5'), isNull);
    expect(parseNoteAmount('oops'), isNull);
  });
}
