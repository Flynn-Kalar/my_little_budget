import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/tag_category_links.dart';
import '../../features/tags/suggestion_order.dart';

class TransactionTagPicker extends StatefulWidget {
  const TransactionTagPicker({
    super.key,
    required this.tags,
    required this.categoryId,
    required this.type,
    required this.value,
    required this.onChanged,
    required this.keyPrefix,
    this.enabled = true,
    this.allowNewTag = false,
  });
  final List<Tag> tags;
  final int? categoryId;
  final String type;
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final String keyPrefix;
  final bool enabled;
  final bool allowNewTag;
  @override
  State<TransactionTagPicker> createState() => _TransactionTagPickerState();
}

class _TransactionTagPickerState extends State<TransactionTagPicker> {
  final _order = TagSuggestionOrder();
  final _newTag = TextEditingController();
  bool _otherExpanded = false;
  @override
  void didUpdateWidget(covariant TransactionTagPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoryId != oldWidget.categoryId ||
        widget.type != oldWidget.type) {
      _otherExpanded = false;
    }
  }

  @override
  void dispose() {
    _newTag.dispose();
    super.dispose();
  }

  void _toggle(String name, bool selected) {
    _order.lock();
    widget.onChanged(
      selected
          ? {...widget.value, name}.toList()
          : widget.value.where((n) => n != name).toList(),
    );
  }

  Widget _chips(List<Tag> tags) => Wrap(
    spacing: 6,
    runSpacing: 2,
    children: [
      for (final tag in tags)
        FilterChip(
          key: ValueKey(
            '${widget.keyPrefix}-tag-choice-${widget.keyPrefix == 'mobile' ? tag.id : tag.name}',
          ),
          label: Text('#${tag.name}'),
          selected: widget.value.contains(tag.name),
          showCheckmark: false,
          avatar: widget.value.contains(tag.name)
              ? const Icon(Icons.check, size: 16)
              : tag.isPinned
              ? const Icon(Icons.star_rounded, size: 16)
              : const SizedBox(width: 16, height: 16),
          onSelected: !widget.enabled ? null : (v) => _toggle(tag.name, v),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final byName = {for (final tag in widget.tags) tag.name: tag};
    final ordered = _order
        .resolve(byName.keys.toList(), (widget.type, widget.categoryId))
        .map((n) => byName[n]!)
        .toList();
    final matched = ordered
        .where(
          (t) =>
              widget.categoryId != null &&
              readTagCategoryIds(t.categoryIdsJson).contains(widget.categoryId),
        )
        .toList();
    final matchedNames = matched.map((t) => t.name).toSet();
    final others = ordered
        .where((t) => !matchedNames.contains(t.name))
        .toList();
    final hiddenSelected = widget.value
        .where(
          (n) =>
              !matchedNames.contains(n) &&
              (!_otherExpanded || !byName.containsKey(n)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (matched.isNotEmpty) ...[
          const Text('카테고리 태그', style: TextStyle(fontWeight: FontWeight.w600)),
          _chips(matched),
        ],
        if (hiddenSelected.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final name in hiddenSelected)
                InputChip(
                  label: Text('#$name'),
                  onDeleted: !widget.enabled
                      ? null
                      : () => _toggle(name, false),
                ),
            ],
          ),
        if (others.isNotEmpty || widget.allowNewTag)
          TextButton.icon(
            key: ValueKey('${widget.keyPrefix}-other-tags-toggle'),
            onPressed: !widget.enabled
                ? null
                : () => setState(() => _otherExpanded = !_otherExpanded),
            icon: Icon(_otherExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(
              '${widget.categoryId == null ? '태그' : '다른 태그'} (${others.length})',
            ),
          ),
        if (_otherExpanded) ...[
          _chips(others),
          if (widget.allowNewTag)
            TextField(
              controller: _newTag,
              enabled: widget.enabled,
              decoration: const InputDecoration(
                labelText: '태그 추가',
                prefixText: '#',
              ),
              onSubmitted: (raw) {
                final names = raw
                    .split(RegExp(r'[,#\s]+'))
                    .map((n) => n.trim())
                    .where((n) => n.isNotEmpty && n.length <= 20);
                widget.onChanged({...widget.value, ...names}.toList());
                _newTag.clear();
              },
            ),
        ],
      ],
    );
  }
}
