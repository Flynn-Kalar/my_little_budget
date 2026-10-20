import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/bulk_management.dart';
import '../../data/providers.dart';
import '../../features/accounts/providers.dart' as accounts;
import '../../features/budget/providers.dart' as budget;
import '../../features/investments/providers.dart' as investments;
import '../../features/notes/providers.dart' as notes;
import '../../features/calendar/providers.dart' as calendar;
import '../../features/settings/providers.dart' as settings;
import '../../features/transactions/providers.dart' as transactions;
import 'tag_category_selector.dart';

export '../../data/bulk_management.dart' show BulkEntity;

class BulkItem {
  const BulkItem(this.id, this.title, [this.subtitle]);
  final int id;
  final String title;
  final String? subtitle;
}

class BulkManageButton extends StatelessWidget {
  const BulkManageButton({
    super.key,
    required this.entity,
    required this.items,
    this.onChanged,
  });
  final BulkEntity entity;
  final List<BulkItem> items;
  final VoidCallback? onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: ValueKey('bulk-select-${entity.name}'),
    onPressed: items.isEmpty
        ? null
        : () async {
            await showDialog<bool>(
              context: context,
              builder: (_) => _BulkDialog(
                entity: entity,
                items: items,
                onChanged: onChanged,
              ),
            );
          },
    icon: const Icon(Icons.checklist_rounded, size: 18),
    label: const Text('다중 선택'),
  );
}

class _BulkDialog extends ConsumerStatefulWidget {
  const _BulkDialog({
    required this.entity,
    required this.items,
    this.onChanged,
  });
  final BulkEntity entity;
  final List<BulkItem> items;
  final VoidCallback? onChanged;
  @override
  ConsumerState<_BulkDialog> createState() => _BulkDialogState();
}

