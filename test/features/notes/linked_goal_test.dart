import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';

void main() {
  final today = DateTime(2026, 11, 18);
  NoteAmountGoal goal(int current, {int target = 1200000, DateTime? due}) =>
      NoteAmountGoal(
        targetAmount: target,
        currentAmount: current,
        startDate: DateTime(2026, 10),
        dueDate: due ?? DateTime(2027, 1, 31),
        source: 'account',
        accountUuid: 'reserve',
      );

  test(
    'monthly quota subtracts net contributions and replenishes withdrawals',
    () {
      // Three months left, 900,000 shortage at month start: 300,000 quota.
      expect(
        goal(400000).monthlyNeeded(today, monthStartAmount: 300000),
        200000,
      );
      expect(goal(700000).monthlyNeeded(today, monthStartAmount: 300000), 0);
      expect(
        goal(200000).monthlyNeeded(today, monthStartAmount: 300000),
        400000,
      );
      expect(goal(1200000).monthlyNeeded(today, monthStartAmount: 300000), 0);
      expect(
        goal(0, target: 100).monthlyNeeded(today, monthStartAmount: 0),
        34,
      );
      // A withdrawal after an already-funded goal is replenished in full.
      expect(
        goal(1100000).monthlyNeeded(today, monthStartAmount: 1300000),
        100000,
      );
    },
  );

  test('due month and overdue need the remaining amount', () {
    for (final due in [
      DateTime(2026, 11, 30),
      DateTime(2026, 11, 1),
      DateTime(2026, 10, 31),
    ]) {
      expect(
        goal(400000, due: due).monthlyNeeded(today, monthStartAmount: 300000),
        800000,
      );
    }
  });

  test('manual, negative, undated and future goals remain meaningful', () {
    final manual = NoteAmountGoal(
      targetAmount: -1000,
      currentAmount: -400,
      startDate: DateTime(2026),
      dueDate: DateTime(2027, 1),
    );
    expect(manual.monthlyNeeded(today), 200);
    expect(manual.monthlyNeeded(today, monthStartAmount: -100), 0);
    final noDate = NoteAmountGoal(
      targetAmount: 1000,
      currentAmount: 400,
      startDate: today,
    );
    expect(noDate.monthlyNeeded(today), isNull);
    expect(noDate.withCurrentAmount(1000).monthlyNeeded(today), 0);
    final future = NoteAmountGoal(
      targetAmount: 1000,
      currentAmount: 0,
      startDate: DateTime(2026, 12),
      dueDate: DateTime(2027, 1),
    );
    expect(future.monthlyNeeded(today), 0);
  });

  test('goal links survive JSON and older blocks remain manual', () {
    final original = NoteAmountGoal(
      targetAmount: 1000000,
      currentAmount: 100000,
      startDate: today,
      dueDate: DateTime(2027),
      source: 'transactions',
      accountUuid: 'bank-uuid',
      tagUuid: 'tag-uuid',
    );
    final block = newNoteGoalBlock('연간 보험료', original);
    expect(NoteGoalBlock.decode(block.encode())!.goal, original);
    expect(block.plainText, contains('자동 집계 목표'));
    expect(block.plainText, isNot(contains('100,000 /')));
    final old = jsonDecode(block.encode()) as Map<String, dynamic>;
    old.removeWhere(
      (key, _) => ['source', 'accountUuid', 'tagUuid'].contains(key),
    );
    expect(NoteGoalBlock.decode(jsonEncode(old))!.goal.source, 'manual');
    expect(
      NoteAmountGoal(
        targetAmount: 1,
        currentAmount: 0,
        startDate: today,
        source: 'account',
      ).validationError,
      contains('계좌'),
    );
    expect(goal(0, target: -1).validationError, isNotNull);
  });
}
