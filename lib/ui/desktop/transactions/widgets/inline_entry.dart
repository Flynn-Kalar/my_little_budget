import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/providers.dart';
import '../../../../features/transactions/validation.dart';
import '../providers.dart';
import 'form_fields.dart';

/// SPEC §4.1 — 상단 한 줄 입력. 수입/지출/이체 추가 + 태그.
class InlineEntry extends ConsumerStatefulWidget {
  const InlineEntry({super.key});

  @override
  ConsumerState<InlineEntry> createState() => _InlineEntryState();
}

class _InlineEntryState extends ConsumerState<InlineEntry> {
  String _type = 'expense';
  DateTime _date = DateTime.now();
  int? _accountId;
  int? _categoryId;
  int? _fromAccountId;
  int? _toAccountId;
  List<String> _tags = [];
  final _amountCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
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

  Future<void> _save() async {
    final result = validateTransaction(
      type: _type,
      amount: parseKRW(_amountCtrl.text),
      occurredOn: toDateKey(_date),
      occurredTime: '00:00',
      memo: _memoCtrl.text,
      accountId: _accountId,
      categoryId: _categoryId,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
    );

    if (result.isFail) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.errors.values.first)));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(transactionsDaoProvider).saveTransaction(
            draft: result.value!,
            tagNames: _type == 'transfer' ? const [] : _tags,
          );
      refreshTransactions(ref);
      setState(() {
        _amountCtrl.clear();
        _memoCtrl.clear();
        _tags = [];
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(activeAccountsProvider).asData?.value ?? const [];
    final categories =
        ref.watch(activeCategoriesProvider).asData?.value ?? const [];
    final tagSuggestions = (ref.watch(allTagsProvider).asData?.value ?? const [])
        .map((t) => t.name)
        .toList();
    final visibleCats = categories
        .where((c) => c.type == (_type == 'income' ? 'income' : 'expense'))
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'income', label: Text('수입')),
                  ButtonSegment(value: 'expense', label: Text('지출')),
                  ButtonSegment(value: 'transfer', label: Text('이체')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _categoryId = null;
                }),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(toDateKey(_date)),
              ),
              if (_type == 'transfer') ...[
                AccountDropdown(
                  hint: '출금',
                  accounts: accounts,
                  value: _fromAccountId,
                  onChanged: (v) => setState(() => _fromAccountId = v),
                ),
                const Icon(Icons.arrow_forward,
                    size: 16, color: AppTokens.muted),
                AccountDropdown(
                  hint: '입금',
                  accounts: accounts,
                  value: _toAccountId,
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              ] else ...[
                AccountDropdown(
                  hint: '자산',
                  accounts: accounts,
                  value: _accountId,
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                CategoryDropdown(
                  categories: visibleCats,
                  value: _categoryId,
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
              ],
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '금액',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              SizedBox(
                width: 180,
                child: TextField(
                  controller: _memoCtrl,
                  decoration: const InputDecoration(
                    hintText: '메모',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('추가'),
              ),
            ],
          ),
          if (_type != 'transfer') ...[
            const SizedBox(height: 10),
            TagInput(
              value: _tags,
              suggestions: tagSuggestions,
              onChanged: (v) => setState(() => _tags = v),
            ),
          ],
        ],
      ),
    );
  }
}
