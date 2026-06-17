import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/categories/validation.dart';
import '../../shared/settings_providers.dart';
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
            return Column(
              children: [for (final item in items) _CategoryCard(item: item)],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.item});

  final Category item;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: _parseColor(item.color)),
        title: Text(item.name),
        subtitle: Text(item.type == 'income' ? '수입' : '지출'),
        trailing: item.archivedAt == null ? null : const Text('보관됨'),
        onTap: () => _CategorySheet.show(context, item: item),
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

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    final error = await ref.read(categoriesDaoProvider).deleteCategory(item.id);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
      return;
    }
    refreshCategories(ref);
    Navigator.pop(context);
    _showSnack('카테고리를 삭제했습니다.');
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
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('삭제'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.appExpense,
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
