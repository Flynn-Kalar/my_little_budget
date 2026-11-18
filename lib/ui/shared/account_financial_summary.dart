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
          if (billing == null && account.cardInstallmentCount > 0)
            Text(
              '할부 ${account.cardInstallmentCount}건 · 결제일·마감일을 설정하면 회차와 잔여 원금을 확인할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (billing != null && billing.installments.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(
                '할부 ${billing.installments.length}건',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '이후 청구 원금 ${formatKRW(billing.installments.fold<int>(0, (sum, plan) => sum + plan.laterPrincipal))}',
                style: const TextStyle(fontSize: 12),
              ),
              children: [
                for (final plan in billing.installments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${plan.purchaseDate} · ${formatKRW(plan.totalAmount)} · ${plan.months}개월 할부',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (plan.current != null)
                          line(
                            '이번 청구 ${plan.current!.round}/${plan.months}회차',
                            formatKRW(plan.current!.amount),
                          ),
                        if (plan.current == null && plan.future.isNotEmpty)
                          line('첫 청구 예정', plan.future.first.paymentDate),
                        line(
                          '이후 ${plan.future.length}회 · 잔여 원금',
                          formatKRW(plan.laterPrincipal),
                        ),
                        for (final part in plan.future)
                          line(
                            '${part.paymentDate} · ${part.round}/${plan.months}회차',
                            formatKRW(part.amount),
                          ),
                      ],
                    ),
                  ),
                Text(
                  '회차별 금액은 상환·환급 차감 전 예정 원금입니다. 수수료는 별도이며 실제 카드사 청구액과 다를 수 있습니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
        ],
      ],
    );
  }
}
