import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/providers.dart';
import '../../color_hex.dart';
import '../providers.dart';

const _kindLabels = {
  'cash': '현금',
  'bank': '은행',
  'card': '카드',
  'other': '기타',
};

/// SPEC §4.2 — 보관된 자산 (접이식). 없으면 미표시.
class ArchivedAccounts extends ConsumerStatefulWidget {
  const ArchivedAccounts({super.key});

  @override
  ConsumerState<ArchivedAccounts> createState() => _State();
}

class _State extends ConsumerState<ArchivedAccounts> {
  bool _open = false;
  int? _busyId;

  Future<void> _restore(int id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(accountsDaoProvider).restoreAccount(id);
      refreshAccountsList(ref);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(int id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영구 삭제'),
        content: Text("'$name' 자산을 완전히 삭제합니다. 되돌릴 수 없습니다."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTokens.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = id);
    final err = await ref.read(accountsDaoProvider).deleteAccount(id);
    if (mounted) {
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      } else {
        refreshAccountsList(ref);
      }
      setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(archivedAccountsProvider).asData?.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_open ? Icons.expand_more : Icons.chevron_right,
                      size: 16, color: AppTokens.muted),
                  const SizedBox(width: 4),
                  Text(
                    '보관된 자산 (${items.length})',
                    style: const TextStyle(
                        fontSize: 13, color: AppTokens.muted),
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            for (final a in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    border: Border.all(
                      color: AppTokens.sidebarBorder,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: 0.6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorFromHex(a.color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a.name,
                            style: const TextStyle(
                                fontSize: 14, color: AppTokens.muted)),
                      ),
                      Text(_kindLabels[a.kind] ?? a.kind,
                          style: const TextStyle(
                              fontSize: 11, color: AppTokens.muted)),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: _busyId == a.id ? null : () => _restore(a.id),
                        icon: const Icon(Icons.unarchive_outlined, size: 14),
                        label: const Text('복원'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.muted,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busyId == a.id
                            ? null
                            : () => _delete(a.id, a.name),
                        icon: const Icon(Icons.delete_outline, size: 14),
                        label: const Text('삭제'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTokens.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
