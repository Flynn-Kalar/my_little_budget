import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/investments/cost_basis.dart';
import '../../../../features/investments/manual_prices.dart';
import '../../../../features/investments/quantity_precision.dart';
import '../../desktop_section.dart';

class InvestmentPortfolioTable extends ConsumerStatefulWidget {
  const InvestmentPortfolioTable({
    super.key,
    required this.holdings,
    required this.accountName,
    required this.pnlRows,
    required this.onBuy,
    required this.buildTradeForm,
    this.searching = false,
  });

  final List<CurrentHolding> holdings;
  final String? accountName;
  final List<RealizedPnL> pnlRows;
  final void Function(CurrentHolding) onBuy;
  final Widget Function(CurrentHolding, String, VoidCallback) buildTradeForm;
  final bool searching;

  @override
  ConsumerState<InvestmentPortfolioTable> createState() => _PortfolioState();
}

class _PortfolioState extends ConsumerState<InvestmentPortfolioTable> {
  String? _expanded;
  String? _side;

  @override
  Widget build(BuildContext context) {
    final pricesAsync = ref.watch(investmentManualPricesProvider);
    final prices = pricesAsync.asData?.value ?? const <String, int>{};
    final holdings = widget.holdings;
    final priced = holdings.where((h) => prices.containsKey(h.ticker));
    final totalValue = priced.fold<int>(
      0,
      (sum, h) => sum + _value(h, prices[h.ticker]!),
    );
    final totalCost = holdings.fold<int>(0, (sum, h) => sum + h.totalCost);
    final totalPnl = priced.fold<int>(
      0,
      (sum, h) => sum + _value(h, prices[h.ticker]!) - h.totalCost,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '보유 종목 ${holdings.length}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '등록한 거래 · 수동 현재가 기준',
                style: TextStyle(fontSize: 12, color: context.desktopMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (pricesAsync.hasError)
          Text(
            '현재가를 불러오지 못했습니다. 다시 열어 주세요.',
            style: TextStyle(color: context.desktopExpense),
          ),
        if (holdings.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 44),
            child: Center(
              child: Text(
                widget.searching
                    ? '검색 결과가 없습니다.'
                    : '보유 종목이 없습니다. 매수 거래를 추가해 주세요.',
              ),
            ),
          )
        else
          DesktopSection(
            minWidth: 1000,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.desktopSelectedSurface.withValues(
                      alpha: .35,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: const Row(
                    children: [
                      SizedBox(width: 28),
                      Expanded(flex: 5, child: Text('종목')),
                      Expanded(
                        flex: 2,
                        child: Text('보유 수량', textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('평균 매수가', textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('현재가', textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('평가 금액', textAlign: TextAlign.right),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text('평가손익', textAlign: TextAlign.right),
                      ),
                      SizedBox(width: 40),
                    ],
                  ),
                ),
                for (final h in holdings) ...[
                  _row(context, h, prices[h.ticker]),
                  if (_expanded == h.ticker)
                    _details(context, h, prices[h.ticker]),
                  Divider(height: 1, color: context.desktopBorder),
                ],
              ],
            ),
          ),
        const SizedBox(height: 20),
        DesktopSection(
          minWidth: 700,
          child: Row(
            children: [
              Expanded(
                child: _metric(
                  context,
                  priced.length == holdings.length && holdings.isNotEmpty
                      ? '총 평가 금액'
                      : '총 매입 금액',
                  priced.length == holdings.length && holdings.isNotEmpty
                      ? totalValue
                      : totalCost,
                ),
              ),
              Expanded(
                child: _metric(
                  context,
                  priced.isEmpty ? '평가손익' : '평가손익 (${priced.length}종목)',
                  priced.isEmpty ? null : totalPnl,
                  signed: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, CurrentHolding h, int? price) {
    final expanded = _expanded == h.ticker;
    final pnl = price == null ? null : _value(h, price) - h.totalCost;
    final color = pnl != null && pnl < 0
        ? context.desktopExpense
        : context.desktopIncome;
    final palette = [
      context.desktopIncome,
      context.desktopAccent,
      const Color(0xFF3985D8),
      const Color(0xFFB78A41),
    ];
    final iconColor =
        palette[h.ticker.runes.fold<int>(0, (a, b) => a + b) % palette.length];
    return Material(
      color: expanded
          ? context.desktopSelectedSurface.withValues(alpha: .5)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('holding-row-${h.ticker}'),
        onTap: () => setState(() {
          _expanded = expanded ? null : h.ticker;
          _side = null;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        String.fromCharCodes(h.ticker.runes.take(2)),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.ticker,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.accountName ?? '연결 계좌 없음',
                            style: TextStyle(
                              color: context.desktopMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  formatInvestmentQuantity(
                    h.quantity,
                  ).replaceFirst(RegExp(r'\.?0+$'), ''),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  formatKRW(h.avgCost.round()),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  price == null ? '—' : formatKRW(price),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  price == null ? '—' : formatKRW(_value(h, price)),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pnl == null
                          ? '—'
                          : '${pnl > 0 ? '+' : ''}${formatKRW(pnl)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: pnl == null ? context.desktopMuted : color,
                      ),
                    ),
                    if (pnl != null && h.totalCost > 0)
                      Text(
                        '${pnl > 0 ? '+' : ''}${(pnl / h.totalCost * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: color, fontSize: 12),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  key: ValueKey('holding-price-${h.ticker}'),
                  tooltip: '현재가 수정',
                  onPressed: () => _editPrice(context, h, price),
                  icon: const Icon(Icons.more_vert, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, CurrentHolding h, int? price) {
    final dividends = widget.pnlRows
        .where((r) => r.ticker == h.ticker && r.kind == RealizedKind.dividend)
        .fold<int>(0, (sum, r) => sum + r.pnl);
    return Container(
      key: ValueKey('holding-details-${h.ticker}'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.desktopSelectedSurface.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _metric(context, '매입 금액', h.totalCost)),
              Expanded(
                child: _metric(
                  context,
                  '평가 금액',
                  price == null ? null : _value(h, price),
                ),
              ),
              Expanded(child: _metric(context, '선택 기간 배당금', dividends)),
              OutlinedButton(
                onPressed: () => _editPrice(context, h, price),
                child: const Text('현재가 수정'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('holding-add-buy-${h.ticker}'),
                onPressed: () => widget.onBuy(h),
                child: const Text('추가 매수'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('holding-sell-${h.ticker}'),
                onPressed: () =>
                    setState(() => _side = _side == 'sell' ? null : 'sell'),
                child: const Text('매도'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                key: ValueKey('holding-dividend-${h.ticker}'),
                onPressed: () => setState(
                  () => _side = _side == 'dividend' ? null : 'dividend',
                ),
                child: const Text('배당금 추가'),
              ),
            ],
          ),
          if (_side != null) ...[
            const SizedBox(height: 16),
            widget.buildTradeForm(
              h,
              _side!,
              () => setState(() => _side = null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    int? amount, {
    bool signed = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, color: context.desktopMuted)),
      const SizedBox(height: 6),
      Text(
        amount == null
            ? '—'
            : '${signed && amount > 0 ? '+' : ''}${formatKRW(amount)}',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: signed && amount != null
              ? (amount < 0 ? context.desktopExpense : context.desktopIncome)
              : null,
        ),
      ),
    ],
  );

  int _value(CurrentHolding holding, int price) =>
      (holding.quantity * price).round();

  Future<void> _editPrice(
    BuildContext context,
    CurrentHolding holding,
    int? current,
  ) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        _PriceDialog(ticker: holding.ticker, current: current),
  );
}

class _PriceDialog extends ConsumerStatefulWidget {
  const _PriceDialog({required this.ticker, required this.current});
  final String ticker;
  final int? current;
  @override
  ConsumerState<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends ConsumerState<_PriceDialog> {
  late final _controller = TextEditingController(
    text: widget.current?.toString() ?? '',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(int? value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(investmentManualPricesProvider.notifier)
          .setPrice(widget.ticker, value);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '저장하지 못했습니다. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text('${widget.ticker} 현재가 수정'),
      content: SizedBox(
        width: 360,
        child: TextField(
          key: const ValueKey('investment-current-price'),
          controller: _controller,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '현재가',
            suffixText: '원',
            helperText: '직접 입력한 현재가를 이 기기에 저장합니다.',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: _busy ? null : () => _save(null),
            child: const Text('현재가 지우기'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('investment-price-save'),
          onPressed: _busy
              ? null
              : () {
                  final value = int.tryParse(
                    _controller.text.replaceAll(',', '').trim(),
                  );
                  if (value == null ||
                      value <= 0 ||
                      value > maxInvestmentPrice) {
                    setState(
                      () => _error =
                          '1원 이상 ${formatKRW(maxInvestmentPrice)} 이하로 입력하세요.',
                    );
                    return;
                  }
                  _save(value);
                },
          child: const Text('저장'),
        ),
      ],
    ),
  );
}
