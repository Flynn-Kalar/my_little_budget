import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/accounts/providers.dart';

/// Card settings shared by the independent desktop and mobile account forms.
class CardBillingFields extends ConsumerWidget {
  const CardBillingFields({
    super.key,
    required this.paymentDay,
    required this.closingDay,
    required this.paymentAccountUuid,
    required this.onPaymentDayChanged,
    required this.onClosingDayChanged,
    required this.onPaymentAccountChanged,
    this.paymentAccountName,
    this.enabled = true,
  });

  final int? paymentDay;
  final int? closingDay;
  final String? paymentAccountUuid;
  final String? paymentAccountName;
  final ValueChanged<int?> onPaymentDayChanged;
  final ValueChanged<int?> onClosingDayChanged;
  final ValueChanged<String?> onPaymentAccountChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountBalancesProvider);
    final banks = (accounts.asData?.value ?? [])
        .where((a) => a.kind == 'bank')
        .toList();
    Widget dayField(
      String label,
      String key,
      int? value,
      ValueChanged<int?> onChanged,
    ) {
      return DropdownButtonFormField<int>(
        key: ValueKey(key),
        initialValue: value ?? 0,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem(value: 0, child: Text('미설정')),
          for (var day = 1; day <= 31; day++)
            DropdownMenuItem(
              value: day,
              child: Text(day == 31 ? '말일 (31일)' : '$day일'),
            ),
        ],
        onChanged: enabled ? (day) => onChanged(day == 0 ? null : day) : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dayField('매월 결제일', 'card-payment-day', paymentDay, onPaymentDayChanged),
        const SizedBox(height: 12),
        dayField('청구 마감일', 'card-closing-day', closingDay, onClosingDayChanged),
        const SizedBox(height: 6),
        const Text(
          '마감일 당일까지는 이전 집계월에 포함하고, 다음 날부터 새 집계월로 계산합니다. 예: 10일 마감 → 10일까지 기존 기간, 11일부터 새 기간. 말일 마감은 그 달의 마지막 날까지 포함합니다. 휴일에는 결제일만 다음 영업일로 이동합니다.',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: const ValueKey('card-payment-account'),
          initialValue: paymentAccountUuid ?? '',
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: '연결 출금계좌',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('미연결')),
            for (final bank in banks)
              DropdownMenuItem(
                value: bank.uuid,
                child: Text(bank.name, overflow: TextOverflow.ellipsis),
              ),
            if (paymentAccountUuid != null &&
                !banks.any((a) => a.uuid == paymentAccountUuid))
              DropdownMenuItem(
                value: paymentAccountUuid,
                child: Text(
                  paymentAccountName ?? '기존 연결 계좌',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: enabled && accounts.hasValue
              ? (value) => onPaymentAccountChanged(value == '' ? null : value)
              : null,
        ),
        if (accounts.hasError)
          TextButton(
            onPressed: () => ref.invalidate(accountBalancesProvider),
            child: const Text('출금계좌 다시 불러오기'),
          ),
      ],
    );
  }
}
