import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/goal_progress_store.dart';
import '../../data/providers.dart';
import '../notes/note_amount_goal.dart';
import '../settings/statement_period.dart';
import 'progress.dart';

final goalProgressProvider = StreamProvider.autoDispose
    .family<LinkedGoalProgress, NoteAmountGoal>((ref, goal) {
      final db = ref.watch(appDatabaseProvider);
      final today = ref.watch(statementTodayProvider);
      return GoalProgressStore(db).watch(goal, today);
    });

final goalAccountsProvider = StreamProvider.autoDispose<List<Account>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.accounts)..where((a) => a.deletedAt.isNull())).watch();
});

final goalTagsProvider = StreamProvider.autoDispose<List<Tag>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.tags)..where((t) => t.deletedAt.isNull())).watch();
});
