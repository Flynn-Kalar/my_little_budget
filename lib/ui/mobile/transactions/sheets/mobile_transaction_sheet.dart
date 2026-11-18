import '../../../../features/settings/statement_period.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transaction_presets_dao.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/transactions/providers.dart';
import '../../../../features/transactions/validation.dart';
import '../../../../features/settings/providers.dart';
import '../../../shared/spending_limit_warning.dart';
import '../../../shared/transaction_budget_preview.dart';
import '../../../shared/transaction_tag_picker.dart';
import '../../../shared/installment_field.dart';
import '../../../shared/recent_transaction_suggestions.dart';
import '../../mobile_widgets.dart';

class MobileTransactionSheet extends ConsumerStatefulWidget {
  const MobileTransactionSheet({super.key, this.row, this.duplicate = false});

  final TransactionRow? row;
  final bool duplicate;

  static Future<void> show(BuildContext context, {TransactionRow? row}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => MobileTransactionSheet(row: row),
    );
  }

  static Future<void> showDuplicate(BuildContext context, TransactionRow row) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (_) => MobileTransactionSheet(row: row, duplicate: true),
    );
  }

  @override
  ConsumerState<MobileTransactionSheet> createState() =>
      _MobileTransactionSheetState();
}

class _MobileTransactionSheetState
    extends ConsumerState<MobileTransactionSheet> {
  late String _type = widget.row?.type ?? 'expense';
  late DateTime _date = widget.row == null
      ? DateTime.now()
      : parseDateKey(widget.row!.occurredOn);
  late TimeOfDay _time =
      _parseTimeOfDay(widget.row?.occurredTime) ??
      TimeOfDay.fromDateTime(DateTime.now());
  late int? _accountId = widget.row?.accountId;
  late int? _installmentMonths = widget.row?.installmentMonths;
  late int? _categoryId = widget.row?.categoryId;
  late int? _fromAccountId = widget.row?.fromAccountId;
  late int? _toAccountId = widget.row?.toAccountId;
  late final _amount = TextEditingController(
    text: widget.row?.amount.toString() ?? '',
  );
  late final _memo = TextEditingController(text: widget.row?.memo ?? '');
  final _memoFocus = FocusNode();
  late final Set<String> _tagNames =
      widget.row?.tags.map((tag) => tag.name).toSet() ?? <String>{};
  bool _busy = false;
  bool _dateExpanded = false;

  bool get _isEdit => widget.row != null && !widget.duplicate;
  bool get _isDuplicate => widget.row != null && widget.duplicate;

  @override
  void dispose() {
    _amount.dispose();
    _memo.dispose();
    _memoFocus.dispose();
    super.dispose();
  }

  void _focusMemo() {
    _memoFocus.requestFocus();
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

  Future<void> _pickPreset() async {
    final items = await ref.read(transactionPresetItemsProvider.future);
    if (!mounted) return;
    final item = await showModalBottomSheet<TransactionPresetListItem>(
      context: context,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (pickerContext) => SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '프리셋 불러오기',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const ListTile(title: Text('저장된 프리셋이 없습니다.'))
            else
              for (final item in items)
                ListTile(
                  enabled: item.isUsable,
                  leading: Icon(
                    item.isUsable
                        ? Icons.bookmark_outline
                        : Icons.warning_amber_outlined,
                  ),
                  title: Text(item.displayName),
                  subtitle: Text(
                    '${formatKRW(item.preset.amount)}'
                    '${item.isUsable ? '' : ' · 사용 불가'}',
                  ),
                  onTap: item.isUsable
                      ? () => Navigator.pop(pickerContext, item)
                      : null,
                ),
          ],
        ),
      ),
    );
    if (item == null || !mounted) return;
    final now = DateTime.now();
    setState(() {
      final draft = item.toDraft();
      _type = draft.type;
      _date = now;
      _time = TimeOfDay.fromDateTime(now);
      _accountId = draft.accountId;
      _installmentMonths = draft.installmentMonths;
      _categoryId = draft.categoryId;
      _fromAccountId = draft.fromAccountId;
      _toAccountId = draft.toAccountId;
      _amount.text = draft.amount.toString();
      _memo.text = draft.memo ?? '';
      _tagNames
        ..clear()
        ..addAll(draft.tagNames);
    });
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
      installmentMonths: _type == 'expense' ? _installmentMonths : null,
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
      final statementPolicy = await ref.read(statementPeriodProvider.future);
      final statementMonth = statementPolicy.anchorForDate(
        DateTime.parse(result.value!.occurredOn),
      );
      final budgetWarnings = await ref
          .read(budgetDaoProvider)
          .budgetLimitWarningsFor(
            result.value!,
            statementMonth: statementMonth,
            period: statementPolicy.range(statementMonth),
          );
      if (!mounted) return;
      refreshTransactions(ref);
      Navigator.pop(context);
      showSpendingLimitWarnings(
        context,
        cardWarning: warning,
        budgetWarnings: budgetWarnings,
      );
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
    final tags =
        ref
            .watch(transactionTagSuggestionsProvider(_categoryId))
            .asData
            ?.value ??
        ref.watch(allTagsProvider).asData?.value ??
        const <Tag>[];
    final visibleCategories = categories
        .where(
          (category) =>
              category.type == (_type == 'income' ? 'income' : 'expense'),
        )
        .toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        mobileBottomPadding(context, spacing: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isDuplicate ? '거래 복사' : (_isEdit ? '거래 수정' : '거래 추가'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isEdit)
                TextButton.icon(
                  key: const ValueKey('mobile-transaction-preset-button'),
                  onPressed: _busy ? null : _pickPreset,
                  icon: const Icon(Icons.bookmarks_outlined),
                  label: const Text('프리셋 불러오기'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                            _installmentMonths = null;
                            _categoryId = null;
                          }),
                  ),
                  const SizedBox(height: 10),
                  MobileAmountField(
                    fieldKey: const ValueKey('mobile-transaction-amount-field'),
                    controller: _amount,
                    enabled: !_busy,
                    suffixText: null,
                    onCompleted: _focusMemo,
                    previewBuilder: _preview,
                  ),
                  const SizedBox(height: 10),
                  if (_type == 'transfer') ...[
                    _AccountField(
                      label: '출금 자산',
                      accounts: accounts,
                      value: _fromAccountId,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _fromAccountId = v),
                    ),
                    const SizedBox(height: 10),
                    _AccountField(
                      label: '입금 자산',
                      accounts: accounts,
                      value: _toAccountId,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _toAccountId = v),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _AccountField(
                            label: '자산',
                            accounts: accounts,
                            value: _accountId,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    _accountId = v;
                                    if (!accounts.any(
                                      (a) => a.id == v && a.kind == 'card',
                                    )) {
                                      _installmentMonths = null;
                                    }
                                  }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryField(
                            categories: visibleCategories,
                            value: _categoryId,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _categoryId = v),
                          ),
                        ),
                      ],
                    ),
                  _preview(_amount),
                  if (_type == 'expense' &&
                      accounts.any(
                        (a) => a.id == _accountId && a.kind == 'card',
                      ))
                    InstallmentField(
                      months: _installmentMonths,
                      amountController: _amount,
                      purchaseDate: _date,
                      account: accounts
                          .where((a) => a.id == _accountId)
                          .firstOrNull,
                      onChanged: _busy
                          ? null
                          : (value) =>
                                setState(() => _installmentMonths = value),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey('mobile-transaction-memo-field'),
                    controller: _memo,
                    focusNode: _memoFocus,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: '메모',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (!_isEdit)
                    RecentTransactionSuggestions(
                      controller: _memo,
                      type: _type,
                      enabled: !_busy,
                      onSelected: (row) => setState(() {
                        _memo.text = row.memo ?? '';
                        _accountId = row.accountId;
                        _installmentMonths = row.installmentMonths;
                        _categoryId = row.categoryId;
                        _fromAccountId = row.fromAccountId;
                        _toAccountId = row.toAccountId;
                        _tagNames
                          ..clear()
                          ..addAll(row.tags.map((t) => t.name));
                      }),
                    ),
                  const SizedBox(height: 8),
                  TransactionTagPicker(
                    tags: tags,
                    categoryId: _categoryId,
                    type: _type,
                    value: _tagNames.toList(),
                    enabled: !_busy,
                    keyPrefix: 'mobile',
                    onChanged: (names) => setState(() {
                      _tagNames
                        ..clear()
                        ..addAll(names);
                    }),
                  ),
                  TextButton.icon(
                    key: const ValueKey('mobile-transaction-date-toggle'),
                    onPressed: _busy
                        ? null
                        : () => setState(() => _dateExpanded = !_dateExpanded),
                    icon: Icon(
                      _dateExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    label: Text(
                      '날짜·시간  ${toDateKey(_date)} ${_timeKey(_time)}',
                    ),
                  ),
                  if (_dateExpanded)
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
                ],
              ),
            ),
          ),
          const Divider(height: 16),
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
    );
  }

  Widget _preview(TextEditingController controller) => TransactionBudgetPreview(
    amountController: controller,
    type: _type,
    date: _date,
    accountId: _accountId,
    categoryId: _categoryId,
    editingId: _isEdit ? widget.row?.id : null,
    enabled: !_busy,
  );
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
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey(value),
      isExpanded: true,
      initialValue: accounts.any((account) => account.id == value)
          ? value
          : null,
      items: [
        for (final account in accounts)
          DropdownMenuItem(
            value: account.id,
            child: Text(account.name, overflow: TextOverflow.ellipsis),
          ),
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
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      key: ValueKey(value),
      isExpanded: true,
      initialValue: categories.any((category) => category.id == value)
          ? value
          : null,
      items: [
        for (final category in categories)
          DropdownMenuItem(
            value: category.id,
            child: Text(category.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
      decoration: const InputDecoration(
        labelText: '카테고리',
        border: OutlineInputBorder(),
      ),
    );
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
