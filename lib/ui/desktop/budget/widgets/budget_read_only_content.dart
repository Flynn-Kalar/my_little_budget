import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/budget_dao.dart';

class BudgetReadOnlyContent extends StatelessWidget {
  const BudgetReadOnlyContent({
    super.key,
    required this.rows,
    required this.onEditGroup,
    required this.onDeleteGroup,
  });

  final List<BudgetVsActual> rows;
  final ValueChanged<BudgetVsActual> onEditGroup;
  final ValueChanged<BudgetVsActual> onDeleteGroup;

  @override
  Widget build(BuildContext context) {
    final totalBudget = rows.fold<int>(0, (sum, row) => sum + row.budgetAmount);
    final totalSpent = rows.fold<int>(0, (sum, row) => sum + row.spentAmount);
    final remaining = totalBudget - totalSpent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BudgetSummary(
          totalBudget: totalBudget,
          totalSpent: totalSpent,
          remaining: remaining,
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const EmptyBudgetGroups()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 820;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final row in rows)
                    SizedBox(
                      key: ValueKey('desktop-budget-group-${row.groupId}'),
                      width: cardWidth,
                      child: BudgetGroupCard(
                        row: row,
                        onEdit: () => onEditGroup(row),
                        onDelete: () => onDeleteGroup(row),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class BudgetSummary extends StatelessWidget {
  const BudgetSummary({
    super.key,
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
            color: context.desktopIncome,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '총 사용액',
            amount: totalSpent,
            icon: Icons.receipt_long_outlined,
            color: context.desktopExpense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '남은 금액',
            amount: remaining,
            icon: Icons.savings_outlined,
            color: remaining < 0
                ? context.desktopExpense
                : context.desktopAccent,
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
    return BudgetCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: context.desktopMuted)),
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

class BudgetGroupCard extends StatelessWidget {
  const BudgetGroupCard({
    super.key,
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetVsActual row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final overBudget = row.spentAmount > row.budgetAmount;
    final progress = row.budgetAmount <= 0
        ? null
        : (row.spentAmount / row.budgetAmount).clamp(0.0, 1.0);

    final remaining = row.budgetAmount - row.spentAmount;
    final overAmount = row.spentAmount - row.budgetAmount;

    return BudgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.groupName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ModeChip(row: row),
                        if (row.adjustment != 0)
                          BudgetInfoChip(
                            label: '조정 ${formatKRW(row.adjustment)}',
                          ),
                        if (row.carryForward) const BudgetInfoChip(label: '이월'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '예산 그룹 수정',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: '예산 그룹 삭제',
                color: context.desktopExpense,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: context.desktopBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? context.desktopExpense : context.desktopIncome,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BudgetAmountPair(label: '예산', amount: row.budgetAmount),
              const SizedBox(width: 18),
              BudgetAmountPair(label: '사용', amount: row.spentAmount),
              const SizedBox(width: 18),
              BudgetAmountPair(label: '잔액', amount: remaining),
              const Spacer(),
              Text(
                '${row.usagePercent}%',
                style: TextStyle(
                  color: overBudget
                      ? context.desktopExpense
                      : context.desktopMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (overBudget) ...[
            const SizedBox(height: 10),
            _OverBudgetNotice(amount: overAmount),
          ],
          if (row.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final category in row.categories)
                  BudgetInfoChip(label: category.name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverBudgetNotice extends StatelessWidget {
  const _OverBudgetNotice({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopExpense.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: context.desktopExpense,
            ),
            const SizedBox(width: 6),
            Text(
              '예산 초과 ${formatKRW(amount)}',
              style: TextStyle(
                color: context.desktopExpense,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
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
      return BudgetInfoChip(label: row.accountName ?? '자산 연동');
    }
    if (row.incomePercentage != null) {
      return BudgetInfoChip(label: '소득 ${row.incomePercentage}%');
    }
    return const BudgetInfoChip(label: '고정 예산');
  }
}

class BudgetAmountPair extends StatelessWidget {
  const BudgetAmountPair({
    super.key,
    required this.label,
    required this.amount,
  });

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.desktopMuted)),
        const SizedBox(height: 2),
        Text(
          formatKRW(amount),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class BudgetInfoChip extends StatelessWidget {
  const BudgetInfoChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.desktopBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class EmptyBudgetGroups extends StatelessWidget {
  const EmptyBudgetGroups({super.key});

  @override
  Widget build(BuildContext context) {
    return BudgetCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '이번 달 예산 그룹이 없습니다.',
            style: TextStyle(color: context.desktopMuted),
          ),
        ),
      ),
    );
  }
}

class BudgetErrorCard extends StatelessWidget {
  const BudgetErrorCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BudgetCard(
      child: Text(message, style: TextStyle(color: context.desktopExpense)),
    );
  }
}

class BudgetCard extends StatelessWidget {
  const BudgetCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
