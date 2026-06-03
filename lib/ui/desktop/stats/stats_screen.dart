import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import 'providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final breakdown = ref.watch(statsExpenseBreakdownProvider);
    final trend = ref.watch(statsMonthlyTrendProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '통계',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _StatsMonthNav(month: month),
            const SizedBox(height: 16),
            breakdown.when(
              data: (rows) => _ExpenseBreakdownCard(rows: rows),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            trend.when(
              data: (rows) => _TrendCard(rows: rows),
              loading: () => const _StatsCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            const _YearlyTodoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatsMonthNav extends ConsumerWidget {
  const _StatsMonthNav({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      ref.read(statsMonthProvider.notifier).state = shiftMonth(month, delta);
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
            ref.read(statsMonthProvider.notifier).state = currentMonthKey();
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

class _ExpenseBreakdownCard extends StatelessWidget {
  const _ExpenseBreakdownCard({required this.rows});

  final List<CategoryBreakdownRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<int>(0, (sum, row) => sum + row.total);

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '지출 카테고리',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                formatKRW(total),
                style: const TextStyle(
                  color: AppTokens.expense,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _EmptyState(message: '이번 달 지출 내역이 없습니다.')
          else
            Column(
              children: [
                for (final row in rows) _BreakdownRow(row: row, total: total),
              ],
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.row, required this.total});

  final CategoryBreakdownRow row;
  final int total;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0 : (row.total * 100 / total).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ColorDot(color: _parseColor(row.categoryColor)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.categoryName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 12),
              Text('$percent%', style: const TextStyle(color: AppTokens.muted)),
              const SizedBox(width: 16),
              SizedBox(
                width: 120,
                child: Text(
                  formatKRW(row.total),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : row.total / total,
              minHeight: 6,
              backgroundColor: AppTokens.sidebarBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                _parseColor(row.categoryColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    final totalIncome = rows.fold<int>(0, (sum, row) => sum + row.income);
    final totalExpense = rows.fold<int>(0, (sum, row) => sum + row.expense);
    final totalNet = totalIncome - totalExpense;

    return _StatsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 12개월 추세',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TrendSummaryTile(
                  label: '수입',
                  amount: totalIncome,
                  color: AppTokens.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrendSummaryTile(
                  label: '지출',
                  amount: totalExpense,
                  color: AppTokens.expense,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TrendSummaryTile(
                  label: '순액',
                  amount: totalNet,
                  color: totalNet < 0 ? AppTokens.expense : AppTokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const _EmptyState(message: '최근 12개월 거래 내역이 없습니다.')
          else
            _TrendTable(rows: rows),
        ],
      ),
    );
  }
}

class _TrendSummaryTile extends StatelessWidget {
  const _TrendSummaryTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTokens.sidebarBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppTokens.muted)),
            const SizedBox(height: 4),
            Text(
              formatKRW(amount),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.rows});

  final List<MonthlyTrendRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TrendHeader(),
        const Divider(height: 1),
        for (final row in rows) _TrendTableRow(row: row),
      ],
    );
  }
}

class _TrendHeader extends StatelessWidget {
  const _TrendHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('월')),
          Expanded(flex: 3, child: Text('수입', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('지출', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('순액', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _TrendTableRow extends StatelessWidget {
  const _TrendTableRow({required this.row});

  final MonthlyTrendRow row;

  @override
  Widget build(BuildContext context) {
    final d = parseMonthKey(row.month);
    final netColor = row.net < 0 ? AppTokens.expense : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('${d.year}.${d.month}')),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.income), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.expense), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(row.net),
              textAlign: TextAlign.right,
              style: TextStyle(color: netColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyTodoCard extends StatelessWidget {
  const _YearlyTodoCard();

  @override
  Widget build(BuildContext context) {
    return const _StatsCard(
      child: Row(
        children: [
          Icon(Icons.table_chart_outlined, color: AppTokens.muted),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연간 통계', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text(
                  '/stats/yearly는 다음 단계에서 구현합니다.',
                  style: TextStyle(color: AppTokens.muted),
                ),
              ],
            ),
          ),
          _StatusPill(label: 'TODO'),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppTokens.muted)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatsCard(
      child: Text(message, style: const TextStyle(color: AppTokens.expense)),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox(width: 10, height: 10),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

Color _parseColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return AppTokens.muted;
  return Color(0xFF000000 | value);
}
