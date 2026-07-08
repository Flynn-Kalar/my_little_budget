import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/budget_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/budget/logic.dart';
import '../../../features/budget/validation.dart';
import 'package:my_little_budget/features/budget/providers.dart';
import 'widgets/budget_read_only_content.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetMonthProvider);
    final income = ref.watch(monthlyExpectedIncomeProvider);
    final rows = ref.watch(budgetRowsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '예산',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _BudgetMonthNav(month: month),
                _CopyPreviousMonthButton(month: month),
                _AddBudgetGroupButton(month: month),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '이전 달에서 복사할 때 같은 이름의 예산 그룹은 건너뜁니다.',
              style: TextStyle(color: context.desktopMuted, fontSize: 12),
            ),
            SizedBox(height: 16),
            income.when(
              data: (value) => _ExpectedIncomeCard(income: value),
              loading: () => const BudgetCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => BudgetErrorCard(message: error.toString()),
            ),
            SizedBox(height: 12),
            rows.when(
              data: (value) => BudgetReadOnlyContent(
                rows: value,
                onEditGroup: (row) =>
                    _BudgetGroupModeEditDialog.show(context, row),
                onDeleteGroup: (row) =>
                    _confirmDeleteBudgetGroup(context, ref, row),
              ),
              loading: () => const BudgetCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => BudgetErrorCard(message: error.toString()),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _CopyPreviousMonthButton extends ConsumerStatefulWidget {
  const _CopyPreviousMonthButton({required this.month});

  final String month;

  @override
  ConsumerState<_CopyPreviousMonthButton> createState() =>
      _CopyPreviousMonthButtonState();
}

class _CopyPreviousMonthButtonState
    extends ConsumerState<_CopyPreviousMonthButton> {
  bool _busy = false;

  Future<void> _copy() async {
    setState(() => _busy = true);
    final sourceMonth = shiftMonth(widget.month, -1);
    try {
      final copied = await ref
          .read(budgetDaoProvider)
          .copyBudgetGroupsWithCarryforward(sourceMonth, widget.month);
      if (!mounted) return;
      refreshBudget(ref);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$sourceMonth 예산에서 $copied개 그룹을 복사했습니다. 같은 이름의 그룹은 건너뜁니다.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : _copy,
      icon: _busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.copy_all_outlined, size: 18),
      label: Text('이전 달에서 복사'),
    );
  }
}

class _AddBudgetGroupButton extends StatelessWidget {
  const _AddBudgetGroupButton({required this.month});

  final String month;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _BudgetGroupModeDialog.show(context, month: month),
      icon: Icon(Icons.add, size: 18),
      label: Text('예산 그룹 추가'),
    );
  }
}

