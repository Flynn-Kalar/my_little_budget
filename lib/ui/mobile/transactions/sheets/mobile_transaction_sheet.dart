import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/transactions/providers.dart';
import '../../../../features/transactions/validation.dart';

final _quickInputTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(tagsDaoProvider).getRecommendedTags(limit: 8),
);

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

  Future<void> _openAmountCalculator() async {
    FocusScope.of(context).unfocus();
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _AmountCalculatorPage(initialValue: _amount.text),
      ),
    );
    if (!mounted || result == null) return;
    _amount.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
    _focusMemo();
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
              key: const ValueKey('mobile-transaction-amount-field'),
              controller: _amount,
              enabled: !_busy,
              readOnly: true,
              showCursor: false,
              keyboardType: TextInputType.none,
              onTap: _busy ? null : _openAmountCalculator,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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

class _AmountCalculatorPage extends StatefulWidget {
  const _AmountCalculatorPage({required this.initialValue});

  final String initialValue;

  @override
  State<_AmountCalculatorPage> createState() => _AmountCalculatorPageState();
}

class _AmountCalculatorPageState extends State<_AmountCalculatorPage> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      final result = parseKRW(text).toString();
      _controller.value = TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    }
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const ValueKey('mobile-transaction-amount-calculator-page'),
      appBar: AppBar(
        title: const Text('금액'),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
          tooltip: '닫기',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final display = value.text.isEmpty ? '0' : value.text;
                      return Text(
                        display,
                        key: const ValueKey(
                          'mobile-transaction-calculator-display',
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _AmountKeypad(
                controller: _controller,
                enabled: true,
                onDone: _complete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountKeypad extends StatelessWidget {
  const _AmountKeypad({
    required this.controller,
    required this.enabled,
    required this.onDone,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onDone;

  static const _rows = [
    [
      _AmountKey('C', _AmountKeyAction.clear),
      _AmountKey('backspace', _AmountKeyAction.backspace),
      _AmountKey('()', _AmountKeyAction.parentheses),
      _AmountKey('÷', _AmountKeyAction.input),
    ],
    [
      _AmountKey('7', _AmountKeyAction.input),
      _AmountKey('8', _AmountKeyAction.input),
      _AmountKey('9', _AmountKeyAction.input),
      _AmountKey('×', _AmountKeyAction.input),
    ],
    [
      _AmountKey('4', _AmountKeyAction.input),
      _AmountKey('5', _AmountKeyAction.input),
      _AmountKey('6', _AmountKeyAction.input),
      _AmountKey('-', _AmountKeyAction.input),
    ],
    [
      _AmountKey('1', _AmountKeyAction.input),
      _AmountKey('2', _AmountKeyAction.input),
      _AmountKey('3', _AmountKeyAction.input),
      _AmountKey('+', _AmountKeyAction.input),
    ],
    [
      _AmountKey('00', _AmountKeyAction.input),
      _AmountKey('0', _AmountKeyAction.input),
      _AmountKey('.', _AmountKeyAction.input),
      _AmountKey('=', _AmountKeyAction.done),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('mobile-transaction-amount-keypad'),
      color: Colors.transparent,
      child: Column(
        children: [
          for (final row in _rows) ...[
            Row(
              children: [
                for (final key in row) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: _AmountKeyButton(
                        item: key,
                        enabled: enabled,
                        onPressed: () => _handle(key),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handle(_AmountKey key) {
    if (!enabled) return;
    switch (key.action) {
      case _AmountKeyAction.input:
        _insert(key.label);
      case _AmountKeyAction.parentheses:
        _insert(_nextParenthesis());
      case _AmountKeyAction.clear:
        controller.clear();
      case _AmountKeyAction.backspace:
        _backspace();
      case _AmountKeyAction.done:
        final text = controller.text.trim();
        if (text.isNotEmpty) {
          _replaceAll(parseKRW(text).toString());
        }
        onDone();
    }
  }

  void _insert(String value) {
    final current = controller.value;
    final selection = current.selection;
    final text = current.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final normalizedStart = start.clamp(0, text.length).toInt();
    final normalizedEnd = end.clamp(0, text.length).toInt();
    final nextText = text.replaceRange(normalizedStart, normalizedEnd, value);
    final offset = normalizedStart + value.length;
    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  void _backspace() {
    final current = controller.value;
    final selection = current.selection;
    final text = current.text;
    if (text.isEmpty) return;
    if (selection.isValid && !selection.isCollapsed) {
      final start = selection.start.clamp(0, text.length).toInt();
      final end = selection.end.clamp(0, text.length).toInt();
      controller.value = TextEditingValue(
        text: text.replaceRange(start, end, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      return;
    }

    final cursor = selection.isValid ? selection.start : text.length;
    final offset = cursor.clamp(0, text.length).toInt();
    if (offset == 0) return;
    controller.value = TextEditingValue(
      text: text.replaceRange(offset - 1, offset, ''),
      selection: TextSelection.collapsed(offset: offset - 1),
    );
  }

  String _nextParenthesis() {
    final selection = controller.selection;
    final text = controller.text;
    final cursor = selection.isValid
        ? selection.start.clamp(0, text.length).toInt()
        : text.length;
    final beforeCursor = text.substring(0, cursor);
    final openCount = '('.allMatches(beforeCursor).length;
    final closeCount = ')'.allMatches(beforeCursor).length;
    return openCount > closeCount ? ')' : '(';
  }

  void _replaceAll(String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _AmountKeyButton extends StatelessWidget {
  const _AmountKeyButton({
    required this.item,
    required this.enabled,
    required this.onPressed,
  });

  final _AmountKey item;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAction = item.action != _AmountKeyAction.input;
    final isDone = item.action == _AmountKeyAction.done;
    final foreground = isDone
        ? theme.colorScheme.onPrimary
        : item.action == _AmountKeyAction.clear ||
              item.action == _AmountKeyAction.backspace
        ? context.appExpense
        : theme.colorScheme.onSurface;
    final background = isDone
        ? theme.colorScheme.primary
        : isAction ||
              item.label == '+' ||
              item.label == '-' ||
              item.label == '×' ||
              item.label == '÷'
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;

    return SizedBox(
      height: 54,
      child: FilledButton(
        key: ValueKey('mobile-transaction-keypad-${item.label}'),
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: 0.38),
          foregroundColor: foreground,
          disabledForegroundColor: foreground.withValues(alpha: 0.38),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: item.action == _AmountKeyAction.backspace
            ? const Icon(Icons.backspace_outlined, size: 24)
            : Text(
                item.label,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

enum _AmountKeyAction { input, parentheses, clear, backspace, done }

class _AmountKey {
  const _AmountKey(this.label, this.action);

  final String label;
  final _AmountKeyAction action;
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
