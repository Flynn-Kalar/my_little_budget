import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../core/theme/app_theme.dart';
import '../../data/daos/accounts_dao.dart';
import '../../features/accounts/fund_purpose.dart';

class AccountFinancialSummary extends StatelessWidget {
  const AccountFinancialSummary({
    super.key,
    required this.account,
    this.showBalances = true,
  });
  final AccountBalance account;
  final bool showBalances;

  @override
  Widget build(BuildContext context) {
    final billing = account.cardBilling;
    Widget line(String label, String value, {bool debt = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: debt ? context.appExpense : null,
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account.fundPurpose != 'living')
          Text(
            fundPurposeLabels[account.fundPurpose]!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (showBalances && account.kind == 'card') ...[
          line(
            '오늘까지 쓴 금액',
            formatKRW(account.cardSpendingToDate),
            debt: account.cardSpendingToDate > 0,
          ),
          line(
            '이번 달 전체 지출액',
            formatKRW(account.cardMonthSpending),
            debt: account.cardMonthSpending > 0,
          ),
          Text(
            '이번 달 기준 · 예정 지출 포함 · 상환 이체 제외',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showBalances && account.kind != 'card') ...[
          line(
            '현재 잔액 · 오늘까지',
            formatKRW(account.balance),
            debt: account.balance < 0,
          ),
          line(
            '이번 달 예상 잔액',
            formatKRW(account.projectedBalance),
            debt: account.projectedBalance < 0,
          ),
        ],
        if (account.kind == 'card') ...[
          const Divider(height: 16),
          line(
            billing == null ? '이번 결제일에 빠질 돈' : '이번 결제 · ${billing.paymentDate}',
            billing == null ? '결제일·마감일 설정 필요' : formatKRW(billing.dueAmount),
            debt: billing != null && billing.dueAmount > 0,
          ),
          line(
            '이후 청구될 돈',
            billing == null ? '설정 필요' : formatKRW(billing.laterAmount),
            debt: billing != null && billing.laterAmount > 0,
          ),
          line(
            '연결 출금계좌',
            account.cardPaymentAccountName ??
                (account.cardPaymentAccountUuid == null
                    ? '미연결'
                    : '연결 계좌를 찾을 수 없음'),
          ),
          if (billing != null)
            Text(
              '입력된 내역 기준 예상 · ${billing.closingDate}까지 이번 청구',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}
