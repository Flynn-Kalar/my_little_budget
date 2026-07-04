import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../color_hex.dart';
import '../providers.dart';

class TransactionsSidePanel extends ConsumerWidget {
  const TransactionsSidePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(monthlySummaryProvider).asData?.value;
    final rows = ref.watch(transactionsMonthRowsProvider).asData?.value;
    final categories =
        ref.watch(transactionsCategoryBreakdownProvider).asData?.value ??
        const <CategoryBreakdownRow>[];

    final today = currentDateKey();
    final todayExpense =
        rows
            ?.where((row) => row.type == 'expense' && row.occurredOn == today)
            .fold<int>(0, (sum, row) => sum + row.amount) ??
        0;
    final plannedRows =
        (rows ?? const <TransactionRow>[])
            .where((row) => row.occurredOn.compareTo(today) > 0)
            .toList()
          ..sort((a, b) {
            final date = a.occurredOn.compareTo(b.occurredOn);
            if (date != 0) return date;
            return a.occurredTime.compareTo(b.occurredTime);
          });
    final plannedTotal = plannedRows.fold<int>(
      0,
      (sum, row) => sum + (row.type == 'income' ? row.amount : -row.amount),
    );
    final plannedExpense = plannedRows
        .where((row) => row.type == 'expense')
        .fold<int>(0, (sum, row) => sum + row.amount);
    final expectedMonthEnd = (summary?.net ?? 0) + plannedTotal;

    return SingleChildScrollView(
      key: const ValueKey('desktop-transactions-side-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelCard(
            title: '월말 예상',
            trailing: TextButton(
              onPressed: () => context.go('/stats'),
              child: const Text('통계 보기'),
            ),
            child: Column(
              children: [
                _MetricRow(
                  label: '오늘 지출',
                  value: '-${formatKRW(todayExpense)}',
                  color: context.desktopExpense,
                ),
                _MetricRow(
                  label: '남은 예정 지출',
                  value: '-${formatKRW(plannedExpense)}',
                  color: context.desktopExpense,
                ),
                _MetricRow(
                  label: '예상 월말 변화',
                  value: _signedMoney(expectedMonthEnd),
                  color: expectedMonthEnd >= 0
                      ? context.desktopAccent
                      : context.desktopExpense,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _PanelCard(
            title: '지출 TOP 5',
            child: categories.isEmpty
                ? const _EmptyPanelText('이번 달 지출이 없습니다.')
                : Column(
                    children: [
                      for (final row in categories.take(5))
                        _CategoryRankRow(
                          row: row,
                          maxTotal: categories.first.total,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          _PanelCard(
            title: '다가오는 예정 거래',
            child: plannedRows.isEmpty
                ? const _EmptyPanelText('예정 거래가 없습니다.')
                : Column(
                    children: [
                      for (final row in plannedRows.take(5))
                        _PlannedRow(row: row),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: context.desktopMuted),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRankRow extends StatelessWidget {
  const _CategoryRankRow({required this.row, required this.maxTotal});

  final CategoryBreakdownRow row;
  final int maxTotal;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(row.categoryColor);
    final ratio = maxTotal <= 0 ? 0.0 : row.total / maxTotal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.categoryName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatKRW(row.total),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: context.desktopSelectedSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannedRow extends StatelessWidget {
  const _PlannedRow({required this.row});

  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final isIncome = row.type == 'income';
    final title = row.type == 'transfer'
        ? '${row.fromAccountName ?? '?'} → ${row.toAccountName ?? '?'}'
        : row.categoryName ?? '(카테고리 없음)';
    final amountColor = row.type == 'transfer'
        ? Theme.of(context).colorScheme.onSurface
        : isIncome
        ? context.desktopIncome
        : context.desktopExpense;
    final sign = row.type == 'transfer' ? '' : (isIncome ? '+' : '-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              row.occurredOn.substring(5),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.desktopWarning,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${formatKRW(row.amount)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanelText extends StatelessWidget {
  const _EmptyPanelText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: context.desktopMuted),
      ),
    );
  }
}

String _signedMoney(int value) {
  if (value > 0) return '+${formatKRW(value)}';
  if (value < 0) return '-${formatKRW(-value)}';
  return formatKRW(0);
}
