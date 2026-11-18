import 'package:flutter/material.dart';

import '../../core/date.dart';
import '../../core/money.dart';
import '../../data/database.dart';
import '../../features/accounts/card_billing.dart';

class InstallmentField extends StatelessWidget {
  const InstallmentField({
    super.key,
    required this.months,
    required this.onChanged,
    required this.amountController,
    required this.purchaseDate,
    this.account,
  });
  final int? months;
  final ValueChanged<int?>? onChanged;
  final TextEditingController amountController;
  final DateTime? purchaseDate;
  final Account? account;

  @override
  Widget build(BuildContext context) => account?.kind != 'card'
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              key: ValueKey('installment-months-${months ?? 1}'),
              initialValue: months ?? 1,
              isExpanded: true,
              menuMaxHeight: 320,
              decoration: const InputDecoration(
                labelText: '결제 방식',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: 1, child: Text('일시불')),
                for (var count = 2; count <= 60; count++)
                  DropdownMenuItem(value: count, child: Text('$count개월 할부')),
              ],
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value == 1 ? null : value),
            ),
            if (months != null)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: amountController,
                builder: (context, value, _) {
                  final amount = tryParseKRW(value.text);
                  final payment = account?.cardPaymentDay;
                  final closing = account?.cardClosingDay;
                  final configured =
                      payment != null &&
                      closing != null &&
                      payment >= 1 &&
                      payment <= 31 &&
                      closing >= 1 &&
                      closing <= 31;
                  final schedule =
                      configured &&
                          purchaseDate != null &&
                          amount != null &&
                          amount >= months!
                      ? cardInstallmentSchedule(
                          purchaseDate: toDateKey(purchaseDate!),
                          amount: amount,
                          months: months!,
                          paymentDay: payment,
                          closingDay: closing,
                        )
                      : null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (amount != null && amount >= months!)
                        Text(
                          '첫 회차 ${formatKRW(amount ~/ months! + amount % months!)} · 이후 월 ${formatKRW(amount ~/ months!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (schedule != null)
                        Text(
                          '첫 결제 예정일 ${schedule.first.paymentDate}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (!configured)
                        const Text(
                          '자산에서 카드 결제일·마감일을 설정하면 청구 일정을 확인할 수 있습니다.',
                          style: TextStyle(fontSize: 12),
                        ),
                      const Text(
                        '총 구매금액을 입력하세요. 지출은 총액으로 한 번 기록하며, 수수료는 별도 지출로 입력합니다.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        );
}
