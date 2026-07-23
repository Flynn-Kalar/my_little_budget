import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/providers.dart';
import '../../color_hex.dart';
import '../../settings/widgets/transaction_preset_dialog.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'transaction_edit_dialog.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];
const _listMaxWidth = 1040.0;
const _secondaryColumnWidth = 150.0;
const _amountColumnWidth = 118.0;
const _menuColumnWidth = 40.0;

String _dateHeader(String dateKey) {
  final parts = dateKey.split('-');
  final dt = DateTime.parse('${dateKey}T00:00:00');
  return '${parts[1]}.${parts[2]} ${_weekdays[dt.weekday % 7]}요일';
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
        child: _ConstrainedTransactionList(
          child: _TransactionListBody(rows: rows, filter: filter, type: type),
        ),
      ),
    );
  }
}

class _ConstrainedTransactionList extends StatelessWidget {
  const _ConstrainedTransactionList({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _listMaxWidth
            ? constraints.maxWidth
            : _listMaxWidth;
        return Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: const ValueKey('desktop-transactions-list-width'),
            width: width,
            child: child,
          ),
        );
      },
    );
  }
}

class _TransactionListBody extends StatefulWidget {
  const _TransactionListBody({
    required this.rows,
    required this.filter,
    required this.type,
  });

  final List<TransactionRow> rows;
  final TransactionFilter filter;
  final String? type;

  @override
  State<_TransactionListBody> createState() => _TransactionListBodyState();
}

class _TransactionListBodyState extends State<_TransactionListBody> {
  bool _plannedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final rows = widget.rows;
    final filter = widget.filter;
    final type = widget.type;
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

    final today = currentDateKey();
    final futureRows = rows.where((row) => row.occurredOn.compareTo(today) > 0);
    final completedRows = rows.where(
      (row) => row.occurredOn.compareTo(today) <= 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (futureRows.isNotEmpty)
          _Section(
            title: '예정 거래',
            rows: futureRows.toList(),
            planned: true,
            collapsible: true,
            expanded: _plannedExpanded,
            onToggle: () =>
                setState(() => _plannedExpanded = !_plannedExpanded),
          ),
        if (futureRows.isNotEmpty && completedRows.isNotEmpty)
          const SizedBox(height: 10),
        if (completedRows.isNotEmpty)
          _Section(title: '완료 거래', rows: completedRows.toList())
        else if (futureRows.isEmpty)
          const SizedBox.shrink(),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.rows,
    this.planned = false,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final List<TransactionRow> rows;
  final bool planned;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TransactionRow>>{};
    final totals = <String, _DailyTotals>{};
    var sectionTotals = const _DailyTotals();
    for (final r in rows) {
      (groups[r.occurredOn] ??= []).add(r);
      totals[r.occurredOn] = (totals[r.occurredOn] ?? const _DailyTotals()).add(
        r,
      );
      sectionTotals = sectionTotals.add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          count: rows.length,
          planned: planned,
          totals: sectionTotals,
          collapsible: collapsible,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          for (final entry in groups.entries) ...[
            _DateHeader(
              date: entry.key,
              totals: totals[entry.key] ?? const _DailyTotals(),
              planned: planned,
            ),
            for (final row in entry.value) _Row(row: row, planned: planned),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.planned,
    required this.totals,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final int count;
  final bool planned;
  final _DailyTotals totals;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Row(
        children: [
          if (collapsible) ...[
            Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 18,
              color: planned ? context.desktopWarning : context.desktopMuted,
            ),
            const SizedBox(width: 2),
          ] else
            Icon(
              planned ? Icons.schedule_outlined : Icons.check_circle_outline,
              size: 16,
              color: planned ? context.desktopWarning : context.desktopMuted,
            ),
          const SizedBox(width: 6),
          Text(
            '$title $count건',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: planned ? context.desktopWarning : context.desktopMuted,
            ),
          ),
          const Spacer(),
          _SectionSummaryText(totals: totals),
        ],
      ),
    );
    if (!collapsible) return content;
    return InkWell(
      key: const ValueKey('desktop-transactions-planned-toggle'),
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}

class _SectionSummaryText extends StatelessWidget {
  const _SectionSummaryText({required this.totals});

  final _DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (totals.income > 0) '수입 ${formatKRW(totals.income)}',
      if (totals.expense > 0) '지출 ${formatKRW(totals.expense)}',
      if (totals.transferCount > 0)
        '이체 ${totals.transferCount}건 · ${formatKRW(totals.transferAmount)}',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' · '),
      textAlign: TextAlign.end,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: context.desktopMuted,
      ),
    );
  }
}

class _DailyTotals {
  const _DailyTotals({
    this.income = 0,
    this.expense = 0,
    this.transferAmount = 0,
    this.transferCount = 0,
  });

  final int income;
  final int expense;
  final int transferAmount;
  final int transferCount;

