import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/daos/transactions_dao.dart';
import '../../data/providers.dart';
import '../../features/transactions/providers.dart';
import '../../features/transactions/selection.dart';

/// Keeps selection and editing in the existing list, without a dialog.
class TransactionSelectionArea extends StatefulWidget {
  const TransactionSelectionArea({
    super.key,
    required this.rows,
    required this.queryKey,
    required this.builder,
    this.expandChild = false,
  });

  final List<TransactionRow> rows;
  final Object queryKey;
  final Widget Function(TransactionSelection selection) builder;
  final bool expandChild;

  @override
  State<TransactionSelectionArea> createState() =>
      _TransactionSelectionAreaState();
}

class _TransactionSelectionAreaState extends State<TransactionSelectionArea> {
  final _selection = TransactionSelection();

  @override
  void didUpdateWidget(covariant TransactionSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selection.reconcile(
      widget.rows.map((row) => row.id),
      queryChanged: oldWidget.queryKey != widget.queryKey,
    );
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _selection,
    builder: (context, _) {
      final child = widget.builder(_selection);
      Widget column({double? toolbarMaxHeight}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: widget.expandChild ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (_selection.active)
            if (toolbarMaxHeight != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: toolbarMaxHeight),
                child: SingleChildScrollView(
                  child: _BulkTransactionEditor(
                    rows: widget.rows,
                    selection: _selection,
                  ),
                ),
              )
            else
              _BulkTransactionEditor(rows: widget.rows, selection: _selection),
          if (widget.expandChild) Expanded(child: child) else child,
        ],
      );
      return PopScope(
        canPop: !_selection.active,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _selection.exit();
        },
        child: widget.expandChild
            ? LayoutBuilder(
                builder: (context, constraints) =>
                    column(toolbarMaxHeight: constraints.maxHeight * .65),
              )
            : column(),
      );
    },
  );
}

class _BulkTransactionEditor extends ConsumerStatefulWidget {
  const _BulkTransactionEditor({required this.rows, required this.selection});
  final List<TransactionRow> rows;
  final TransactionSelection selection;

  @override
  ConsumerState<_BulkTransactionEditor> createState() =>
      _BulkTransactionEditorState();
}

class _BulkTransactionEditorState
    extends ConsumerState<_BulkTransactionEditor> {
  final _tags = TextEditingController();
  int? _categoryId;
  String _tagMode = 'keep';
  bool _expanded = false;
  String? _error;

  @override
  void dispose() {
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save(int? categoryId) async {
    final selection = widget.selection;
    final ids = selection.ids.toSet();
    final tags = _tagMode == 'keep'
        ? null
        : _tags.text
              .split(',')
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList();
    if (tags != null && tags.any((t) => t.length > 20)) {
      setState(() => _error = '태그는 각각 20자 이하로 입력해주세요.');
      return;
    }
    setState(() => _error = null);
    selection.setBusy(true);
    try {
      await ref
          .read(transactionsDaoProvider)
          .bulkEditTransactions(
            ids: ids,
            categoryId: categoryId,
            tagNames: tags,
          );
      if (!mounted) return;
      refreshTransactions(ref);
      setState(() {
        _expanded = false;
        _categoryId = null;
        _tagMode = 'keep';
        _tags.clear();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${ids.length}건을 수정했습니다.')));
    } catch (_) {
      if (mounted) setState(() => _error = '수정하지 못했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) selection.setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;
    final selected = widget.rows
        .where((r) => selection.contains(r.id))
        .toList();
    final types = selected.map((r) => r.type).toSet();
    final canCategory =
        types.length == 1 &&
        (types.single == 'income' || types.single == 'expense');
    final categories =
        (ref.watch(activeCategoriesProvider).asData?.value ?? const [])
            .where((c) => canCategory && c.type == types.single)
            .toList();
    final effectiveCategory = categories.any((c) => c.id == _categoryId)
        ? _categoryId
        : null;
    final income = selected
        .where((r) => r.type == 'income')
        .fold(0, (int n, r) => n + r.amount);
    final expense = selected
        .where((r) => r.type == 'expense')
        .fold(0, (int n, r) => n + r.amount);
    final busy = selection.busy;

    return Card(
      key: const ValueKey('transaction-selection-toolbar'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${selected.length}건 선택',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy || selected.isEmpty
                      ? null
                      : () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.edit_outlined,
                    size: 18,
                  ),
                  label: const Text('일괄 수정'),
                ),
                IconButton(
                  tooltip: '선택 모드 종료',
                  onPressed: busy ? null : selection.exit,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (selected.isNotEmpty)
              Text(
                '수입 ${formatKRW(income)} · 지출 ${formatKRW(expense)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => selection.selectAll(
                              widget.rows.map((r) => r.id),
                            ),
                      child: Text('조회 결과 전체 선택 (${widget.rows.length}건)'),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy || selected.isEmpty ? null : selection.clear,
                  child: const Text('선택 해제'),
                ),
              ],
            ),
            if (_expanded)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .28,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<int>(
                        key: ValueKey(
                          'bulk-category-$effectiveCategory-${types.join()}',
                        ),
                        initialValue: effectiveCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '카테고리'),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('변경하지 않음'),
                          ),
                          for (final c in categories)
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                        ],
                        onChanged: busy || !canCategory
                            ? null
                            : (v) => setState(() => _categoryId = v),
                      ),
                      if (!canCategory)
                        const Text(
                          '카테고리는 같은 유형의 수입 또는 지출만 선택하면 변경할 수 있습니다.',
                          style: TextStyle(fontSize: 12),
                        ),
                      DropdownButtonFormField<String>(
                        key: ValueKey('bulk-tag-mode-$_tagMode'),
                        initialValue: _tagMode,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '태그'),
                        items: const [
                          DropdownMenuItem(
                            value: 'keep',
                            child: Text('변경하지 않음'),
                          ),
                          DropdownMenuItem(
                            value: 'replace',
                            child: Text('새 태그로 교체'),
                          ),
                        ],
                        onChanged: busy
                            ? null
                            : (v) => setState(() => _tagMode = v!),
                      ),
                      if (_tagMode != 'keep') ...[
                        const Text(
                          '비워두면 선택한 거래의 태그를 모두 제거합니다.',
                          style: TextStyle(fontSize: 12),
                        ),
                        TextField(
                          key: const ValueKey('bulk-tags-input'),
                          controller: _tags,
                          enabled: !busy,
                          decoration: const InputDecoration(
                            labelText: '새 태그',
                            hintText: '쉼표로 구분: 식비, 점심',
                          ),
                        ),
                      ],
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_expanded)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed:
                      busy ||
                          selected.isEmpty ||
                          (effectiveCategory == null && _tagMode == 'keep')
                      ? null
                      : () => _save(effectiveCategory),
                  child: Text('${selected.length}건에 적용'),
                ),
              ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
