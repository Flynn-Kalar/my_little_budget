import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/investments_dao.dart';

class InvestmentSummaryCard extends StatelessWidget {
  const InvestmentSummaryCard({super.key, required this.summary});

  final InvestmentSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: '매수',
            amount: summary.buy,
            icon: Icons.south_west,
            color: context.desktopExpense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '매도',
            amount: summary.sell,
            icon: Icons.north_east,
            color: context.desktopIncome,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '배당',
            amount: summary.dividend,
            icon: Icons.payments_outlined,
            color: const Color(0xFFD79A21),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '실현손익',
            amount: summary.realizedPnl,
            icon: Icons.swap_vert,
            color: summary.realizedPnl < 0
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
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.desktopBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${label == '실현손익' && amount > 0 ? '+' : ''}${formatKRW(amount)}',
                      style: TextStyle(
                        color: label == '실현손익'
                            ? (amount < 0
                                  ? context.desktopExpense
                                  : context.desktopIncome)
                            : null,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
