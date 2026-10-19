import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/daos/budget_dao.dart';
import '../../features/budget/daily_allowance.dart';

class DailyBudgetGuidance extends StatelessWidget {
  const DailyBudgetGuidance({
    super.key,
    required this.month,
    required this.rows,
    this.singlePeriodLabel = false,
    this.margin,
  });
  final String month;
  final List<BudgetVsActual> rows;
  final bool singlePeriodLabel;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();
    final allowances = [
      for (final row in rows)
        (
          row,
          dailyAllowance(
            month: month,
            budget: row.budgetAmount,
            spent: row.spentAmount,
            now: now,
          ),
        ),
    ].where((e) => e.$2 != null).toList();
    if (allowances.isEmpty) return const SizedBox.shrink();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return Card(
      margin: margin,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              month == currentMonth
                  ? '남은 기간 하루 사용 가능 예산'
                  : '월 전체 기준 하루 사용 가능 예산',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            if (singlePeriodLabel) ...[
              Text(
                '${allowances.first.$2!.days}일 기준',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
            ],
            for (final entry in allowances)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${entry.$1.groupName} · ${entry.$2!.remaining < 0 ? '${formatKRW(-entry.$2!.remaining)} 초과' : '하루 ${formatKRW(entry.$2!.daily)}'}'
                  '${singlePeriodLabel ? '' : ' (${entry.$2!.days}일 기준)'}',
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              '등록된 예정 지출을 포함한 남은 예산 기준입니다. 그룹별 금액은 합산하지 않습니다.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
