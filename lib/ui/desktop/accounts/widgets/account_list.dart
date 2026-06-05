import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/daos/accounts_dao.dart';
import '../../../../data/providers.dart';
import '../../color_hex.dart';
import '../account_refresh.dart';
import '../providers.dart';
import 'account_form_dialog.dart';

const _kindLabels = {'cash': '현금', 'bank': '은행', 'card': '카드', 'other': '기타'};

/// SPEC §4.2 — 자산 목록. 호버 편집·순서 편집·추가 통합.
class AccountList extends ConsumerStatefulWidget {
  const AccountList({super.key});

  @override
  ConsumerState<AccountList> createState() => _State();
}

class _State extends ConsumerState<AccountList> {
  bool _reorderMode = false;
  List<AccountBalance> _draft = const [];
  bool _saving = false;
  int? _hoveredId;

  void _startReorder(List<AccountBalance> items) {
    setState(() {
      _reorderMode = true;
      _draft = List.of(items);
    });
  }

  void _cancelReorder() {
    setState(() => _reorderMode = false);
  }

  Future<void> _saveReorder(List<AccountBalance> original) async {
    final sameOrder =
        _draft.length == original.length &&
        List.generate(
          _draft.length,
          (i) => _draft[i].accountId == original[i].accountId,
        ).every((x) => x);
    if (sameOrder) {
      setState(() => _reorderMode = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(accountsDaoProvider)
          .updateAccountOrder(_draft.map((a) => a.accountId).toList());
      refreshAccountMetadata(ref);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _reorderMode = false;
        });
      }
    }
  }

  void _swap(int i, int j) {
    if (i < 0 || j < 0 || i >= _draft.length || j >= _draft.length) return;
    setState(() {
      final next = List.of(_draft);
      final tmp = next[i];
      next[i] = next[j];
      next[j] = tmp;
      _draft = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(accountBalancesProvider);
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('불러오기 오류: $e'),
      ),
      data: (items) {
        final visible = _reorderMode ? _draft : items;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 액션
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_reorderMode) ...[
                    TextButton.icon(
                      onPressed: _saving ? null : _cancelReorder,
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('취소'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTokens.muted,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : () => _saveReorder(items),
                      icon: const Icon(Icons.check, size: 14),
                      label: Text(_saving ? '저장 중…' : '순서 저장'),
                    ),
                  ] else if (items.length > 1)
                    OutlinedButton.icon(
                      onPressed: () => _startReorder(items),
                      icon: const Icon(Icons.swap_vert, size: 14),
                      label: const Text('순서 편집'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTokens.muted,
                      ),
                    ),
                ],
              ),
            ),

            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  '등록된 계좌가 없습니다.',
                  style: TextStyle(color: AppTokens.muted),
                ),
              )
            else
              for (var i = 0; i < visible.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _reorderMode
                      ? _ReorderRow(
                          account: visible[i],
                          isFirst: i == 0,
                          isLast: i == visible.length - 1,
                          onUp: () => _swap(i, i - 1),
                          onDown: () => _swap(i, i + 1),
                        )
                      : MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredId = visible[i].accountId),
                          onExit: (_) => setState(() => _hoveredId = null),
                          child: _DisplayRow(
                            account: visible[i],
                            showEditIcon: _hoveredId == visible[i].accountId,
                            onTap: () =>
                                context.go('/accounts/${visible[i].accountId}'),
                            onEdit: () => AccountFormDialog.show(
                              context,
                              account: visible[i],
                            ),
                          ),
                        ),
                ),

            // 추가 버튼
            if (!_reorderMode)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => AccountFormDialog.show(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('계좌 추가'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.muted,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DisplayRow extends StatelessWidget {
  const _DisplayRow({
    required this.account,
    required this.showEditIcon,
    required this.onTap,
    required this.onEdit,
  });
  final AccountBalance account;
  final bool showEditIcon;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppTokens.sidebarBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _ColorDot(color: account.color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(account.name, style: const TextStyle(fontSize: 14)),
              ),
              _Meta(account: account),
              const SizedBox(width: 8),
              _BalanceText(account: account),
              SizedBox(
                width: 32,
                child: showEditIcon
                    ? IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        color: AppTokens.muted,
                        tooltip: '편집',
                        onPressed: onEdit,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({
    required this.account,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
  });
  final AccountBalance account;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Column(
            children: [
              IconButton(
                onPressed: isFirst ? null : onUp,
                icon: const Icon(Icons.arrow_upward, size: 14),
                tooltip: '위로',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 22),
              ),
              IconButton(
                onPressed: isLast ? null : onDown,
                icon: const Icon(Icons.arrow_downward, size: 14),
                tooltip: '아래로',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 22),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _ColorDot(color: account.color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(account.name, style: const TextStyle(fontSize: 14)),
          ),
          _Meta(account: account),
          const SizedBox(width: 8),
          _BalanceText(account: account),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final String color;
  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: colorFromHex(color),
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.account});
  final AccountBalance account;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _kindLabels[account.kind] ?? account.kind,
          style: const TextStyle(fontSize: 11, color: AppTokens.muted),
        ),
        if (account.isInvestment) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTokens.transfer.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '투자',
              style: TextStyle(fontSize: 10, color: AppTokens.transfer),
            ),
          ),
        ],
        if (account.excludeFromTotal) ...[
          const SizedBox(width: 8),
          const Text(
            '제외',
            style: TextStyle(fontSize: 11, color: AppTokens.muted),
          ),
        ],
      ],
    );
  }
}

class _BalanceText extends StatelessWidget {
  const _BalanceText({required this.account});
  final AccountBalance account;
  @override
  Widget build(BuildContext context) {
    final color = account.excludeFromTotal
        ? AppTokens.muted
        : account.balance < 0
        ? AppTokens.expense
        : null;
    return Text(
      formatKRW(account.balance),
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    );
  }
}
