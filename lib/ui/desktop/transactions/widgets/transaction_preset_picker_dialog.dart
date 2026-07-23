import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money.dart';
import '../../../../data/daos/transaction_presets_dao.dart';
import '../../../../features/settings/providers.dart';

class TransactionPresetPickerDialog extends ConsumerWidget {
  const TransactionPresetPickerDialog({super.key});

  static Future<TransactionPresetListItem?> show(BuildContext context) =>
      showDialog<TransactionPresetListItem>(
        context: context,
        builder: (_) => const TransactionPresetPickerDialog(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(transactionPresetItemsProvider);
    return AlertDialog(
      title: const Text('프리셋 불러오기'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: items.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('불러오지 못했습니다: $error')),
          data: (rows) => rows.isEmpty
              ? const Center(child: Text('저장된 프리셋이 없습니다.'))
              : ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final item = rows[index];
                    return ListTile(
                      enabled: item.isUsable,
                      leading: Icon(
                        item.isUsable
                            ? Icons.bookmark_outline
                            : Icons.warning_amber,
                      ),
                      title: Text(item.displayName),
                      subtitle: Text(
                        '${formatKRW(item.preset.amount)}'
                        '${item.isUsable ? '' : ' · 사용 불가'}',
                      ),
                      onTap: item.isUsable
                          ? () => Navigator.pop(context, item)
                          : null,
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
