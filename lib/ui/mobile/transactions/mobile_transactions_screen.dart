import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:my_little_budget/features/transactions/providers.dart';

import '../mobile_widgets.dart';
import 'sheets/mobile_transaction_advanced_filter_sheet.dart';
import 'sheets/mobile_transaction_sheet.dart';
import 'widgets/mobile_transaction_list.dart';
import 'widgets/mobile_transaction_search_filter_bar.dart';
import 'widgets/mobile_transaction_summary.dart';

class MobileTransactionsScreen extends ConsumerWidget {
  const MobileTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final rows = ref.watch(transactionsListProvider);

    return MobilePageScaffold(
      title: '내역',
      actions: [
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-transactions-budget-button'),
          onPressed: () {
            context.push('/budget');
          },
          icon: const Icon(Icons.savings_outlined, size: 18),
          label: const Text('예산'),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-transactions-investments-button'),
          onPressed: () {
            context.push('/investments');
          },
          icon: const Icon(Icons.trending_up, size: 18),
          label: const Text('투자'),
        ),
      ],
      onAdd: () => MobileTransactionSheet.show(context),
      addTooltip: '거래 추가',
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(selectedMonthProvider.notifier).state = value,
        ),
        MobileTransactionSearchFilterBar(
          onOpenAdvancedFilter: () =>
              MobileTransactionAdvancedFilterSheet.show(context),
        ),
        MobileAsync(
          value: summary,
          builder: (value) => MobileTransactionSummary(summary: value),
        ),
        MobileAsync(
          value: rows,
          builder: (value) {
            if (value.isEmpty) return const EmptyMobileCard('표시할 내역이 없습니다.');
            return MobileGroupedTransactions(
              rows: value,
              onEdit: (row) => MobileTransactionSheet.show(context, row: row),
              onDuplicate: (row) =>
                  MobileTransactionSheet.showDuplicate(context, row),
            );
          },
        ),
      ],
    );
  }
}
