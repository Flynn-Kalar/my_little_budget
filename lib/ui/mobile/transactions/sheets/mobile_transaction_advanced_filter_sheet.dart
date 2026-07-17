import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/database.dart';
import '../../../../features/transactions/providers.dart';
import '../../mobile_widgets.dart';

class MobileTransactionAdvancedFilterSheet extends ConsumerStatefulWidget {
  const MobileTransactionAdvancedFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MobileTransactionAdvancedFilterSheet(),
    );
  }

  @override
  ConsumerState<MobileTransactionAdvancedFilterSheet> createState() =>
      _MobileTransactionAdvancedFilterSheetState();
}

class _MobileTransactionAdvancedFilterSheetState
    extends ConsumerState<MobileTransactionAdvancedFilterSheet> {
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
        bottom: mobileBottomPadding(context, spacing: 16),
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
