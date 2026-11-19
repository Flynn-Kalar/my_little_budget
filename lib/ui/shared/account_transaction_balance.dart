import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/daos/transactions_dao.dart';

/// Keep period usage distinct from lifetime debt in card transaction rows.
class AccountTransactionBalance extends StatelessWidget {
  const AccountTransactionBalance({super.key, required this.row});

  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final balance = row.balanceAfter;
    if (balance == null) return const SizedBox.shrink();
    final spending = row.cardSpendingAfter;
    final style = TextStyle(
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (spending != null)
          Text('기간 사용액 ${formatKRW(spending)}', style: style),
        Text(
          spending == null
              ? formatKRW(balance)
              : balance > 0
              ? '초과 상환액 ${formatKRW(balance)}'
              : '미결제 잔액 ${formatKRW(-balance)}',
          style: style,
        ),
      ],
    );
  }
}
