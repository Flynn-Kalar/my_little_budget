import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/transactions/validation.dart';
import '../../shared/transactions_providers.dart';
import '../mobile_widgets.dart';

final _quickInputTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getRecommendedTags(limit: 8),
);

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
      onAdd: () => _TransactionSheet.show(context),
      addTooltip: '거래 추가',
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(selectedMonthProvider.notifier).state = value,
        ),
        const _SearchFilterBar(),
        MobileAsync(
          value: summary,
          builder: (value) => _Summary(summary: value),
        ),
        MobileAsync(
          value: rows,
          builder: (value) {
            if (value.isEmpty) return const EmptyMobileCard('표시할 내역이 없습니다.');
            return _GroupedTransactions(rows: value);
          },
        ),
      ],
    );
  }
}

class _SearchFilterBar extends ConsumerStatefulWidget {
  const _SearchFilterBar();

  @override
  ConsumerState<_SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends ConsumerState<_SearchFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(searchFilterProvider).q ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    final current = ref.read(searchFilterProvider);
    final query = value.trim();
    ref.read(searchFilterProvider.notifier).state = TransactionFilter(
      q: query.isEmpty ? null : query,
      minAmount: current.minAmount,
      maxAmount: current.maxAmount,
      accountId: current.accountId,
      categoryIds: current.categoryIds,
      tagIds: current.tagIds,
      untaggedOnly: current.untaggedOnly,
      fromDate: current.fromDate,
      toDate: current.toDate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(searchFilterProvider);
    final type = ref.watch(typeFilterProvider);
    final query = filter.q ?? '';
    final advancedActive = _hasAdvancedTransactionFilter(filter);
    final activeCount = _activeTransactionFilterCount(filter, type);
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return MobileCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        key: const ValueKey('mobile-transactions-search-filter-bar'),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('mobile-transactions-search-field'),
                  controller: _controller,
                  onChanged: _setQuery,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '메모, 카테고리, 계좌명 검색',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            key: const ValueKey(
                              'mobile-transactions-search-clear',
                            ),
                            onPressed: () {
                              _controller.clear();
                              _setQuery('');
                            },
                            icon: const Icon(Icons.close),
                            tooltip: '검색어 지우기',
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('mobile-transactions-filter-button'),
                onPressed: () => _AdvancedFilterSheet.show(context),
                isSelected: advancedActive,
                selectedIcon: const Icon(Icons.filter_alt),
                icon: const Icon(Icons.tune),
                tooltip: activeCount > 0 ? '필터 $activeCount개 적용됨' : '필터',
              ),
              if (activeCount > 0) ...[
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('mobile-transactions-filter-reset'),
                  onPressed: () {
                    _controller.clear();
                    ref.read(typeFilterProvider.notifier).state = null;
                    ref.read(searchFilterProvider.notifier).state =
                        const TransactionFilter();
                  },
                  icon: const Icon(Icons.refresh),
                  tooltip: '검색·필터 초기화',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          _TypeFilter(type: type),
        ],
      ),
    );
  }
}

bool _hasAdvancedTransactionFilter(TransactionFilter filter) {
  return filter.minAmount != null ||
      filter.maxAmount != null ||
      filter.accountId != null ||
      (filter.categoryIds?.isNotEmpty ?? false) ||
      (filter.tagIds?.isNotEmpty ?? false) ||
      filter.untaggedOnly ||
      filter.fromDate != null ||
      filter.toDate != null;
}

int _activeTransactionFilterCount(TransactionFilter filter, String? type) {
  var count = 0;
  if (type != null) count++;
  if (filter.q?.trim().isNotEmpty ?? false) count++;
  if (filter.minAmount != null) count++;
  if (filter.maxAmount != null) count++;
  if (filter.accountId != null) count++;
  if (filter.categoryIds?.isNotEmpty ?? false) count++;
  if (filter.tagIds?.isNotEmpty ?? false) count++;
  if (filter.untaggedOnly) count++;
  if (filter.fromDate != null) count++;
  if (filter.toDate != null) count++;
  return count;
}

