import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../features/investments/quantity_precision.dart';
import '../../color_hex.dart';
import '../../transactions/widgets/transaction_edit_dialog.dart';
import '../providers.dart';
import 'adjustment_edit_dialog.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

String _dateHeader(String dateKey) {
  final yy = dateKey.substring(2, 4);
  final mm = dateKey.substring(5, 7);
  final dd = dateKey.substring(8, 10);
  final dt = DateTime.parse('${dateKey}T00:00:00');
  return '$yy.$mm.$dd (${_weekdays[dt.weekday % 7]})';
}

/// SPEC §4.3 — 자산 상세 거래 목록.
class AccountTxList extends ConsumerWidget {
  const AccountTxList({
    super.key,
    required this.accountId,
    required this.initialBalance,
  });

  final int accountId;
  final int initialBalance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountTransactionsProvider(accountId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(40),
        child: Center(child: Text('불러오기 오류: $e')),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 48),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTokens.sidebarBorder),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '거래 내역이 없습니다.',
                  style: TextStyle(color: AppTokens.muted),
                ),
              ),
              const SizedBox(height: 20),
              _InitialBalanceRow(initialBalance: initialBalance),
            ],
          );
        }

        // 날짜별 그룹
        final groups = <String, List<TransactionRow>>{};
        for (final r in rows) {
          (groups[r.occurredOn] ??= []).add(r);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: Text(
                  _dateHeader(entry.key),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.muted,
                  ),
                ),
              ),
              for (final row in entry.value)
                _TxRowItem(row: row, accountId: accountId),
            ],
            const SizedBox(height: 20),
            _InitialBalanceRow(initialBalance: initialBalance),
          ],
        );
      },
    );
  }
}

class _TxRowItem extends ConsumerWidget {
  const _TxRowItem({required this.row, required this.accountId});
  final TransactionRow row;
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (row.source == 'investment') {
      return _InvestmentVirtualRow(row: row);
    }
    if (row.type == 'adjustment') {
      return _AdjustmentRow(row: row, accountId: accountId);
    }
    return _GeneralRow(row: row, accountId: accountId);
  }
}

class _GeneralRow extends ConsumerWidget {
  const _GeneralRow({required this.row, required this.accountId});
  final TransactionRow row;
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = row.type == 'transfer';
    final isIncome = row.type == 'income';
    final showTime = row.occurredTime != '00:00';

    final Widget leading;
    final String title;
    final List<String> metaParts;
    final Color amountColor;
    final String sign;

    if (isTransfer) {
      final isIncoming = row.toAccountId == accountId;
      final counterpart = isIncoming ? row.fromAccountName : row.toAccountName;
      final direction = isIncoming ? '← 이체 입금' : '→ 이체 출금';
      leading = const CircleAvatar(
        radius: 14,
        backgroundColor: AppTokens.sidebarActive,
        child: Icon(Icons.swap_horiz, size: 16, color: AppTokens.muted),
      );
      title = direction;
      metaParts = [
        if (showTime) row.occurredTime,
        ?counterpart,
        if (row.memo != null) row.memo!,
      ];
      amountColor = isIncoming ? AppTokens.income : AppTokens.expense;
      sign = isIncoming ? '+' : '-';
    } else {
      leading = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorFromHex(row.categoryColor),
        ),
      );
      title = row.categoryName ?? '(카테고리 없음)';
      metaParts = [
        if (showTime) row.occurredTime,
        if (row.memo != null) row.memo!,
      ];
      amountColor = isIncome ? AppTokens.income : AppTokens.expense;
      sign = isIncome ? '+' : '-';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            await TransactionEditDialog.show(context, row);
            refreshAccountDetail(ref, accountId);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTokens.sidebarBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                SizedBox(width: 28, child: Center(child: leading)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (row.tags.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            for (final t in row.tags)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: _TagChip(name: t.name, color: t.color),
                              ),
                          ],
                        ],
                      ),
                      if (metaParts.isNotEmpty)
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTokens.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$sign${formatKRW(row.amount)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdjustmentRow extends ConsumerWidget {
  const _AdjustmentRow({required this.row, required this.accountId});
  final TransactionRow row;
  final int accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delta = row.amount;
    final isUp = delta > 0;
    final color = isUp ? AppTokens.income : AppTokens.expense;
    final sign = isUp ? '+' : '−';
    final showTime = row.occurredTime != '00:00';
    final metaParts = [
      if (showTime) row.occurredTime,
      if (row.memo != null) row.memo!,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => AdjustmentEditDialog.show(
            context,
            row: row,
            accountId: accountId,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTokens.sidebarBorder,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTokens.sidebarActive,
                  child: Icon(Icons.tune, size: 14, color: AppTokens.muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '잔액 조정',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (metaParts.isNotEmpty)
                        Text(
                          metaParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTokens.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '$sign${formatKRW(delta.abs())}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvestmentVirtualRow extends StatelessWidget {
  const _InvestmentVirtualRow({required this.row});
  final TransactionRow row;

  @override
  Widget build(BuildContext context) {
    final side = row.investmentSide ?? '';
    final impact = row.balanceImpact ?? 0;
    final sideLabel =
        {'buy': '매수', 'sell': '매도', 'dividend': '배당'}[side] ?? side;
    final sideColor = switch (side) {
      'buy' => AppTokens.muted,
      'sell' => AppTokens.income,
      _ => AppTokens.transfer, // dividend
    };
    final amountColor = impact > 0
        ? AppTokens.income
        : impact < 0
        ? AppTokens.expense
        : AppTokens.muted;
    final sign = impact > 0
        ? '+'
        : impact < 0
        ? '−'
        : '';
    final amountText = side == 'buy'
        ? '자산 전환'
        : '$sign${formatKRW(impact.abs())}';
    final detail = switch (side) {
      'buy' =>
        '매입 ${formatKRW(row.originalAmount ?? 0)} · '
            '${_qty(row.quantity)}주',
      'sell' =>
        '매도 ${formatKRW(row.originalAmount ?? 0)} · '
            '평단원가 ${formatKRW(row.costBasis ?? 0)}',
      _ => '배당금',
    };
    final showTime = row.occurredTime != '00:00';
    final meta = [if (showTime) row.occurredTime, detail].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go('/investments'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: AppTokens.sidebarBorder),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sideLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: sideColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.ticker ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  amountText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _qty(double? q) {
    if (q == null) return formatInvestmentQuantity(0);
    // 소수점 12자리까지, 불필요한 0 제거
    return formatInvestmentQuantity(q);
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.name, required this.color});
  final String name;
  final String color;

  @override
  Widget build(BuildContext context) {
    final c = colorFromHex(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('#$name', style: TextStyle(fontSize: 10, color: c)),
    );
  }
}

class _InitialBalanceRow extends StatelessWidget {
  const _InitialBalanceRow({required this.initialBalance});
  final int initialBalance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            '초기',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTokens.muted,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            border: Border.all(color: AppTokens.sidebarBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTokens.muted,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '초기 잔액',
                  style: TextStyle(fontSize: 14, color: AppTokens.muted),
                ),
              ),
              Text(
                formatKRW(initialBalance),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTokens.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
