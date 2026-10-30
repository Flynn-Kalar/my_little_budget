import 'package:flutter/material.dart';
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
    for (final value in [null, 0, maxNoteGoalAmount]) {
      draft.addAmount(value);
      expect(draft.current.text, '1,700,000');
      expect(draft.additionError, isNotNull);
    }
    draft.target.text = '0';
    expect(draft.validationError, isNotNull);
    draft.target.text = '10';
    draft.current.text = '-1';
    expect(draft.validationError, isNull);
    draft.current.text = '0';
    draft.due = draft.start.subtract(const Duration(days: 1));
    expect(draft.validationError, isNotNull);
    expect(parseNoteAmount('12.5'), 13);
    expect(parseNoteAmount('oops'), isNull);
  });

  test(
    'signed amounts subtract through zero and enforce both range limits',
    () {
      final draft = NoteGoalDraft(null)..enabled = true;
      addTearDown(draft.dispose);
      draft.target.text = '3,000,000';
      draft.current.text = '1,200,000';
      draft.addition.text = '-24500';
      draft.addAmount(parseNoteAmount(draft.addition.text));
      expect(draft.current.text, '1,175,500');
      expect(draft.addition.text, isEmpty);
      expect(draft.additionError, isNull);
      draft.addAmount(-1200000);
      expect(draft.current.text, '-24,500');
      expect(draft.validationError, isNull);
      expect(draft.goal!.progress, 0);
      expect(draft.goal!.remaining, 3024500);
      for (final sign in [-1, 1]) {
        draft.current.text = '${sign * maxNoteGoalAmount}';
        draft.addAmount(sign);
        expect(draft.additionError, isNotNull);
        expect(parseNoteAmount(draft.current.text), sign * maxNoteGoalAmount);
        draft.addAmount(-sign);
        expect(draft.additionError, isNull);
      }
      draft.current.text = '1,200,000-24500';
      expect(draft.validationError, isNull);
      draft.addAmount(-10);
      expect(draft.additionError, isNull);
      expect(draft.current.text, '1,175,490');
      expect(parseNoteAmount('-24,500'), -24500);
      expect(parseNoteAmount('+24,500'), 24500);
      expect(parseNoteAmount('-*24500'), isNull);
      expect(parseNoteAmount('-'), isNull);
    },
  );

  test('negative targets progress toward the negative amount', () {
    for (final current in [100, 0, -50, -100, -150]) {
      final goal = NoteAmountGoal(
        targetAmount: -100,
        currentAmount: current,
        startDate: DateTime(2026),
      );
      expect(goal.validationError, isNull);
      expect(goal.progress, (current / -100).clamp(0.0, 1.0));
      expect(goal.remaining, current < -100 ? 0 : current + 100);
    }
    final goal = NoteAmountGoal(
      targetAmount: maxNoteGoalAmount,
      currentAmount: -maxNoteGoalAmount,
      startDate: DateTime(2026),
    );
    expect(goal.validationError, isNull);
    expect(goal.remaining, 2 * maxNoteGoalAmount);
  });

  test(
    'goal amounts evaluate all operators and reject invalid expressions',
    () {
      expect(parseNoteAmount('1,175,500-20000'), 1155500);
      expect(parseNoteAmount('(1,000+2,000)×3÷2'), 4500);
      expect(parseNoteAmount('-500+200*2'), -100);
      expect(parseNoteAmount('1000/3'), 333);
      expect(parseNoteAmount('1000-1000'), 0);
      for (final input in ['', '1+', '10/0', '(10+2', '1e10', 'text']) {
        expect(parseNoteAmount(input), isNull, reason: input);
      }
      final draft = NoteGoalDraft(null)..enabled = true;
      addTearDown(draft.dispose);
      draft.target.text = '1500000*2';
      draft.current.text = '1,175,500-20000';
      expect(draft.validationError, isNull);
      expect(draft.goal!.targetAmount, 3000000);
      expect(draft.goal!.currentAmount, 1155500);
      draft.addAmount(parseNoteAmount('20000/2'));
      expect(draft.current.text, '1,165,500');
      draft.target.text = '$maxNoteGoalAmount+1';
      expect(draft.validationError, isNotNull);
      draft.target.text = '10/0';
      expect(draft.validationError, isNotNull);
    },
  );

  testWidgets('goal form accepts a deduction and offers operator entry', (
    tester,
  ) async {
    final draft = NoteGoalDraft(null)..enabled = true;
    draft.target.text = '3,000,000';
    draft.current.text = '1,200,000';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NoteGoalForm(draft: draft)),
        ),
      ),
    );
    final fields = find.byType(TextField);
    for (final field in tester.widgetList<TextField>(fields)) {
      expect(field.keyboardType, TextInputType.text);
    }
    await tester.enterText(fields.at(2), '-49,000/2');
    await tester.tap(find.text('금액 추가'));
    await tester.pumpAndSettle();
    expect(draft.current.text, '1,175,500');
    expect(draft.validationError, isNull);
    expect(find.textContaining('1,175,500 / 3,000,000원'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    draft.dispose();
  });
}
