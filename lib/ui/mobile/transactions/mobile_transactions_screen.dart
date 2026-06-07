import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/transactions/validation.dart';
import '../../desktop/transactions/providers.dart';
import '../mobile_widgets.dart';

class MobileTransactionsScreen extends ConsumerWidget {
  const MobileTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthlySummaryProvider);
    final rows = ref.watch(transactionsListProvider);
    final type = ref.watch(typeFilterProvider);

    return MobilePageScaffold(
      title: '내역',
      onAdd: () => _TransactionSheet.show(context),
      addTooltip: '거래 추가',
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(selectedMonthProvider.notifier).state = value,
        ),
        const _SearchCard(),
        const _AdvancedFilterCard(),
        _TypeFilter(type: type),
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

class _SearchCard extends ConsumerStatefulWidget {
  const _SearchCard();

  @override
  ConsumerState<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends ConsumerState<_SearchCard> {
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
    final query = ref.watch(searchFilterProvider).q ?? '';
    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return MobileCard(
      child: TextField(
        controller: _controller,
        onChanged: _setQuery,
        decoration: InputDecoration(
          hintText: '메모, 카테고리, 계좌명 검색',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
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
    );
  }
}

class _TypeFilter extends ConsumerWidget {
  const _TypeFilter({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [
      (null, '전체'),
      ('income', '수입'),
      ('expense', '지출'),
      ('transfer', '이체'),
    ];

    return MobileCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            ChoiceChip(
              label: Text(option.$2),
              selected: type == option.$1,
              onSelected: (_) =>
                  ref.read(typeFilterProvider.notifier).state = option.$1,
            ),
        ],
      ),
    );
  }
}

class _AdvancedFilterCard extends ConsumerWidget {
  const _AdvancedFilterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(searchFilterProvider);
    final active =
        hasActiveTransactionFilter(filter) &&
        !(filter.q?.trim().isNotEmpty == true &&
            filter.minAmount == null &&
            filter.maxAmount == null &&
            filter.accountId == null &&
            (filter.categoryIds?.isEmpty ?? true) &&
            (filter.tagIds?.isEmpty ?? true) &&
            !filter.untaggedOnly &&
            filter.fromDate == null &&
            filter.toDate == null);
    return MobileCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              active ? '필터가 적용되어 있습니다' : '기간, 계좌, 카테고리, 태그 필터',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _AdvancedFilterSheet.show(context),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('필터'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      child: Column(
        children: [
          AmountLine(
            label: '수입',
            value: formatKRW(summary.income),
            valueColor: AppTokens.income,
          ),
          AmountLine(
            label: '지출',
            value: formatKRW(summary.expense),
            valueColor: AppTokens.expense,
          ),
          AmountLine(
            label: '순수익',
            value: formatKRW(summary.net),
            valueColor: summary.net < 0 ? AppTokens.expense : AppTokens.income,
          ),
        ],
      ),
    );
  }
}

class _GroupedTransactions extends StatelessWidget {
  const _GroupedTransactions({required this.rows});

  final List<TransactionRow> rows;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TransactionRow>>{};
    for (final row in rows) {
      (groups[row.occurredOn] ??= []).add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          _DateHeader(date: entry.key),
          for (final row in entry.value) _TransactionCard(row: row),
        ],
      ],
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        _dateLabel(date),
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.row});

  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (row.type) {
      'income' => AppTokens.income,
      'expense' => AppTokens.expense,
      'transfer' => AppTokens.transfer,
      _ => theme.colorScheme.onSurface,
    };
    final title = row.memo?.trim().isNotEmpty == true
        ? row.memo!.trim()
        : row.categoryName ?? row.ticker ?? _typeLabel(row.type);
    final account =
        row.accountName ??
        [
          if (row.fromAccountName != null) row.fromAccountName,
          if (row.toAccountName != null) row.toAccountName,
        ].whereType<String>().join(' → ');

    return MobileCard(
      child: InkWell(
        onTap: () => _TransactionSheet.show(context, row: row),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatKRW(row.amount),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(row.occurredTime, style: _metaStyle(context)),
                Text(_typeLabel(row.type), style: _metaStyle(context)),
                if (account.isNotEmpty)
                  Text(account, style: _metaStyle(context)),
                if (row.categoryName != null)
                  Text(row.categoryName!, style: _metaStyle(context)),
              ],
            ),
            if (row.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in row.tags)
                    Chip(
                      label: Text('#${tag.name}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({this.row});

  final TransactionRow? row;

  static Future<void> show(BuildContext context, {TransactionRow? row}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(row: row),
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

  bool get _isEdit => widget.row != null;

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
            id: widget.row?.id,
            draft: result.value!,
            tagNames: _tagNames.toList(),
          );
      if (!mounted) return;
      refreshTransactions(ref);
      Navigator.pop(context);
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
              _isEdit ? '거래 수정' : '거래 추가',
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
                      foregroundColor: AppTokens.expense,
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

class _TagNameSelector extends StatelessWidget {
  const _TagNameSelector({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('태그', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (tags.isEmpty)
          Text(
            '등록된 태그가 없습니다.',
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
              for (final tag in tags)
                FilterChip(
                  label: Text('#${tag.name}'),
                  selected: selectedNames.contains(tag.name),
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

TextStyle _metaStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
  fontSize: 12,
);

String _typeLabel(String type) => switch (type) {
  'income' => '수입',
  'expense' => '지출',
  'transfer' => '이체',
  _ => type,
};

String _dateLabel(String dateKey) {
  try {
    final date = parseDateKey(dateKey);
    return '${date.year}년 ${date.month}월 ${date.day}일';
  } catch (_) {
    return dateKey;
  }
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
