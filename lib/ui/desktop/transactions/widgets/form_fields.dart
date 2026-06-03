import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/database.dart';
import '../../color_hex.dart';

class AccountDropdown extends StatelessWidget {
  const AccountDropdown({
    super.key,
    required this.hint,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });
  final String hint;
  final List<Account> accounts;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      hint: Text(hint),
      value: accounts.any((a) => a.id == value) ? value : null,
      items: accounts
          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });
  final List<Category> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      hint: const Text('카테고리'),
      value: categories.any((c) => c.id == value) ? value : null,
      items: categories
          .map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorFromHex(c.color),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(c.name),
                  ],
                ),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// 태그 이름 입력. 칩으로 표시·삭제, Enter 또는 제안 클릭으로 추가. SPEC §4.1.
class TagInput extends StatefulWidget {
  const TagInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.suggestions = const [],
  });
  final List<String> value;
  final ValueChanged<List<String>> onChanged;
  final List<String> suggestions;

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.length > 20 || widget.value.contains(name)) {
      _ctrl.clear();
      setState(() {});
      return;
    }
    widget.onChanged([...widget.value, name]);
    _ctrl.clear();
    setState(() {});
  }

  void _remove(String name) {
    widget.onChanged(widget.value.where((t) => t != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    final matches = widget.suggestions
        .where((s) => !widget.value.contains(s))
        .where((s) => query.isEmpty || s.contains(query))
        .take(8)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...widget.value.map((t) => InputChip(
                  label: Text('#$t'),
                  onDeleted: () => _remove(t),
                )),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: '태그 추가',
                  isDense: true,
                  prefixText: '#',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _add,
              ),
            ),
          ],
        ),
        if (matches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              children: matches
                  .map((s) => ActionChip(
                        label: Text('#$s',
                            style: const TextStyle(
                                fontSize: 12, color: AppTokens.muted)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _add(s),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
