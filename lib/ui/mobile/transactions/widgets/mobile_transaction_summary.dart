import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../mobile_widgets.dart';
import '../../../shared/overview_widgets.dart';

class MobileTransactionSummary extends StatelessWidget {
  const MobileTransactionSummary({super.key, required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final income = context.appIncome;
    final expense = context.appExpense;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OverviewAmountCard(
                label: '수입',
                amount: summary.income,
                color: income,
                icon: Icons.south,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OverviewAmountCard(
                label: '지출',
                amount: summary.expense,
                color: expense,
                icon: Icons.north,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AmountLine(
          label: '순수익',
          value: formatKRW(summary.net),
          valueColor: summary.net < 0 ? expense : income,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
