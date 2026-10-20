import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import '../../../shared/overview_widgets.dart';

class SummaryBar extends ConsumerWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider).asData?.value;
    final income = summary?.income ?? 0;
    final expense = summary?.expense ?? 0;
    final net = income - expense;

    return Row(
      key: const ValueKey('desktop-transactions-summary-bar'),
      children: [
        Expanded(
          child: OverviewAmountCard(
            label: '수입',
            amount: income,
            color: context.desktopIncome,
            icon: Icons.south,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OverviewAmountCard(
            label: '지출',
            amount: expense,
            color: context.desktopExpense,
            icon: Icons.north,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OverviewAmountCard(
            label: '순수입',
            amount: net,
            color: net < 0 ? context.desktopExpense : context.desktopAccent,
            icon: Icons.bar_chart,
          ),
        ),
      ],
    );
  }
}
