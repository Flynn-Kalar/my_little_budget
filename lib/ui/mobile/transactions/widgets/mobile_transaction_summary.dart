import 'package:flutter/material.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../mobile_widgets.dart';

class MobileTransactionSummary extends StatelessWidget {
  const MobileTransactionSummary({super.key, required this.summary});

  final MonthlySummary summary;

  @override
  Widget build(BuildContext context) {
    final income = context.appIncome;
    final expense = context.appExpense;
    return MobileCard(
      child: Column(
        children: [
          AmountLine(
            label: '수입',
            value: formatKRW(summary.income),
            valueColor: income,
          ),
          AmountLine(
            label: '지출',
            value: formatKRW(summary.expense),
            valueColor: expense,
          ),
          AmountLine(
            label: '순수익',
            value: formatKRW(summary.net),
            valueColor: summary.net < 0 ? expense : income,
          ),
        ],
      ),
    );
  }
}
