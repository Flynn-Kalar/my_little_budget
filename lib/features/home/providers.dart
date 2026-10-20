import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/date.dart';
import '../../data/daos/budget_dao.dart';
import '../../data/daos/transactions_dao.dart';
import '../../data/providers.dart';

final homeMonthProvider = StateProvider<String>((ref) => currentMonthKey());

class HomeOverview {
  const HomeOverview(this.summary, this.budgets, this.recent);
  final MonthlySummary summary;
  final List<BudgetVsActual> budgets;
  final List<TransactionRow> recent;

  int get budget => budgets.fold(0, (sum, row) => sum + row.budgetAmount);
  int get spent => budgets.fold(0, (sum, row) => sum + row.spentAmount);
  int get remaining => budget - spent;
}

final homeOverviewProvider = StreamProvider.autoDispose<HomeOverview>((ref) {
  final month = ref.watch(homeMonthProvider);
  final db = ref.watch(appDatabaseProvider);
  final transactions = ref.watch(transactionsDaoProvider);
  final budget = ref.watch(budgetDaoProvider);
  // Observe writes directly, including sync, without retaining another page's
  // filtered or month-specific caches.
  final changes = Stream<void>.multi((controller) {
    final subscription = db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            db.transactions,
            db.accounts,
            db.categories,
            db.tags,
            db.transactionTags,
            db.budgetGroups,
            db.budgetGroupCategories,
            db.monthlyIncome,
          ]),
        )
        .listen((_) => controller.add(null), onError: controller.addError);
    controller.onCancel = subscription.cancel;
    controller.add(null);
  });
  return changes.asyncMap((_) async {
    final results = await Future.wait<Object>([
      transactions.monthlySummary(month),
      budget.budgetGroupVsActual(month),
      transactions.listTransactionsByMonth(month),
    ]);
    final rows = results[2] as List<TransactionRow>;
    final today = currentDateKey();
    final recent =
        rows.where((row) => row.occurredOn.compareTo(today) <= 0).toList()
          ..sort((a, b) {
            final date = b.occurredOn.compareTo(a.occurredOn);
            if (date != 0) return date;
            final time = b.occurredTime.compareTo(a.occurredTime);
            return time != 0 ? time : b.id.compareTo(a.id);
          });
    return HomeOverview(
      results[0] as MonthlySummary,
      results[1] as List<BudgetVsActual>,
      recent.take(5).toList(),
    );
  });
});
