import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:my_little_budget/features/transactions/providers.dart';

class SummaryBar extends ConsumerWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider).asData?.value;
    final income = summary?.income ?? 0;
    final expense = summary?.expense ?? 0;
    final net = income - expense;

    return Container(
      key: const ValueKey('desktop-transactions-summary-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _Cell(label: '수입', value: income, color: context.desktopIncome),
          _Cell(
            label: '지출',
            value: expense,
            color: context.desktopExpense,
            prefix: expense > 0 ? '-' : '',
          ),
          _Cell(
            label: '순수입',
            value: net,
            color: net > 0
                ? context.desktopAccent
                : net < 0
                ? context.desktopExpense
                : Theme.of(context).colorScheme.onSurface,
            prefix: net > 0 ? '+' : '',
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.color,
    this.prefix = '',
  });
  final String label;
  final int value;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: context.desktopMuted),
          ),
          SizedBox(height: 3),
          Text(
            '$prefix${formatKRW(value)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
