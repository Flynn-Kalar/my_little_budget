import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/budget_dao.dart';
import '../../../data/providers.dart';
import 'providers.dart';

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
            const Text(
              '예산',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _BudgetMonthNav(month: month),
            const SizedBox(height: 16),
            income.when(
              data: (value) => _ExpectedIncomeCard(income: value),
              loading: () => const _BudgetCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 12),
            rows.when(
              data: (value) => _BudgetReadOnlyContent(rows: value),
              loading: () => const _BudgetCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _BudgetReadOnlyContent extends StatelessWidget {
  const _BudgetReadOnlyContent({required this.rows});

  final List<BudgetVsActual> rows;

  @override
  Widget build(BuildContext context) {
    final totalBudget = rows.fold<int>(0, (sum, row) => sum + row.budgetAmount);
    final totalSpent = rows.fold<int>(0, (sum, row) => sum + row.spentAmount);
    final remaining = totalBudget - totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BudgetSummary(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          remaining: remaining,
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const _EmptyBudgetGroups()
        else
          Column(
            children: [
              for (final row in rows) ...[
                _BudgetGroupCard(row: row),
                const SizedBox(height: 10),
              ],
            ],
          ),
      ],
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
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(budgetMonthProvider.notifier).state = currentMonthKey();
          },
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text('${d.year}년 ${d.month}월'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
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

    return _BudgetCard(
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppTokens.income),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '이번 달 예상 소득',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            formatKRW(income),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _ExpectedIncomeDialog.show(
              context,
              month: month,
              income: income,
            ),
            icon: const Icon(Icons.edit_outlined),
            tooltip: '예상 수입 수정',
          ),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({
    required this.totalBudget,
    required this.totalSpent,
    required this.remaining,
  });

  final int totalBudget;
  final int totalSpent;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: '총 예산',
            amount: totalBudget,
            icon: Icons.flag_outlined,
            color: AppTokens.income,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '총 사용액',
            amount: totalSpent,
            icon: Icons.receipt_long_outlined,
            color: AppTokens.expense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '남은 금액',
            amount: remaining,
            icon: Icons.savings_outlined,
            color: remaining < 0 ? AppTokens.expense : AppTokens.accent,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _BudgetCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTokens.muted)),
                const SizedBox(height: 4),
                Text(
                  formatKRW(amount),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetGroupCard extends ConsumerWidget {
  const _BudgetGroupCard({required this.row});

  final BudgetVsActual row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overBudget = row.spentAmount > row.budgetAmount;
    final progress = row.budgetAmount <= 0
        ? null
        : (row.spentAmount / row.budgetAmount).clamp(0.0, 1.0);

    return _BudgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.groupName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _ModeChip(row: row),
              const SizedBox(width: 4),
              IconButton(
                onPressed: () => _BudgetGroupEditDialog.show(context, row),
                icon: const Icon(Icons.edit_outlined),
                tooltip: '예산 그룹 수정',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppTokens.sidebarBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? AppTokens.expense : AppTokens.income,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _AmountPair(label: '예산', amount: row.budgetAmount),
              const SizedBox(width: 24),
              _AmountPair(label: '사용', amount: row.spentAmount),
              const SizedBox(width: 24),
              _AmountPair(
                label: '잔액',
                amount: row.budgetAmount - row.spentAmount,
              ),
              const Spacer(),
              Text(
                '${row.usagePercent}%',
                style: TextStyle(
                  color: overBudget ? AppTokens.expense : AppTokens.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (row.adjustment != 0 || row.carryForward) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (row.adjustment != 0)
                  _InfoChip(label: '조정 ${formatKRW(row.adjustment)}'),
                if (row.carryForward) const _InfoChip(label: '이월'),
              ],
            ),
          ],
          if (row.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in row.categories)
                  _InfoChip(label: category.name),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            '삭제 기능은 다음 단계에서 구현합니다.',
            style: TextStyle(color: AppTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.row});

  final BudgetVsActual row;

  @override
  Widget build(BuildContext context) {
    if (row.accountId != null) {
      return _InfoChip(label: row.accountName ?? '자산 연동');
    }
    if (row.incomePercentage != null) {
      return _InfoChip(label: '소득 ${row.incomePercentage}%');
    }
    return const _InfoChip(label: '고정 예산');
  }
}

class _AmountPair extends StatelessWidget {
  const _AmountPair({required this.label, required this.amount});

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTokens.muted)),
        const SizedBox(height: 2),
        Text(
          formatKRW(amount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTokens.sidebarBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _EmptyBudgetGroups extends StatelessWidget {
  const _EmptyBudgetGroups();

  @override
  Widget build(BuildContext context) {
    return const _BudgetCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '이번 달 예산 그룹이 없습니다.',
            style: TextStyle(color: AppTokens.muted),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _BudgetCard(
      child: Text(message, style: const TextStyle(color: AppTokens.expense)),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
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
      title: const Text('예상 수입 수정'),
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
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ],
    );
  }
}

class _BudgetGroupEditDialog extends ConsumerStatefulWidget {
  const _BudgetGroupEditDialog({required this.row});

  final BudgetVsActual row;

  static Future<void> show(BuildContext context, BudgetVsActual row) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BudgetGroupEditDialog(row: row),
    );
  }

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
              Text(modeMessage, style: const TextStyle(color: AppTokens.muted)),
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _adjustment,
              enabled: widget.row.accountId == null && !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '조정액',
                suffixText: '원',
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _carryForward,
              onChanged: _canEditCarryForward && !_busy
                  ? (value) => setState(() => _carryForward = value)
                  : null,
              contentPadding: EdgeInsets.zero,
              title: const Text('잔액 이월'),
              subtitle: const Text('삭제 기능은 다음 단계에서 구현합니다.'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ],
    );
  }
}
