import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/daos/transactions_dao.dart';
import '../../../../features/transactions/providers.dart';
import '../../mobile_widgets.dart';

class MobileTransactionSearchFilterBar extends ConsumerStatefulWidget {
  const MobileTransactionSearchFilterBar({
    super.key,
    required this.onOpenAdvancedFilter,
  });

  final VoidCallback onOpenAdvancedFilter;

  @override
  ConsumerState<MobileTransactionSearchFilterBar> createState() =>
      _MobileTransactionSearchFilterBarState();
}

class _MobileTransactionSearchFilterBarState
    extends ConsumerState<MobileTransactionSearchFilterBar> {
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
                onPressed: widget.onOpenAdvancedFilter,
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
          _MobileTransactionTypeFilter(type: type),
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

class _MobileTransactionTypeFilter extends ConsumerWidget {
  const _MobileTransactionTypeFilter({required this.type});

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
