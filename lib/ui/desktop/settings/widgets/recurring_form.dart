import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/recurring_dao.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../../features/recurring/validation.dart';
import '../../../desktop/transactions/widgets/form_fields.dart';
import 'package:my_little_budget/features/settings/providers.dart';

class RecurringForm extends ConsumerStatefulWidget {
  const RecurringForm({
    super.key,
    this.item,
    required this.accounts,
    required this.categories,
    required this.tags,
    required this.onDone,
  });

  final RecurringListItem? item;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Tag> tags;
  final VoidCallback onDone;

  @override
  ConsumerState<RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<RecurringForm> {
  late final _nameCtrl = TextEditingController(
    text: widget.item?.recurring.name ?? '',
  );
  late final _amountCtrl = TextEditingController(
    text: widget.item?.recurring.amount.toString() ?? '',
  );
  late final _startCtrl = TextEditingController(
    text: widget.item?.recurring.startDate ?? currentDateKey(),
  );
  late final _endCtrl = TextEditingController(
    text: widget.item?.recurring.endDate ?? '',
  );
  late final _timeCtrl = TextEditingController(
    text: widget.item?.recurring.occurredTime ?? '09:00',
  );
  late final _memoCtrl = TextEditingController(
    text: widget.item?.recurring.memo ?? '',
  );

  late String _type = widget.item?.recurring.type ?? 'expense';
  late String _frequency = widget.item?.recurring.frequency ?? 'monthly';
  late int? _accountId = widget.item?.recurring.accountId;
  late int? _categoryId = widget.item?.recurring.categoryId;
  late int? _fromAccountId = widget.item?.recurring.fromAccountId;
  late int? _toAccountId = widget.item?.recurring.toAccountId;
  late int _dayOfMonth = widget.item?.recurring.dayOfMonth ?? 1;
  late int _dayOfWeek = widget.item?.recurring.dayOfWeek ?? 1;
  late List<String> _tagNames = _parseTagNames(widget.item?.recurring.tagNames);
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _timeCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsedTime = parseTimeInput(_timeCtrl.text) ?? _timeCtrl.text.trim();
    final endDate = _endCtrl.text.trim().isEmpty ? null : _endCtrl.text.trim();
    final result = validateRecurring(
      type: _type,
      name: _nameCtrl.text,
      amount: parseKRW(_amountCtrl.text),
      frequency: _frequency,
      occurredTime: parsedTime,
      startDate: _startCtrl.text.trim(),
      dayOfMonth: _frequency == 'monthly' ? _dayOfMonth : null,
      dayOfWeek: _frequency == 'weekly' ? _dayOfWeek : null,
      endDate: endDate,
      memo: _memoCtrl.text,
      accountId: _accountId,
      categoryId: _categoryId,
      fromAccountId: _fromAccountId,
      toAccountId: _toAccountId,
      tagNames: _tagNames,
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
          .read(recurringDaoProvider)
          .saveRecurring(id: widget.item?.recurring.id, draft: result.value!);
      refreshRecurring(ref);
      widget.onDone();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = controller.text.trim().isEmpty
        ? DateTime.now()
        : parseDateKey(controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) controller.text = toDateKey(picked);
  }

  @override
  Widget build(BuildContext context) {
    final visibleCategories = widget.categories
        .where((c) => c.type == (_type == 'income' ? 'income' : 'expense'))
        .toList();
    final suggestions = widget.tags.map((t) => t.name).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameCtrl,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: '이름',
              hintText: '예: 월세, 구독, 월급',
              isDense: true,
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: SegmentedButton<String>(
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
              ),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '금액',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              SizedBox(
                width: 130,
                child: DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(
                    labelText: '주기',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('매월')),
                    DropdownMenuItem(value: 'weekly', child: Text('매주')),
                  ],
                  onChanged: (v) => setState(() => _frequency = v ?? 'monthly'),
                ),
              ),
              if (_frequency == 'monthly')
                SizedBox(
                  width: 110,
                  child: DropdownButtonFormField<int>(
                    initialValue: _dayOfMonth,
                    decoration: const InputDecoration(
                      labelText: '일',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 1; i <= 31; i++)
                        DropdownMenuItem(value: i, child: Text('$i일')),
                    ],
                    onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                  ),
                )
              else
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<int>(
                    initialValue: _dayOfWeek,
                    decoration: const InputDecoration(
                      labelText: '요일',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < 7; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(_weekdayLabels[i]),
                        ),
                    ],
                    onChanged: (v) => setState(() => _dayOfWeek = v ?? 1),
                  ),
                ),
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_type == 'transfer') ...[
                _AccountSelect(
                  label: '출금 자산',
                  accounts: widget.accounts,
                  value: _fromAccountId,
                  onChanged: (v) => setState(() => _fromAccountId = v),
                ),
                _AccountSelect(
                  label: '입금 자산',
                  accounts: widget.accounts,
                  value: _toAccountId,
                  onChanged: (v) => setState(() => _toAccountId = v),
                ),
              ] else ...[
                _CategorySelect(
                  categories: visibleCategories,
                  value: _categoryId,
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                _AccountSelect(
                  label: '자산',
                  accounts: widget.accounts,
                  value: _accountId,
                  onChanged: (v) => setState(() => _accountId = v),
                ),
              ],
            ],
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              _DateField(
                label: '시작일',
                controller: _startCtrl,
                onPick: () => _pickDate(_startCtrl),
              ),
              _DateField(
                label: '종료일',
                controller: _endCtrl,
                onPick: () => _pickDate(_endCtrl),
              ),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _timeCtrl,
                  decoration: const InputDecoration(
                    labelText: '시각',
                    hintText: 'HH:MM',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onEditingComplete: () {
                    final parsed = parseTimeInput(_timeCtrl.text);
                    if (parsed != null) _timeCtrl.text = parsed;
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: TagInput(
                  value: _tagNames,
                  suggestions: suggestions,
                  onChanged: (v) => setState(() => _tagNames = v),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          TextField(
            controller: _memoCtrl,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: '메모',
              isDense: true,
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '저장 중...' : '저장'),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: _busy ? null : widget.onDone,
                child: Text('취소'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _weekdayLabels = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];

class _AccountSelect extends StatelessWidget {
  const _AccountSelect({
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
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final a in accounts)
            DropdownMenuItem(value: a.id, child: Text(a.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _CategorySelect extends StatelessWidget {
  const _CategorySelect({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<Category> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<int>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: '카테고리',
          isDense: true,
          border: OutlineInputBorder(),
        ),
        items: [
          for (final c in categories)
            DropdownMenuItem(value: c.id, child: Text(c.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onPick,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            onPressed: onPick,
            icon: Icon(Icons.calendar_today, size: 14),
            tooltip: '날짜 선택',
          ),
        ),
      ),
    );
  }
}

List<String> _parseTagNames(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final parsed = jsonDecode(raw);
    if (parsed is List) {
      return parsed.whereType<String>().toList();
    }
  } catch (_) {
    // ignore invalid stored JSON
  }
  return const [];
}