class _BudgetMonthNav extends ConsumerWidget {
  const _BudgetMonthNav({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      ref.read(budgetMonthProvider.notifier).state = shiftMonth(month, delta);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(budgetMonthProvider.notifier).state = currentMonthKey();
          },
          icon: Icon(Icons.calendar_month, size: 18),
          label: Text('${d.year}년 ${d.month}월'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _ExpectedIncomeCard extends ConsumerWidget {
  const _ExpectedIncomeCard({required this.income});

  final int income;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(budgetMonthProvider);

    return BudgetCard(
      child: Row(
        children: [
          Icon(Icons.payments_outlined, color: context.desktopIncome),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '이번 달 예상 소득',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatKRW(income),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: () => _ExpectedIncomeDialog.show(
              context,
              month: month,
              income: income,
            ),
            icon: Icon(Icons.edit_outlined),
            tooltip: '예상 수입 수정',
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteBudgetGroup(
  BuildContext context,
  WidgetRef ref,
  BudgetVsActual row,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('예산 그룹 삭제'),
      content: Text("'${row.groupName}' 예산 그룹을 삭제할까요?"),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await ref.read(budgetDaoProvider).deleteBudgetGroup(row.groupId);
  if (!context.mounted) return;
  refreshBudget(ref);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('예산 그룹을 삭제했습니다.')));
}

class _BudgetGroupCreateDialog extends ConsumerStatefulWidget {
  const _BudgetGroupCreateDialog({required this.month});

  final String month;

  @override
  ConsumerState<_BudgetGroupCreateDialog> createState() =>
      _BudgetGroupCreateDialogState();
}

class _BudgetGroupCreateDialogState
    extends ConsumerState<_BudgetGroupCreateDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _categoryIds = <int>{};
  bool _carryForward = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showSnack('그룹명을 입력해주세요.');
      return;
    }
    if (_categoryIds.isEmpty) {
      _showSnack('연결 카테고리를 선택해주세요.');
      return;
    }
    final amount = parseKRW(_amount.text);
    if (amount < 1) {
      _showSnack('월 예산 금액을 입력해주세요.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(budgetDaoProvider)
          .createBudgetGroup(
            name: name,
            month: widget.month,
            amount: amount,
            categoryIds: _categoryIds.toList(),
            carryForward: _carryForward,
          );
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예산 그룹을 추가했습니다.')));
    } catch (e) {
      if (mounted) _showSnack('예산 그룹 추가에 실패했습니다: $e');
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
    final categories = ref.watch(budgetExpenseCategoriesProvider);

    return AlertDialog(
      title: Text('예산 그룹 추가'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                decoration: const InputDecoration(labelText: '그룹명'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _amount,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '월 예산 금액',
                  suffixText: '원',
                ),
              ),
              SizedBox(height: 12),
              SwitchListTile(
                value: _carryForward,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _carryForward = value),
                contentPadding: EdgeInsets.zero,
                title: Text('carry-forward 사용'),
              ),
              SizedBox(height: 12),
              Text('연결 카테고리', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(height: 8),
              categories.when(
                data: (items) {
                  if (items.isEmpty) {
                    return Text(
                      '사용 가능한 지출 카테고리가 없습니다.',
                      style: TextStyle(color: context.desktopMuted),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final category in items)
                        FilterChip(
                          label: Text(category.name),
                          selected: _categoryIds.contains(category.id),
                          onSelected: _busy
                              ? null
                              : (selected) {
                                  setState(() {
                                    if (selected) {
                                      _categoryIds.add(category.id);
                                    } else {
                                      _categoryIds.remove(category.id);
                                    }
                                  });
                                },
                        ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(minHeight: 3),
                error: (error, _) => Text(
                  error.toString(),
                  style: TextStyle(color: context.desktopExpense),
                ),
              ),
              SizedBox(height: 12),
              Text(
                '고정 예산 그룹은 선택한 지출 카테고리의 사용액을 합산해 예산 대비 사용액을 계산합니다.',
                style: TextStyle(color: context.desktopMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}

enum _BudgetGroupMode {
  fixed('고정 금액'),
  percentage('소득 비율'),
  accountLinked('계좌 연동');

  const _BudgetGroupMode(this.label);
  final String label;
}

_BudgetGroupMode _modeForRow(BudgetVsActual row) {
  if (row.accountId != null) return _BudgetGroupMode.accountLinked;
  if (row.incomePercentage != null) return _BudgetGroupMode.percentage;
  return _BudgetGroupMode.fixed;
}

class _BudgetGroupModeDialog extends ConsumerStatefulWidget {
  const _BudgetGroupModeDialog({required this.month});

  final String month;

  static Future<void> show(BuildContext context, {required String month}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BudgetGroupModeDialog(month: month),
    );
  }

  @override
  ConsumerState<_BudgetGroupModeDialog> createState() =>
      _BudgetGroupModeDialogState();
}

class _BudgetGroupModeDialogState
    extends ConsumerState<_BudgetGroupModeDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _percentage = TextEditingController();
  final _categoryIds = <int>{};
  _BudgetGroupMode _mode = _BudgetGroupMode.fixed;
  int? _accountId;
  bool _carryForward = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _percentage.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateBudgetGroup(
      name: _name.text,
      month: widget.month,
      amount: _mode == _BudgetGroupMode.fixed ? parseKRW(_amount.text) : 0,
      categoryIds: _mode == _BudgetGroupMode.accountLinked
          ? const []
          : _categoryIds.toList(),
      accountId: _mode == _BudgetGroupMode.accountLinked ? _accountId : null,
      percentage: _mode == _BudgetGroupMode.percentage
          ? int.tryParse(_percentage.text.trim())
          : null,
      carryForward: _mode == _BudgetGroupMode.accountLinked
          ? false
          : _carryForward,
    );
    if (result.isFail) {
      _showSnack(result.errors.values.first);
      return;
    }

    setState(() => _busy = true);
    try {
      final draft = result.value!;
      await ref
          .read(budgetDaoProvider)
          .createBudgetGroup(
            name: draft.name,
            month: draft.month,
            amount: draft.amount,
            categoryIds: draft.categoryIds,
            accountId: draft.accountId,
            percentage: draft.percentage,
            carryForward: draft.carryForward,
          );
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예산 그룹을 추가했습니다.')));
    } catch (e) {
      if (mounted) _showSnack('예산 그룹 추가에 실패했습니다: $e');
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
    final categories = ref.watch(budgetExpenseCategoriesProvider);
    final accounts = ref.watch(budgetActiveAccountsProvider);
    final income = ref.watch(monthlyExpectedIncomeProvider).asData?.value ?? 0;
    final percent = int.tryParse(_percentage.text.trim()) ?? 0;
    final preview = percentageBase(expectedIncome: income, percentage: percent);

    return AlertDialog(
      title: Text('예산 그룹 추가'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                autofocus: true,
                decoration: const InputDecoration(labelText: '그룹명'),
              ),
              SizedBox(height: 12),
              SegmentedButton<_BudgetGroupMode>(
                segments: [
                  for (final mode in _BudgetGroupMode.values)
                    ButtonSegment(value: mode, label: Text(mode.label)),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (selected) => setState(() {
                        _mode = selected.first;
                        if (_mode == _BudgetGroupMode.accountLinked) {
                          _carryForward = false;
                        }
                      }),
              ),
              SizedBox(height: 12),
              if (_mode == _BudgetGroupMode.fixed) ...[
                TextField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '월 예산 금액',
                    suffixText: '원',
                  ),
                ),
                SizedBox(height: 12),
              ],
              if (_mode == _BudgetGroupMode.percentage) ...[
                TextField(
                  controller: _percentage,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '예상 수입 대비 비율',
                    suffixText: '%',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 8),
                Text(
                  '현재 예상 수입 ${formatKRW(income)} 기준: ${formatKRW(preview)}',
                  style: TextStyle(color: context.desktopMuted),
                ),
                SizedBox(height: 12),
              ],
              if (_mode == _BudgetGroupMode.accountLinked) ...[
                accounts.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Text(
                        '연결 가능한 계좌가 없습니다.',
                        style: TextStyle(color: context.desktopMuted),
                      );
                    }
                    return DropdownButtonFormField<int>(
                      initialValue: _accountId,
                      items: [
                        for (final account in items)
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(account.name),
                          ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _accountId = value),
                      decoration: const InputDecoration(labelText: '연결 계좌'),
                    );
                  },
                  loading: () => const LinearProgressIndicator(minHeight: 3),
                  error: (error, _) => Text(
                    error.toString(),
                    style: TextStyle(color: context.desktopExpense),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '계좌 연동 그룹은 선택 계좌의 월초 잔액과 이번 달 입출금 흐름으로 예산을 계산합니다. carry-forward와 카테고리 연결은 사용하지 않습니다.',
                  style: TextStyle(color: context.desktopMuted, fontSize: 12),
                ),
                SizedBox(height: 12),
              ],
              if (_mode != _BudgetGroupMode.accountLinked) ...[
                SwitchListTile(
                  value: _carryForward,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _carryForward = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text('carry-forward 사용'),
                ),
                SizedBox(height: 12),
                _CategorySelector(
                  categories: categories,
                  selectedIds: _categoryIds,
                  enabled: !_busy,
                  onChanged: () => setState(() {}),
                ),
                SizedBox(height: 12),
                Text(
                  '선택한 지출 카테고리의 사용액이 이 예산 그룹에 합산됩니다. 최소 1개 이상 선택해야 합니다.',
                  style: TextStyle(color: context.desktopMuted, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}

class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.categories,
    required this.selectedIds,
    required this.enabled,
    required this.onChanged,
  });

  final AsyncValue<List<Category>> categories;
  final Set<int> selectedIds;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('연결 카테고리', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 8),
        categories.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(
                '사용 가능한 지출 카테고리가 없습니다.',
                style: TextStyle(color: context.desktopMuted),
              );
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in items)
                  FilterChip(
                    label: Text(category.name),
                    selected: selectedIds.contains(category.id),
                    onSelected: enabled
                        ? (selected) {
                            if (selected) {
                              selectedIds.add(category.id);
                            } else {
                              selectedIds.remove(category.id);
                            }
                            onChanged();
                          }
                        : null,
                  ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (error, _) => Text(
            error.toString(),
            style: TextStyle(color: context.desktopExpense),
          ),
        ),
      ],
    );
  }
}

Future<void> _syncBudgetGroupCategories(
  BudgetDao dao,
  BudgetVsActual row,
  Set<int> selectedIds,
) async {
  final before = row.categories.map((category) => category.id).toSet();
  final toAdd = selectedIds.difference(before);
  final toRemove = before.difference(selectedIds);

  for (final categoryId in toAdd) {
    await dao.addCategoryToGroup(row.groupId, categoryId);
  }
  for (final categoryId in toRemove) {
    await dao.removeCategoryFromGroup(row.groupId, categoryId);
  }
}

class _AccountLinkedEditor extends ConsumerWidget {
  const _AccountLinkedEditor({
    required this.accountId,
    required this.month,
    required this.busy,
    required this.onChanged,
  });

  final int? accountId;
  final String month;
  final bool busy;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(budgetActiveAccountsProvider);
    final preview = accountId == null
        ? null
        : ref.watch(
            budgetAccountLinkedPreviewProvider((
              accountId: accountId!,
              month: month,
            )),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        accounts.when(
          data: (items) {
            if (items.isEmpty) {
              return Text(
                '연결 가능한 계좌가 없습니다.',
                style: TextStyle(color: context.desktopMuted),
              );
            }
            return DropdownButtonFormField<int>(
              initialValue: accountId,
              items: [
                for (final account in items)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: busy ? null : onChanged,
              decoration: const InputDecoration(labelText: '연결 계좌'),
            );
          },
          loading: () => const LinearProgressIndicator(minHeight: 3),
          error: (error, _) => Text(
            error.toString(),
            style: TextStyle(color: context.desktopExpense),
          ),
        ),
        SizedBox(height: 12),
        if (preview != null)
          preview.when(
            data: (value) => _AccountLinkedPreview(flow: value),
            loading: () => const LinearProgressIndicator(minHeight: 3),
            error: (error, _) => Text(
              error.toString(),
              style: TextStyle(color: context.desktopExpense),
            ),
          )
        else
          Text(
            '계좌를 선택하면 이번 달 예산 계산 preview가 표시됩니다.',
            style: TextStyle(color: context.desktopMuted, fontSize: 12),
          ),
      ],
    );
  }
}

class _AccountLinkedPreview extends StatelessWidget {
  const _AccountLinkedPreview({required this.flow});

  final ({int available, int spent}) flow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.desktopBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: BudgetAmountPair(
                label: '예산 preview',
                amount: flow.available,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: BudgetAmountPair(label: '사용 preview', amount: flow.spent),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetGroupModeEditDialog extends ConsumerStatefulWidget {
  const _BudgetGroupModeEditDialog({required this.row});

  final BudgetVsActual row;

  static Future<void> show(BuildContext context, BudgetVsActual row) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BudgetGroupModeEditDialog(row: row),
    );
  }

  @override
  ConsumerState<_BudgetGroupModeEditDialog> createState() =>
      _BudgetGroupModeEditDialogState();
}

class _BudgetGroupModeEditDialogState
    extends ConsumerState<_BudgetGroupModeEditDialog> {
  late final _amount = TextEditingController(
    text: widget.row.baseAmount.toString(),
  );
  late final _percentage = TextEditingController(
    text: widget.row.incomePercentage?.toString() ?? '',
  );
  late final _adjustment = TextEditingController(
    text: widget.row.adjustment.toString(),
  );
  late final Set<int> _categoryIds;
  late int? _accountId = widget.row.accountId;
  late bool _carryForward = widget.row.carryForward;
  bool _busy = false;

  _BudgetGroupMode get _mode => _modeForRow(widget.row);

  @override
  void initState() {
    super.initState();
    _categoryIds = widget.row.categories.map((category) => category.id).toSet();
  }

  @override
  void dispose() {
    _amount.dispose();
    _percentage.dispose();
    _adjustment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dao = ref.read(budgetDaoProvider);
    final percentage = int.tryParse(_percentage.text.trim());

    if (_mode == _BudgetGroupMode.accountLinked &&
        (_accountId == null || _accountId! <= 0)) {
      _showSnack('연결 계좌를 선택해 주세요.');
      return;
    }

    if (_mode != _BudgetGroupMode.accountLinked && _categoryIds.isEmpty) {
      _showSnack('연결 카테고리를 하나 이상 선택해 주세요.');
      return;
    }

    if (_mode == _BudgetGroupMode.percentage &&
        (percentage == null || percentage <= 0 || percentage > 1000)) {
      _showSnack('퍼센트는 1~1000 사이 정수여야 합니다.');
      return;
    }

    setState(() => _busy = true);
    try {
      if (_mode == _BudgetGroupMode.fixed) {
        await dao.updateBudgetGroupAmount(
          widget.row.groupId,
          parseKRW(_amount.text),
        );
      }
      if (_mode == _BudgetGroupMode.percentage) {
        await dao.updateBudgetGroupPercentage(widget.row.groupId, percentage);
      }
      if (_mode != _BudgetGroupMode.accountLinked) {
        await dao.updateBudgetGroupAdjustment(
          widget.row.groupId,
          parseKRW(_adjustment.text),
        );
        await dao.updateBudgetGroupCarryForward(
          widget.row.groupId,
          _carryForward,
        );
        await _syncBudgetGroupCategories(dao, widget.row, _categoryIds);
      }
      if (_mode == _BudgetGroupMode.accountLinked) {
        await dao.updateBudgetGroupAccount(widget.row.groupId, _accountId!);
      }
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('예산 그룹을 수정했습니다.')));
    } catch (e) {
      if (mounted) _showSnack('예산 그룹 수정에 실패했습니다: $e');
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
    final categories = ref.watch(budgetExpenseCategoriesProvider);
    final month = ref.watch(budgetMonthProvider);
    final income =
        widget.row.expectedIncome ??
        ref.watch(monthlyExpectedIncomeProvider).asData?.value ??
        0;
    final percent =
        int.tryParse(_percentage.text.trim()) ??
        widget.row.incomePercentage ??
        0;
    final preview = percentageBase(expectedIncome: income, percentage: percent);

    return AlertDialog(
      title: Text(widget.row.groupName),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BudgetInfoChip(label: _mode.label),
              SizedBox(height: 12),
              if (_mode == _BudgetGroupMode.fixed) ...[
                TextField(
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '월 예산 금액',
                    suffixText: '원',
                  ),
                ),
                SizedBox(height: 12),
              ],
              if (_mode == _BudgetGroupMode.percentage) ...[
                TextField(
                  controller: _percentage,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '예상 수입 대비 비율',
                    suffixText: '%',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 8),
                Text(
                  '현재 예상 수입 ${formatKRW(income)} 기준: ${formatKRW(preview)}',
                  style: TextStyle(color: context.desktopMuted),
                ),
                SizedBox(height: 12),
              ],
              if (_mode == _BudgetGroupMode.accountLinked) ...[
                _AccountLinkedEditor(
                  accountId: _accountId,
                  month: month,
                  busy: _busy,
                  onChanged: (value) => setState(() => _accountId = value),
                ),
              ] else ...[
                TextField(
                  controller: _adjustment,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '조정액',
                    suffixText: '원',
                  ),
                ),
                SizedBox(height: 12),
                SwitchListTile(
                  value: _carryForward,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _carryForward = value),
                  contentPadding: EdgeInsets.zero,
                  title: Text('carry-forward 사용'),
                ),
                SizedBox(height: 12),
                _CategorySelector(
                  categories: categories,
                  selectedIds: _categoryIds,
                  enabled: !_busy,
                  onChanged: () => setState(() {}),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}

class _ExpectedIncomeDialog extends ConsumerStatefulWidget {
  const _ExpectedIncomeDialog({required this.month, required this.income});

  final String month;
  final int income;

  static Future<void> show(
    BuildContext context, {
    required String month,
    required int income,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _ExpectedIncomeDialog(month: month, income: income),
    );
  }

  @override
  ConsumerState<_ExpectedIncomeDialog> createState() => _ExpectedIncomeState();
}

class _ExpectedIncomeState extends ConsumerState<_ExpectedIncomeDialog> {
  late final TextEditingController _income;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _income = TextEditingController(text: widget.income.toString());
  }

  @override
  void dispose() {
    _income.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(budgetDaoProvider)
          .setMonthlyExpectedIncome(widget.month, parseKRW(_income.text));
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('예상 수입 수정'),
      content: SizedBox(
        width: 360,
        child: TextField(
          controller: _income,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '월 예상 수입',
            suffixText: '원',
          ),
          onSubmitted: (_) => _busy ? null : _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}

class _BudgetGroupEditDialog extends ConsumerStatefulWidget {
  const _BudgetGroupEditDialog({required this.row});

  final BudgetVsActual row;

  @override
  ConsumerState<_BudgetGroupEditDialog> createState() =>
      _BudgetGroupEditDialogState();
}

class _BudgetGroupEditDialogState
    extends ConsumerState<_BudgetGroupEditDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _adjustment;
  late bool _carryForward;
  bool _busy = false;

  bool get _canEditAmount =>
      widget.row.accountId == null && widget.row.incomePercentage == null;
  bool get _canEditCarryForward => widget.row.accountId == null;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: widget.row.baseAmount.toString());
    _adjustment = TextEditingController(text: widget.row.adjustment.toString());
    _carryForward = widget.row.carryForward;
  }

  @override
  void dispose() {
    _amount.dispose();
    _adjustment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final dao = ref.read(budgetDaoProvider);
      if (_canEditAmount) {
        await dao.updateBudgetGroupAmount(
          widget.row.groupId,
          parseKRW(_amount.text),
        );
      }
      if (widget.row.accountId == null) {
        await dao.updateBudgetGroupAdjustment(
          widget.row.groupId,
          parseKRW(_adjustment.text),
        );
      }
      if (_canEditCarryForward) {
        await dao.updateBudgetGroupCarryForward(
          widget.row.groupId,
          _carryForward,
        );
      }
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final modeMessage = widget.row.accountId != null
        ? '자산 연동 그룹은 자산 흐름으로 예산이 계산되어 금액/조정/이월을 수정하지 않습니다.'
        : widget.row.incomePercentage != null
        ? '소득 비율 그룹의 기준 예산은 예상 수입과 비율로 계산됩니다. 이번 단계에서는 조정액과 이월만 수정합니다.'
        : null;

    return AlertDialog(
      title: Text(widget.row.groupName),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (modeMessage != null) ...[
              Text(modeMessage, style: TextStyle(color: context.desktopMuted)),
              SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              enabled: _canEditAmount && !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '기준 예산',
                suffixText: '원',
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _adjustment,
              enabled: widget.row.accountId == null && !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '조정액',
                suffixText: '원',
              ),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              value: _carryForward,
              onChanged: _canEditCarryForward && !_busy
                  ? (value) => setState(() => _carryForward = value)
                  : null,
              contentPadding: EdgeInsets.zero,
              title: Text('잔액 이월'),
              subtitle: Text('남은 예산을 다음 달 조정액으로 이월합니다.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}
