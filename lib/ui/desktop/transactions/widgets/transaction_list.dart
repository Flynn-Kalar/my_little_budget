import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../color_hex.dart';
import '../providers.dart';
import 'transaction_edit_dialog.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _dateHeader(String dateKey) {
  final parts = dateKey.split('-');
  final dt = DateTime.parse('${dateKey}T00:00:00');
  return '${parts[1]}.${parts[2]} (${_weekdays[dt.weekday % 7]})';
}

class TransactionList extends ConsumerWidget {
  const TransactionList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(transactionsListProvider);
    final filter = ref.watch(searchFilterProvider);
    final type = ref.watch(typeFilterProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('불러오기 오류: $e')),
      data: (rows) => SingleChildScrollView(
        key: const ValueKey('desktop-transactions-list-scroll'),
        child: _TransactionListBody(rows: rows, filter: filter, type: type),
      ),
    );
  }
}

class _TransactionListBody extends StatelessWidget {
  const _TransactionListBody({
    required this.rows,
    required this.filter,
    required this.type,
  });

  final List<TransactionRow> rows;
  final TransactionFilter filter;
  final String? type;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      final hasSearch = filter.q?.trim().isNotEmpty ?? false;
      final hasFilter = type != null || hasActiveTransactionFilter(filter);
      final message = hasSearch
          ? '검색 결과가 없습니다.'
          : hasFilter
          ? '필터 결과가 없습니다.'
          : '이번 달엔 아직 기록이 없어요.';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: context.desktopBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(message, style: TextStyle(color: context.desktopMuted)),
      );
    }

    final groups = <String, List<TransactionRow>>{};
    final totals = <String, _DailyTotals>{};
    for (final r in rows) {
      (groups[r.occurredOn] ??= []).add(r);
      totals[r.occurredOn] = (totals[r.occurredOn] ?? const _DailyTotals()).add(
        r,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _DateHeader(
            date: entry.key,
            totals: totals[entry.key] ?? const _DailyTotals(),
          ),
          for (final row in entry.value) _Row(row: row),
        ],
      ],
    );
  }
}

class _DailyTotals {
  const _DailyTotals({this.income = 0, this.expense = 0});

  final int income;
  final int expense;

  _DailyTotals add(TransactionRow row) => switch (row.type) {
    'income' => _DailyTotals(income: income + row.amount, expense: expense),
    'expense' => _DailyTotals(income: income, expense: expense + row.amount),
    _ => this,
  };
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.totals});

  final String date;
  final _DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        key: ValueKey('desktop-transactions-date-header-$date'),
        children: [
          Expanded(
            child: Text(
              _dateHeader(date),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.desktopMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              _DailyTotalText(
                key: ValueKey('desktop-transactions-date-income-$date'),
                label: '수입',
                value: totals.income,
                color: context.desktopIncome,
              ),
              _DailyTotalText(
                key: ValueKey('desktop-transactions-date-expense-$date'),
                label: '지출',
                value: totals.expense,
                color: context.desktopExpense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyTotalText extends StatelessWidget {
  const _DailyTotalText({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${formatKRW(value)}',
      textAlign: TextAlign.end,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});
  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final isTransfer = row.type == 'transfer';
    final isIncome = row.type == 'income';
    final showTime = row.occurredTime != '00:00';

    final Widget leading;
    final String title;
    final List<String> metaParts;

    if (isTransfer) {
      leading = CircleAvatar(
        radius: 14,
        backgroundColor: context.desktopSelectedSurface,
        child: Icon(Icons.swap_horiz, size: 16, color: context.desktopMuted),
      );
      title = '이체';
      metaParts = [
        if (showTime) row.occurredTime,
        '${row.fromAccountName ?? '?'} → ${row.toAccountName ?? '?'}',
        if (row.memo != null) row.memo!,
      ];
    } else {
      leading = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorFromHex(row.categoryColor),
        ),
      );
      title = row.categoryName ?? '(카테고리 없음)';
      metaParts = [
        if (showTime) row.occurredTime,
        row.accountName ?? '(자산 없음)',
        if (row.memo != null) row.memo!,
      ];
    }

    final amountColor = isTransfer
        ? Theme.of(context).colorScheme.onSurface
        : isIncome
        ? context.desktopIncome
        : context.desktopExpense;
    final sign = isTransfer ? '' : (isIncome ? '+' : '-');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => TransactionEditDialog.show(context, row),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: context.desktopBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: 28, child: Center(child: leading)),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (row.tags.isNotEmpty) ...[
                            SizedBox(width: 8),
                            ...row.tags.map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _TagChip(name: t.name, color: t.color),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (metaParts.isNotEmpty)
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.82),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '$sign${formatKRW(row.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: amountColor,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '거래 메뉴',
                  onSelected: (value) {
                    if (value == 'edit') {
                      TransactionEditDialog.show(context, row);
                    } else if (value == 'copy') {
                      TransactionEditDialog.showDuplicate(context, row);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('수정')),
                    PopupMenuItem(value: 'copy', child: Text('복사')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.name, required this.color});
  final String name;
  final String color;

  @override
  Widget build(BuildContext context) {
    final c = colorFromHex(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('#$name', style: TextStyle(fontSize: 10, color: c)),
    );
  }
}
