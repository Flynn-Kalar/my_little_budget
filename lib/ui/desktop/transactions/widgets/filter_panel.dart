import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../providers.dart';
import 'form_fields.dart';

/// SPEC §4.1 — 검색/세부 필터 패널. searchFilterProvider 에 적용.
class FilterPanel extends ConsumerStatefulWidget {
  const FilterPanel({super.key});

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

  @override
  void dispose() {
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

  void _reset() {
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
    ref.read(searchFilterProvider.notifier).state = const TransactionFilter();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
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
    final accounts = ref.watch(activeAccountsProvider).asData?.value ?? const [];
    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ?? const [];
    final tags = ref.watch(allTagsProvider).asData?.value ?? const [];

    return Card(
      elevation: 0,
      color: AppTokens.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.filter_list, size: 20),
        title: const Text('필터', style: TextStyle(fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _qCtrl,
                  decoration: const InputDecoration(
                    labelText: '검색 (메모·카테고리·자산)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _apply(),
                ),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _minCtrl,
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
                  controller: _maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최대 금액',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              AccountDropdown(
                hint: '자산 전체',
                accounts: accounts,
                value: _accountId,
                onChanged: (v) => setState(() => _accountId = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickDate(true),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_fromDate == null ? '시작일' : toDateKey(_fromDate!)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text('~'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickDate(false),
                icon: const Icon(Icons.calendar_today, size: 14),
                label: Text(_toDate == null ? '종료일' : toDateKey(_toDate!)),
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
                  .map((c) => FilterChip(
                        label: Text(c.name),
                        selected: _categoryIds.contains(c.id),
                        onSelected: (s) => setState(() {
                          s ? _categoryIds.add(c.id) : _categoryIds.remove(c.id);
                        }),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const _SectionLabel('태그'),
              const Spacer(),
              const Text('태그 없는 거래만',
                  style: TextStyle(fontSize: 12, color: AppTokens.muted)),
              Switch(
                value: _untaggedOnly,
                onChanged: (v) => setState(() => _untaggedOnly = v),
              ),
            ],
          ),
          if (!_untaggedOnly && tags.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((t) => FilterChip(
                        label: Text('#${t.name}'),
                        selected: _tagIds.contains(t.id),
                        onSelected: (s) => setState(() {
                          s ? _tagIds.add(t.id) : _tagIds.remove(t.id);
                        }),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _reset, child: const Text('초기화')),
              const SizedBox(width: 8),
              FilledButton(onPressed: _apply, child: const Text('적용')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.muted),
      );
}
