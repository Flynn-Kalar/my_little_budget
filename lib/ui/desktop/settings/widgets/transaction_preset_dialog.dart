import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../data/daos/transaction_presets_dao.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/presets/validation.dart';
import '../../../../features/settings/providers.dart';

class TransactionPresetDialog extends ConsumerStatefulWidget {
  const TransactionPresetDialog({super.key, this.item, this.source});

  final TransactionPresetListItem? item;
  final TransactionRow? source;

  static Future<void> show(
    BuildContext context, {
    TransactionPresetListItem? item,
    TransactionRow? source,
  }) => showDialog<void>(
    context: context,
    builder: (_) => TransactionPresetDialog(item: item, source: source),
  );

  @override
  ConsumerState<TransactionPresetDialog> createState() => _State();
}

class _State extends ConsumerState<TransactionPresetDialog> {
  late String _type =
      widget.item?.preset.type ?? widget.source?.type ?? 'expense';
  late int? _accountId =
      widget.item?.preset.accountId ?? widget.source?.accountId;
  late int? _categoryId =
      widget.item?.preset.categoryId ?? widget.source?.categoryId;
  late int? _fromAccountId =
      widget.item?.preset.fromAccountId ?? widget.source?.fromAccountId;
  late int? _toAccountId =
      widget.item?.preset.toAccountId ?? widget.source?.toAccountId;
  late final _name = TextEditingController(
    text: widget.item?.preset.name ?? '',
  );
  late final _amount = TextEditingController(
    text:
        (widget.item?.preset.amount ?? widget.source?.amount)?.toString() ?? '',
  );
  late final _memo = TextEditingController(
    text: widget.item?.preset.memo ?? widget.source?.memo ?? '',
  );
  late final _tags = TextEditingController(
    text:
        (widget.item?.tagNames ??
                widget.source?.tags.map((tag) => tag.name).toList() ??
                const <String>[])
            .join(', '),
  );
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _memo.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateTransactionPreset(
      name: _name.text,
      type: _type,
      amount: parseKRW(_amount.text),
      memo: _memo.text,
      accountId: _accountId,
      categoryId: _categoryId,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
      tagNames: _tags.text.split(','),
    );
    if (result.isFail) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errors.values.first)));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(transactionPresetsDaoProvider)
          .savePreset(id: widget.item?.preset.id, draft: result.value!);
      refreshTransactionPresets(ref);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(settingsAccountsProvider).asData?.value ?? const <Account>[];
    final categories =
        ref.watch(settingsActiveCategoriesProvider).asData?.value ??
        const <Category>[];
    final visibleCategories = categories
        .where((category) => category.type == _type)
        .toList();
    return AlertDialog(
      title: Text(widget.item == null ? '프리셋 만들기' : '프리셋 수정'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('거래를 저장하는 화면이 아닙니다. 날짜와 시간은 프리셋을 불러올 때 현재값으로 입력됩니다.'),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('지출')),
                  ButtonSegment(value: 'income', label: Text('수입')),
                  ButtonSegment(value: 'transfer', label: Text('이체')),
                ],
                selected: {_type},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() {
                        _type = value.first;
                        _accountId = null;
                        _categoryId = null;
                        _fromAccountId = null;
                        _toAccountId = null;
                      }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '프리셋 이름(선택)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '금액',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_type == 'transfer') ...[
                _AccountDropdown(
                  label: '출금 자산',
                  accounts: accounts,
                  value: _fromAccountId,
                  onChanged: (value) => setState(() => _fromAccountId = value),
                ),
                const SizedBox(height: 12),
                _AccountDropdown(
                  label: '입금 자산',
                  accounts: accounts,
                  value: _toAccountId,
                  onChanged: (value) => setState(() => _toAccountId = value),
                ),
              ] else ...[
                _AccountDropdown(
                  label: '자산',
                  accounts: accounts,
                  value: _accountId,
                  onChanged: (value) => setState(() => _accountId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue:
                      visibleCategories.any((c) => c.id == _categoryId)
                      ? _categoryId
                      : null,
                  items: [
                    for (final category in visibleCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  decoration: const InputDecoration(
                    labelText: '카테고리',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _memo,
                decoration: const InputDecoration(
                  labelText: '메모',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tags,
                decoration: const InputDecoration(
                  labelText: '태그(쉼표로 구분)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(widget.item == null ? '프리셋 저장' : '수정 저장'),
        ),
      ],
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({
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
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: accounts.any((account) => account.id == value) ? value : null,
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
