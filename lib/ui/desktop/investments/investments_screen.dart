import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/investments_dao.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/investments/cost_basis.dart';
import '../../../features/investments/quantity_precision.dart';
import '../../../features/investments/validation.dart';
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
    final realizedPnl = ref.watch(realizedPnlProvider);

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
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _InvestmentMonthNav(month: month),
                const _AddInvestmentButton(),
              ],
            ),
            const SizedBox(height: 12),
            const _InvestmentFilterBar(),
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
              data: (value) => _InvestmentRowsCard(
                rows: value,
                filterActive: ref.watch(investmentFilterProvider).isActive,
              ),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 16),
            realizedPnl.when(
              data: (value) => _RealizedPnlCard(rows: value),
              loading: () => const _InvestmentCard(
                child: LinearProgressIndicator(minHeight: 3),
              ),
              error: (error, _) => _ErrorCard(message: error.toString()),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _AddInvestmentButton extends StatelessWidget {
  const _AddInvestmentButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => _InvestmentCreateDialog.show(
        context,
        initialSide: 'buy',
        lockSide: true,
      ),
      icon: const Icon(Icons.add, size: 18),
      label: const Text('투자 거래 추가'),
    );
  }
}

class _InvestmentFilterBar extends ConsumerStatefulWidget {
  const _InvestmentFilterBar();

  @override
  ConsumerState<_InvestmentFilterBar> createState() =>
      _InvestmentFilterBarState();
}

class _InvestmentFilterBarState extends ConsumerState<_InvestmentFilterBar> {
  final _tickerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tickerCtrl.text = ref.read(investmentFilterProvider).ticker ?? '';
  }

  @override
  void dispose() {
    _tickerCtrl.dispose();
    super.dispose();
  }

  void _setFilter(InvestmentFilter filter) {
    ref.read(investmentFilterProvider.notifier).state = filter;
  }

  Future<void> _pickDate(bool isFrom) async {
    final filter = ref.read(investmentFilterProvider);
    final initialKey = isFrom ? filter.fromDate : filter.toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialKey == null
          ? DateTime.now()
          : DateTime.parse(initialKey),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    _setFilter(
      filter.copyWith(
        fromDate: isFrom ? toDateKey(picked) : filter.fromDate,
        toDate: isFrom ? filter.toDate : toDateKey(picked),
      ),
    );
  }

  void _reset() {
    _tickerCtrl.clear();
    _setFilter(const InvestmentFilter());
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(investmentFilterProvider);
    final accounts =
        ref.watch(investmentFilterAccountsProvider).asData?.value ?? const [];

    return _InvestmentCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<String>(
            key: const ValueKey('investment-side-filter'),
            segments: const [
              ButtonSegment(value: 'all', label: Text('전체')),
              ButtonSegment(value: 'buy', label: Text('BUY')),
              ButtonSegment(value: 'sell', label: Text('SELL')),
              ButtonSegment(value: 'dividend', label: Text('DIVIDEND')),
            ],
            selected: {filter.side ?? 'all'},
            emptySelectionAllowed: false,
            onSelectionChanged: (values) {
              final side = values.first == 'all' ? null : values.first;
              _setFilter(filter.copyWith(side: side));
            },
          ),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<int>(
              key: const ValueKey('investment-account-filter'),
              initialValue: filter.accountId ?? -1,
              decoration: const InputDecoration(
                labelText: '계좌',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: -1, child: Text('전체 계좌')),
                for (final account in accounts)
                  DropdownMenuItem(
                    value: account.id,
                    child: Text(account.name),
                  ),
              ],
              onChanged: (value) => _setFilter(
                filter.copyWith(accountId: value == -1 ? null : value),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              key: const ValueKey('investment-ticker-filter'),
              controller: _tickerCtrl,
              decoration: const InputDecoration(
                labelText: '종목',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  _setFilter(filter.copyWith(ticker: value.trim())),
            ),
          ),
          OutlinedButton.icon(
            key: const ValueKey('investment-from-filter'),
            onPressed: () => _pickDate(true),
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(filter.fromDate ?? '시작일'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('investment-to-filter'),
            onPressed: () => _pickDate(false),
            icon: const Icon(Icons.calendar_today, size: 14),
            label: Text(filter.toDate ?? '종료일'),
          ),
          TextButton.icon(
            key: const ValueKey('investment-filter-reset'),
            onPressed: filter.isActive ? _reset : null,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('초기화'),
          ),
        ],
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
                      : '활성 투자 자산이 없으면 투자 거래는 계좌 없이 저장됩니다.',
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

class _HoldingsCard extends ConsumerStatefulWidget {
  const _HoldingsCard({required this.holdings});

  final List<CurrentHolding> holdings;

  @override
  ConsumerState<_HoldingsCard> createState() => _HoldingsCardState();
}

class _HoldingsCardState extends ConsumerState<_HoldingsCard> {
  String? _expandedTicker;

  @override
  Widget build(BuildContext context) {
    final holdings = widget.holdings;
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
                for (final holding in holdings) ...[
                  _HoldingRow(
                    holding: holding,
                    expanded: _expandedTicker == holding.ticker,
                    onTap: () {
                      setState(() {
                        _expandedTicker = _expandedTicker == holding.ticker
                            ? null
                            : holding.ticker;
                      });
                    },
                  ),
                  if (_expandedTicker == holding.ticker)
                    _HoldingInlineActions(
                      holding: holding,
                      onSaved: () => setState(() => _expandedTicker = null),
                    ),
                ],
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
  const _HoldingRow({
    required this.holding,
    required this.expanded,
    required this.onTap,
  });

  final CurrentHolding holding;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppTokens.muted,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      holding.ticker,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
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
      ),
    );
  }
}

