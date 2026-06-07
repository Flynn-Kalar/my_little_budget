import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../desktop/stats/providers.dart';
import '../mobile_widgets.dart';

class MobileYearlyStatsScreen extends ConsumerWidget {
  const MobileYearlyStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(statsYearProvider);
    final trend = ref.watch(yearlyMonthlyTrendProvider);
    final categories = ref.watch(yearlyExpenseByCategoryProvider);

    return MobilePage(
      title: '연간 통계',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/stats'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('월간 통계'),
          ),
        ),
        MobileCard(
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    ref.read(statsYearProvider.notifier).state = year - 1,
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 연도',
              ),
              Expanded(
                child: Text(
                  '$year',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () =>
                    ref.read(statsYearProvider.notifier).state = year + 1,
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 연도',
              ),
            ],
          ),
        ),
        MobileAsync(
          value: trend,
          builder: (value) => _YearlySummary(rows: value),
        ),
        MobileAsync(
          value: categories,
          builder: (value) => _YearlyCategories(rows: value),
        ),
      ],
    );
  }
}

class _YearlySummary extends StatelessWidget {
  const _YearlySummary({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final income = rows.fold<int>(0, (sum, row) => sum + row.income);
    final expense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final net = income - expense;

    return MobileCard(
      child: Column(
        children: [
          AmountLine(
            label: '수입',
            value: formatKRW(income),
            valueColor: AppTokens.income,
          ),
          AmountLine(
            label: '지출',
            value: formatKRW(expense),
            valueColor: AppTokens.expense,
          ),
          AmountLine(
            label: '순수입',
            value: formatKRW(net),
            valueColor: net < 0 ? AppTokens.expense : AppTokens.income,
          ),
          const SizedBox(height: 8),
          const Divider(),
          for (final row in rows)
            AmountLine(
              label: row.month,
              value: formatKRW(row.net),
              valueColor: row.net < 0 ? AppTokens.expense : AppTokens.income,
            ),
        ],
      ),
    );
  }
}

class _YearlyCategories extends StatelessWidget {
  const _YearlyCategories({required this.rows});

  final List<YearlyPivotRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('카테고리 통계가 없습니다.');
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);

    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리 요약', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final row in rows)
            AmountLine(
              label:
                  '${row.categoryName} · ${total == 0 ? 0 : (row.total / total * 100).round()}%',
              value: formatKRW(row.total),
              valueColor: AppTokens.expense,
            ),
        ],
      ),
    );
  }
}
