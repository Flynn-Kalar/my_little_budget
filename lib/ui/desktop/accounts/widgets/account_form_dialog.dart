import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/colors.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/accounts_dao.dart';
import '../../../../data/providers.dart';
import '../../../../features/accounts/validation.dart';
import '../account_refresh.dart';
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
    text: (widget.account?.balance ?? 0).toString(),
  );
  late String _kind = widget.account?.kind ?? 'bank';
  late String _color =
      widget.account?.color ?? randomColor(); // 신규는 마운트 시 1회 랜덤
  late bool _excludeFromTotal = widget.account?.excludeFromTotal ?? false;
  late bool _isInvestment = widget.account?.isInvestment ?? false;
  bool _busy = false;

  bool get _isEditing => widget.account != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateAccount(
      name: _nameCtrl.text,
      kind: _kind,
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
      await ref
          .read(accountsDaoProvider)
          .saveAccount(
            id: widget.account?.accountId,
            draft: result.value!,
            currentBalance: parseKRW(_balanceCtrl.text),
          );
      refreshAccountMetadata(ref, accountId: widget.account?.accountId);
      if (widget.account != null) {
        refreshAccountTransactionMutation(ref, widget.account!.accountId);
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final acc = widget.account;
    if (acc == null) return;
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
              const SizedBox(height: 12),
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
                onChanged: (v) => setState(() => _kind = v ?? 'bank'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _balanceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: _isEditing ? '현재 잔액' : '초기 잔액',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  helperText: _isEditing
                      ? '변경분은 오늘 날짜의 잔액 조정 거래로 기록됩니다.'
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '색상',
                style: TextStyle(fontSize: 12, color: AppTokens.muted),
              ),
              const SizedBox(height: 8),
              ColorSwatchPicker(
                value: _color,
                onChanged: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('총 순자산에서 제외', style: TextStyle(fontSize: 14)),
                value: _excludeFromTotal,
                onChanged: (v) => setState(() => _excludeFromTotal = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
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
            onPressed: _busy ? null : _archive,
            style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
            child: const Text('보관'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
      ],
    );
  }
}
