import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/providers.dart';

final statsMonthProvider = StateProvider<String>((ref) => currentMonthKey());
final statsYearProvider = StateProvider<int>((ref) => DateTime.now().year);

final statsExpenseBreakdownProvider =
    FutureProvider.autoDispose<List<CategoryBreakdownRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.expenseByCategory(month);
    });

final statsMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final month = ref.watch(statsMonthProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.monthlyTrend(12, month);
    });

final availableStatsYearsProvider = FutureProvider.autoDispose<List<int>>((
  ref,
) {
  final dao = ref.watch(transactionsDaoProvider);
  return dao.availableTransactionYears();
});

final yearlyMonthlyTrendProvider =
    FutureProvider.autoDispose<List<MonthlyTrendRow>>((ref) async {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.monthlyTrend(12, '$year-12');
    });

final yearlyExpenseByCategoryProvider =
    FutureProvider.autoDispose<List<YearlyPivotRow>>((ref) {
      final year = ref.watch(statsYearProvider);
      final dao = ref.watch(transactionsDaoProvider);
      return dao.yearlyCategoryPivot(year, 'expense');
    });
