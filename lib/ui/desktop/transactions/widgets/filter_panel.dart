import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/database.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'form_fields.dart';
import 'type_filter.dart';

class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key, this.onExpandedChanged});

  final ValueChanged<bool>? onExpandedChanged;

  @override
  ConsumerState<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends ConsumerState<FilterPanel> {
  final _qCtrl = TextEditingController();
  final _minCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  int? _accountId;
  final Set<int> _categoryIds = {};
  final Set<int> _tagIds = {};
  bool _untaggedOnly = false;
  DateTime? _fromDate;
  DateTime? _toDate;
  Timer? _searchDebounce;
  bool _expanded = false;

  void _setExpanded(bool expanded) {
    setState(() => _expanded = expanded);
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  void initState() {
    super.initState();
    final filter = ref.read(searchFilterProvider);
    _qCtrl.text = filter.q ?? '';
    _minCtrl.text = filter.minAmount == null ? '' : '${filter.minAmount}';
    _maxCtrl.text = filter.maxAmount == null ? '' : '${filter.maxAmount}';
    _accountId = filter.accountId;
    _categoryIds.addAll(filter.categoryIds ?? const []);
    _tagIds.addAll(filter.tagIds ?? const []);
    _untaggedOnly = filter.untaggedOnly;
    _fromDate = filter.fromDate == null
        ? null
        : DateTime.parse(filter.fromDate!);
    _toDate = filter.toDate == null ? null : DateTime.parse(filter.toDate!);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _qCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final min = _minCtrl.text.trim().isEmpty ? null : parseKRW(_minCtrl.text);
    final max = _maxCtrl.text.trim().isEmpty ? null : parseKRW(_maxCtrl.text);
    ref.read(searchFilterProvider.notifier).state = TransactionFilter(
      q: _qCtrl.text.trim().isEmpty ? null : _qCtrl.text.trim(),
      minAmount: min,
      maxAmount: max,
      accountId: _accountId,
      categoryIds: _categoryIds.isEmpty ? null : _categoryIds.toList(),
      tagIds: _untaggedOnly || _tagIds.isEmpty ? null : _tagIds.toList(),
      untaggedOnly: _untaggedOnly,
      fromDate: _fromDate == null ? null : toDateKey(_fromDate!),
      toDate: _toDate == null ? null : toDateKey(_toDate!),
    );
  }

  void _scheduleSearchApply() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _apply);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    setState(_qCtrl.clear);
    _apply();
  }

  void _reset() {
    _searchDebounce?.cancel();
    setState(() {
      _qCtrl.clear();
      _minCtrl.clear();
      _maxCtrl.clear();
      _accountId = null;
      _categoryIds.clear();
      _tagIds.clear();
      _untaggedOnly = false;
      _fromDate = null;
      _toDate = null;
    });
    ref.read(typeFilterProvider.notifier).state = null;
    ref.read(searchFilterProvider.notifier).state = const TransactionFilter();
  }

  int _activeFilterCount(TransactionFilter filter, String? typeFilter) {
    var count = 0;
    if (typeFilter != null) count++;
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

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ko', 'KR'),
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(activeAccountsProvider).asData?.value ?? const [];
    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ?? const [];
    final tags = ref.watch(allTagsProvider).asData?.value ?? const [];
    final filter = ref.watch(searchFilterProvider);
    final typeFilter = ref.watch(typeFilterProvider);
    final hasFilter = typeFilter != null || hasActiveTransactionFilter(filter);
    final activeCount = _activeFilterCount(filter, typeFilter);

    if (!_expanded) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () => _setExpanded(true),
            icon: const Icon(Icons.filter_list, size: 18),
            label: Text(activeCount > 0 ? '검색·필터 $activeCount' : '검색·필터'),
          ),
          if (hasFilter)
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: const Text('초기화'),
              onPressed: _reset,
            ),
        ],
      );
    }

    final query = filter.q?.trim();
    final statusText = query != null && query.isNotEmpty
        ? '검색 중 "$query"'
        : hasFilter
        ? '필터 적용 중'
        : '필터 없음';

    return Card(
      elevation: 0,
      color: context.desktopSurface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.filter_list, size: 20),
                const SizedBox(width: 10),
                const Text(
                  '필터',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasFilter
                        ? context.desktopIncome
                        : context.desktopMuted,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '필터 접기',
                  onPressed: () => _setExpanded(false),
                  icon: const Icon(Icons.keyboard_arrow_up, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: _TypeFilterSection(),
            ),
            const SizedBox(height: 12),
            _FilterControls(
              qCtrl: _qCtrl,
              minCtrl: _minCtrl,
              maxCtrl: _maxCtrl,
              accounts: accounts,
              categories: categories,
              tags: tags,
              accountId: _accountId,
              categoryIds: _categoryIds,
              tagIds: _tagIds,
              untaggedOnly: _untaggedOnly,
              fromDate: _fromDate,
              toDate: _toDate,
              onSearchChanged: () {
                setState(() {});
                _scheduleSearchApply();
              },
              onSearchSubmitted: () {
                _searchDebounce?.cancel();
                _apply();
              },
              onClearSearch: _clearSearch,
              onAccountChanged: (v) => setState(() => _accountId = v),
              onPickFromDate: () => _pickDate(true),
              onPickToDate: () => _pickDate(false),
              onCategoryChanged: (id, selected) => setState(() {
                selected ? _categoryIds.add(id) : _categoryIds.remove(id);
              }),
              onUntaggedChanged: (v) => setState(() => _untaggedOnly = v),
              onTagChanged: (id, selected) => setState(() {
                selected ? _tagIds.add(id) : _tagIds.remove(id);
              }),
              onReset: _reset,
              onApply: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeFilterSection extends StatelessWidget {
  const _TypeFilterSection();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionLabel('거래 유형'), SizedBox(height: 8), TypeFilter()],
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.qCtrl,
    required this.minCtrl,
    required this.maxCtrl,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.accountId,
    required this.categoryIds,
    required this.tagIds,
    required this.untaggedOnly,
    required this.fromDate,
    required this.toDate,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onAccountChanged,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onCategoryChanged,
    required this.onUntaggedChanged,
    required this.onTagChanged,
    required this.onReset,
    required this.onApply,
  });

  final TextEditingController qCtrl;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Tag> tags;
  final int? accountId;
  final Set<int> categoryIds;
  final Set<int> tagIds;
  final bool untaggedOnly;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VoidCallback onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onClearSearch;
  final ValueChanged<int?> onAccountChanged;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final void Function(int id, bool selected) onCategoryChanged;
  final ValueChanged<bool> onUntaggedChanged;
  final void Function(int id, bool selected) onTagChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          key: const ValueKey('desktop-transactions-filter-controls-row'),
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                key: const ValueKey('transactions-search-field'),
                controller: qCtrl,
                decoration: const InputDecoration(
                  labelText: '검색(제목/메모)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => onSearchChanged(),
                onSubmitted: (_) => onSearchSubmitted(),
              ),
            ),
            if (qCtrl.text.isNotEmpty)
              IconButton(
                key: const ValueKey('transactions-search-clear'),
                tooltip: '검색 초기화',
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear, size: 18),
              ),
            SizedBox(
              width: 110,
              child: TextField(
                key: const ValueKey('transactions-min-amount-field'),
                controller: minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '최소 금액',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                key: const ValueKey('transactions-max-amount-field'),
                controller: maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '최대 금액',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          key: const ValueKey('desktop-transactions-filter-account-date-row'),
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AccountDropdown(
              key: const ValueKey('transactions-account-filter-field'),
              hint: '자산 전체',
              accounts: accounts,
              value: accountId,
              onChanged: onAccountChanged,
            ),
            OutlinedButton.icon(
              key: const ValueKey('transactions-from-date-filter-button'),
              onPressed: onPickFromDate,
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(fromDate == null ? '시작일' : toDateKey(fromDate!)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('~'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('transactions-to-date-filter-button'),
              onPressed: onPickToDate,
              icon: const Icon(Icons.calendar_today, size: 14),
              label: Text(toDate == null ? '종료일' : toDateKey(toDate!)),
            ),
          ],
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('카테고리'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories
                .map(
                  (c) => FilterChip(
                    label: Text(c.name),
                    selected: categoryIds.contains(c.id),
                    onSelected: (s) => onCategoryChanged(c.id, s),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const _SectionLabel('태그'),
            const Spacer(),
            Text(
              '태그 없는 거래만',
              style: TextStyle(fontSize: 12, color: context.desktopMuted),
            ),
            Switch(value: untaggedOnly, onChanged: onUntaggedChanged),
          ],
        ),
        if (!untaggedOnly && tags.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: tags
                .map(
                  (t) => FilterChip(
                    label: Text('#${t.name}'),
                    selected: tagIds.contains(t.id),
                    onSelected: (s) => onTagChanged(t.id, s),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(onPressed: onReset, child: const Text('초기화')),
            const SizedBox(width: 8),
            FilledButton(onPressed: onApply, child: const Text('적용')),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: context.desktopMuted,
    ),
  );
}
