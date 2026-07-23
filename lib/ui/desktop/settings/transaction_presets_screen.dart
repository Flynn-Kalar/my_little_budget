import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../data/daos/transaction_presets_dao.dart';
import '../../../data/providers.dart';
import '../../../features/settings/providers.dart';
import 'widgets/transaction_preset_dialog.dart';

class TransactionPresetsScreen extends ConsumerWidget {
  const TransactionPresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionPresetItemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('내역 프리셋'),
        actions: [
          FilledButton.icon(
            onPressed: () => TransactionPresetDialog.show(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('새 프리셋'),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('프리셋을 불러오지 못했습니다: $error')),
          data: (rows) => rows.isEmpty
              ? const Center(
                  child: Text('저장된 프리셋이 없습니다.\n자주 쓰는 내역을 미리 저장해보세요.'),
                )
              : ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _PresetTile(item: rows[index]),
                ),
        ),
      ),
    );
  }
}

class _PresetTile extends ConsumerWidget {
  const _PresetTile({required this.item});

  final TransactionPresetListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = item.preset.type == 'transfer'
        ? '${item.fromAccountName ?? '출금 자산 없음'} → '
              '${item.toAccountName ?? '입금 자산 없음'}'
        : '${item.accountName ?? '자산 없음'} · '
              '${item.categoryName ?? '카테고리 없음'}';
    return Card(
      child: ListTile(
        leading: Icon(
          item.preset.type == 'income'
              ? Icons.south_west
              : item.preset.type == 'transfer'
              ? Icons.swap_horiz
              : Icons.north_east,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (!item.isUsable)
              const Chip(
                avatar: Icon(Icons.warning_amber, size: 16),
                label: Text('사용 불가'),
              ),
          ],
        ),
        subtitle: Text('$detail · ${formatKRW(item.preset.amount)}'),
        onTap: () => TransactionPresetDialog.show(context, item: item),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await TransactionPresetDialog.show(context, item: item);
            } else if (value == 'delete') {
              await ref
                  .read(transactionPresetsDaoProvider)
                  .deletePreset(item.preset.id);
              refreshTransactionPresets(ref);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('수정')),
            PopupMenuItem(value: 'delete', child: Text('삭제')),
          ],
        ),
      ),
    );
  }
}
