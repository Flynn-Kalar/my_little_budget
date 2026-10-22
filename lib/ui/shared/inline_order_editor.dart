import 'package:flutter/material.dart';

/// Category-style order editing, using the same page instead of another route.
class InlineOrderEditor<T> extends StatefulWidget {
  const InlineOrderEditor({
    super.key,
    required this.items,
    required this.idOf,
    required this.titleOf,
    required this.onSave,
    required this.builder,
    this.groupOf,
    this.prefix = 'order',
    this.fill = false,
    this.onStart,
    this.enabled = true,
  });
  final List<T> items;
  final int Function(T) idOf;
  final String Function(T) titleOf;
  final String Function(T)? groupOf;
  final Future<void> Function(List<T>) onSave;
  final Widget Function(BuildContext, Widget) builder;
  final String prefix;
  final bool fill;
  final VoidCallback? onStart;
  final bool enabled;

  @override
  State<InlineOrderEditor<T>> createState() => _InlineOrderEditorState<T>();
}

class _InlineOrderEditorState<T> extends State<InlineOrderEditor<T>> {
  List<T>? _draft;
  bool _saving = false;
  String? _error;
  bool _sameGroup(T a, T b) =>
      widget.groupOf?.call(a) == widget.groupOf?.call(b);

  void _move(int i, int j) {
    final draft = _draft!;
    if (_saving ||
        j < 0 ||
        j >= draft.length ||
        !_sameGroup(draft[i], draft[j])) {
      return;
    }
    setState(() {
      final row = draft.removeAt(i);
      draft.insert(j, row);
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(List.of(_draft!));
      if (mounted) setState(() => _draft = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = '순서를 저장하지 못했습니다. 목록이 바뀌었다면 취소 후 다시 시도하세요.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    if (draft == null) {
      return widget.builder(
        context,
        OutlinedButton.icon(
          key: ValueKey('${widget.prefix}-button'),
          onPressed: !widget.enabled || widget.items.length < 2
              ? null
              : () {
                  widget.onStart?.call();
                  setState(() {
                    _draft = List.of(widget.items);
                    _error = null;
                  });
                },
          icon: const Icon(Icons.swap_vert, size: 16),
          label: const Text('순서 편집'),
        ),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < draft.length; i++) {
      final item = draft[i], id = widget.idOf(draft[i]);
      if (widget.groupOf != null &&
          (i == 0 || !_sameGroup(draft[i - 1], item))) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              widget.groupOf!(item),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            key: ValueKey('${widget.prefix}-row-$id'),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                IconButton(
                  key: ValueKey('${widget.prefix}-up-$id'),
                  tooltip: '위로 이동',
                  onPressed:
                      _saving || i == 0 || !_sameGroup(draft[i - 1], item)
                      ? null
                      : () => _move(i, i - 1),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                ),
                IconButton(
                  key: ValueKey('${widget.prefix}-down-$id'),
                  tooltip: '아래로 이동',
                  onPressed:
                      _saving ||
                          i == draft.length - 1 ||
                          !_sameGroup(draft[i + 1], item)
                      ? null
                      : () => _move(i, i + 1),
                  icon: const Icon(Icons.arrow_downward, size: 16),
                ),
                Expanded(child: Text(widget.titleOf(item))),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) setState(() => _draft = null);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _draft = null),
                icon: const Icon(Icons.close, size: 16),
                label: const Text('취소'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: ValueKey('${widget.prefix}-save'),
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check, size: 16),
                label: Text(_saving ? '저장 중...' : '순서 저장'),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          if (widget.fill)
            Expanded(child: ListView(children: rows))
          else
            ...rows,
        ],
      ),
    );
  }
}
