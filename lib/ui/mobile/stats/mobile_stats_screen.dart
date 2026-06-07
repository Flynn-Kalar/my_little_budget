import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../desktop/stats/providers.dart';
import '../mobile_widgets.dart';

class MobileStatsScreen extends ConsumerWidget {
  const MobileStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final breakdown = ref.watch(statsExpenseBreakdownProvider);
    final trend = ref.watch(statsMonthlyTrendProvider);

    return MobilePage(
      title: '통계',
      children: [
        MobileMonthNav(
          month: month,
          onChanged: (value) =>
              ref.read(statsMonthProvider.notifier).state = value,
        ),
        MobileAsync(
          value: breakdown,
          builder: (value) => _Breakdown(rows: value),
        ),
        MobileAsync(
          value: trend,
          builder: (value) => _Trend(rows: value),
        ),
      ],
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows});

  final List<CategoryBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('지출 통계가 없습니다.');
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리별 지출', style: TextStyle(fontWeight: FontWeight.w800)),
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

class _Trend extends StatelessWidget {
  const _Trend({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const EmptyMobileCard('월별 추세가 없습니다.');
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('월별 추세', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          for (final row in rows.take(12))
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
