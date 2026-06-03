import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/budget_dao.dart';
import '../../../data/providers.dart';
import '../shell/badges_providers.dart';

final budgetMonthProvider = StateProvider<String>((ref) => currentMonthKey());

final monthlyExpectedIncomeProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final month = ref.watch(budgetMonthProvider);
  final dao = ref.watch(budgetDaoProvider);
  return dao.getMonthlyExpectedIncome(month);
});

final budgetRowsProvider = FutureProvider.autoDispose<List<BudgetVsActual>>((
  ref,
) async {
  final month = ref.watch(budgetMonthProvider);
  final dao = ref.watch(budgetDaoProvider);
  return dao.budgetGroupVsActual(month);
});

void refreshBudget(WidgetRef ref) {
  ref.invalidate(monthlyExpectedIncomeProvider);
  ref.invalidate(budgetRowsProvider);
  ref.invalidate(overBudgetCountProvider);
}