  _DailyTotals add(TransactionRow row) => switch (row.type) {
    'income' => _DailyTotals(
      income: income + row.amount,
      expense: expense,
      transferAmount: transferAmount,
      transferCount: transferCount,
    ),
    'expense' => _DailyTotals(
      income: income,
      expense: expense + row.amount,
      transferAmount: transferAmount,
      transferCount: transferCount,
    ),
    'transfer' => _DailyTotals(
      income: income,
      expense: expense,
      transferAmount: transferAmount + row.amount,
      transferCount: transferCount + 1,
    ),
    _ => this,
  };
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.totals,
    required this.planned,
  });

  final String date;
  final _DailyTotals totals;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        key: ValueKey('desktop-transactions-date-header-$date'),
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  _dateHeader(date),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (planned) ...[
                  const SizedBox(width: 6),
                  _PlannedBadge(compact: true),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (totals.income > 0)
                _DailyTotalText(
                  key: ValueKey('desktop-transactions-date-income-$date'),
                  label: '수입',
                  value: totals.income,
                  color: context.desktopIncome,
                ),
              if (totals.expense > 0)
                _DailyTotalText(
                  key: ValueKey('desktop-transactions-date-expense-$date'),
                  label: '지출',
                  value: totals.expense,
                  color: context.desktopExpense,
                ),
              if (totals.transferCount > 0)
                _TransferTotalText(
                  key: ValueKey('desktop-transactions-date-transfer-$date'),
                  count: totals.transferCount,
                  value: totals.transferAmount,
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

class _TransferTotalText extends StatelessWidget {
  const _TransferTotalText({
    super.key,
    required this.count,
    required this.value,
  });

  final int count;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '이체 $count건 · ${formatKRW(value)}',
      textAlign: TextAlign.end,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: context.desktopMuted,
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.row, required this.planned});
  final TransactionRow row;
  final bool planned;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('이 거래를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.desktopExpense,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(transactionsDaoProvider).deleteTransaction(row.id);
    refreshTransactions(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('거래를 삭제했습니다.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = row.type == 'transfer';
    final isIncome = row.type == 'income';
    final showTime = row.occurredTime != '00:00';

    final Widget leading;
    final String title;
    final List<String> metaParts;
    final String secondary;

    if (isTransfer) {
      leading = CircleAvatar(
        radius: 14,
        backgroundColor: context.desktopSelectedSurface,
        child: Icon(Icons.swap_horiz, size: 16, color: context.desktopMuted),
      );
      title = '${row.fromAccountName ?? '?'} → ${row.toAccountName ?? '?'}';
      metaParts = [if (showTime) row.occurredTime];
      secondary = '이체';
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
      metaParts = [if (showTime) row.occurredTime];
      secondary = row.accountName ?? '(자산 없음)';
    }

    final amountColor = isTransfer
        ? Theme.of(context).colorScheme.onSurface
        : isIncome
        ? context.desktopIncome
        : context.desktopExpense;
    final sign = isTransfer ? '' : (isIncome ? '+' : '-');

    final visibleTags = row.tags.take(2).toList();
    final hiddenTagCount = row.tags.length - visibleTags.length;
    final memo = row.memo?.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => TransactionEditDialog.show(context, row),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: context.desktopBorder.withValues(alpha: 0.72),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: 28, child: Center(child: leading)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (planned) ...[
                            const _PlannedBadge(),
                            const SizedBox(width: 6),
                          ],
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
                      if (memo != null && memo.isNotEmpty)
                        Text(
                          memo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.desktopMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: _secondaryColumnWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.76),
                        ),
                      ),
                      if (visibleTags.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: [
                            ...visibleTags.map(
                              (t) => _TagChip(name: t.name, color: t.color),
                            ),
                            if (hiddenTagCount > 0)
                              _MoreTagChip(count: hiddenTagCount),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: _amountColumnWidth,
                  child: Text(
                    '$sign${formatKRW(row.amount)}',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: amountColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: _menuColumnWidth,
                  child: PopupMenuButton<String>(
                    tooltip: '거래 메뉴',
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') {
                        TransactionEditDialog.show(context, row);
                      } else if (value == 'copy') {
                        TransactionEditDialog.showDuplicate(context, row);
                      } else if (value == 'preset') {
                        TransactionPresetDialog.show(context, source: row);
                      } else if (value == 'delete') {
                        _confirmAndDelete(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('수정')),
                      const PopupMenuItem(value: 'copy', child: Text('복사')),
                      const PopupMenuItem(
                        value: 'preset',
                        child: Text('프리셋으로 저장'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          '삭제',
                          style: TextStyle(color: context.desktopExpense),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlannedBadge extends StatelessWidget {
  const _PlannedBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 7,
          vertical: compact ? 1 : 2,
        ),
        child: Text(
          '예정',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w800,
            color: context.desktopWarning,
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

class _MoreTagChip extends StatelessWidget {
  const _MoreTagChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '+$count',
        style: TextStyle(fontSize: 10, color: context.desktopMuted),
      ),
    );
  }
}
