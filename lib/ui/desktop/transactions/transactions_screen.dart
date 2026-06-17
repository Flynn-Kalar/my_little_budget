import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          children: const [
            Text(
              '내역',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            MonthNav(),
            SizedBox(height: 16),
            SummaryBar(),
            SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TypeFilter(),
                SizedBox(width: 8),
                Expanded(child: FilterPanel()),
              ],
            ),
            SizedBox(height: 16),
            InlineEntry(),
            SizedBox(height: 8),
            TransactionList(),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
