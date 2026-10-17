import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/daos/transactions_dao.dart';
import '../../data/providers.dart';
import '../../features/transactions/providers.dart';

Future<void> showBulkTransactionEditor(
  BuildContext context,
  WidgetRef ref,
) async {
  try {
    final rows = await ref.read(transactionsListProvider.future);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _BulkTransactionEditor(rows: rows),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('거래 목록을 불러오지 못했습니다.')));
    }
  }
}

class _BulkTransactionEditor extends ConsumerStatefulWidget {
  const _BulkTransactionEditor({required this.rows});
  final List<TransactionRow> rows;
  @override
  ConsumerState<_BulkTransactionEditor> createState() =>
      _BulkTransactionEditorState();
}

class _BulkTransactionEditorState
    extends ConsumerState<_BulkTransactionEditor> {
  final _selected = <int>{};
  final _tags = TextEditingController();
  int? _categoryId;
  String _tagMode = 'keep';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(transactionsDaoProvider)
          .bulkEditTransactions(
            ids: _selected,
            categoryId: _categoryId,
            tagNames: tags,
          );
      if (!mounted) return;
      refreshTransactions(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${_selected.length}건을 수정했습니다.')));
    } catch (error) {
      if (mounted) setState(() => _error = '수정하지 못했습니다. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.rows
        .where((r) => _selected.contains(r.id))
        .map((r) => r.type)
        .toSet();
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
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Text('거래 일괄 수정 · ${_selected.length}건 선택'),
        content: SizedBox(
          width: 560,
          height: (MediaQuery.sizeOf(context).height * .62).clamp(380.0, 600.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('현재 조회 결과에서 변경할 거래를 선택하세요.'),
              CheckboxListTile(
                title: Text('전체 선택 (${widget.rows.length}건)'),
                value:
                    widget.rows.isNotEmpty &&
                    _selected.length == widget.rows.length,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                        _selected.clear();
                        if (v == true) {
                          _selected.addAll(widget.rows.map((r) => r.id));
                        }
                        _categoryId = null;
                      }),
              ),
              Expanded(
                child: widget.rows.isEmpty
                    ? const Center(child: Text('표시할 거래가 없습니다.'))
                    : ListView.builder(
                        itemCount: widget.rows.length,
                        itemBuilder: (context, index) {
                          final row = widget.rows[index];
                          return CheckboxListTile(
                            dense: true,
                            value: _selected.contains(row.id),
                            title: Text(
                              '${row.memo ?? row.categoryName ?? row.type} · ${formatKRW(row.amount)}',
                            ),
                            subtitle: Text(
                              '${row.occurredOn} · ${row.accountName ?? '${row.fromAccountName} → ${row.toAccountName}'}',
                            ),
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(row.id);
                                    } else {
                                      _selected.remove(row.id);
                                    }
                                    _categoryId = null;
                                  }),
                          );
                        },
                      ),
              ),
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
                onChanged: _busy || !canCategory
                    ? null
                    : (v) => setState(() => _categoryId = v),
              ),
              if (!canCategory)
                const Text(
                  '카테고리는 같은 유형의 수입 또는 지출만 선택하면 변경할 수 있습니다.',
                  style: TextStyle(fontSize: 12),
                ),
              DropdownButtonFormField<String>(
                initialValue: _tagMode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '태그'),
                items: const [
                  DropdownMenuItem(value: 'keep', child: Text('변경하지 않음')),
                  DropdownMenuItem(value: 'replace', child: Text('새 태그로 교체')),
                ],
                onChanged: _busy ? null : (v) => setState(() => _tagMode = v!),
              ),
              if (_tagMode != 'keep')
                const Text(
                  '비워두면 선택한 거래의 태그를 모두 제거합니다.',
                  style: TextStyle(fontSize: 12),
                ),
              if (_tagMode != 'keep')
                TextField(
                  controller: _tags,
                  enabled: !_busy,
                  decoration: const InputDecoration(
                    labelText: '새 태그',
                    hintText: '쉼표로 구분: 식비, 점심',
                  ),
                ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed:
                _busy ||
                    _selected.isEmpty ||
                    (effectiveCategory == null && _tagMode == 'keep')
                ? null
                : _save,
            child: Text('${_selected.length}건에 적용'),
          ),
        ],
      ),
    );
  }
}