class _TypeFilter extends ConsumerWidget {
  const _TypeFilter({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [
      ('all', '전체'),
      ('income', '수입'),
      ('expense', '지출'),
      ('transfer', '이체'),
    ];
    final selected = type ?? 'all';

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        key: const ValueKey('mobile-transactions-type-filter-inline'),
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: [
          for (final option in options)
            ButtonSegment<String>(value: option.$1, label: Text(option.$2)),
        ],
        selected: {selected},
        onSelectionChanged: (value) {
          final next = value.first;
          ref.read(typeFilterProvider.notifier).state = next == 'all'
              ? null
              : next;
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final income = context.appIncome;
    final expense = context.appExpense;
    return MobileCard(
      child: Column(
        children: [
          AmountLine(
            label: '수입',
            value: formatKRW(summary.income),
            valueColor: income,
          ),
          AmountLine(
            label: '지출',
            value: formatKRW(summary.expense),
            valueColor: expense,
          ),
          AmountLine(
            label: '순수익',
            value: formatKRW(summary.net),
            valueColor: summary.net < 0 ? expense : income,
          ),
        ],
      ),
    );
  }
}

class _GroupedTransactions extends StatefulWidget {
  const _GroupedTransactions({required this.rows});

  final List<TransactionRow> rows;

  @override
  State<_GroupedTransactions> createState() => _GroupedTransactionsState();
}

class _GroupedTransactionsState extends State<_GroupedTransactions> {
  bool _plannedExpanded = true;

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
          ),
        if (planned.isNotEmpty && completed.isNotEmpty)
          const SizedBox(height: 6),
        if (completed.isNotEmpty)
          _TransactionSection(title: '완료 거래', rows: completed),
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
              planned: planned,
            ),
            for (final row in entry.value)
              _TransactionCard(row: row, planned: planned),
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
  const _DateHeader({
    required this.date,
    required this.totals,
    this.planned = false,
  });

