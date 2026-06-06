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

class InvestmentFilter {
  const InvestmentFilter({
    this.side,
    this.accountId,
    this.ticker,
    this.fromDate,
    this.toDate,
  });

  final String? side;
  final int? accountId;
  final String? ticker;
  final String? fromDate;
  final String? toDate;

  bool get isActive =>
      side != null ||
      accountId != null ||
      (ticker?.trim().isNotEmpty ?? false) ||
      fromDate != null ||
      toDate != null;

  InvestmentFilter copyWith({
    Object? side = _sentinel,
    Object? accountId = _sentinel,
    Object? ticker = _sentinel,
    Object? fromDate = _sentinel,
    Object? toDate = _sentinel,
  }) {
    return InvestmentFilter(
      side: side == _sentinel ? this.side : side as String?,
      accountId: accountId == _sentinel ? this.accountId : accountId as int?,
      ticker: ticker == _sentinel ? this.ticker : ticker as String?,
      fromDate: fromDate == _sentinel ? this.fromDate : fromDate as String?,
      toDate: toDate == _sentinel ? this.toDate : toDate as String?,
    );
  }
}

const _sentinel = Object();

final investmentFilterProvider = StateProvider<InvestmentFilter>(
  (ref) => const InvestmentFilter(),
);

final investmentFilterAccountsProvider =
    FutureProvider.autoDispose<List<Account>>(
      (ref) => ref.watch(accountsDaoProvider).getActiveAccounts(),
    );

final investmentRowsProvider = FutureProvider.autoDispose<List<Investment>>((
  ref,
) async {
  final month = ref.watch(investmentMonthProvider);
  final filter = ref.watch(investmentFilterProvider);
  final dao = ref.watch(investmentsDaoProvider);
  final rows = await dao.listInvestmentsByMonth(month);
  return rows.where((row) {
    if (filter.side != null && row.side != filter.side) return false;
    if (filter.accountId != null && row.accountId != filter.accountId) {
      return false;
    }
    final ticker = filter.ticker?.trim().toLowerCase();
    if (ticker != null && ticker.isNotEmpty) {
      if (!row.ticker.toLowerCase().contains(ticker)) return false;
    }
    if (filter.fromDate != null &&
        row.occurredOn.compareTo(filter.fromDate!) < 0) {
      return false;
    }
    if (filter.toDate != null && row.occurredOn.compareTo(filter.toDate!) > 0) {
      return false;
    }
    return true;
  }).toList();
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

final realizedPnlProvider = FutureProvider.autoDispose<List<RealizedPnL>>((
  ref,
) async {
  final month = ref.watch(investmentMonthProvider);
  final range = monthRange(month);
  final dao = ref.watch(investmentsDaoProvider);
  return dao.getRealizedPnL(range.start, range.end);
});

void refreshInvestments(WidgetRef ref, {int? accountId}) {
  ref.invalidate(investmentRowsProvider);
  ref.invalidate(investmentMonthlySummaryProvider);
  ref.invalidate(currentHoldingsProvider);
  ref.invalidate(investmentAccountProvider);
  ref.invalidate(realizedPnlProvider);
  ref.invalidate(accountBalancesProvider);
  if (accountId != null) {
    ref.invalidate(accountByIdProvider(accountId));
    ref.invalidate(accountTransactionsProvider(accountId));
  }
}
