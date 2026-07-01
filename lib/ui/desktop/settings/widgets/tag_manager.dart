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
  bool _reorderMode = false;
  bool _saving = false;
  int? _editingId;
  int? _busyId;
  List<Tag> _draft = const [];

  void _startReorder() {
    setState(() {
      _showAdd = false;
      _editingId = null;
      _draft = List.of(widget.tags);
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
    final same =
        _draft.length == widget.tags.length &&
        List.generate(
          _draft.length,
          (i) => _draft[i].id == widget.tags[i].id,
        ).every((x) => x);
    if (same) {
      setState(() => _reorderMode = false);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(tagsDaoProvider)
          .updateTagOrder(_draft.map((tag) => tag.id).toList());
      refreshTags(ref);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _reorderMode = false;
        });
      }
    }
  }

  Future<void> _delete(Tag tag) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('태그 삭제'),
        content: Text('거래에 붙은 태그도 함께 해제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제'),
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
    final visible = _reorderMode ? _draft : widget.tags;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            if (widget.tags.length > 1)
              _reorderMode
                  ? Row(
                      children: [
                        TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _reorderMode = false),
                          icon: Icon(Icons.close, size: 14),
                          label: Text('취소'),
                        ),
                        SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _saveReorder,
                          icon: Icon(Icons.check, size: 14),
                          label: Text(_saving ? '저장 중...' : '순서 저장'),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: _startReorder,
                      icon: Icon(Icons.swap_vert, size: 14),
                      label: Text('순서 편집'),
                    ),
          ],
        ),
        if (widget.tags.length > 1) SizedBox(height: 10),
        if (visible.isEmpty && !_showAdd)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '등록된 태그가 없습니다.',
              style: TextStyle(fontSize: 13, color: context.desktopMuted),
            ),
          ),
        for (var i = 0; i < visible.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _editingId == visible[i].id && !_reorderMode
                ? TagForm(
                    tag: visible[i],
                    onDone: () => setState(() => _editingId = null),
                  )
                : _reorderMode
                ? _ReorderTagRow(
                    tag: visible[i],
                    isFirst: i == 0,
                    isLast: i == visible.length - 1,
                    onUp: () => _swap(i, i - 1),
                    onDown: () => _swap(i, i + 1),
                  )
                : _TagRow(
                    tag: visible[i],
                    busy: _busyId == visible[i].id,
                    onEdit: () => setState(() {
                      _showAdd = false;
                      _editingId = visible[i].id;
                    }),
                    onDelete: () => _delete(visible[i]),
                  ),
          ),
        if (!_reorderMode)
          _showAdd
              ? TagForm(onDone: () => setState(() => _showAdd = false))
              : Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _editingId = null;
                      _showAdd = true;
                    }),
                    icon: Icon(Icons.add, size: 16),
                    label: Text('태그 추가'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.desktopMuted,
                    ),
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
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
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
          SizedBox(width: 12),
          Expanded(child: Text('#${tag.name}', style: TextStyle(fontSize: 14))),
          IconButton(
            onPressed: busy ? null : onEdit,
            icon: Icon(Icons.edit_outlined, size: 16),
            tooltip: '편집',
            color: context.desktopMuted,
          ),
          IconButton(
            onPressed: busy ? null : onDelete,
            icon: Icon(Icons.delete_outline, size: 16),
            tooltip: '삭제',
            color: context.desktopWarning,
          ),
        ],
      ),
    );
  }
}

class _ReorderTagRow extends StatelessWidget {
  const _ReorderTagRow({
    required this.tag,
    required this.isFirst,
    required this.isLast,
    required this.onUp,
    required this.onDown,
  });

  final Tag tag;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
      decoration: BoxDecoration(
        color: context.desktopSurface,
        border: Border.all(color: context.desktopBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: isFirst ? null : onUp,
            icon: Icon(Icons.arrow_upward, size: 14),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: isLast ? null : onDown,
            icon: Icon(Icons.arrow_downward, size: 14),
            visualDensity: VisualDensity.compact,
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorFromHex(tag.color),
            ),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('#${tag.name}', style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