class _BulkDialogState extends ConsumerState<_BulkDialog> {
  final _selected = <int>{};
  String _query = '';
  String? _error;
  bool _busy = false;
  List<BulkItem> get _visible => widget.items
      .where(
        (item) => '${item.title} ${item.subtitle ?? ''}'.toLowerCase().contains(
          _query.trim().toLowerCase(),
        ),
      )
      .toList();
  Future<bool> _confirm(String action, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${_selected.length}개 $action'),
          content: SingleChildScrollView(
            child: Text(
              '$detail\n\n${widget.items.where((item) => _selected.contains(item.id)).take(10).map((item) => '• ${item.title}').join('\n')}${_selected.length > 10 ? '\n외 ${_selected.length - 10}개' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('bulk-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _apply(BulkOperation operation, String label) async {
    final detail = switch (widget.entity) {
      BulkEntity.categories =>
        '사용 중인 카테고리가 포함되어 있으면 전체 삭제를 취소합니다. 삭제한 카테고리의 태그 지정도 해제됩니다.',
      BulkEntity.tags => '태그를 삭제하고 거래와 프리셋에서 해당 태그를 해제합니다. 거래 자체는 유지됩니다.',
      BulkEntity.accounts => '선택한 자산을 보관합니다. 기존 거래 기록은 유지됩니다.',
      BulkEntity.recurring =>
        operation == BulkOperation.delete
            ? '반복 규칙을 삭제합니다. 이미 생성된 거래는 유지됩니다.'
            : '선택한 반복 거래 규칙의 활성 상태를 변경합니다.',
      BulkEntity.investments => '선택한 투자 내역을 삭제합니다. 보유 수량·손익·자산 잔액이 다시 계산됩니다.',
      BulkEntity.budgets => '선택한 예산 그룹과 카테고리 연결을 삭제합니다. 거래 내역은 유지됩니다.',
      BulkEntity.notes =>
        operation == BulkOperation.delete
            ? '선택한 메모와 체크리스트·알림을 삭제합니다.'
            : '선택한 메모의 상단 고정 상태를 변경합니다.',
      BulkEntity.calendar => '선택한 원본 일정과 해당 반복 회차·알림을 함께 삭제합니다.',
      BulkEntity.presets => '선택한 프리셋을 삭제합니다. 기존 거래 내역은 유지됩니다.',
    };
    if (!await _confirm(label, detail) || !mounted) return;
    await _run(
      () => BulkManagement(
        ref.read(appDatabaseProvider),
      ).apply(widget.entity, Set.of(_selected), operation),
    );
  }

  Future<void> _categories() async {
    final result = await showDialog<({Set<int> ids, BulkTagCategoryMode mode})>(
      context: context,
      builder: (_) => const _TagCategoriesDialog(),
    );
    if (result == null || !mounted) return;
    final mode = switch (result.mode) {
      BulkTagCategoryMode.add => '기존 지정에 선택한 카테고리를 추가합니다.',
      BulkTagCategoryMode.replace =>
        result.ids.isEmpty
            ? '기존 카테고리 지정을 모두 해제합니다.'
            : '기존 지정을 선택한 카테고리로 교체합니다.',
      BulkTagCategoryMode.remove => '선택한 카테고리만 기존 지정에서 해제합니다.',
    };
    if (!await _confirm('카테고리 지정', mode) || !mounted) return;
    await _run(
      () => BulkManagement(
        ref.read(appDatabaseProvider),
      ).assignTagCategories(Set.of(_selected), result.ids, result.mode),
    );
  }

  Future<void> _run(Future<void> Function() operation) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      widget.onChanged?.call();
      await _refresh();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error
              .toString()
              .replaceFirst('Bad state: ', '')
              .replaceFirst('Invalid argument(s): ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    switch (widget.entity) {
      case BulkEntity.categories:
        settings.refreshCategories(ref);
        settings.refreshTransactionPresets(ref);
      case BulkEntity.tags:
        settings.refreshTags(ref);
        settings.refreshTransactionPresets(ref);
        settings.refreshRecurring(ref);
      case BulkEntity.accounts:
        accounts.refreshAccountsList(ref);
        ref.invalidate(accounts.accountByIdProvider);
        ref.invalidate(accounts.accountTransactionsProvider);
        ref.invalidate(transactions.activeAccountsProvider);
        ref.invalidate(budget.budgetActiveAccountsProvider);
        ref.invalidate(budget.budgetRowsProvider);
        ref.invalidate(settings.settingsAccountsProvider);
        ref.invalidate(investments.investmentAccountProvider);
      case BulkEntity.recurring:
        settings.refreshRecurring(ref);
      case BulkEntity.presets:
        settings.refreshTransactionPresets(ref);
      case BulkEntity.budgets:
        budget.refreshBudget(ref);
      case BulkEntity.investments:
        investments.refreshInvestments(ref);
        ref.invalidate(accounts.accountTransactionsProvider);
        ref.invalidate(accounts.accountByIdProvider);
        transactions.refreshTransactions(ref);
      case BulkEntity.notes:
        ref.invalidate(notes.notesProvider);
        await notes.rebuildNoteNotifications(ref);
      case BulkEntity.calendar:
        calendar.refreshCalendarEvents(ref);
        await notes.rebuildNoteNotifications(ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final all =
        visible.isNotEmpty &&
        visible.every((item) => _selected.contains(item.id));
    final entity = widget.entity;
    final actions = <Widget>[
      if (entity == BulkEntity.tags) _action('카테고리 지정', _categories),
      if (entity == BulkEntity.recurring) ...[
        _action('활성화', () => _apply(BulkOperation.enable, '활성화')),
        _action('비활성화', () => _apply(BulkOperation.disable, '비활성화')),
      ],
      if (entity == BulkEntity.notes) ...[
        _action('고정', () => _apply(BulkOperation.pin, '고정')),
        _action('고정 해제', () => _apply(BulkOperation.unpin, '고정 해제')),
      ],
      if (entity == BulkEntity.accounts)
        _action('보관', () => _apply(BulkOperation.archive, '보관'))
      else
        _action('삭제', () => _apply(BulkOperation.delete, '삭제')),
    ];
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entity.label} 다중 선택'),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height:
              (MediaQuery.sizeOf(context).height -
                      MediaQuery.viewInsetsOf(context).vertical -
                      220)
                  .clamp(180.0, 520.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                enabled: !_busy,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '목록에서 검색',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              Row(
                children: [
                  Checkbox(
                    key: const ValueKey('bulk-select-all'),
                    value: all,
                    onChanged: _busy || visible.isEmpty
                        ? null
                        : (value) => setState(() {
                            if (value == true) {
                              _selected.addAll(visible.map((item) => item.id));
                            } else {
                              _selected.removeAll(
                                visible.map((item) => item.id),
                              );
                            }
                          }),
                  ),
                  const Expanded(child: Text('검색 결과 전체 선택')),
                  const SizedBox(width: 8),
                  Text('${_selected.length}개 선택'),
                ],
              ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    return CheckboxListTile(
                      key: ValueKey('bulk-item-${item.id}'),
                      value: _selected.contains(item.id),
                      title: Text(item.title),
                      subtitle: item.subtitle == null
                          ? null
                          : Text(item.subtitle!),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                _selected.add(item.id);
                              } else {
                                _selected.remove(item.id);
                              }
                            }),
                    );
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final action in actions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: action,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _action(String label, VoidCallback run) => FilledButton.tonal(
    onPressed: _busy || _selected.isEmpty ? null : run,
    child: Text(label),
  );
}

class _TagCategoriesDialog extends StatefulWidget {
  const _TagCategoriesDialog();
  @override
  State<_TagCategoriesDialog> createState() => _TagCategoriesDialogState();
}

class _TagCategoriesDialogState extends State<_TagCategoriesDialog> {
  Set<int> _ids = {};
  BulkTagCategoryMode _mode = BulkTagCategoryMode.add;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('태그 카테고리 일괄 지정'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<BulkTagCategoryMode>(
              segments: const [
                ButtonSegment(
                  value: BulkTagCategoryMode.add,
                  label: Text('추가'),
                ),
                ButtonSegment(
                  value: BulkTagCategoryMode.replace,
                  label: Text('교체'),
                ),
                ButtonSegment(
                  value: BulkTagCategoryMode.remove,
                  label: Text('해제'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (value) =>
                  setState(() => _mode = value.first),
            ),
            const SizedBox(height: 8),
            Text(switch (_mode) {
              BulkTagCategoryMode.add => '기존 카테고리는 유지하고 선택한 카테고리를 추가합니다.',
              BulkTagCategoryMode.replace =>
                '기존 지정을 교체합니다. 선택하지 않고 적용하면 모두 해제됩니다.',
              BulkTagCategoryMode.remove => '선택한 카테고리만 기존 지정에서 해제합니다.',
            }),
            TagCategorySelector(
              selected: _ids,
              includeArchived: _mode == BulkTagCategoryMode.remove,
              onChanged: (value) => setState(() => _ids = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: _ids.isEmpty && _mode != BulkTagCategoryMode.replace
            ? null
            : () => Navigator.pop(context, (ids: _ids, mode: _mode)),
        child: const Text('적용'),
      ),
    ],
  );
}
