import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/investments_dao.dart';
import '../../../data/database.dart';
import '../../../features/investments/cost_basis.dart';
import 'providers.dart';

class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(investmentMonthProvider);
    final account = ref.watch(investmentAccountProvider);
    final summary = ref.watch(investmentMonthlySummaryProvider);
    final holdings = ref.watch(currentHoldingsProvider);
    final rows = ref.watch(investmentRowsProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1100),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '투자',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _InvestmentMonthNav(month: month),
            const SizedBox(height: 16),
            account.when(
              data: (value) => _InvestmentAccountBanner(account: value),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 12),
            summary.when(
              data: (value) => _InvestmentSummaryCard(summary: value),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            holdings.when(
              data: (value) => _HoldingsCard(holdings: value),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            rows.when(
              data: (value) => _InvestmentRowsCard(rows: value),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            const _PnlTodoCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _InvestmentMonthNav extends ConsumerWidget {
  const _InvestmentMonthNav({required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      ref.read(investmentMonthProvider.notifier).state = shiftMonth(
        month,
        delta,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(investmentMonthProvider.notifier).state =
                currentMonthKey();
          },
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text('${d.year}년 ${d.month}월'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _InvestmentAccountBanner extends StatelessWidget {
  const _InvestmentAccountBanner({required this.account});

  final Account? account;

  @override
  Widget build(BuildContext context) {
    final hasAccount = account != null;

    return _InvestmentCard(
      child: Row(
        children: [
          Icon(
            hasAccount
                ? Icons.account_balance_wallet_outlined
                : Icons.info_outline,
            color: hasAccount ? AppTokens.income : AppTokens.warning,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasAccount ? '투자 계좌 연결됨' : '투자 계좌 없음',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  hasAccount
                      ? '${account!.name} 계좌에 투자 거래가 연결됩니다.'
                      : '활성 투자 자산이 없으면 새 투자 거래는 계좌 없이 저장됩니다.',
                  style: const TextStyle(color: AppTokens.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentSummaryCard extends StatelessWidget {
  const _InvestmentSummaryCard({required this.summary});

  final InvestmentSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: '매수',
            amount: summary.buy,
            icon: Icons.south_west,
            color: AppTokens.expense,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '매도',
            amount: summary.sell,
            icon: Icons.north_east,
            color: AppTokens.income,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '배당',
            amount: summary.dividend,
            icon: Icons.payments_outlined,
            color: AppTokens.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: '순현금흐름',
            amount: summary.net,
            icon: Icons.swap_vert,
            color: summary.net < 0 ? AppTokens.expense : AppTokens.accent,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final int amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _InvestmentCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTokens.muted)),
                const SizedBox(height: 4),
                Text(
                  formatKRW(amount),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoldingsCard extends StatelessWidget {
  const _HoldingsCard({required this.holdings});

  final List<CurrentHolding> holdings;

  @override
  Widget build(BuildContext context) {
    final totalCost = holdings.fold<int>(0, (sum, row) => sum + row.totalCost);

    return _InvestmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '현재 보유 종목',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                formatKRW(totalCost),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (holdings.isEmpty)
            const _EmptyState(message: '현재 보유 중인 종목이 없습니다.')
          else
            Column(
              children: [
                const _HoldingsHeader(),
                const Divider(height: 1),
                for (final holding in holdings) _HoldingRow(holding: holding),
              ],
            ),
        ],
      ),
    );
  }
}

class _HoldingsHeader extends StatelessWidget {
  const _HoldingsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('종목')),
          Expanded(flex: 2, child: Text('수량', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('평단', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('원가', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _HoldingRow extends StatelessWidget {
  const _HoldingRow({required this.holding});

  final CurrentHolding holding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              holding.ticker,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatQuantity(holding.quantity),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(holding.avgCost.round()),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(holding.totalCost),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentRowsCard extends StatelessWidget {
  const _InvestmentRowsCard({required this.rows});

  final List<Investment> rows;

  @override
  Widget build(BuildContext context) {
    return _InvestmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '월간 투자 거래',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _EmptyState(message: '이번 달 투자 거래가 없습니다.')
          else
            Column(
              children: [
                const _InvestmentRowsHeader(),
                const Divider(height: 1),
                for (final row in rows) _InvestmentRow(row: row),
              ],
            ),
        ],
      ),
    );
  }
}

class _InvestmentRowsHeader extends StatelessWidget {
  const _InvestmentRowsHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('일자')),
          Expanded(flex: 2, child: Text('구분')),
          Expanded(flex: 3, child: Text('종목')),
          Expanded(flex: 2, child: Text('수량', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('금액', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.row});

  final Investment row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('${row.occurredOn} ${row.occurredTime}'),
          ),
          Expanded(flex: 2, child: _SidePill(side: row.side)),
          Expanded(
            flex: 3,
            child: Text(
              row.ticker,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.side == 'dividend' ? '-' : _formatQuantity(row.quantity),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(row.totalAmount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidePill extends StatelessWidget {
  const _SidePill({required this.side});

  final String side;

  @override
  Widget build(BuildContext context) {
    final label = switch (side) {
      'buy' => '매수',
      'sell' => '매도',
      'dividend' => '배당',
      _ => side,
    };
    final color = switch (side) {
      'buy' => AppTokens.expense,
      'sell' => AppTokens.income,
      'dividend' => AppTokens.warning,
      _ => AppTokens.muted,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.sidebarActive,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTokens.sidebarBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _PnlTodoCard extends StatelessWidget {
  const _PnlTodoCard();

  @override
  Widget build(BuildContext context) {
    return const _InvestmentCard(
      child: Row(
        children: [
          Icon(Icons.insights_outlined, color: AppTokens.muted),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('실현손익', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text(
                  'PnL 탭은 다음 단계에서 구현합니다.',
                  style: TextStyle(color: AppTokens.muted),
                ),
              ],
            ),
          ),
          _StatusPill(label: 'TODO'),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: const TextStyle(color: AppTokens.muted)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _InvestmentCard(
      child: Text(message, style: const TextStyle(color: AppTokens.expense)),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

String _formatQuantity(double value) {
  final fixed = value.toStringAsFixed(6);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}
