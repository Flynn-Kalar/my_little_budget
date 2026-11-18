import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../data/daos/accounts_dao.dart';
import '../../features/accounts/fund_purpose.dart';

class FundPurposeField extends StatelessWidget {
  const FundPurposeField({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final String value;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: const ValueKey('account-fund-purpose'),
    initialValue: value,
    isExpanded: true,
    decoration: const InputDecoration(
      labelText: '자금 용도',
      border: OutlineInputBorder(),
      helperText: '계좌 잔액 전체를 생활비와 준비금으로 구분합니다.',
      helperMaxLines: 2,
    ),
    items: fundPurposeLabels.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList(),
    onChanged: onChanged == null ? null : (value) => onChanged!(value!),
  );
}

class FundPurposeSummary extends StatelessWidget {
  const FundPurposeSummary({super.key, required this.accounts});
  final List<AccountBalance> accounts;
  @override
  Widget build(BuildContext context) {
    final funds = accounts.where(
      (a) =>
          !a.excludeFromTotal &&
          !a.isInvestment &&
          (a.kind == 'cash' || a.kind == 'bank'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 20),
        const Text('용도별 자금', style: TextStyle(fontWeight: FontWeight.w600)),
        for (final purpose in fundPurposeLabels.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    purpose.key == 'living' ? '생활비 계좌 잔액' : purpose.value,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  formatKRW(
                    funds
                        .where((a) => a.fundPurpose == purpose.key)
                        .fold<int>(0, (sum, a) => sum + a.balance),
                  ),
                ),
              ],
            ),
          ),
        Text(
          '오늘 기준 현금·은행 잔액 · 준비금은 생활비 합계에서 제외',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