class _HoldingInlineActions extends StatelessWidget {
  const _HoldingInlineActions({required this.holding, required this.onSaved});

  final CurrentHolding holding;
  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 0, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTokens.sidebarActive,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTokens.sidebarBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${holding.ticker} · ${_formatQuantity(holding.quantity)} 보유',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 720;
                  final forms = [
                    _HoldingInlineForm(
                      side: 'sell',
                      holding: holding,
                      onSaved: onSaved,
                    ),
                    _HoldingInlineForm(
                      side: 'dividend',
                      holding: holding,
                      onSaved: onSaved,
                    ),
                  ];
                  if (narrow) {
                    return Column(
                      children: [
                        forms[0],
                        const SizedBox(height: 12),
                        forms[1],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: forms[0]),
                      const SizedBox(width: 12),
                      Expanded(child: forms[1]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HoldingInlineForm extends ConsumerStatefulWidget {
  const _HoldingInlineForm({
    required this.side,
    required this.holding,
    required this.onSaved,
  });

  final String side;
  final CurrentHolding holding;
  final VoidCallback onSaved;

  @override
  ConsumerState<_HoldingInlineForm> createState() => _HoldingInlineFormState();
}

class _HoldingInlineFormState extends ConsumerState<_HoldingInlineForm> {
  final _date = TextEditingController(text: currentDateKey());
  final _quantity = TextEditingController();
  final _totalAmount = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _memo = TextEditingController();
  bool _busy = false;

  bool get _isSell => widget.side == 'sell';

  @override
  void dispose() {
    _date.dispose();
    _quantity.dispose();
    _totalAmount.dispose();
    _fee.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(_date.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _date.text = toDateKey(picked);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final rawQuantity = double.tryParse(_quantity.text.trim());
      final quantity = _isSell && rawQuantity != null
          ? normalizeQuantity(rawQuantity)
          : (_isSell ? null : 0.0);
      final fee = _isSell ? parseKRW(_fee.text) : 0;
      final totalAmount = _isSell
          ? parseKRW(_totalAmount.text) - fee
          : parseKRW(_totalAmount.text);

      final result = validateInvestment(
        side: widget.side,
        occurredOn: _date.text.trim(),
        occurredTime: nowTime(),
        ticker: widget.holding.ticker,
        quantity: quantity,
        totalAmount: totalAmount,
        memo: _memo.text,
      );
      if (result.isFail) {
        _showSnack(result.errors.values.first);
        return;
      }

      final quantityError = checkSellQuantity(
        side: widget.side,
        ticker: widget.holding.ticker,
        quantity: result.value!.quantity,
        heldQuantities: {widget.holding.ticker: widget.holding.quantity},
      );
      if (quantityError != null) {
        _showSnack(quantityError);
        return;
      }

      final linkedAccount = await ref.read(investmentAccountProvider.future);
      await ref
          .read(investmentsDaoProvider)
          .saveInvestment(draft: result.value!);
      if (!mounted) return;
      refreshInvestments(ref, accountId: linkedAccount?.id);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_sideLabel(widget.side)} 거래를 저장했습니다.')),
      );
    } catch (e) {
      if (mounted) _showSnack('저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTokens.sidebarBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _sideIcon(widget.side),
                  size: 16,
                  color: _sideColor(widget.side),
                ),
                const SizedBox(width: 6),
                Text(
                  _isSell ? '매도 입력' : '배당 입력',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _date,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '거래일',
                suffixIcon: IconButton(
                  onPressed: _busy ? null : _pickDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_isSell) ...[
              _QuantityField(controller: _quantity, label: '매도 수량'),
              const SizedBox(height: 10),
              TextField(
                controller: _totalAmount,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '총 매도금액',
                  suffixText: '원',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fee,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '수수료',
                  suffixText: '원',
                ),
              ),
            ] else ...[
              TextField(
                controller: _totalAmount,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '배당금 총액',
                  suffixText: '원',
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _memo,
              enabled: !_busy,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '메모'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_sideIcon(widget.side), size: 16),
                label: Text(_isSell ? '매도 저장' : '배당 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentRowsCard extends StatelessWidget {
  const _InvestmentRowsCard({required this.rows, required this.filterActive});

  final List<Investment> rows;
  final bool filterActive;

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
            _EmptyState(
              message: filterActive ? '필터 결과가 없습니다.' : '이번 달 투자 거래가 없습니다.',
            )
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

class _InvestmentRow extends ConsumerWidget {
  const _InvestmentRow({required this.row});

  final Investment row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sideColor = _sideColor(row.side);

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
              style: TextStyle(color: sideColor, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 104,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '수정',
                  onPressed: () =>
                      _InvestmentCreateDialog.show(context, investment: row),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  tooltip: '삭제',
                  onPressed: () => _confirmDeleteInvestment(context, ref, row),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: AppTokens.expense,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteInvestment(
  BuildContext context,
  WidgetRef ref,
  Investment row,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('투자 거래 삭제'),
      content: Text('${row.ticker} ${_sideLabel(row.side)} 거래를 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final linkedAccount = await ref.read(investmentAccountProvider.future);
    await ref.read(investmentsDaoProvider).deleteInvestment(row.id);
    if (!context.mounted) return;
    refreshInvestments(ref, accountId: linkedAccount?.id);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('투자 거래를 삭제했습니다.')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('삭제에 실패했습니다: $e')));
  }
}

class _SidePill extends StatelessWidget {
  const _SidePill({required this.side});

  final String side;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _sideColor(side).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _sideColor(side).withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_sideIcon(side), size: 12, color: _sideColor(side)),
                const SizedBox(width: 4),
                Text(
                  _sideLabel(side),
                  style: TextStyle(
                    color: _sideColor(side),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _RealizedPnlCard extends StatelessWidget {
  const _RealizedPnlCard({required this.rows});

  final List<RealizedPnL> rows;

  @override
  Widget build(BuildContext context) {
    final totalPnl = rows.fold<int>(0, (sum, row) => sum + row.pnl);
    final totalSell = rows
        .where((row) => row.kind == RealizedKind.sell)
        .fold<int>(0, (sum, row) => sum + row.sellAmount);
    final totalDividend = rows
        .where((row) => row.kind == RealizedKind.dividend)
        .fold<int>(0, (sum, row) => sum + row.sellAmount);

    return _InvestmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '실현손익',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  label: '월간 실현손익',
                  amount: totalPnl,
                  color: totalPnl < 0 ? AppTokens.expense : AppTokens.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineMetric(
                  label: '총 매도금액',
                  amount: totalSell,
                  color: AppTokens.income,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineMetric(
                  label: '총 배당금',
                  amount: totalDividend,
                  color: AppTokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const _EmptyState(message: '이번 달 실현손익 내역이 없습니다.')
          else
            Column(
              children: [
                const _RealizedPnlHeader(),
                const Divider(height: 1),
                for (final row in rows) _RealizedPnlRow(row: row),
              ],
            ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTokens.sidebarActive,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
    );
  }
}

class _RealizedPnlHeader extends StatelessWidget {
  const _RealizedPnlHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('거래일')),
          Expanded(flex: 2, child: Text('종류')),
          Expanded(flex: 2, child: Text('ticker')),
          Expanded(flex: 2, child: Text('수량', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('매도/배당', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('원가', textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('손익', textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('수익률', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _RealizedPnlRow extends StatelessWidget {
  const _RealizedPnlRow({required this.row});

  final RealizedPnL row;

  @override
  Widget build(BuildContext context) {
    final side = row.kind == RealizedKind.sell ? 'sell' : 'dividend';
    final pnlColor = row.pnl < 0 ? AppTokens.expense : AppTokens.income;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('${row.occurredOn} ${row.occurredTime}'),
          ),
          Expanded(flex: 2, child: _SidePill(side: side)),
          Expanded(
            flex: 2,
            child: Text(
              row.ticker,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.kind == RealizedKind.dividend
                  ? '-'
                  : _formatQuantity(row.quantity),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.sellAmount), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(formatKRW(row.costBasis), textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 3,
            child: Text(
              formatKRW(row.pnl),
              textAlign: TextAlign.right,
              style: TextStyle(color: pnlColor, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.kind == RealizedKind.dividend
                  ? '-'
                  : _formatPercent(row.returnRate),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvestmentCreateDialog extends ConsumerStatefulWidget {
  const _InvestmentCreateDialog({
    this.investment,
    this.initialSide = 'buy',
    this.lockSide = false,
  });

  final Investment? investment;
  final String initialSide;
  final bool lockSide;

  static Future<void> show(
    BuildContext context, {
    Investment? investment,
    String initialSide = 'buy',
    bool lockSide = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _InvestmentCreateDialog(
        investment: investment,
        initialSide: initialSide,
        lockSide: lockSide,
      ),
    );
  }

  @override
  ConsumerState<_InvestmentCreateDialog> createState() =>
      _InvestmentCreateDialogState();
}

class _InvestmentCreateDialogState
    extends ConsumerState<_InvestmentCreateDialog> {
  String _side = 'buy';
  final _date = TextEditingController(text: currentDateKey());
  final _ticker = TextEditingController();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _totalAmount = TextEditingController();
  final _fee = TextEditingController(text: '0');
  final _memo = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    final row = widget.investment;
    if (row == null) return;

    _side = row.side;
    _date.text = row.occurredOn;
    _ticker.text = row.ticker;
    _memo.text = row.memo ?? '';
    if (row.side == 'dividend') {
      _totalAmount.text = row.totalAmount.toString();
      return;
    }

    _quantity.text = _formatQuantity(row.quantity);
    if (row.side == 'buy') {
      final unitPrice = row.quantity == 0
          ? row.totalAmount
          : (row.totalAmount / row.quantity).round();
      _unitPrice.text = unitPrice.toString();
    } else {
      _totalAmount.text = row.totalAmount.toString();
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _ticker.dispose();
    _name.dispose();
    _quantity.dispose();
    _unitPrice.dispose();
    _totalAmount.dispose();
    _fee.dispose();
    _memo.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: parseDateKey(_date.text),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _date.text = toDateKey(picked);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final rawQuantity = double.tryParse(_quantity.text.trim());
      final quantity = rawQuantity == null
          ? null
          : normalizeQuantity(rawQuantity);
      final unitPrice = parseKRW(_unitPrice.text);
      final fee = parseKRW(_fee.text);
      final totalAmount = switch (_side) {
        'buy' => quantity == null ? null : (quantity * unitPrice).round() + fee,
        'sell' => parseKRW(_totalAmount.text) - fee,
        'dividend' => parseKRW(_totalAmount.text),
        _ => null,
      };
      final result = validateInvestment(
        side: _side,
        occurredOn: _date.text.trim(),
        occurredTime: widget.investment?.occurredTime ?? nowTime(),
        ticker: _ticker.text,
        quantity: _side == 'dividend' ? 0 : quantity,
        totalAmount: totalAmount,
        memo: _mergedMemo(),
      );

      if (result.isFail) {
        _showSnack(result.errors.values.first);
        return;
      }

      final holdings = await ref.read(currentHoldingsProvider.future);
      final heldQuantities = {
        for (final holding in holdings) holding.ticker: holding.quantity,
      };
      final original = widget.investment;
      if (original != null && original.side == 'sell') {
        heldQuantities[original.ticker] =
            (heldQuantities[original.ticker] ?? 0) + original.quantity;
      }
      final heldTickers = heldQuantities.keys.toSet();
      final tickerError = checkTradableTicker(
        side: _side,
        ticker: result.value!.ticker,
        heldTickers: heldTickers,
        existingTicker: widget.investment?.ticker,
      );
      if (tickerError != null) {
        _showSnack(tickerError);
        return;
      }
      final quantityError = checkSellQuantity(
        side: _side,
        ticker: result.value!.ticker,
        quantity: result.value!.quantity,
        heldQuantities: heldQuantities,
      );
      if (quantityError != null) {
        _showSnack(quantityError);
        return;
      }

      final linkedAccount = await ref.read(investmentAccountProvider.future);
      await ref
          .read(investmentsDaoProvider)
          .saveInvestment(id: widget.investment?.id, draft: result.value!);
      if (!mounted) return;
      refreshInvestments(ref, accountId: linkedAccount?.id);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_sideLabel(_side)} 거래를 저장했습니다.')),
      );
    } catch (e) {
      if (mounted) _showSnack('저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _mergedMemo() {
    final memo = _memo.text.trim();
    if (_side != 'buy') return memo.isEmpty ? null : memo;
    final name = _name.text.trim();
    if (name.isEmpty && memo.isEmpty) return null;
    if (name.isEmpty) return memo;
    if (memo.isEmpty) return '종목명: $name';
    return '종목명: $name\n$memo';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(investmentAccountProvider);

    return AlertDialog(
      title: const Text('투자 거래 추가'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lockSide)
                _SidePill(side: _side)
              else
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'buy', label: Text('BUY')),
                    ButtonSegment(value: 'sell', label: Text('SELL')),
                    ButtonSegment(value: 'dividend', label: Text('DIVIDEND')),
                  ],
                  selected: {_side},
                  onSelectionChanged: _busy
                      ? null
                      : (values) => setState(() => _side = values.first),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _date,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '거래일',
                  suffixIcon: IconButton(
                    onPressed: _busy ? null : _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ticker,
                enabled: !_busy,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'ticker'),
              ),
              const SizedBox(height: 12),
              if (_side == 'buy') ...[
                TextField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '종목명 / name',
                    helperText: '현재 DB에는 별도 종목명 컬럼이 없어 메모에 함께 저장됩니다.',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _QuantityField(controller: _quantity)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _unitPrice,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '단가',
                          suffixText: '원',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ] else if (_side == 'sell') ...[
                _QuantityField(controller: _quantity, label: '매도 수량'),
                const SizedBox(height: 12),
                TextField(
                  controller: _totalAmount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '총 매도금액',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                TextField(
                  controller: _totalAmount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '배당금 총액',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_side != 'dividend') ...[
                TextField(
                  controller: _fee,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '수수료',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              account.when(
                data: (value) => InputDecorator(
                  decoration: const InputDecoration(labelText: '연결 계좌'),
                  child: Text(value?.name ?? '활성 투자 계좌 없음'),
                ),
                loading: () => const LinearProgressIndicator(minHeight: 3),
                error: (error, _) => Text(
                  error.toString(),
                  style: const TextStyle(color: AppTokens.expense),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memo,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '메모'),
              ),
              const SizedBox(height: 12),
              const Text(
                'PnL 탭과 거래 수정/삭제는 다음 단계에서 구현합니다.',
                style: TextStyle(color: AppTokens.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ],
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({required this.controller, this.label = '수량'});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
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
  return formatInvestmentQuantity(value);
}

String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _sideLabel(String side) {
  return switch (side) {
    'buy' => 'BUY',
    'sell' => 'SELL',
    'dividend' => 'DIVIDEND',
    _ => side,
  };
}

Color _sideColor(String side) {
  return switch (side) {
    'buy' => AppTokens.expense,
    'sell' => AppTokens.income,
    'dividend' => AppTokens.warning,
    _ => AppTokens.muted,
  };
}

IconData _sideIcon(String side) {
  return switch (side) {
    'buy' => Icons.south_west,
    'sell' => Icons.north_east,
    'dividend' => Icons.payments_outlined,
    _ => Icons.circle_outlined,
  };
}
