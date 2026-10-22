import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/daos/recurring_dao.dart';
import '../../data/providers.dart';
import '../../features/settings/providers.dart';
import 'inline_order_editor.dart';
import 'bulk_manage_button.dart';

class RecurringOrderEditor extends ConsumerWidget {
  const RecurringOrderEditor({
    super.key,
    required this.items,
    required this.builder,
  });
  final List<RecurringListItem> items;
  final Widget Function(BuildContext, Widget) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      InlineOrderEditor<RecurringListItem>(
        prefix: 'recurring-order',
        enabled: !bulkSelectionIsBusy(ref, BulkEntity.recurring),
        onStart: () =>
            ref
                    .read(bulkSelectionProvider(BulkEntity.recurring).notifier)
                    .state =
                null,
        items: items,
        idOf: (item) => item.recurring.id,
        titleOf: (item) => item.recurring.name,
        onSave: (rows) async {
          await ref
              .read(recurringDaoProvider)
              .updateRecurringOrder(rows.map((r) => r.recurring.id).toList());
          refreshRecurring(ref);
        },
        builder: builder,
      );
}
