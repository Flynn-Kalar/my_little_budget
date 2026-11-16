import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/budget_dao.dart';
import '../../data/providers.dart';
import '../settings/statement_period.dart';
import '../transactions/validation.dart';
import 'daily_allowance.dart';

typedef EntryBudgetKey = ({String month, int? editingId});

final entryBudgetRowsProvider = StreamProvider.autoDispose
    .family<List<BudgetVsActual>, EntryBudgetKey>((ref, key) async* {
      final dao = ref.watch(budgetDaoProvider);
      final policy = await ref.watch(statementPeriodProvider.future);
      yield* dao.watchEntryBudgetRows(
        key.month,
        period: policy.range(key.month),
        excludingTransactionId: key.editingId,
      );
    });

bool entryAffectsBudget(BudgetVsActual row, TransactionDraft draft) =>
    draft.type == 'expense' &&
    (row.accountId != null
        ? row.accountId == draft.accountId
        : row.categories.any((c) => c.id == draft.categoryId));

class EntryBudgetPreview {
  const EntryBudgetPreview(this.row, this.amount, this.allowance);
  final BudgetVsActual row;
  final int amount;
  final DailyAllowance? allowance;
  int get before => row.budgetAmount - row.spentAmount;
  int get remaining => before - amount;
}

List<EntryBudgetPreview> previewEntryBudgets({
  required List<BudgetVsActual> rows,
  required TransactionDraft draft,
  required StatementPeriod policy,
  required DateTime today,
}) {
  if (draft.type != 'expense' || draft.amount <= 0) return const [];
  final month = policy.anchorForDate(DateTime.parse(draft.occurredOn));
  return [
    for (final row in rows)
      if (entryAffectsBudget(row, draft))
        EntryBudgetPreview(
          row,
          draft.amount,
          dailyAllowance(
            month: month,
            budget: row.budgetAmount,
            spent: row.spentAmount + draft.amount,
            now: today,
            period: policy.range(month),
          ),
        ),
  ];
}