  final String date;
  final _DailyTotals totals;
  final bool planned;

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
  const _TransactionCard({required this.row, this.planned = false});

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
        onTap: () => _TransactionSheet.show(context, row: row),
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
                    _TransactionSheet.show(context, row: row);
                  } else if (value == 'copy') {
                    _TransactionSheet.showDuplicate(context, row);
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

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({this.row, this.duplicate = false});

  final TransactionRow? row;
  final bool duplicate;

  static Future<void> show(BuildContext context, {TransactionRow? row}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(row: row),
    );
  }

  static Future<void> showDuplicate(BuildContext context, TransactionRow row) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(row: row, duplicate: true),
    );
  }

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  late String _type = widget.row?.type ?? 'expense';
  late DateTime _date = widget.row == null
      ? DateTime.now()
      : parseDateKey(widget.row!.occurredOn);
  late TimeOfDay _time =
      _parseTimeOfDay(widget.row?.occurredTime) ??
      TimeOfDay.fromDateTime(DateTime.now());
  late int? _accountId = widget.row?.accountId;
  late int? _categoryId = widget.row?.categoryId;
  late int? _fromAccountId = widget.row?.fromAccountId;
  late int? _toAccountId = widget.row?.toAccountId;
  late final _amount = TextEditingController(
    text: widget.row?.amount.toString() ?? '',
  );
  late final _memo = TextEditingController(text: widget.row?.memo ?? '');
  late final Set<String> _tagNames =
      widget.row?.tags.map((tag) => tag.name).toSet() ?? <String>{};
  bool _busy = false;

  bool get _isEdit => widget.row != null && !widget.duplicate;
  bool get _isDuplicate => widget.row != null && widget.duplicate;

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final result = validateTransaction(
      type: _type,
      amount: parseKRW(_amount.text),
      occurredOn: toDateKey(_date),
      occurredTime: _timeKey(_time),
      memo: _memo.text,
      accountId: _accountId,
      categoryId: _categoryId,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
    );
    if (result.isFail) {
      _showSnack(_transactionErrorMessage(result.errors.keys.first));
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(transactionsDaoProvider)
          .saveTransaction(
            id: _isEdit ? widget.row?.id : null,
            draft: result.value!,
            tagNames: _tagNames.toList(),
          );
      final warning = await ref
          .read(transactionsDaoProvider)
          .cardLimitWarningFor(result.value!);
      if (!mounted) return;
      refreshTransactions(ref);
      ref.invalidate(_quickInputTagsProvider);
      Navigator.pop(context);
      _showCardLimitWarning(context, warning);
      _showSnack(_isEdit ? '거래를 수정했습니다.' : '거래를 추가했습니다.');
    } catch (e) {
      if (mounted) _showSnack('거래 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final row = widget.row;
    if (row == null) return;
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

    setState(() => _busy = true);
    try {
      await ref.read(transactionsDaoProvider).deleteTransaction(row.id);
      if (!mounted) return;
      refreshTransactions(ref);
      Navigator.pop(context);
      _showSnack('거래를 삭제했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(activeAccountsProvider).asData?.value ?? const [];
    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ?? const [];
    final tags = ref.watch(allTagsProvider).asData?.value ?? const <Tag>[];
    final quickTags =
        ref.watch(_quickInputTagsProvider).asData?.value ??
        tags.take(8).toList();
    final visibleCategories = categories
        .where(
          (category) =>
              category.type == (_type == 'income' ? 'income' : 'expense'),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isDuplicate ? '거래 복사' : (_isEdit ? '거래 수정' : '거래 추가'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'income', label: Text('수입')),
                ButtonSegment(value: 'expense', label: Text('지출')),
                ButtonSegment(value: 'transfer', label: Text('이체')),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (selected) => setState(() {
                      _type = selected.first;
                      _categoryId = null;
                    }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(toDateKey(_date)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickTime,
                    icon: const Icon(Icons.schedule, size: 16),
                    label: Text(_timeKey(_time)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_type == 'transfer') ...[
              _AccountField(
                label: '출금 자산',
                accounts: accounts,
                value: _fromAccountId,
                onChanged: (value) => setState(() => _fromAccountId = value),
              ),
              const SizedBox(height: 12),
              _AccountField(
                label: '입금 자산',
                accounts: accounts,
                value: _toAccountId,
                onChanged: (value) => setState(() => _toAccountId = value),
              ),
            ] else ...[
              _AccountField(
                label: '자산',
                accounts: accounts,
                value: _accountId,
                onChanged: (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 12),
              _CategoryField(
                categories: visibleCategories,
                value: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _memo,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '메모',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _TagNameSelector(
              tags: tags,
              quickTags: quickTags,
              selectedNames: _tagNames,
              enabled: !_busy,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isEdit)
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.appExpense,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showCardLimitWarning(BuildContext context, CardLimitWarning? warning) {
  if (warning == null) return;
  final message = warning.exceeded
      ? '${warning.accountName} 한도를 ${formatKRW(-warning.remaining)} 초과했습니다.'
      : '${warning.accountName} 한도까지 ${formatKRW(warning.remaining)} 남았습니다.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

class _AdvancedFilterSheet extends ConsumerStatefulWidget {
  const _AdvancedFilterSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AdvancedFilterSheet(),
    );
  }

  @override
  ConsumerState<_AdvancedFilterSheet> createState() =>
      _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends ConsumerState<_AdvancedFilterSheet> {
  late DateTime? _fromDate;
  late DateTime? _toDate;
  late int? _accountId;
  late final Set<int> _categoryIds;
  late final Set<int> _tagIds;
  late bool _untaggedOnly;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(searchFilterProvider);
    _fromDate = filter.fromDate == null ? null : parseDateKey(filter.fromDate!);
    _toDate = filter.toDate == null ? null : parseDateKey(filter.toDate!);
    _accountId = filter.accountId;
    _categoryIds = {...?filter.categoryIds};
    _tagIds = {...?filter.tagIds};
    _untaggedOnly = filter.untaggedOnly;
  }

  Future<void> _pickDate({required bool from}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from
          ? (_fromDate ?? DateTime.now())
          : (_toDate ?? _fromDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
        } else {
          _toDate = picked;
          if (_fromDate != null && _fromDate!.isAfter(picked)) {
            _fromDate = picked;
          }
        }
      });
    }
  }

  void _apply() {
    final current = ref.read(searchFilterProvider);
    ref.read(searchFilterProvider.notifier).state = TransactionFilter(
      q: current.q,
      minAmount: current.minAmount,
      maxAmount: current.maxAmount,
      accountId: _accountId,
      categoryIds: _categoryIds.isEmpty ? null : _categoryIds.toList(),
      tagIds: _tagIds.isEmpty ? null : _tagIds.toList(),
      untaggedOnly: _untaggedOnly,
      fromDate: _fromDate == null ? null : toDateKey(_fromDate!),
      toDate: _toDate == null ? null : toDateKey(_toDate!),
    );
    Navigator.pop(context);
  }

  void _reset() {
    final current = ref.read(searchFilterProvider);
    ref.read(searchFilterProvider.notifier).state = TransactionFilter(
      q: current.q,
      minAmount: current.minAmount,
      maxAmount: current.maxAmount,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(activeAccountsProvider).asData?.value ?? const <Account>[];
    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ?? const <Category>[];
    final tags = ref.watch(allTagsProvider).asData?.value ?? const <Tag>[];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '고급 필터',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(from: true),
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(
                      _fromDate == null ? '시작일' : toDateKey(_fromDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(from: false),
                    icon: const Icon(Icons.event, size: 16),
                    label: Text(_toDate == null ? '종료일' : toDateKey(_toDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: accounts.any((account) => account.id == _accountId)
                  ? _accountId
                  : null,
              items: [
                const DropdownMenuItem(value: -1, child: Text('전체 계좌')),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _accountId = value == -1 ? null : value),
              decoration: const InputDecoration(
                labelText: '계좌',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _IdChipSelector<Category>(
              title: '카테고리',
              items: categories,
              selectedIds: _categoryIds,
              idOf: (item) => item.id,
              labelOf: (item) => item.name,
              enabled: true,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
            _IdChipSelector<Tag>(
              title: '태그',
              items: tags,
              selectedIds: _tagIds,
              idOf: (item) => item.id,
              labelOf: (item) => '#${item.name}',
              enabled: !_untaggedOnly,
              onChanged: () => setState(() {}),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _untaggedOnly,
              onChanged: (value) => setState(() {
                _untaggedOnly = value;
                if (value) _tagIds.clear();
              }),
              title: const Text('미태그만 보기'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('초기화'),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _apply, child: const Text('적용')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagNameSelector extends StatefulWidget {
  const _TagNameSelector({
    required this.tags,
    required this.quickTags,
    required this.selectedNames,
    required this.enabled,
    required this.onChanged,
  });

  final List<Tag> tags;
  final List<Tag> quickTags;
  final Set<String> selectedNames;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  State<_TagNameSelector> createState() => _TagNameSelectorState();
}

class _TagNameSelectorState extends State<_TagNameSelector> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final featured = <Tag>[];
    final featuredNames = <String>{};
    for (final tag in widget.quickTags) {
      if (featuredNames.add(tag.name)) featured.add(tag);
    }
    for (final tag in widget.tags) {
      if (widget.selectedNames.contains(tag.name) &&
          featuredNames.add(tag.name)) {
        featured.add(tag);
      }
    }
    final remaining = [
      for (final tag in widget.tags)
        if (!featuredNames.contains(tag.name)) tag,
    ];
    final visibleRemaining = _showAll ? remaining : remaining.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('태그', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (widget.tags.isEmpty)
          Text(
            '등록된 태그가 없습니다.',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          )
        else ...[
          _TagChipGroup(
            tags: featured,
            selectedNames: widget.selectedNames,
            enabled: widget.enabled,
            onChanged: widget.onChanged,
          ),
          if (remaining.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 8),
            const Text('전체 태그', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _TagChipGroup(
              tags: visibleRemaining,
              selectedNames: widget.selectedNames,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
            ),
            if (remaining.length > visibleRemaining.length) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = true),
                  icon: const Icon(Icons.expand_more, size: 18),
                  label: Text('전체보기 (${remaining.length})'),
                ),
              ),
            ] else if (_showAll && remaining.length > 12) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showAll = false),
                  icon: const Icon(Icons.expand_less, size: 18),
                  label: const Text('접기'),
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }
}

class _TagChipGroup extends StatelessWidget {
  const _TagChipGroup({
    required this.tags,
    required this.selectedNames,
    required this.enabled,
    required this.onChanged,
  });

  final List<Tag> tags;
  final Set<String> selectedNames;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tag in tags)
          FilterChip(
            label: Text('#${tag.name}'),
            selected: selectedNames.contains(tag.name),
            avatar: tag.isPinned
                ? const Icon(Icons.star_rounded, size: 16)
                : null,
            onSelected: enabled
                ? (selected) {
                    if (selected) {
                      selectedNames.add(tag.name);
                    } else {
                      selectedNames.remove(tag.name);
                    }
                    onChanged();
                  }
                : null,
          ),
      ],
    );
  }
}

class _IdChipSelector<T> extends StatelessWidget {
  const _IdChipSelector({
    required this.title,
    required this.items,
    required this.selectedIds,
    required this.idOf,
    required this.labelOf,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final List<T> items;
  final Set<int> selectedIds;
  final int Function(T item) idOf;
  final String Function(T item) labelOf;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            '$title 항목이 없습니다.',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                FilterChip(
                  label: Text(labelOf(item)),
                  selected: selectedIds.contains(idOf(item)),
                  onSelected: enabled
                      ? (selected) {
                          if (selected) {
                            selectedIds.add(idOf(item));
                          } else {
                            selectedIds.remove(idOf(item));
                          }
                          onChanged();
                        }
                      : null,
                ),
            ],
          ),
      ],
    );
  }
}

class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: accounts.any((account) => account.id == value)
          ? value
          : null,
      items: [
        for (final account in accounts)
          DropdownMenuItem(value: account.id, child: Text(account.name)),
      ],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<Category> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: categories.any((category) => category.id == value)
          ? value
          : null,
      items: [
        for (final category in categories)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
      ],
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: '카테고리',
        border: OutlineInputBorder(),
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

TimeOfDay? _parseTimeOfDay(String? value) {
  if (value == null) return null;
  final parsed = parseTimeInput(value);
  if (parsed == null) return null;
  final parts = parsed.split(':');
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

String _timeKey(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String _transactionErrorMessage(String field) => switch (field) {
  'amount' => '금액을 입력해주세요.',
  'accountId' => '자산을 선택해주세요.',
  'categoryId' => '카테고리를 선택해주세요.',
  'fromAccountId' => '출금 자산을 선택해주세요.',
  'toAccountId' => '입금 자산을 선택해주세요.',
  'memo' => '메모는 200자 이하로 입력해주세요.',
  _ => '입력값을 확인해주세요.',
};
