import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date.dart';
import '../../core/money.dart';
import '../../data/daos/budget_dao.dart';
import '../../data/providers.dart';
import '../../features/budget/entry_preview.dart';
import '../../features/budget/providers.dart';
import '../../features/transactions/validation.dart';
import '../../features/settings/statement_period.dart';
import 'amount_input_formatter.dart';

/// Shared readout only; each platform owns its input layout.
class TransactionBudgetPreview extends ConsumerWidget {
  const TransactionBudgetPreview({
    super.key,
    required this.amountController,
    required this.type,
    required this.date,
    required this.accountId,
    required this.categoryId,
    this.editingId,
    this.enabled = true,
  });

  final TextEditingController amountController;
  final String type;
  final DateTime? date;
  final int? accountId;
  final int? categoryId;
  final int? editingId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type != 'expense') return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: amountController,
      builder: (context, value, _) {
        final amount = tryParseKRW(value.text);
        if (date == null) return const _Hint('날짜를 확인하면 예산을 계산할 수 있어요.');
        if (amount == null || amount <= 0) {
          return const _Hint('금액을 입력하면 사용 후 예산을 확인할 수 있어요.');
        }
        if (accountId == null || categoryId == null) {
          return const _Hint('자산과 카테고리를 선택하면 예산을 확인할 수 있어요.');
        }
        return Consumer(
          builder: (context, ref, _) {
            final policy = ref.watch(statementPeriodProvider);
            return policy.when(
              loading: () => const _Hint('예산을 불러오는 중…'),
              error: (_, _) => const _Hint('집계 기간을 불러오지 못했습니다.'),
              data: (policy) {
                final month = policy.anchorForDate(date!);
                final key = (month: month, editingId: editingId);
                final rows = ref.watch(entryBudgetRowsProvider(key));
                final draft = TransactionDraft(
                  type: type,
                  amount: amount,
                  occurredOn: toDateKey(date!),
                  occurredTime: '00:00',
                  accountId: accountId,
                  categoryId: categoryId,
                );
                return rows.when(
                  skipLoadingOnRefresh: false,
                  loading: () => const _Hint('예산을 불러오는 중…'),
                  error: (_, _) => Row(
                    children: [
                      const Expanded(child: Text('예산을 불러오지 못했습니다.')),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(entryBudgetRowsProvider(key)),
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                  data: (rows) {
                    final previews = previewEntryBudgets(
                      rows: rows,
                      draft: draft,
                      policy: policy,
                      today: ref.watch(statementTodayProvider),
                    );
                    if (previews.isEmpty) {
                      return const _Hint('이 자산·카테고리에 연결된 예산이 없습니다.');
                    }
                    final period = policy.range(month);
                    return Container(
                      key: const ValueKey('transaction-budget-preview'),
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '입력 후 예산 · ${policy.displayMonth(month)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${period.start} ~ ${period.end}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          for (final preview in previews)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${preview.row.groupName} · ${preview.remaining < 0 ? '${formatKRW(-preview.remaining)} 초과' : '${formatKRW(preview.remaining)} 남음'}',
                                    key: ValueKey(
                                      'entry-budget-${preview.row.groupId}',
                                    ),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: preview.remaining < 0
                                          ? Theme.of(context).colorScheme.error
                                          : null,
                                    ),
                                  ),
                                  Text(
                                    '${editingId == null ? '입력 전' : '기존 거래 제외'} ${formatKRW(preview.before)} → 사용 후 ${formatKRW(preview.remaining)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  if (preview.allowance != null)
                                    Text(
                                      '하루 ${formatKRW(preview.allowance!.daily)} 사용 가능 · ${preview.allowance!.days}일 기준',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if (preview.remaining < 0 &&
                                      preview.row.accountId == null)
                                    TextButton(
                                      key: ValueKey(
                                        'move-budget-${preview.row.groupId}',
                                      ),
                                      onPressed: !enabled
                                          ? null
                                          : () => showDialog<void>(
                                              context: context,
                                              builder: (_) => _MoveBudgetDialog(
                                                target: preview,
                                                rows: rows,
                                                draft: draft,
                                                month: month,
                                                policy: policy,
                                                editingId: editingId,
                                              ),
                                            ),
                                      child: const Text('다른 예산에서 가져오기'),
                                    ),
                                  if (preview.remaining < 0 &&
                                      preview.row.accountId != null)
                                    const Text(
                                      '자산 연동 예산은 해당 자산의 잔액과 입출금으로 계산됩니다.',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                          if (previews.length > 1)
                            const Text(
                              '같은 지출을 포함할 수 있어 그룹별 예산은 합산하지 않습니다.',
                              style: TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );
}

class _MoveBudgetDialog extends ConsumerStatefulWidget {
  const _MoveBudgetDialog({
    required this.target,
    required this.rows,
    required this.draft,
    required this.month,
    required this.policy,
    this.editingId,
  });
  final EntryBudgetPreview target;
  final List<BudgetVsActual> rows;
  final TransactionDraft draft;
  final String month;
  final StatementPeriod policy;
  final int? editingId;
  @override
  ConsumerState<_MoveBudgetDialog> createState() => _MoveBudgetDialogState();
}

class _MoveBudgetDialogState extends ConsumerState<_MoveBudgetDialog> {
  int? _source;
  late final _amount = TextEditingController(
    text: formatAmountInput('${-widget.target.remaining}'),
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _move() async {
    final amount = tryParseKRW(_amount.text);
    if (_source == null || amount == null || amount <= 0) {
      setState(() => _error = '가져올 예산과 양수 금액을 선택해주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(budgetDaoProvider)
          .moveBudgetAllocation(
            month: widget.month,
            period: widget.policy.range(widget.month),
            fromGroupId: _source!,
            toGroupId: widget.target.row.groupId,
            amount: amount,
            draft: widget.draft,
            editingTransactionId: widget.editingId,
          );
      if (!mounted) return;
      refreshBudget(ref);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '이동하지 못했습니다. 예산의 남은 금액을 확인하고 다시 시도해주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.rows
        .where(
          (r) =>
              r.accountId == null &&
              r.groupId != widget.target.row.groupId &&
              r.budgetAmount -
                      r.spentAmount -
                      (entryAffectsBudget(r, widget.draft)
                          ? widget.draft.amount
                          : 0) >
                  0,
        )
        .toList();
    return AlertDialog(
      title: Text('${widget.target.row.groupName} 예산 채우기'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sources.isEmpty)
                const Text('가져올 수 있는 다른 카테고리 예산이 없습니다.')
              else ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('entry-budget-source'),
                  initialValue: _source,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '가져올 예산'),
                  items: [
                    for (final row in sources)
                      DropdownMenuItem(
                        value: row.groupId,
                        child: Text(
                          '${row.groupName} · ${formatKRW(row.budgetAmount - row.spentAmount - (entryAffectsBudget(row, widget.draft) ? widget.draft.amount : 0))}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _source = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('entry-budget-move-amount'),
                  controller: _amount,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [amountInputFormatter],
                  decoration: const InputDecoration(
                    labelText: '이동 금액',
                    suffixText: '원',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('이동을 누르면 예산에 바로 저장됩니다. 입력 중인 거래는 별도로 저장해주세요.'),
              ],
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        FilledButton(
          onPressed: _busy || sources.isEmpty ? null : _move,
          child: const Text('이동'),
        ),
      ],
    );
  }
}
