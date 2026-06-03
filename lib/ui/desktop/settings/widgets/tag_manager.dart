import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/database.dart';
import '../../../../data/providers.dart';
import '../../../desktop/color_hex.dart';
import '../providers.dart';
import 'tag_form.dart';

class TagManager extends ConsumerStatefulWidget {
  const TagManager({super.key, required this.tags});

  final List<Tag> tags;

  @override
  ConsumerState<TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends ConsumerState<TagManager> {
  bool _showAdd = false;
  int? _editingId;
  int? _busyId;

  Future<void> _delete(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('태그 삭제'),
        content: const Text('거래에 붙은 태그도 함께 해제됩니다.'),
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
    setState(() => _busyId = tag.id);
    try {
      await ref.read(tagsDaoProvider).deleteTag(tag.id);
      refreshTags(ref);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.tags.isEmpty && !_showAdd)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('등록된 태그가 없습니다.',
                style: TextStyle(fontSize: 13, color: AppTokens.muted)),
          ),
        for (final tag in widget.tags)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _editingId == tag.id
                ? TagForm(
                    tag: tag,
                    onDone: () => setState(() => _editingId = null),
                  )
                : _TagRow(
                    tag: tag,
                    busy: _busyId == tag.id,
                    onEdit: () => setState(() {
                      _showAdd = false;
                      _editingId = tag.id;
                    }),
                    onDelete: () => _delete(tag),
                  ),
          ),
        _showAdd
            ? TagForm(onDone: () => setState(() => _showAdd = false))
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    _editingId = null;
                    _showAdd = true;
                  }),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('태그 추가'),
                  style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
                ),
              ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final Tag tag;
  final bool busy;
  final VoidCallback onEdit;
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorFromHex(tag.color),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text('#${tag.name}', style: const TextStyle(fontSize: 14))),
          IconButton(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: '편집',
            color: AppTokens.muted,
          ),
          IconButton(
            onPressed: busy ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            tooltip: '삭제',
            color: AppTokens.warning,
          ),
        ],
      ),
    );
  }
}
