import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../desktop/color_hex.dart';
import '../providers.dart';
import 'category_form.dart';

class CategoryManager extends ConsumerStatefulWidget {
  const CategoryManager({
    super.key,
    required this.type,
    required this.title,
    required this.items,
  });

  final String type; // income | expense | archived
  final String title;
  final List<Category> items;

  @override
  ConsumerState<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends ConsumerState<CategoryManager> {
  bool _showAdd = false;
  bool _reorderMode = false;
  bool _saving = false;
  int? _editingId;
  int? _busyId;
  List<Category> _draft = const [];

  bool get _isArchived => widget.type == 'archived';

  void _startReorder() {
    setState(() {
      _showAdd = false;
      _editingId = null;
      _draft = List.of(widget.items);
      _reorderMode = true;
    });
  }

  void _swap(int i, int j) {
    if (i < 0 || j < 0 || i >= _draft.length || j >= _draft.length) return;
    setState(() {
      final next = List.of(_draft);
      final tmp = next[i];
      next[i] = next[j];
      next[j] = tmp;
      _draft = next;
    });
  }

  Future<void> _saveReorder() async {
    final same = _draft.length == widget.items.length &&
        List.generate(_draft.length, (i) => _draft[i].id == widget.items[i].id)
            .every((x) => x);
    if (same) {
      setState(() => _reorderMode = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(categoriesDaoProvider)
          .updateCategoryOrder(widget.type, _draft.map((c) => c.id).toList());
      refreshCategories(ref);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _reorderMode = false;
        });
      }
    }
  }

  Future<void> _restore(int id) async {
    setState(() => _busyId = id);
    try {
      await ref.read(categoriesDaoProvider).restoreCategory(id);
      refreshCategories(ref);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영구 삭제'),
        content: Text("'${category.name}' 카테고리를 완전히 삭제합니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = category.id);
    final err = await ref.read(categoriesDaoProvider).deleteCategory(category.id);
    if (mounted) {
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      } else {
        refreshCategories(ref);
      }
      setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _reorderMode ? _draft : widget.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(widget.title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.muted)),
            const Spacer(),
            if (!_isArchived && widget.items.length > 1)
              _reorderMode
                  ? Row(
                      children: [
                        TextButton.icon(
                          onPressed:
                              _saving ? null : () => setState(() => _reorderMode = false),
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveReorder,
                          icon: const Icon(Icons.check, size: 14),
                          label: Text(_saving ? '저장 중...' : '순서 저장'),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: _startReorder,
                      icon: const Icon(Icons.swap_vert, size: 14),
                      label: const Text('순서 편집'),
                    ),
          ],
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _isArchived ? '보관된 카테고리가 없습니다.' : '카테고리가 없습니다.',
              style: const TextStyle(fontSize: 13, color: AppTokens.muted),
            ),
          ),
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _editingId == visible[i].id && !_reorderMode
                ? CategoryForm(
                    category: visible[i],
                    onDone: () => setState(() => _editingId = null),
                  )
                : _reorderMode
                    ? _ReorderCategoryRow(
                        category: visible[i],
                        isFirst: i == 0,
                        isLast: i == visible.length - 1,
                        onUp: () => _swap(i, i - 1),
                        onDown: () => _swap(i, i + 1),
                      )
                    : _CategoryRow(
                        category: visible[i],
                        archived: _isArchived,
                        busy: _busyId == visible[i].id,
                        onEdit: () => setState(() {
                          _showAdd = false;
                          _editingId = visible[i].id;
                        }),
                        onRestore: () => _restore(visible[i].id),
                        onDelete: () => _delete(visible[i]),
                      ),
          ),
        if (!_isArchived && !_reorderMode)
          _showAdd
              ? CategoryForm(
                  type: widget.type,
                  onDone: () => setState(() => _showAdd = false),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _editingId = null;
                      _showAdd = true;
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('카테고리 추가'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppTokens.muted),
                  ),
                ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.archived,
    required this.busy,
    required this.onEdit,
    required this.onRestore,
    required this.onDelete,
  });

  final Category category;
  final bool archived;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _ColorDot(color: category.color),
          const SizedBox(width: 12),
          Expanded(child: Text(category.name, style: const TextStyle(fontSize: 14))),
          if (archived)
            Text(category.type == 'expense' ? '지출' : '수입',
                style: const TextStyle(fontSize: 11, color: AppTokens.muted)),
          const SizedBox(width: 8),
          if (archived) ...[
            TextButton.icon(
              onPressed: busy ? null : onRestore,
              icon: const Icon(Icons.unarchive_outlined, size: 14),
              label: const Text('복원'),
            ),
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 14),
              label: const Text('삭제'),
              style: TextButton.styleFrom(foregroundColor: AppTokens.warning),
            ),
          ] else
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 16),
              tooltip: '편집',
              color: AppTokens.muted,
            ),
        ],
      ),
    );
  }
}

class _ReorderCategoryRow extends StatelessWidget {
  const _ReorderCategoryRow({
    required this.category,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
  });

  final Category category;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        border: Border.all(color: AppTokens.sidebarBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isFirst ? null : onUp,
            icon: const Icon(Icons.arrow_upward, size: 14),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: isLast ? null : onDown,
            icon: const Icon(Icons.arrow_downward, size: 14),
            visualDensity: VisualDensity.compact,
          ),
          _ColorDot(color: category.color),
          const SizedBox(width: 12),
          Expanded(child: Text(category.name, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});
  final String color;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorFromHex(color),
        ),
      );
}
