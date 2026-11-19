import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/colors.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/accounts_dao.dart';
import '../../../../data/providers.dart';
import '../../../../features/accounts/validation.dart';
import '../../../../features/settings/statement_period.dart';
import '../../../shared/amount_input_formatter.dart';
import '../../../shared/card_billing_fields.dart';
import '../../../shared/fund_purpose.dart';
import '../../../../features/accounts/account_refresh.dart';
import 'color_swatch_picker.dart';

const _kindLabels = {'cash': '현금', 'bank': '은행', 'card': '카드', 'other': '기타'};

/// SPEC §4.2 — 자산 신규/편집/보관 다이얼로그.
class AccountFormDialog extends ConsumerStatefulWidget {
  const AccountFormDialog({super.key, this.account});
  final AccountBalance? account;

  static Future<void> show(BuildContext context, {AccountBalance? account}) {
    return showDialog<void>(
      context: context,
      builder: (_) => AccountFormDialog(account: account),
    );
  }

  @override
  ConsumerState<AccountFormDialog> createState() => _State();
}

class _State extends ConsumerState<AccountFormDialog> {
  late final _nameCtrl = TextEditingController(
    text: widget.account?.name ?? '',
  );
  late final _balanceCtrl = TextEditingController(
    text: formatAmountInput(
      (widget.account?.kind == 'card'
              ? widget.account!.cardSpendingToDate
              : widget.account?.balance ?? 0)
          .toString(),
    ),
  );
  late final _cardLimitCtrl = TextEditingController(
    text: formatAmountInput(widget.account?.cardLimit?.toString() ?? ''),
  );
  late String _kind = widget.account?.kind ?? 'bank';
  late String _fundPurpose = widget.account?.fundPurpose ?? 'living';
  late int? _paymentDay = widget.account?.cardPaymentDay;
  late int? _closingDay = widget.account?.cardClosingDay;
  late String? _paymentAccountUuid = widget.account?.cardPaymentAccountUuid;
  late String _color =
      widget.account?.color ?? randomColor(); // 신규는 마운트 시 1회 랜덤
  late bool _excludeFromTotal = widget.account?.excludeFromTotal ?? false;
  late bool _isInvestment = widget.account?.isInvestment ?? false;
  bool _busy = false;

  bool get _isEditing => widget.account != null;

