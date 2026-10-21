import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/investments/cost_basis.dart';
import '../../../features/investments/quantity_precision.dart';
import '../../../features/investments/validation.dart';
import 'package:my_little_budget/features/investments/providers.dart';
import '../../shared/amount_input_formatter.dart';
import '../page_back_button.dart';
import '../desktop_section.dart';
import 'widgets/investment_summary_card.dart';
import 'widgets/investment_portfolio_table.dart';
import '../../shared/bulk_manage_button.dart';

final _desktopHoldingsProvider =
    FutureProvider.autoDispose<List<CurrentHolding>>((ref) async {
      final accountId = ref.watch(
        investmentFilterProvider.select((f) => f.accountId),
      );
      final dao = ref.watch(investmentsDaoProvider);
      final all = await ref.watch(currentHoldingsProvider.future);
      if (accountId == null) return all;
      return dao.listCurrentHoldings(accountId: accountId);
    });

class InvestmentsScreen extends ConsumerStatefulWidget {
  const InvestmentsScreen({super.key});

  @override
  ConsumerState<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends ConsumerState<InvestmentsScreen> {
  bool _yearly = false;
  int _tab = 0;
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(investmentMonthProvider);
    final account = ref.watch(investmentAccountProvider);
    final summary = _yearly
        ? ref.watch(investmentYearlySummaryProvider(_year))
        : ref.watch(investmentMonthlySummaryProvider);
    final holdings = ref.watch(_desktopHoldingsProvider);
    final rows = _yearly
        ? ref.watch(investmentYearlyRowsProvider(_year))
        : ref.watch(investmentRowsProvider);
    final realizedPnl = _yearly
        ? ref.watch(investmentYearlyRealizedPnlProvider(_year))
        : ref.watch(realizedPnlProvider);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: SingleChildScrollView(
          key: const ValueKey('desktop-investments-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DesktopSection(
                minWidth: 840,
                child: Row(
                  children: [
                    const PageBackButton(),
                    const Text(
                      '투자',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    _InvestmentPeriodNav(
                      yearly: _yearly,
                      month: month,
                      year: _year,
                      onModeChanged: (yearly) => setState(() {
                        _yearly = yearly;
                        if (yearly) _year = parseMonthKey(month).year;
                      }),
                      onMonthChanged: (value) =>
                          ref.read(investmentMonthProvider.notifier).state =
                              value,
                      onYearChanged: (value) => setState(() => _year = value),
                    ),
                    const SizedBox(width: 20),
                    const _AddInvestmentButton(),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              summary.when(
                data: (value) => DesktopSection(
                  minWidth: 800,
                  child: InvestmentSummaryCard(summary: value),
                ),
                loading: () => const _InvestmentCard(
                  child: LinearProgressIndicator(minHeight: 3),
                ),
                error: (error, _) => _ErrorCard(message: error.toString()),
              ),
              const SizedBox(height: 20),
              _InvestmentCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopSection(
                      minWidth: 480,
                      child: Row(
                        children: [
                          for (final (index, title) in [
                            (0, '보유 종목'),
                            (1, '거래 내역'),
                            (2, '실현손익'),
                          ])
                            SizedBox(
                              width: 160,
                              child: InkWell(
                                key: ValueKey('desktop-investments-tab-$index'),
                                onTap: () => setState(() => _tab = index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        width: 3,
                                        color: _tab == index
                                            ? context.desktopIncome
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _tab == index
                                          ? context.desktopIncome
                                          : context.desktopMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    _InvestmentFilterBar(showTradeFilters: _tab != 0),
                    const SizedBox(height: 24),
                    if (_tab == 0)
                      holdings.when(
                        data: (value) {
                          final filter = ref.watch(investmentFilterProvider);
                          final query =
                              filter.ticker?.trim().toLowerCase() ?? '';
                          return InvestmentPortfolioTable(
                            searching:
                                query.isNotEmpty || filter.accountId != null,
                            holdings: value
                                .where(
                                  (h) => h.ticker.toLowerCase().contains(query),
                                )
                                .toList(),
                            accountName: account.asData?.value?.name,
                            pnlRows: realizedPnl.asData?.value ?? const [],
                            onBuy: (holding) => _InvestmentCreateDialog.show(
                              context,
                              initialSide: 'buy',
                              initialTicker: holding.ticker,
                              lockSide: true,
                            ),
                            buildTradeForm: (holding, side, onSaved) =>
                                _HoldingInlineForm(
                                  key: ValueKey('${holding.ticker}-$side'),
                                  holding: holding,
                                  side: side,
                                  onSaved: onSaved,
                                ),
                          );
                        },
                        loading: () => const _InvestmentCard(
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                        error: (error, _) =>
                            _ErrorCard(message: error.toString()),
                      ),
                    if (_tab == 1)
                      DesktopSection(
                        minWidth: 900,
                        child: rows.when(
                          data: (value) => _InvestmentRowsCard(
                            rows: value,
                            filterActive: ref
                                .watch(investmentFilterProvider)
                                .isActive,
                            yearly: _yearly,
                          ),
                          loading: () => const _InvestmentCard(
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                          error: (error, _) =>
                              _ErrorCard(message: error.toString()),
                        ),
                      ),
                    if (_tab == 2)
                      DesktopSection(
                        minWidth: 1000,
                        child: realizedPnl.when(
                          data: (value) {
                            final visibleIds =
                                rows.asData?.value.map((r) => r.id).toSet() ??
                                <int>{};
                            return _RealizedPnlCard(
                              rows: value
                                  .where((r) => visibleIds.contains(r.id))
                                  .toList(),
                              yearly: _yearly,
                            );
                          },
                          loading: () => const _InvestmentCard(
                            child: LinearProgressIndicator(minHeight: 3),
                          ),
                          error: (error, _) =>
                              _ErrorCard(message: error.toString()),
                        ),
                      ),
                    if (account.hasError)
                      Text(
                        '투자 계좌를 불러오지 못했습니다.',
                        style: TextStyle(color: context.desktopExpense),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.desktopMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '거래 내역에서 항목을 길게 누르면 여러 건을 선택할 수 있어요.',
                      style: TextStyle(
                        color: context.desktopMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    ).bulkSelectionViewport(BulkEntity.investments);
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
      icon: Icon(Icons.add, size: 18),
      label: Text('투자 거래 추가'),
    );
  }
}

class _InvestmentFilterBar extends ConsumerStatefulWidget {
  const _InvestmentFilterBar({required this.showTradeFilters});
  final bool showTradeFilters;

  @override
  ConsumerState<_InvestmentFilterBar> createState() =>
      _InvestmentFilterBarState();
}

class _InvestmentFilterBarState extends ConsumerState<_InvestmentFilterBar> {
  final _tickerCtrl = TextEditingController();
  bool _expanded = false;

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

    return DesktopSection(
      minWidth: 700,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 360,
                child: TextField(
                  key: const ValueKey('investment-ticker-filter'),
                  controller: _tickerCtrl,
                  decoration: const InputDecoration(
                    hintText: '종목명·티커 검색',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      _setFilter(filter.copyWith(ticker: value.trim())),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('investment-account-filter'),
                  initialValue: filter.accountId ?? -1,
                  isExpanded: true,
                  decoration: const InputDecoration(isDense: true),
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
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const ValueKey('desktop-investment-filter-toggle'),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: Text(_expanded ? '필터 접기' : '필터'),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (widget.showTradeFilters)
                  SegmentedButton<String>(
                    key: const ValueKey('investment-side-filter'),
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('전체')),
                      ButtonSegment(value: 'buy', label: Text('매수')),
                      ButtonSegment(value: 'sell', label: Text('매도')),
                      ButtonSegment(value: 'dividend', label: Text('배당')),
                    ],
                    selected: {filter.side ?? 'all'},
                    emptySelectionAllowed: false,
                    onSelectionChanged: (values) {
                      final side = values.first == 'all' ? null : values.first;
                      _setFilter(filter.copyWith(side: side));
                    },
                  ),
                if (widget.showTradeFilters)
                  OutlinedButton.icon(
                    key: const ValueKey('investment-from-filter'),
                    onPressed: () => _pickDate(true),
                    icon: Icon(Icons.calendar_today, size: 14),
                    label: Text(filter.fromDate ?? '시작일'),
                  ),
                if (widget.showTradeFilters)
                  OutlinedButton.icon(
                    key: const ValueKey('investment-to-filter'),
                    onPressed: () => _pickDate(false),
                    icon: Icon(Icons.calendar_today, size: 14),
                    label: Text(filter.toDate ?? '종료일'),
                  ),
                TextButton.icon(
                  key: const ValueKey('investment-filter-reset'),
                  onPressed: filter.isActive ? _reset : null,
                  icon: Icon(Icons.refresh, size: 16),
                  label: Text('초기화'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InvestmentPeriodNav extends StatelessWidget {
  const _InvestmentPeriodNav({
    required this.yearly,
    required this.month,
    required this.year,
    required this.onModeChanged,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  final bool yearly;
  final String month;
  final int year;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<String> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      if (yearly) {
        onYearChanged(year + delta);
      } else {
        onMonthChanged(shiftMonth(month, delta));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SegmentedButton<bool>(
          key: const ValueKey('investment-period-mode'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('월별')),
            ButtonSegment(value: true, label: Text('연별')),
          ],
          selected: {yearly},
          onSelectionChanged: (values) => onModeChanged(values.first),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => shift(-1),
          icon: Icon(Icons.chevron_left),
          tooltip: yearly ? '이전 연도' : '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            if (yearly) {
              onYearChanged(DateTime.now().year);
            } else {
              onMonthChanged(currentMonthKey());
            }
          },
          icon: Icon(Icons.calendar_month, size: 18),
          label: Text(yearly ? '$year년' : '${d.year}년 ${d.month}월'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: Icon(Icons.chevron_right),
          tooltip: yearly ? '다음 연도' : '다음 달',
        ),
        SizedBox(width: 8),
        const SizedBox(width: 12),
        TextButton(
          onPressed: () {
            onMonthChanged(currentMonthKey());
            onYearChanged(DateTime.now().year);
          },
          child: const Text('오늘'),
        ),
      ],
    );
  }
}

class _HoldingInlineForm extends ConsumerStatefulWidget {
  const _HoldingInlineForm({
    super.key,
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
  final _memo = TextEditingController();
  final _quantityFocus = FocusNode();
  final _totalAmountFocus = FocusNode();
  final _memoFocus = FocusNode();
  bool _busy = false;

  bool get _isSell => widget.side == 'sell';

  @override
  void dispose() {
    _date.dispose();
    _quantity.dispose();
    _totalAmount.dispose();
    _memo.dispose();
    _quantityFocus.dispose();
    _totalAmountFocus.dispose();
    _memoFocus.dispose();
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
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final rawQuantity = double.tryParse(_quantity.text.trim());
      final quantity = _isSell && rawQuantity != null
          ? normalizeQuantity(rawQuantity)
          : (_isSell ? null : 0.0);
      final totalAmount = parseKRW(_totalAmount.text);

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
        _showValidationSnack(result.errors.values.first);
        return;
      }

      final quantityError = checkSellQuantity(
        side: widget.side,
        ticker: widget.holding.ticker,
        quantity: result.value!.quantity,
        heldQuantities: {widget.holding.ticker: widget.holding.quantity},
      );
      if (quantityError != null) {
        _showValidationSnack(quantityError);
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

  void _showValidationSnack(String message) {
    _showSnack('입력값을 확인해 주세요. $message');
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.desktopSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.desktopBorder),
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
                  color: _sideColor(context, widget.side),
                ),
                SizedBox(width: 6),
                Text(
                  _isSell ? '매도 입력' : '배당 입력',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: 10),
            TextField(
              controller: _date,
              readOnly: true,
              decoration: InputDecoration(
                labelText: '거래일',
                suffixIcon: IconButton(
                  onPressed: _busy ? null : _pickDate,
                  icon: Icon(Icons.calendar_month_outlined),
                ),
              ),
            ),
            SizedBox(height: 10),
            if (_isSell) ...[
              _QuantityField(
                controller: _quantity,
                focusNode: _quantityFocus,
                label: '매도 수량',
                enabled: !_busy,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _totalAmountFocus.requestFocus(),
              ),
              SizedBox(height: 10),
            ],
            TextField(
              key: ValueKey('holding-${widget.side}-total-amount-field'),
              controller: _totalAmount,
              focusNode: _totalAmountFocus,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: const [amountInputFormatter],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _memoFocus.requestFocus(),
              decoration: InputDecoration(
                labelText: _isSell ? '매도 총액' : '배당금 총액',
                suffixText: '원',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _memo,
              focusNode: _memoFocus,
              enabled: !_busy,
              minLines: 2,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _save(),
              decoration: const InputDecoration(labelText: '메모'),
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? SizedBox(
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
  const _InvestmentRowsCard({
    required this.rows,
    required this.filterActive,
    required this.yearly,
  });

  final List<Investment> rows;
  final bool filterActive;
  final bool yearly;

  @override
  Widget build(BuildContext context) {
    return _InvestmentCard(
      framed: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            yearly ? '연간 투자 거래' : '월간 투자 거래',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          if (rows.isEmpty)
            _EmptyState(
              message: filterActive
                  ? '필터 결과가 없습니다.'
                  : yearly
                  ? '이번 연도 투자 거래가 없습니다.'
                  : '이번 달 투자 거래가 없습니다.',
            )
          else
            Column(
              children: [
                BulkSelectionToolbar(
                  entity: BulkEntity.investments,
                  items: [
                    for (final row in rows)
                      BulkItem(
                        row.id,
                        row.ticker,
                        '${row.occurredOn} · ${_sideLabel(row.side)} · ${formatKRW(row.totalAmount)}',
                      ),
                  ],
                ),
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
    return Padding(
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
    final sideColor = _sideColor(context, row.side);

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
              style: TextStyle(fontWeight: FontWeight.w600),
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
                  key: ValueKey('investment-edit-${row.id}'),
                  tooltip: '수정',
                  onPressed: () =>
                      _InvestmentCreateDialog.show(context, investment: row),
                  icon: Icon(Icons.edit_outlined, size: 18),
                ),
                IconButton(
                  key: ValueKey('investment-delete-${row.id}'),
                  tooltip: '삭제',
                  onPressed: () => _confirmDeleteInvestment(context, ref, row),
                  icon: Icon(Icons.delete_outline, size: 18),
                  color: context.desktopExpense,
                ),
              ],
            ),
          ),
        ],
      ),
    ).bulkSelectable(BulkEntity.investments, row.id);
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
      key: const ValueKey('investment-delete-confirm-dialog'),
      title: Text('투자 거래 삭제'),
      content: Text('${row.ticker} ${_sideLabel(row.side)} 거래를 삭제할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('investment-delete-confirm-button'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('삭제'),
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
          color: _sideColor(context, side).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _sideColor(context, side).withValues(alpha: 0.35),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sideIcon(side),
                  size: 12,
                  color: _sideColor(context, side),
                ),
                SizedBox(width: 4),
                Text(
                  _sideLabel(side),
                  style: TextStyle(
                    color: _sideColor(context, side),
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
  const _RealizedPnlCard({required this.rows, required this.yearly});

  final List<RealizedPnL> rows;
  final bool yearly;

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
      framed: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '실현손익',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  label: yearly ? '연간 실현손익' : '월간 실현손익',
                  amount: totalPnl,
                  color: totalPnl < 0
                      ? context.desktopExpense
                      : context.desktopIncome,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _InlineMetric(
                  label: '총 매도금액',
                  amount: totalSell,
                  color: context.desktopIncome,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _InlineMetric(
                  label: '총 배당금',
                  amount: totalDividend,
                  color: context.desktopWarning,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          if (rows.isEmpty)
            _EmptyState(
              message: yearly ? '이번 연도 실현손익 내역이 없습니다.' : '이번 달 실현손익 내역이 없습니다.',
            )
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
        color: context.desktopSelectedSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.desktopMuted)),
            SizedBox(height: 4),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('거래일')),
          Expanded(flex: 2, child: Text('종류')),
          Expanded(flex: 2, child: Text('종목명')),
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
    final pnlColor = row.pnl < 0
        ? context.desktopExpense
        : context.desktopIncome;

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
              style: TextStyle(fontWeight: FontWeight.w600),
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
    this.initialTicker,
    this.lockSide = false,
  });

  final Investment? investment;
  final String initialSide;
  final String? initialTicker;
  final bool lockSide;

  static Future<void> show(
    BuildContext context, {
    Investment? investment,
    String initialSide = 'buy',
    String? initialTicker,
    bool lockSide = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => _InvestmentCreateDialog(
        investment: investment,
        initialSide: initialSide,
        initialTicker: initialTicker,
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
  final _quantity = TextEditingController();
  final _totalAmount = TextEditingController();
  final _memo = TextEditingController();
  final _tickerFocus = FocusNode();
  final _quantityFocus = FocusNode();
  final _totalAmountFocus = FocusNode();
  final _memoFocus = FocusNode();
  bool _busy = false;

  bool get _tickerLocked => widget.initialTicker?.isNotEmpty == true;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _ticker.text = widget.initialTicker ?? '';
    final row = widget.investment;
    if (row == null) return;

    _side = row.side;
    _date.text = row.occurredOn;
    _ticker.text = row.ticker;
    _memo.text = row.memo ?? '';
    _totalAmount.text = row.totalAmount.toString();
    if (row.side != 'dividend') {
      _quantity.text = _formatQuantity(row.quantity);
    }
  }

  @override
  void dispose() {
    _date.dispose();
    _ticker.dispose();
    _quantity.dispose();
    _totalAmount.dispose();
    _memo.dispose();
    _tickerFocus.dispose();
    _quantityFocus.dispose();
    _totalAmountFocus.dispose();
    _memoFocus.dispose();
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
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final rawQuantity = double.tryParse(_quantity.text.trim());
      final quantity = rawQuantity == null
          ? null
          : normalizeQuantity(rawQuantity);
      final totalAmount = parseKRW(_totalAmount.text);
      final result = validateInvestment(
        side: _side,
        occurredOn: _date.text.trim(),
        occurredTime: widget.investment?.occurredTime ?? nowTime(),
        ticker: _ticker.text,
        quantity: _side == 'dividend' ? 0 : quantity,
        totalAmount: totalAmount,
        memo: _memo.text,
      );

      if (result.isFail) {
        _showValidationSnack(result.errors.values.first);
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
        _showValidationSnack(tickerError);
        return;
      }
      final quantityError = checkSellQuantity(
        side: _side,
        ticker: result.value!.ticker,
        quantity: result.value!.quantity,
        heldQuantities: heldQuantities,
      );
      if (quantityError != null) {
        _showValidationSnack(quantityError);
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showValidationSnack(String message) {
    _showSnack('입력값을 확인해 주세요. $message');
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(investmentAccountProvider);

    return AlertDialog(
      key: const ValueKey('investment-dialog'),
      title: Text('투자 거래 추가'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 48).clamp(280.0, 540.0),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lockSide)
                _SidePill(side: _side)
              else
                SegmentedButton<String>(
                  key: const ValueKey('investment-dialog-side'),
                  segments: const [
                    ButtonSegment(value: 'buy', label: Text('매수')),
                    ButtonSegment(value: 'sell', label: Text('매도')),
                    ButtonSegment(value: 'dividend', label: Text('배당')),
                  ],
                  selected: {_side},
                  onSelectionChanged: _busy
                      ? null
                      : (values) => setState(() => _side = values.first),
                ),
              SizedBox(height: 12),
              TextField(
                key: const ValueKey('investment-date-field'),
                controller: _date,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: '거래일',
                  suffixIcon: IconButton(
                    onPressed: _busy ? null : _pickDate,
                    icon: Icon(Icons.calendar_month_outlined),
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                key: const ValueKey('investment-name-field'),
                controller: _ticker,
                focusNode: _tickerFocus,
                enabled: !_busy && !_tickerLocked,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) {
                  if (_side == 'buy' || _side == 'sell') {
                    _quantityFocus.requestFocus();
                  } else {
                    _totalAmountFocus.requestFocus();
                  }
                },
                decoration: const InputDecoration(labelText: '종목명'),
              ),
              SizedBox(height: 12),
              if (_side == 'buy' || _side == 'sell') ...[
                _QuantityField(
                  controller: _quantity,
                  focusNode: _quantityFocus,
                  label: _side == 'sell' ? '매도 수량' : '수량',
                  enabled: !_busy,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _totalAmountFocus.requestFocus(),
                ),
                SizedBox(height: 12),
              ],
              TextField(
                key: const ValueKey('investment-total-amount-field'),
                controller: _totalAmount,
                focusNode: _totalAmountFocus,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: const [amountInputFormatter],
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _memoFocus.requestFocus(),
                decoration: InputDecoration(
                  labelText: switch (_side) {
                    'buy' => '구매 총액',
                    'sell' => '매도 총액',
                    _ => '배당금 총액',
                  },
                  suffixText: '원',
                ),
              ),
              SizedBox(height: 12),
              account.when(
                data: (value) => InputDecorator(
                  decoration: const InputDecoration(labelText: '연결 계좌'),
                  child: Text(value?.name ?? '활성 투자 계좌 없음'),
                ),
                loading: () => const LinearProgressIndicator(minHeight: 3),
                error: (error, _) => Text(
                  error.toString(),
                  style: TextStyle(color: context.desktopExpense),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                key: const ValueKey('investment-memo-field'),
                controller: _memo,
                focusNode: _memoFocus,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _busy ? null : _save(),
                decoration: const InputDecoration(labelText: '메모'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('investment-cancel-button'),
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('investment-save-button'),
          onPressed: _busy ? null : _save,
          child: Text('저장'),
        ),
      ],
    );
  }
}

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    this.focusNode,
    this.label = '수량',
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('investment-quantity-field'),
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: context.desktopMuted, size: 22),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.desktopMuted),
            ),
          ],
        ),
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
      child: Text(message, style: TextStyle(color: context.desktopExpense)),
    );
  }
}

class _InvestmentCard extends StatelessWidget {
  const _InvestmentCard({required this.child, this.framed = true});

  final Widget child;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    if (!framed) return child;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: context.desktopBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

String _formatQuantity(double value) {
  return formatInvestmentQuantity(value);
}

String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String _sideLabel(String side) {
  return switch (side) {
    'buy' => '매수',
    'sell' => '매도',
    'dividend' => '배당',
    _ => side,
  };
}

Color _sideColor(BuildContext context, String side) {
  return switch (side) {
    'buy' => context.appExpense,
    'sell' => context.appIncome,
    'dividend' => context.appWarning,
    _ => context.desktopMuted,
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
