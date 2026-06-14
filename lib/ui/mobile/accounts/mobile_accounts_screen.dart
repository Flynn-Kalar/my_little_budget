import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/daos/accounts_dao.dart';
import '../../../data/providers.dart';
import '../../../features/accounts/validation.dart';
import '../../shared/accounts_providers.dart';
import '../mobile_widgets.dart';

class MobileAccountsScreen extends ConsumerWidget {
  const MobileAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountBalancesProvider);

    return MobilePageScaffold(
      title: '자산',
      onAdd: () => _AccountSheet.show(context),
      addTooltip: '자산 추가',
      children: [
        MobileAsync(
          value: accounts,
          builder: (value) {
            if (value.isEmpty) return const EmptyMobileCard('등록된 자산이 없습니다.');
            final included = value.where((row) => !row.excludeFromTotal);
            final total = included.fold<int>(
              0,
              (sum, row) => sum + row.balance,
            );
            return Column(
              children: [
                MobileCard(
                  child: AmountLine(
                    label: '총 자산',
                    value: formatKRW(total),
                    valueColor: total < 0
                        ? AppTokens.expense
                        : AppTokens.income,
                  ),
                ),
                for (final row in value) _AccountCard(account: row),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});

  final AccountBalance account;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('자산 삭제'),
        content: Text('${account.name} 자산을 삭제할까요?'),
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
    if (confirmed != true) return;

    final error = await ref
        .read(accountsDaoProvider)
        .deleteAccount(account.accountId);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    refreshAccountsList(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('자산을 삭제했습니다.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return MobileCard(
      child: InkWell(
        onTap: () => context.go('/accounts/${account.accountId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    account.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (account.isInvestment)
                  Icon(
                    Icons.trending_up,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                PopupMenuButton<String>(
                  tooltip: '자산 메뉴',
                  onSelected: (value) {
                    if (value == 'detail') {
                      context.go('/accounts/${account.accountId}');
                    }
                    if (value == 'edit') {
                      _AccountSheet.show(context, account: account);
                    }
                    if (value == 'delete') {
                      _delete(context, ref);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'detail',
                      child: ListTile(
                        leading: Icon(Icons.receipt_long_outlined),
                        title: Text('거래내역 보기'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('수정'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('삭제'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            AmountLine(
              label: _kindLabel(account.kind),
              value: formatKRW(account.balance),
              valueColor: account.balance < 0
                  ? AppTokens.expense
                  : AppTokens.income,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSheet extends ConsumerStatefulWidget {
  const _AccountSheet({this.account});

  final AccountBalance? account;

  static Future<void> show(BuildContext context, {AccountBalance? account}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AccountSheet(account: account),
    );
  }

  @override
  ConsumerState<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<_AccountSheet> {
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _balance = TextEditingController(
    text: (widget.account?.balance ?? 0).toString(),
  );
  late String _kind = widget.account?.kind ?? 'bank';
  late bool _exclude = widget.account?.excludeFromTotal ?? false;
  late bool _investment = widget.account?.isInvestment ?? false;
  bool _busy = false;

  bool get _isEdit => widget.account != null;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateAccount(
      name: _name.text,
      kind: _kind,
      initialBalance: parseKRW(_balance.text),
      excludeFromTotal: _exclude,
      isInvestment: _investment,
    );
    if (result.isFail) {
      _showSnack('자산 이름을 입력해주세요.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(accountsDaoProvider)
          .saveAccount(
            id: widget.account?.accountId,
            draft: result.value!,
            currentBalance: parseKRW(_balance.text),
          );
      if (!mounted) return;
      refreshAccountsList(ref);
      Navigator.pop(context);
      _showSnack(_isEdit ? '자산을 수정했습니다.' : '자산을 추가했습니다.');
    } catch (e) {
      if (mounted) _showSnack('자산 저장에 실패했습니다: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final account = widget.account;
    if (account == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('자산 삭제'),
        content: Text('${account.name} 자산을 삭제할까요?'),
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
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final error = await ref
          .read(accountsDaoProvider)
          .deleteAccount(account.accountId);
      if (!mounted) return;
      if (error != null) {
        _showSnack(error);
        return;
      }
      refreshAccountsList(ref);
      Navigator.pop(context);
      _showSnack('자산을 삭제했습니다.');
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? '자산 수정' : '자산 추가',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: '자산 이름',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('현금')),
                DropdownMenuItem(value: 'bank', child: Text('은행')),
                DropdownMenuItem(value: 'card', child: Text('카드')),
                DropdownMenuItem(value: 'other', child: Text('기타')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _kind = value!),
              decoration: const InputDecoration(
                labelText: '종류',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balance,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '현재 잔액',
                suffixText: '원',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _exclude,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _exclude = value),
              title: const Text('총액에서 제외'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _investment,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _investment = value),
              title: const Text('투자 자산'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_isEdit)
                  TextButton.icon(
                    onPressed: _busy ? null : _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('삭제'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTokens.expense,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _kindLabel(String kind) => switch (kind) {
  'cash' => '현금',
  'bank' => '은행',
  'card' => '카드',
  'other' => '기타',
  _ => kind,
};