  void _changeKind(String kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _balanceCtrl.text = formatAmountInput(
        (kind == 'card'
                ? widget.account?.cardSpendingToDate ?? 0
                : widget.account?.balance ?? 0)
            .toString(),
      );
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _cardLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cardLimit = _kind == 'card' && _cardLimitCtrl.text.trim().isNotEmpty
        ? parseKRW(_cardLimitCtrl.text)
        : null;
    final result = validateAccount(
      name: _nameCtrl.text,
      kind: _kind,
      cardLimit: cardLimit,
      fundPurpose: (_kind == 'bank' || _kind == 'cash') && !_isInvestment
          ? _fundPurpose
          : 'living',
      cardPaymentDay: _kind == 'card' ? _paymentDay : null,
      cardClosingDay: _kind == 'card' ? _closingDay : null,
      cardPaymentAccountUuid: _kind == 'card' ? _paymentAccountUuid : null,
      color: _color,
      excludeFromTotal: _excludeFromTotal,
      isInvestment: _isInvestment,
    );
    if (result.isFail) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errors.values.first)));
      return;
    }
    setState(() => _busy = true);
    try {
      final today = ref.read(statementTodayProvider);
      final policy = await ref.read(statementPeriodProvider.future);
      final period = policy.range(policy.anchorForDate(today));
      await ref
          .read(accountsDaoProvider)
          .saveAccount(
            id: widget.account?.accountId,
            draft: result.value!,
            currentBalance: parseKRW(_balanceCtrl.text),
            adjustBalance:
                _kind != 'card' ||
                !_isEditing ||
                widget.account!.kind != 'card' ||
                parseKRW(_balanceCtrl.text) !=
                    widget.account!.cardSpendingToDate,
            asOf: today,
            currentCardSpending: _kind == 'card'
                ? parseKRW(_balanceCtrl.text)
                : null,
            statementStart: period.start,
            statementEnd: period.end,
          );
      refreshAccountMetadata(ref, accountId: widget.account?.accountId);
      if (widget.account != null) {
        refreshAccountTransactionMutation(ref, widget.account!.accountId);
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('자산 저장에 실패했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final acc = widget.account;
    if (acc == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const ValueKey('account-archive-confirm-dialog'),
        title: Text('자산 보관'),
        content: Text("'${acc.name}' 자산을 보관할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('account-archive-confirm-button'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('보관'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(accountsDaoProvider).archiveAccount(acc.accountId);
      refreshAccountMetadata(ref, accountId: acc.accountId);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('account-form-dialog'),
      title: Text(_isEditing ? '자산 편집' : '자산 추가'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '이름',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(
                  labelText: '종류',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _kindLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: _busy ? null : (v) => _changeKind(v ?? 'bank'),
              ),
              if ((_kind == 'bank' || _kind == 'cash') && !_isInvestment) ...[
                const SizedBox(height: 12),
                FundPurposeField(
                  value: _fundPurpose,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _fundPurpose = value),
                ),
              ],
              if (_kind == 'card') ...[
                const SizedBox(height: 12),
                CardBillingFields(
                  paymentDay: _paymentDay,
                  closingDay: _closingDay,
                  paymentAccountUuid: _paymentAccountUuid,
                  paymentAccountName: widget.account?.cardPaymentAccountName,
                  enabled: !_busy,
                  onPaymentDayChanged: (value) =>
                      setState(() => _paymentDay = value),
                  onClosingDayChanged: (value) =>
                      setState(() => _closingDay = value),
                  onPaymentAccountChanged: (value) =>
                      setState(() => _paymentAccountUuid = value),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: _cardLimitCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [amountInputFormatter],
                  decoration: const InputDecoration(
                    labelText: '카드 한도',
                    suffixText: '원',
                    isDense: true,
                    border: OutlineInputBorder(),
                    helperText: '현재 카드 부채가 한도의 80% 이상이면 경고합니다.',
                  ),
                ),
              ],
              SizedBox(height: 12),
              TextField(
                controller: _balanceCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [amountInputFormatter],
                decoration: InputDecoration(
                  labelText: _kind == 'card'
                      ? '오늘까지 쓴 금액'
                      : _isEditing
                      ? '현재 잔액'
                      : '초기 잔액',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  helperMaxLines: 3,
                  helperText: _kind == 'card'
                      ? '마감일 다음 날부터 오늘까지의 사용액을 입력하세요. 마감일 미설정 시 공통 집계기간을 따릅니다. 변경분은 오늘의 사용액 조정으로 기록합니다.'
                      : _isEditing
                      ? '오늘까지의 잔액을 수정합니다. 예정 거래는 그대로 두고 변경분을 오늘의 잔액 조정으로 기록합니다.'
                      : null,
                ),
              ),
              SizedBox(height: 16),
              Text(
                '색상',
                style: TextStyle(fontSize: 12, color: context.desktopMuted),
              ),
              SizedBox(height: 8),
              ColorSwatchPicker(
                value: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('총 순자산에서 제외', style: TextStyle(fontSize: 14)),
                value: _excludeFromTotal,
                onChanged: (v) => setState(() => _excludeFromTotal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '투자 페이지 연동 (1개 자산만)',
                  style: TextStyle(fontSize: 14),
                ),
                value: _isInvestment,
                onChanged: (v) => setState(() => _isInvestment = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            key: const ValueKey('account-archive-button'),
            onPressed: _busy ? null : _archive,
            style: TextButton.styleFrom(foregroundColor: context.desktopMuted),
            child: Text('보관'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: Text('저장')),
      ],
    );
  }
}
