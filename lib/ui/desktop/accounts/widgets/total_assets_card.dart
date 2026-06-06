import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/accounts_dao.dart';
import '../../../../features/accounts/grouping.dart';
import '../../color_hex.dart';
import '../providers.dart';

/// SPEC §4.2 — 총 순자산 + 4그룹 색띠 비중 바 + 라벨.
class TotalAssetsCard extends ConsumerWidget {
  const TotalAssetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances =
        ref.watch(accountBalancesProvider).asData?.value ?? const [];
    final included = balances.where((a) => !a.excludeFromTotal).toList();
    final total = included.fold<int>(0, (s, a) => s + a.balance);

    // 4그룹 분류
    final byGroup = <AccountGroup, List<AccountBalance>>{};
    for (final a in included) {
      final g = classifyAccount(
        kind: a.kind,
        balance: a.balance,
        isInvestment: a.isInvestment,
      );
      (byGroup[g] ??= []).add(a);
    }
    final groupRows = [
      for (final g in accountGroupOrder)
        if (byGroup.containsKey(g))
          (group: g, sum: byGroup[g]!.fold<int>(0, (s, a) => s + a.balance)),
    ];
    final positiveTotal = groupRows
        .where((g) => g.group != AccountGroup.debt && g.sum > 0)
        .fold<int>(0, (s, g) => s + g.sum);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '총 순자산',
            style: TextStyle(fontSize: 12, color: AppTokens.muted),
          ),
          const SizedBox(height: 6),
          Text(
            formatKRW(total),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: total < 0 ? AppTokens.expense : null,
            ),
          ),
          if (groupRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GroupBar(rows: groupRows, positiveTotal: positiveTotal),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final g in groupRows)
                  _GroupLegend(group: g.group, sum: g.sum),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupBar extends StatelessWidget {
  const _GroupBar({required this.rows, required this.positiveTotal});
  final List<({AccountGroup group, int sum})> rows;
  final int positiveTotal;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            for (final r in rows)
              Expanded(
                flex: _weight(r),
                child: ColoredBox(color: colorFromHex(r.group.colorHex)),
              ),
          ],
        ),
      ),
    );
  }

  int _weight(({AccountGroup group, int sum}) r) {
    final abs = r.sum.abs();
    final denom = positiveTotal + (r.group == AccountGroup.debt ? abs : 0);
    // flex 는 int 비례. 정확도 위해 ×1000.
    if (denom <= 0) return 1;
    final w = (abs / denom * 1000).round();
    return w == 0 ? 1 : w;
  }
}

class _GroupLegend extends StatelessWidget {
  const _GroupLegend({required this.group, required this.sum});
  final AccountGroup group;
  final int sum;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorFromHex(group.colorHex),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          group.label,
          style: const TextStyle(fontSize: 12, color: AppTokens.muted),
        ),
        const SizedBox(width: 4),
        Text(
          formatKRW(sum),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sum < 0 ? AppTokens.expense : null,
          ),
        ),
      ],
    );
  }
}
