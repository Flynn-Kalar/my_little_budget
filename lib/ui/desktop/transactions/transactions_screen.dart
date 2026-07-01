import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'widgets/filter_panel.dart';
import 'widgets/inline_entry.dart';
import 'widgets/month_nav.dart';
import 'widgets/summary_bar.dart';
import 'widgets/transaction_list.dart';
import 'widgets/type_filter.dart';

/// Desktop transaction screen. Data access stays inside the child widgets.
class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '내역',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('desktop-transactions-budget-button'),
                  onPressed: () => context.go('/budget'),
                  icon: const Icon(Icons.savings_outlined, size: 18),
                  label: const Text('예산'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const MonthNav(),
            const SizedBox(height: 16),
            const SummaryBar(),
            const SizedBox(height: 20),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypeFilter(),
                SizedBox(width: 8),
                Expanded(child: FilterPanel()),
              ],
            ),
            const SizedBox(height: 16),
            const InlineEntry(),
            const SizedBox(height: 8),
            const TransactionList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
