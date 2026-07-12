import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/providers.dart';
import '../../../../features/transactions/providers.dart';
import '../../mobile_widgets.dart';

class MobileGroupedTransactions extends StatefulWidget {
  const MobileGroupedTransactions({
    super.key,
    required this.rows,
    required this.onEdit,
    required this.onDuplicate,
  });

  final List<TransactionRow> rows;
  final ValueChanged<TransactionRow> onEdit;
  final ValueChanged<TransactionRow> onDuplicate;

  @override
  State<MobileGroupedTransactions> createState() =>
      _MobileGroupedTransactionsState();
}

class _MobileGroupedTransactionsState extends State<MobileGroupedTransactions> {
  bool _plannedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final today = currentDateKey();
    final planned = widget.rows
        .where((row) => row.occurredOn.compareTo(today) > 0)
        .toList();
    final completed = widget.rows
        .where((row) => row.occurredOn.compareTo(today) <= 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (planned.isNotEmpty)
          _TransactionSection(
            title: '예정 거래',
            rows: planned,
            planned: true,
            collapsible: true,
            expanded: _plannedExpanded,
            onToggle: () =>
                setState(() => _plannedExpanded = !_plannedExpanded),
            onEdit: widget.onEdit,
            onDuplicate: widget.onDuplicate,
          ),
        if (planned.isNotEmpty && completed.isNotEmpty)
          const SizedBox(height: 6),
        if (completed.isNotEmpty)
          _TransactionSection(
            title: '완료 거래',
            rows: completed,
            onEdit: widget.onEdit,
            onDuplicate: widget.onDuplicate,
          ),
      ],
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

class _TransactionSection extends StatelessWidget {
  const _TransactionSection({
    required this.title,
    required this.rows,
    required this.onEdit,
    required this.onDuplicate,
    this.planned = false,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final List<TransactionRow> rows;
  final ValueChanged<TransactionRow> onEdit;
  final ValueChanged<TransactionRow> onDuplicate;
  final bool planned;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TransactionRow>>{};
    final totals = <String, _DailyTotals>{};
    var sectionTotals = const _DailyTotals();
    for (final row in rows) {
      (groups[row.occurredOn] ??= []).add(row);
      totals[row.occurredOn] = (totals[row.occurredOn] ?? const _DailyTotals())
          .add(row);
      sectionTotals = sectionTotals.add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: title,
          count: rows.length,
          totals: sectionTotals,
          planned: planned,
          collapsible: collapsible,
          expanded: expanded,
          onToggle: onToggle,
        ),
        if (expanded)
          for (final entry in groups.entries) ...[
            _DateHeader(
              date: entry.key,
              totals: totals[entry.key] ?? const _DailyTotals(),
            ),
            for (final row in entry.value)
              _TransactionCard(
                row: row,
                planned: planned,
                onEdit: onEdit,
                onDuplicate: onDuplicate,
              ),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.totals,
    required this.planned,
    this.collapsible = false,
    this.expanded = true,
    this.onToggle,
  });

  final String title;
  final int count;
  final _DailyTotals totals;
  final bool planned;
  final bool collapsible;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final color = planned ? context.appWarning : _metaColor(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          Icon(
            collapsible
                ? (expanded ? Icons.expand_more : Icons.chevron_right)
                : (planned
                      ? Icons.schedule_outlined
                      : Icons.check_circle_outline),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$title $count건',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const Spacer(),
          Flexible(child: _TotalsSummaryText(totals: totals)),
        ],
      ),
    );
    if (!collapsible) return content;
    return InkWell(
      key: const ValueKey('mobile-transactions-planned-toggle'),
      onTap: onToggle,
      borderRadius: BorderRadius.circular(6),
      child: content,
    );
  }
}

