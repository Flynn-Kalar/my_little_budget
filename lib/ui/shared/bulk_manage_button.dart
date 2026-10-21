import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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

final bulkSelectionProvider = StateProvider.autoDispose
    .family<Set<int>?, BulkEntity>((ref, entity) => null);
final _bulkBusyProvider = StateProvider.autoDispose.family<bool, BulkEntity>(
  (ref, entity) => false,
);

bool bulkSelectionIsBusy(WidgetRef ref, BulkEntity entity) =>
    ref.read(_bulkBusyProvider(entity));

extension BulkSelectableWidget on Widget {
  Widget bulkSelectionViewport(BulkEntity entity) =>
      _BulkSelectionViewport(entity: entity, child: this);
  Widget bulkSelectable(BulkEntity entity, int? id, {bool compact = false}) =>
      id == null
      ? this
      : BulkSelectable(entity: entity, id: id, compact: compact, child: this);
}

class _BulkSelectionViewport extends ConsumerWidget {
  const _BulkSelectionViewport({required this.entity, required this.child});
  final BulkEntity entity;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: EdgeInsets.only(
      bottom: ref.watch(bulkSelectionProvider(entity)) == null ? 0 : 160,
    ),
    child: child,
  );
}

class BulkSelectable extends ConsumerWidget {
  const BulkSelectable({
    super.key,
    required this.entity,
    required this.id,
    required this.child,
    this.compact = false,
  });
  final BulkEntity entity;
  final int id;
  final Widget child;
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(bulkSelectionProvider(entity));
    final busy = ref.watch(_bulkBusyProvider(entity));
    void toggle() {
      final next = Set<int>.of(selected ?? {});
      if (!next.add(id)) next.remove(id);
      ref.read(bulkSelectionProvider(entity).notifier).state = next;
    }

    return Semantics(
      selected: selected?.contains(id),
      child: GestureDetector(
        key: ValueKey('bulk-row-${entity.name}-$id'),
        behavior: HitTestBehavior.opaque,
        onLongPress: busy
            ? null
            : selected == null
            ? () =>
                  ref.read(bulkSelectionProvider(entity).notifier).state = {id}
            : toggle,
        onTap: busy || selected == null ? null : toggle,
        child: selected == null
            ? child
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: compact ? 20 : 44,
                    height: compact ? 20 : null,
                    child: Checkbox(
                      key: ValueKey('bulk-item-$id'),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      value: selected.contains(id),
                      onChanged: busy ? null : (_) => toggle(),
                    ),
                  ),
                  Expanded(child: IgnorePointer(child: child)),
                ],
              ),
      ),
    );
  }
}

class BulkSelectionToolbar extends ConsumerStatefulWidget {
  const BulkSelectionToolbar({
    super.key,
    required this.entity,
    required this.items,
    this.onChanged,
  });
  final BulkEntity entity;
  final List<BulkItem> items;
  final VoidCallback? onChanged;
  @override
  ConsumerState<BulkSelectionToolbar> createState() =>
      _BulkSelectionToolbarState();
}

class _BulkSelectionToolbarState extends ConsumerState<BulkSelectionToolbar>
    with AutomaticKeepAliveClientMixin {
  OverlayEntry? _overlay;
  Widget? _panel;
  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _overlay?.remove();
    _overlay?.dispose();
    super.dispose();
  }

  Widget _host(Widget? panel) {
    final active = panel != null;
    _panel = panel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_panel == null) {
        _overlay?.remove();
        _overlay?.dispose();
        _overlay = null;
      } else if (_overlay != null) {
        _overlay!.markNeedsBuild();
      } else {
        _overlay = OverlayEntry(
          builder: (context) => Positioned(
            left: 12,
            right: 12,
            bottom:
                MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                12,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _panel,
                ),
              ),
            ),
          ),
        );
        Overlay.of(context, rootOverlay: true).insert(_overlay!);
      }
    });
    return PopScope(
      canPop: !active,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy) {
          ref.read(bulkSelectionProvider(widget.entity).notifier).state = null;
        }
      },
      child: const SizedBox.shrink(),
    );
  }

  Set<int> get _selected =>
      ref.read(bulkSelectionProvider(widget.entity)) ?? {};
  String? _error;
  bool _busy = false;
  @override
  void didUpdateWidget(covariant BulkSelectionToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_busy) return;
    final ids = widget.items.map((item) => item.id).toSet();
    if (_selected.any((id) => !ids.contains(id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _busy) return;
        final remaining = _selected.intersection(
          widget.items.map((i) => i.id).toSet(),
        );
        ref.read(bulkSelectionProvider(widget.entity).notifier).state =
            remaining.isEmpty ? null : remaining;
      });
    }
  }

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
    ref.read(_bulkBusyProvider(widget.entity).notifier).state = true;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      ref.read(bulkSelectionProvider(widget.entity).notifier).state = null;
      widget.onChanged?.call();
      await _refresh();
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
      if (mounted) {
        ref.read(_bulkBusyProvider(widget.entity).notifier).state = false;
        setState(() => _busy = false);
      }
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
    super.build(context);
    final selected = ref.watch(bulkSelectionProvider(widget.entity));
    if (selected == null) {
      _error = null;
      return _host(null);
    }
    final all =
        widget.items.isNotEmpty &&
        widget.items.every((item) => selected.contains(item.id));
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

    return _host(
      ConstrainedBox(
        key: ValueKey('bulk-selection-toolbar-${entity.name}'),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Checkbox(
                  key: const ValueKey('bulk-select-all'),
                  value: all,
                  onChanged: _busy
                      ? null
                      : (value) {
                          ref
                              .read(bulkSelectionProvider(entity).notifier)
                              .state = value == true
                              ? widget.items.map((item) => item.id).toSet()
                              : <int>{};
                        },
                ),
                Text('${selected.length}개 선택'),
                TextButton(
                  key: const ValueKey('bulk-cancel-selection'),
                  onPressed: _busy
                      ? null
                      : () {
                          ref
                                  .read(bulkSelectionProvider(entity).notifier)
                                  .state =
                              null;
                          setState(() => _error = null);
                        },
                  child: const Text('선택 취소'),
                ),
              ],
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_busy) const LinearProgressIndicator(),
            Wrap(spacing: 8, runSpacing: 4, children: actions),
            const SizedBox(height: 8),
          ],
        ),
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
