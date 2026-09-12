import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/recurring_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/recurring/validation.dart';
import 'package:my_little_budget/features/settings/providers.dart';
import '../mobile_widgets.dart';

class MobileRecurringScreen extends ConsumerWidget {
  const MobileRecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringItemsProvider);
    return MobilePageScaffold(
      title: '반복 거래',
      onAdd: () => _RecurringSheet.show(context),
      addTooltip: '반복거래 추가',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        MobileAsync(
          value: items,
          builder: (value) {
            if (value.isEmpty) return const EmptyMobileCard('반복거래가 없습니다.');
            return Column(
              children: [for (final item in value) _RecurringCard(item: item)],
            );
          },
        ),
      ],
    );
  }
}

class _RecurringCard extends ConsumerWidget {
  const _RecurringCard({required this.item});

  final RecurringListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recurring = item.recurring;
    return MobileCard(
      child: InkWell(
        onTap: () => _RecurringSheet.show(context, item: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recurring.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                Switch(
                  value: recurring.active,
                  onChanged: (value) async {
                    await ref
                        .read(recurringDaoProvider)
                        .toggleRecurringActive(recurring.id, value);
                    refreshRecurring(ref);
                  },
                ),
              ],
            ),
            AmountLine(
              label: _typeLabel(recurring.type),
              value: formatKRW(recurring.amount),
            ),
            Text(
              switch (recurring.frequency) {
                'weekly' => '매주 ${_weekdayLabel(recurring.dayOfWeek)}',
                'daily' =>
                  recurring.includeNonBusinessDays
                      ? '매일 · 주말·공휴일 포함'
                      : '매일 · 주말·공휴일 제외',
                _ =>
                  recurring.monthlyMode == 'nth_weekday'
                      ? '매월 ${recurring.weekOfMonth}주차 '
                            '${_weekdayLabel(recurring.dayOfWeek)}'
                      : '매월 ${recurring.dayOfMonth ?? 1}일'
                            '${_monthlyAdjustmentLabel(recurring.nonBusinessDayAdjustment)}',
              },
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringSheet extends ConsumerStatefulWidget {
  const _RecurringSheet({this.item});

  final RecurringListItem? item;

  static Future<void> show(BuildContext context, {RecurringListItem? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecurringSheet(item: item),
    );
  }

  @override
  ConsumerState<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends ConsumerState<_RecurringSheet> {
  late final _name = TextEditingController(
    text: widget.item?.recurring.name ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.item?.recurring.amount.toString() ?? '',
  );
  late final _memo = TextEditingController(
    text: widget.item?.recurring.memo ?? '',
  );
  late final _time = TextEditingController(
    text: widget.item?.recurring.occurredTime ?? nowTime(),
  );
  late final _dayOfMonthCtrl = TextEditingController(
    text: (widget.item?.recurring.dayOfMonth ?? 1).toString(),
  );
  late DateTime _startDate = widget.item == null
      ? DateTime.now()
      : parseDateKey(widget.item!.recurring.startDate);
  late DateTime? _endDate = widget.item?.recurring.endDate == null
      ? null
      : parseDateKey(widget.item!.recurring.endDate!);
  late final Set<String> _tagNames = _parseTagNames(
    widget.item?.recurring.tagNames,
  ).toSet();
  late String _type = widget.item?.recurring.type ?? 'expense';
  late String _frequency = widget.item?.recurring.frequency ?? 'monthly';
  late int _dayOfMonth = widget.item?.recurring.dayOfMonth ?? 1;
  late int _dayOfWeek = widget.item?.recurring.dayOfWeek ?? 1;
  late String _monthlyMode = widget.item?.recurring.monthlyMode ?? 'day';
  late int _weekOfMonth = widget.item?.recurring.weekOfMonth ?? 1;
  late String _nonBusinessDayAdjustment =
      widget.item?.recurring.nonBusinessDayAdjustment ?? 'same';
  late bool _includeNonBusinessDays =
      widget.item?.recurring.includeNonBusinessDays ?? true;
  late int? _accountId = widget.item?.recurring.accountId;
  late int? _categoryId = widget.item?.recurring.categoryId;
  late int? _fromAccountId = widget.item?.recurring.fromAccountId;
  late int? _toAccountId = widget.item?.recurring.toAccountId;
  bool _busy = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _memo.dispose();
    _time.dispose();
    _dayOfMonthCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _save() async {
    final result = validateRecurring(
      type: _type,
      name: _name.text,
      amount: parseKRW(_amount.text),
      frequency: _frequency,
      occurredTime: parseTimeInput(_time.text) ?? _time.text.trim(),
      startDate: toDateKey(_startDate),
      endDate: _endDate == null ? null : toDateKey(_endDate!),
      dayOfMonth: _dayOfMonth,
      dayOfWeek: _dayOfWeek,
      monthlyMode: _monthlyMode,
      weekOfMonth: _weekOfMonth,
      nonBusinessDayAdjustment: _nonBusinessDayAdjustment,
      includeNonBusinessDays: _includeNonBusinessDays,
      memo: _memo.text,
      accountId: _accountId,
      categoryId: _categoryId,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
      tagNames: _tagNames.toList(),
    );
    if (result.isFail) {
      _showSnack('필수 입력값을 확인해주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(recurringDaoProvider)
          .saveRecurring(id: widget.item?.recurring.id, draft: result.value!);
      if (!mounted) return;
      refreshRecurring(ref);
      Navigator.pop(context);
      _showSnack(_isEdit ? '반복거래를 수정했습니다.' : '반복거래를 추가했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    await ref.read(recurringDaoProvider).deleteRecurring(item.recurring.id);
    if (!mounted) return;
    refreshRecurring(ref);
    Navigator.pop(context);
    _showSnack('반복거래를 삭제했습니다.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(settingsAccountsProvider).asData?.value ?? const <Account>[];
    final categories =
        ref.watch(settingsActiveCategoriesProvider).asData?.value ??
        const <Category>[];
    final tags = ref.watch(settingsTagsProvider).asData?.value ?? const <Tag>[];
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
        bottom: mobileBottomPadding(context, spacing: 16),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '반복거래 수정' : '반복거래 추가',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
            MobileAmountField(controller: _amount, enabled: !_busy),
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
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'monthly', label: Text('매월')),
                ButtonSegment(value: 'weekly', label: Text('매주')),
                ButtonSegment(value: 'daily', label: Text('매일')),
              ],
              selected: {_frequency},
              showSelectedIcon: false,
              onSelectionChanged: _busy
                  ? null
                  : (selected) => setState(() => _frequency = selected.first),
            ),
            const SizedBox(height: 12),
            if (_frequency == 'monthly') ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'day', label: Text('N일')),
                  ButtonSegment(value: 'nth_weekday', label: Text('N주차 N요일')),
                ],
                selected: {_monthlyMode},
                showSelectedIcon: false,
                onSelectionChanged: _busy
                    ? null
                    : (selected) =>
                          setState(() => _monthlyMode = selected.first),
              ),
              const SizedBox(height: 12),
              if (_monthlyMode == 'day') ...[
                TextField(
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '반복 일자',
                    suffixText: '일',
                    border: OutlineInputBorder(),
                  ),
                  controller: _dayOfMonthCtrl,
                  onChanged: (value) => _dayOfMonth = int.tryParse(value) ?? 1,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _nonBusinessDayAdjustment,
                  items: const [
                    DropdownMenuItem(value: 'same', child: Text('당일 입력 유지')),
                    DropdownMenuItem(
                      value: 'previous',
                      child: Text('전 영업일로 당기기'),
                    ),
                    DropdownMenuItem(value: 'next', child: Text('다음 영업일로 미루기')),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(
                          () => _nonBusinessDayAdjustment = value ?? 'same',
                        ),
                  decoration: const InputDecoration(
                    labelText: '주말·공휴일 처리',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _weekOfMonth,
                        items: [
                          for (var i = 1; i <= 5; i++)
                            DropdownMenuItem(value: i, child: Text('$i주차')),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) =>
                                  setState(() => _weekOfMonth = value ?? 1),
                        decoration: const InputDecoration(
                          labelText: '주차',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _RecurringWeekdayField(
                        value: _dayOfWeek,
                        enabled: !_busy,
                        onChanged: (value) =>
                            setState(() => _dayOfWeek = value),
                      ),
                    ),
                  ],
                ),
            ] else if (_frequency == 'weekly')
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('월요일')),
                  DropdownMenuItem(value: 2, child: Text('화요일')),
                  DropdownMenuItem(value: 3, child: Text('수요일')),
                  DropdownMenuItem(value: 4, child: Text('목요일')),
                  DropdownMenuItem(value: 5, child: Text('금요일')),
                  DropdownMenuItem(value: 6, child: Text('토요일')),
                  DropdownMenuItem(value: 0, child: Text('일요일')),
                ],
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _dayOfWeek = value ?? 1),
                decoration: const InputDecoration(
                  labelText: '요일',
                  border: OutlineInputBorder(),
                ),
              )
            else
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('주말·공휴일 포함'),
                subtitle: Text(
                  _includeNonBusinessDays
                      ? '토·일요일과 대한민국 공휴일에도 거래를 생성합니다.'
                      : '평일 중 대한민국 공휴일이 아닌 날에만 생성합니다.',
                ),
                value: _includeNonBusinessDays,
                onChanged: _busy
                    ? null
                    : (value) =>
                          setState(() => _includeNonBusinessDays = value),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _time,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '발생 시각',
                hintText: 'HH:MM',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickStartDate,
                    icon: const Icon(Icons.event, size: 16),
                    label: Text('시작 ${toDateKey(_startDate)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickEndDate,
                    icon: const Icon(Icons.event_available, size: 16),
                    label: Text(
                      _endDate == null
                          ? '종료일 없음'
                          : '종료 ${toDateKey(_endDate!)}',
                    ),
                  ),
                ),
              ],
            ),
            if (_endDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _endDate = null),
                  child: const Text('종료일 제거'),
                ),
              ),
            const SizedBox(height: 12),
            _RecurringTagSelector(
              tags: tags,
              selectedNames: _tagNames,
              enabled: !_busy,
              onChanged: () => setState(() {}),
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

class _RecurringWeekdayField extends StatelessWidget {
  const _RecurringWeekdayField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      items: const [
        DropdownMenuItem(value: 1, child: Text('월요일')),
        DropdownMenuItem(value: 2, child: Text('화요일')),
        DropdownMenuItem(value: 3, child: Text('수요일')),
        DropdownMenuItem(value: 4, child: Text('목요일')),
        DropdownMenuItem(value: 5, child: Text('금요일')),
        DropdownMenuItem(value: 6, child: Text('토요일')),
        DropdownMenuItem(value: 0, child: Text('일요일')),
      ],
      onChanged: enabled
          ? (value) {
              if (value != null) onChanged(value);
            }
          : null,
      decoration: const InputDecoration(
        labelText: '요일',
        border: OutlineInputBorder(),
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

class _RecurringTagSelector extends StatelessWidget {
  const _RecurringTagSelector({
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

List<String> _parseTagNames(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    if (parsed is List) {
      return parsed
          .whereType<String>()
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
    }
  } catch (_) {
    // Ignore malformed legacy values.
  }
  return const [];
}

String _typeLabel(String type) => switch (type) {
  'income' => '수입',
  'expense' => '지출',
  'transfer' => '이체',
  _ => type,
};

String _weekdayLabel(int? value) => switch (value) {
  0 => '일요일',
  1 => '월요일',
  2 => '화요일',
  3 => '수요일',
  4 => '목요일',
  5 => '금요일',
  6 => '토요일',
  _ => '월요일',
};

String _monthlyAdjustmentLabel(String value) => switch (value) {
  'previous' => ' · 전 영업일',
  'next' => ' · 후 영업일',
  _ => '',
};
