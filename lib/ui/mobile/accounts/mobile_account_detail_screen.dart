import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/transactions_dao.dart';
import '../../../features/investments/quantity_precision.dart';
import '../../desktop/accounts/providers.dart';
import '../mobile_widgets.dart';

class MobileAccountDetailScreen extends ConsumerWidget {
  const MobileAccountDetailScreen({super.key, required this.accountId});

  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountByIdProvider(accountId));
    final rows = ref.watch(accountTransactionsProvider(accountId));

    return MobilePageScaffold(
      title: '자산 상세',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/accounts'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('자산 목록'),
          ),
        ),
        MobileAsync(
          value: account,
          builder: (value) {
            if (value == null) return const EmptyMobileCard('자산을 찾을 수 없습니다.');
            return MobileCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AmountLine(
                    label: _kindLabel(value.kind),
                    value: formatKRW(value.balance),
                    valueColor: value.balance < 0
                        ? AppTokens.expense
                        : AppTokens.income,
                  ),
                  if (value.isInvestment)
                    Text(
                      '투자 자산',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        MobileAsync(
          value: rows,
          builder: (value) {
            if (value.isEmpty) return const EmptyMobileCard('거래내역이 없습니다.');
            return Column(
              children: [
                for (final row in value) _AccountTransactionCard(row: row),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AccountTransactionCard extends StatelessWidget {
  const _AccountTransactionCard({required this.row});

  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = row.type == 'income' ? AppTokens.income : AppTokens.expense;
    return MobileCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                formatKRW(row.amount),
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          if (row.memo?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              row.memo!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String get _title {
    if (row.source == 'investment') return row.categoryName ?? '투자 거래';
    if (row.type == 'transfer') return '이체';
    return row.categoryName ?? _typeLabel(row.type);
  }

  String get _subtitle {
    final date = '${row.occurredOn} ${row.occurredTime}';
    if (row.source == 'investment') {
      final quantity = row.quantity == null || row.quantity == 0
          ? ''
          : ' · 수량 ${formatInvestmentQuantity(row.quantity!)}';
      return '$date$quantity';
    }
    if (row.type == 'transfer') {
      final from = row.fromAccountName ?? '-';
      final to = row.toAccountName ?? '-';
      return '$date · $from → $to';
    }
    return '$date · ${row.accountName ?? ''}';
  }
}

String _typeLabel(String type) => switch (type) {
  'income' => '수입',
  'expense' => '지출',
  'transfer' => '이체',
  'adjustment' => '잔액 조정',
  _ => type,
};

String _kindLabel(String kind) => switch (kind) {
  'cash' => '현금',
  'bank' => '은행',
  'card' => '카드',
  'other' => '기타',
  _ => kind,
};
