import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../features/home/providers.dart';
import '../../../features/budget/providers.dart';
import '../../../features/transactions/providers.dart';
import '../../shared/overview_widgets.dart';
import '../mobile_widgets.dart';
import '../transactions/sheets/mobile_transaction_sheet.dart';

class MobileHomeScreen extends ConsumerWidget {
  const MobileHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(homeMonthProvider);
    return MobilePageScaffold(
      title: '이번 달 가계부',
      onAdd: () => MobileTransactionSheet.show(context),
      addTooltip: '거래 추가',
      children: [
        Text('차근차근 모으는 나의 일상', style: TextStyle(color: context.desktopMuted)),
        const SizedBox(height: 16),
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(homeMonthProvider.notifier).state = value,
        ),
        MobileAsync(
          value: ref.watch(homeOverviewProvider),
          builder: (overview) => Column(
            children: [
              BudgetOverviewCard(
                overview: overview,
                onBudget: () {
                  ref.read(budgetMonthProvider.notifier).state = month;
                  context.push('/budget');
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OverviewAmountCard(
                      label: '수입',
                      amount: overview.summary.income,
                      color: context.appIncome,
                      icon: Icons.south,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OverviewAmountCard(
                      label: '지출',
                      amount: overview.summary.expense,
                      color: context.appExpense,
                      icon: Icons.north,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              RecentOverviewCard(
                rows: overview.recent,
                onAll: () {
                  ref.read(selectedMonthProvider.notifier).state = month;
                  ref.read(typeFilterProvider.notifier).state = null;
                  ref.read(searchFilterProvider.notifier).state =
                      const TransactionFilter();
                  context.go('/transactions');
                },
                onEdit: (row) => MobileTransactionSheet.show(context, row: row),
              ),
            ],
          ),
        ),
        const SizedBox(height: 64),
      ],
    );
  }
}
