import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/date.dart';
import '../../../data/daos/investments_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/investments/cost_basis.dart';
import '../accounts/providers.dart';

final investmentMonthProvider = StateProvider<String>(
  (ref) => currentMonthKey(),
);

final investmentRowsProvider = FutureProvider.autoDispose<List<Investment>>((
  ref,
) async {
  final month = ref.watch(investmentMonthProvider);
  final dao = ref.watch(investmentsDaoProvider);
  return dao.listInvestmentsByMonth(month);
});

final investmentMonthlySummaryProvider =
    FutureProvider.autoDispose<InvestmentSummary>((ref) async {
      final month = ref.watch(investmentMonthProvider);
      final dao = ref.watch(investmentsDaoProvider);
      return dao.investmentMonthlySummary(month);
    });

final investmentAccountProvider = FutureProvider.autoDispose<Account?>((ref) {
  final dao = ref.watch(investmentsDaoProvider);
  return dao.getInvestmentAccount();
});

final currentHoldingsProvider =
    FutureProvider.autoDispose<List<CurrentHolding>>((ref) {
      final dao = ref.watch(investmentsDaoProvider);
      return dao.listCurrentHoldings();
    });

void refreshInvestments(WidgetRef ref, {int? accountId}) {
  ref.invalidate(investmentRowsProvider);
  ref.invalidate(investmentMonthlySummaryProvider);
  ref.invalidate(currentHoldingsProvider);
  ref.invalidate(investmentAccountProvider);
  ref.invalidate(accountBalancesProvider);
  if (accountId != null) {
    ref.invalidate(accountByIdProvider(accountId));
    ref.invalidate(accountTransactionsProvider(accountId));
  }
}
