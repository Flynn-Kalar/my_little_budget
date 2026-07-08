import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/categories/validation.dart';
import 'package:my_little_budget/features/settings/providers.dart';
import '../mobile_widgets.dart';

class MobileCategoriesScreen extends ConsumerWidget {
  const MobileCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allCategoriesProvider);
    return MobilePageScaffold(
      title: '카테고리 관리',
      onAdd: () => _CategorySheet.show(context),
      addTooltip: '카테고리 추가',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.chevron_left),
            label: const Text('설정'),
          ),
        ),
        MobileAsync(
          value: categories,
          builder: (items) {
            if (items.isEmpty) return const EmptyMobileCard('카테고리가 없습니다.');
            final expense = _active(items, 'expense');
            final income = _active(items, 'income');
            final archived = items.where((c) => c.archivedAt != null).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CategorySection(title: '지출 카테고리', items: expense),
                _CategorySection(title: '수입 카테고리', items: income),
                if (archived.isNotEmpty)
                  _CategorySection(
                    title: '보관된 카테고리',
                    items: archived,
                    archived: true,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  List<Category> _active(List<Category> all, String type) {
    return all.where((c) => c.type == type && c.archivedAt == null).toList();
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.items,
    this.archived = false,
  });

  final String title;
  final List<Category> items;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          _CategoryCard(
            item: items[i],
            sectionItems: items,
            index: i,
            archived: archived,
          ),
      ],
    );
  }
}

class _CategoryCard extends ConsumerWidget {
  const _CategoryCard({
    required this.item,
    required this.sectionItems,
    required this.index,
    required this.archived,
  });

  final Category item;
  final List<Category> sectionItems;
  final int index;
  final bool archived;

  Future<void> _move(WidgetRef ref, int direction) async {
    final target = index + direction;
    if (target < 0 || target >= sectionItems.length) return;
    final ordered = [...sectionItems];
    final moving = ordered.removeAt(index);
    ordered.insert(target, moving);
    await ref
        .read(categoriesDaoProvider)
        .updateCategoryOrder(item.type, ordered.map((c) => c.id).toList());
    refreshCategories(ref);
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await ref.read(categoriesDaoProvider).restoreCategory(item.id);
    if (!context.mounted) return;
    refreshCategories(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('카테고리를 복원했습니다.')));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('영구 삭제'),
        content: Text('${item.name} 카테고리를 완전히 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await ref.read(categoriesDaoProvider).deleteCategory(item.id);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    refreshCategories(ref);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('카테고리를 삭제했습니다.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MobileCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: _parseColor(item.color)),
        title: Text(item.name),
        subtitle: Text(item.type == 'income' ? '수입' : '지출'),
        trailing: PopupMenuButton<String>(
          tooltip: '카테고리 메뉴',
          onSelected: (value) {
            if (value == 'edit') {
              _CategorySheet.show(context, item: item);
            } else if (value == 'up') {
              _move(ref, -1);
            } else if (value == 'down') {
              _move(ref, 1);
            } else if (value == 'restore') {
              _restore(context, ref);
            } else if (value == 'delete') {
              _delete(context, ref);
            }
          },
          itemBuilder: (context) => [
            if (!archived)
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('수정'),
                ),
              ),
            if (!archived)
              PopupMenuItem(
                value: 'up',
                enabled: index > 0,
                child: const ListTile(
                  leading: Icon(Icons.arrow_upward),
                  title: Text('위로 이동'),
                ),
              ),
            if (!archived)
              PopupMenuItem(
                value: 'down',
                enabled: index < sectionItems.length - 1,
                child: const ListTile(
                  leading: Icon(Icons.arrow_downward),
                  title: Text('아래로 이동'),
                ),
              ),
            if (archived)
              const PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.unarchive_outlined),
                  title: Text('복원'),
                ),
              ),
            if (archived)
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('삭제'),
                ),
              ),
          ],
        ),
        onTap: archived ? null : () => _CategorySheet.show(context, item: item),
      ),
    );
  }
}

class _CategorySheet extends ConsumerStatefulWidget {
  const _CategorySheet({this.item});

  final Category? item;

  static Future<void> show(BuildContext context, {Category? item}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CategorySheet(item: item),
    );
  }

  @override
  ConsumerState<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends ConsumerState<_CategorySheet> {
  late final _name = TextEditingController(text: widget.item?.name ?? '');
  late String _type = widget.item?.type ?? 'expense';
  bool _busy = false;

  bool get _isEdit => widget.item != null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final result = validateCategory(name: _name.text, type: _type);
    if (result.isFail) {
      _showSnack('카테고리 이름을 입력해주세요.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(categoriesDaoProvider)
          .saveCategory(id: widget.item?.id, draft: result.value!);
      if (!mounted) return;
      refreshCategories(ref);
      Navigator.pop(context);
      _showSnack(_isEdit ? '카테고리를 수정했습니다.' : '카테고리를 추가했습니다.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final item = widget.item;
    if (item == null) return;
    await ref.read(categoriesDaoProvider).archiveCategory(item.id);
    if (!mounted) return;
    refreshCategories(ref);
    Navigator.pop(context);
    _showSnack('카테고리를 보관했습니다.');
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? '카테고리 수정' : '카테고리 추가',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: '이름',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('지출')),
              ButtonSegment(value: 'income', label: Text('수입')),
            ],
            selected: {_type},
            showSelectedIcon: false,
            onSelectionChanged: _isEdit || _busy
                ? null
                : (selected) => setState(() => _type = selected.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_isEdit)
                TextButton.icon(
                  onPressed: _busy ? null : _archive,
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('보관'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.appAccent,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _parseColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return Color(0xFF000000 | (value ?? 0x64748B));
}
