import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/accounts_dao.dart';
import '../../../../features/accounts/grouping.dart';
import '../../color_hex.dart';
import 'package:my_little_budget/features/accounts/providers.dart';

/// SPEC §4.2 — 총 순자산 + 4그룹 색띠 비중 바 + 라벨.
class TotalAssetsCard extends ConsumerWidget {
  const TotalAssetsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances =
        ref.watch(accountBalancesProvider).asData?.value ?? const [];
    final included = balances.where((a) => !a.excludeFromTotal).toList();
    final excluded = balances.where((a) => a.excludeFromTotal).toList();
    final netTotal = included.fold<int>(0, (s, a) => s + a.balance);
    final excludedTotal = excluded.fold<int>(0, (s, a) => s + a.balance);

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
    final assetTotal = groupRows
        .where((g) => g.group != AccountGroup.debt && g.sum > 0)
        .fold<int>(0, (s, g) => s + g.sum);
    final debtTotal = groupRows
        .where((g) => g.group == AccountGroup.debt)
        .fold<int>(0, (s, g) => s + g.sum.abs());
    final positiveTotal = groupRows
        .where((g) => g.group != AccountGroup.debt && g.sum > 0)
        .fold<int>(0, (s, g) => s + g.sum);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _AssetMetric(
                  label: '총자산',
                  amount: assetTotal,
                  color: context.desktopIncome,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AssetMetric(
                  label: '총부채',
                  amount: debtTotal,
                  color: context.desktopExpense,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _AssetMetric(
                  label: '총 순자산',
                  amount: netTotal,
                  color: netTotal < 0
                      ? context.desktopExpense
                      : context.desktopAccent,
                  emphasized: true,
                ),
              ),
            ],
          ),
          if (groupRows.isNotEmpty) ...[
            SizedBox(height: 16),
            _GroupBar(rows: groupRows, positiveTotal: positiveTotal),
            SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                for (final g in groupRows)
                  _GroupLegend(group: g.group, sum: g.sum),
              ],
            ),
          ],
          if (excluded.isNotEmpty) ...[
            SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.desktopSelectedSurface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.desktopMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '총액에서 제외한 계좌 ${excluded.length}개 · ${formatKRW(excludedTotal)}',
                        style: TextStyle(
                          color: context.desktopMuted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssetMetric extends StatelessWidget {
  const _AssetMetric({
    required this.label,
    required this.amount,
    required this.color,
    this.emphasized = false,
  });

  final String label;
  final int amount;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.desktopMuted),
            ),
            SizedBox(height: 5),
            Text(
              formatKRW(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: emphasized ? 20 : 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
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
        SizedBox(width: 6),
        Text(
          group.label,
          style: TextStyle(fontSize: 12, color: context.desktopMuted),
        ),
        SizedBox(width: 4),
        Text(
          formatKRW(sum),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: sum < 0 ? context.desktopExpense : null,
          ),
        ),
      ],
    );
  }
}
