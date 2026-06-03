import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/budget_dao.dart';
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

class _ExpectedIncomeCard extends StatelessWidget {
  const _ExpectedIncomeCard({required this.income});

  final int income;

  @override
  Widget build(BuildContext context) {
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

class _BudgetGroupCard extends StatelessWidget {
  const _BudgetGroupCard({required this.row});

  final BudgetVsActual row;

  @override
  Widget build(BuildContext context) {
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
