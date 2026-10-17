import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/daos/transactions_dao.dart';
import '../../features/transactions/providers.dart';

/// Explicit suggestions never overwrite a draft until the user chooses one.
class RecentTransactionSuggestions extends ConsumerWidget {
  const RecentTransactionSuggestions({
    super.key,
    required this.controller,
    required this.type,
    required this.onSelected,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String type;
  final ValueChanged<TransactionRow> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref.watch(recentInputEntriesProvider).asData?.value ??
        const <TransactionRow>[];
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const SizedBox.shrink();
        final seen = <String>{};
        final matches = entries
            .where((e) {
              final memo = e.memo?.trim() ?? '';
              final key =
                  '$memo|${e.accountId}|${e.categoryId}|${e.fromAccountId}|${e.toAccountId}|${e.tags.map((t) => t.name).join(',')}';
              return e.type == type &&
                  memo.toLowerCase().contains(query) &&
                  seen.add(key);
            })
            .take(3)
            .toList();
        if (matches.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '최근 입력에서 계좌·분류·태그 불러오기',
                style: TextStyle(fontSize: 12),
              ),
              for (final row in matches)
                TextButton.icon(
                  onPressed: enabled ? () => onSelected(row) : null,
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(
                    '${row.memo} · ${row.accountName ?? '${row.fromAccountName} → ${row.toAccountName}'}'
                    '${row.categoryName == null ? '' : ' · ${row.categoryName}'}'
                    '${row.tags.isEmpty ? '' : ' · ${row.tags.map((t) => '#${t.name}').join(' ')}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
