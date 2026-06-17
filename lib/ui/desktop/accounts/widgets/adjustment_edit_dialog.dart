import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/transactions_dao.dart';
import '../../../../data/providers.dart';
import '../../../../features/transactions/validation.dart';
import '../account_refresh.dart';

/// SPEC §4.3 — 자산 잔액 조정 거래 편집. 타입 토글 없이 날짜/시각/금액/메모만.
class AdjustmentEditDialog extends ConsumerStatefulWidget {
  const AdjustmentEditDialog({
    super.key,
    required this.row,
    required this.accountId,
  });

  final TransactionRow row;
  final int accountId;

  static Future<void> show(
    BuildContext context, {
    required TransactionRow row,
    required int accountId,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AdjustmentEditDialog(row: row, accountId: accountId),
    );
  }

  @override
  ConsumerState<AdjustmentEditDialog> createState() => _State();
}

class _State extends ConsumerState<AdjustmentEditDialog> {
  late DateTime _date = parseDateKey(widget.row.occurredOn);
  late final String _time = widget.row.occurredTime;
  late final _amountCtrl = TextEditingController(
    text: widget.row.amount.toString(),
  );
  late final _memoCtrl = TextEditingController(text: widget.row.memo ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = parseKRW(_amountCtrl.text);
    final result = validateTransaction(
      type: 'adjustment',
      amount: amount,
      occurredOn: toDateKey(_date),
      occurredTime: _time,
      memo: _memoCtrl.text,
      accountId: widget.accountId,
    );
    if (result.isFail) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.errors.values.first)));
      return;
    }
    setState(() => _busy = true);
    await ref
        .read(transactionsDaoProvider)
        .saveTransaction(id: widget.row.id, draft: result.value!);
    refreshAccountTransactionMutation(ref, widget.accountId);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    await ref.read(transactionsDaoProvider).deleteTransaction(widget.row.id);
    refreshAccountTransactionMutation(ref, widget.accountId);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('잔액 조정'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: Icon(Icons.calendar_today, size: 14),
              label: Text(toDateKey(_date)),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: '±금액 (음수는 잔액 감소)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(
                labelText: '메모',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 4),
            Text(
              '양수는 잔액 증가, 음수는 감소입니다.',
              style: TextStyle(fontSize: 11, color: context.desktopMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: context.desktopExpense),
          child: Text('삭제'),
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
