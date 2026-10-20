import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/money.dart';
import '../../data/daos/recurring_dao.dart';
import '../../data/providers.dart';
import '../../features/settings/providers.dart';

class RecurringOrderButton extends ConsumerWidget {
  const RecurringOrderButton({super.key, required this.items});
  final List<RecurringListItem> items;
  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    key: const ValueKey('recurring-order-button'),
    onPressed: items.length < 2
        ? null
        : () => showDialog<void>(
            context: context,
            builder: (_) => _RecurringOrderDialog(
              items: items,
              onSave: (ids) async {
                await ref.read(recurringDaoProvider).updateRecurringOrder(ids);
                if (context.mounted) refreshRecurring(ref);
              },
            ),
          ),
    icon: const Icon(Icons.swap_vert, size: 18),
    label: const Text('순서 편집'),
  );
}

class _RecurringOrderDialog extends StatefulWidget {
  const _RecurringOrderDialog({required this.items, required this.onSave});
  final List<RecurringListItem> items;
  final Future<void> Function(List<int>) onSave;
  @override
  State<_RecurringOrderDialog> createState() => _RecurringOrderDialogState();
}

class _RecurringOrderDialogState extends State<_RecurringOrderDialog> {
  late final _draft = List.of(widget.items);
  bool _busy = false;
  String? _error;
  void _move(int from, int to) {
    if (_busy || to < 0 || to >= _draft.length || from == to) return;
    setState(() {
      final row = _draft.removeAt(from);
      _draft.insert(to, row);
      _error = null;
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onSave(_draft.map((item) => item.recurring.id).toList());
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('반복 거래 순서 편집'),
      content: SizedBox(
        width: 560,
        height: (MediaQuery.sizeOf(context).height - 240).clamp(160.0, 440.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('손잡이를 드래그하거나 위·아래 버튼으로 이동하세요.'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _draft.length,
                onReorder: (oldIndex, newIndex) => _move(
                  oldIndex,
                  newIndex > oldIndex ? newIndex - 1 : newIndex,
                ),
                itemBuilder: (context, index) {
                  final item = _draft[index], row = item.recurring;
                  return ListTile(
                    key: ValueKey('recurring-order-row-${row.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: ReorderableDragStartListener(
                      index: index,
                      enabled: !_busy,
                      child: const Tooltip(
                        message: '드래그하여 순서 변경',
                        child: Icon(Icons.drag_indicator),
                      ),
                    ),
                    title: Text(
                      row.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${row.active ? '활성' : '비활성'} · ${formatKRW(row.amount)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('recurring-order-up-${row.id}'),
                          tooltip: '위로 이동',
                          onPressed: _busy || index == 0
                              ? null
                              : () => _move(index, index - 1),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                        IconButton(
                          key: ValueKey('recurring-order-down-${row.id}'),
                          tooltip: '아래로 이동',
                          onPressed: _busy || index == _draft.length - 1
                              ? null
                              : () => _move(index, index + 1),
                          icon: const Icon(Icons.arrow_downward, size: 18),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const ValueKey('recurring-order-save'),
          onPressed: _busy ? null : _save,
          child: const Text('순서 저장'),
        ),
      ],
    ),
  );
}
