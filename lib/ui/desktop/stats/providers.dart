import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/providers.dart';

final statsMonthProvider = StateProvider<String>((ref) => currentMonthKey());

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