class _TotalsSummaryText extends StatelessWidget {
  const _TotalsSummaryText({required this.totals});

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
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: _metaColor(context),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date, required this.totals});

  final String date;
  final _DailyTotals totals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Row(
        key: ValueKey('mobile-transactions-date-header-$date'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              _dateLabel(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 4,
              children: [
                _DailyTotalText(
                  key: ValueKey('mobile-transactions-date-income-$date'),
                  label: '수입',
                  value: totals.income,
                  color: context.appIncome,
                ),
                _DailyTotalText(
                  key: ValueKey('mobile-transactions-date-expense-$date'),
                  label: '지출',
                  value: totals.expense,
                  color: context.appExpense,
                ),
                if (totals.transferCount > 0)
                  _TransferTotalText(
                    key: ValueKey('mobile-transactions-date-transfer-$date'),
                    count: totals.transferCount,
                    value: totals.transferAmount,
                  ),
              ],
            ),
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
        color: _metaColor(context),
      ),
    );
  }
}

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({
    required this.row,
    required this.onEdit,
    required this.onDuplicate,
    this.planned = false,
  });

  final TransactionRow row;
  final ValueChanged<TransactionRow> onEdit;
  final ValueChanged<TransactionRow> onDuplicate;
  final bool planned;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('거래 삭제'),
        content: const Text('이 거래를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    await ref.read(transactionsDaoProvider).deleteTransaction(row.id);
    refreshTransactions(ref);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('거래를 삭제했습니다.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = switch (row.type) {
      'income' => context.appIncome,
      'expense' => context.appExpense,
      'transfer' => context.appTransfer,
      _ => theme.colorScheme.onSurface,
    };
    final isTransfer = row.type == 'transfer';
    final isIncome = row.type == 'income';
    final memo = row.memo?.trim();
    final title = isTransfer
        ? [
            if (row.fromAccountName != null) row.fromAccountName,
            if (row.toAccountName != null) row.toAccountName,
          ].whereType<String>().join(' → ')
        : row.categoryName ?? row.ticker ?? memo ?? _typeLabel(row.type);
    final account =
        row.accountName ??
        [
          if (row.fromAccountName != null) row.fromAccountName,
          if (row.toAccountName != null) row.toAccountName,
        ].whereType<String>().join(' → ');

    final sign = isTransfer ? '' : (isIncome ? '+' : '-');
    final visibleTags = row.tags.take(2).toList();
    final hiddenTagCount = row.tags.length - visibleTags.length;

    return MobileCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: InkWell(
        onTap: () => onEdit(row),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: isTransfer
                    ? Icon(Icons.swap_horiz, size: 18, color: color)
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _categoryColor(row.categoryColor, color),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (planned) ...[
                        _PlannedBadge(),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          title.isEmpty ? _typeLabel(row.type) : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 7,
                    runSpacing: 2,
                    children: [
                      if (row.occurredTime != '00:00')
                        Text(row.occurredTime, style: _metaStyle(context)),
                      Text(_typeLabel(row.type), style: _metaStyle(context)),
                      if (!isTransfer && account.isNotEmpty)
                        Text(account, style: _metaStyle(context)),
                    ],
                  ),
                  if (memo != null && memo.isNotEmpty && memo != title) ...[
                    const SizedBox(height: 2),
                    Text(
                      memo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _metaStyle(context),
                    ),
                  ],
                  if (visibleTags.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        for (final tag in visibleTags)
                          _TagChip(name: tag.name, color: tag.color),
                        if (hiddenTagCount > 0)
                          _MoreTagChip(count: hiddenTagCount),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
              child: Text(
                '$sign${formatKRW(row.amount)}',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(
              width: 40,
              child: PopupMenuButton<String>(
                tooltip: '거래 메뉴',
                padding: EdgeInsets.zero,
                iconSize: 22,
                onSelected: (value) async {
                  if (value == 'edit') {
                    onEdit(row);
                  } else if (value == 'copy') {
                    onDuplicate(row);
                  } else if (value == 'delete') {
                    await _confirmAndDelete(context, ref);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('수정'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('복사'),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        '삭제',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

TextStyle _metaStyle(BuildContext context) =>
    TextStyle(color: _metaColor(context), fontSize: 12);

Color _metaColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78);

class _PlannedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.appWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '예정',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: context.appWarning,
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
    final parsed = _colorFromHex(color, context.appAccent);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: parsed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '#$name',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: parsed,
          ),
        ),
      ),
    );
  }
}

class _MoreTagChip extends StatelessWidget {
  const _MoreTagChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(
          '+$count',
          style: TextStyle(fontSize: 10, color: _metaColor(context)),
        ),
      ),
    );
  }
}

String _typeLabel(String type) => switch (type) {
  'income' => '수입',
  'expense' => '지출',
  'transfer' => '이체',
  _ => type,
};

String _dateLabel(String dateKey) {
  try {
    final date = parseDateKey(dateKey);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.month}월 ${date.day}일 (${weekdays[date.weekday - 1]})';
  } catch (_) {
    return dateKey;
  }
}

Color _categoryColor(String? hex, Color fallback) =>
    hex == null ? fallback : _colorFromHex(hex, fallback);

Color _colorFromHex(String hex, Color fallback) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
