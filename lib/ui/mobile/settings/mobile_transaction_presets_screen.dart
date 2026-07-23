import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../data/daos/transaction_presets_dao.dart';
import '../../../data/providers.dart';
import '../../../features/settings/providers.dart';
import '../mobile_widgets.dart';
import 'sheets/mobile_transaction_preset_sheet.dart';

class MobileTransactionPresetsScreen extends ConsumerWidget {
  const MobileTransactionPresetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionPresetItemsProvider);
    return MobilePageScaffold(
      title: '내역 프리셋',
      onAdd: () => MobileTransactionPresetSheet.show(context),
      addTooltip: '새 프리셋',
      children: [
        items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('프리셋을 불러오지 못했습니다: $error'),
          data: (rows) => rows.isEmpty
              ? const MobileCard(
                  child: Text('저장된 프리셋이 없습니다.\n자주 쓰는 내역을 미리 저장해보세요.'),
                )
              : Column(
                  children: [for (final item in rows) _PresetCard(item: item)],
                ),
        ),
      ],
    );
  }
}

class _PresetCard extends ConsumerWidget {
  const _PresetCard({required this.item});

  final TransactionPresetListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = item.preset.type == 'transfer'
        ? '${item.fromAccountName ?? '출금 자산 없음'} → '
              '${item.toAccountName ?? '입금 자산 없음'}'
        : '${item.accountName ?? '자산 없음'} · '
              '${item.categoryName ?? '카테고리 없음'}';
    return MobileCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: () => MobileTransactionPresetSheet.show(context, item: item),
        title: Text(
          item.displayName,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$detail · ${formatKRW(item.preset.amount)}'
          '${item.isUsable ? '' : '\n사용 불가 · 자산이나 카테고리를 수정해주세요.'}',
        ),
        isThreeLine: !item.isUsable,
        leading: Icon(
          item.isUsable ? Icons.bookmark_outline : Icons.warning_amber,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') {
              await MobileTransactionPresetSheet.show(context, item: item);
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
