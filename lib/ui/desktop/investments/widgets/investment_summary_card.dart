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
            color: context.desktopWarning,
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
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
