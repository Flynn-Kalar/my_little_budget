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
class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  bool _isHeaderCollapsed = false;
  bool _isFilterExpanded = false;
  final _filterPanelKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isHeaderCollapsed) ...[
            const Text(
              '내역',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              const Expanded(child: MonthNav()),
              FilledButton.tonalIcon(
                key: const ValueKey('desktop-transactions-budget-button'),
                onPressed: () => context.go('/budget'),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('예산'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                key: const ValueKey('desktop-transactions-investments-button'),
                onPressed: () => context.go('/investments'),
                icon: const Icon(Icons.trending_up, size: 18),
                label: const Text('투자'),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const ValueKey('desktop-transactions-collapse-button'),
                tooltip: _isHeaderCollapsed ? '상단 펼치기' : '상단 접기',
                onPressed: () =>
                    setState(() => _isHeaderCollapsed = !_isHeaderCollapsed),
                icon: Icon(
                  _isHeaderCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                ),
              ),
            ],
          ),
          if (!_isHeaderCollapsed) ...[
            const SizedBox(height: 16),
            const SummaryBar(),
            const SizedBox(height: 20),
            Row(
              key: const ValueKey('desktop-transactions-filter-row'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TypeFilter(),
                if (!_isFilterExpanded) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _buildFilterPanel()),
                ],
              ],
            ),
            if (_isFilterExpanded) ...[
              const SizedBox(height: 14),
              SizedBox(
                key: const ValueKey('desktop-transactions-expanded-filter'),
                width: double.infinity,
                child: _buildFilterPanel(),
              ),
            ],
            const SizedBox(height: 16),
            const InlineEntry(),
          ],
          const SizedBox(height: 8),
          const Expanded(child: TransactionList()),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return FilterPanel(
      key: _filterPanelKey,
      onExpandedChanged: (expanded) {
        if (_isFilterExpanded == expanded) return;
        setState(() => _isFilterExpanded = expanded);
      },
    );
  }
}
