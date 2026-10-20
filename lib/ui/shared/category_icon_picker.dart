import 'package:flutter/material.dart';
import '../../core/category_icons.dart';
import 'category_icon.dart';

class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.value,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.onChanged,
    this.enabled = true,
  });
  final String? value;
  final String name;
  final String type;
  final String colorHex;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: !enabled
        ? null
        : () async {
            final result = await showDialog<({String? icon})>(
              context: context,
              builder: (_) => _IconDialog(value: value, name: name, type: type),
            );
            if (result != null) onChanged(result.icon);
          },
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CategoryIconBadge(
            name: name,
            type: type,
            iconId: value,
            colorHex: colorHex,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '아이콘 선택 · ${categoryIconById(value)?.label ?? '자동 선택'}',
            ),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
    ),
  );
}

class _IconDialog extends StatefulWidget {
  const _IconDialog({this.value, required this.name, required this.type});
  final String? value;
  final String name;
  final String type;
  @override
  State<_IconDialog> createState() => _IconDialogState();
}

class _IconDialogState extends State<_IconDialog> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final options = categoryIconOptions
        .where(
          (o) => '${o.label} ${o.id}'.toLowerCase().contains(
            _query.trim().toLowerCase(),
          ),
        )
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('카테고리 아이콘'),
      content: SizedBox(
        width: 520,
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).vertical -
                    220)
                .clamp(120.0, 420.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: '아이콘 검색 (예: 교통, 반려동물)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(
                resolveCategoryIcon(name: widget.name, type: widget.type),
              ),
              onPressed: () => Navigator.pop(context, (icon: null as String?)),
              label: const Text('자동 선택 (카테고리 이름 기준)'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: Text('검색 결과가 없습니다.'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 90,
                            mainAxisExtent: 76,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = widget.value == option.id;
                        return Tooltip(
                          message: option.label,
                          child: Material(
                            color: selected
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              key: ValueKey('category-icon-${option.id}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: () =>
                                  Navigator.pop(context, (icon: option.id)),
                              child: Semantics(
                                selected: selected,
                                button: true,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      option.icon,
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.primary,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      option.label.split(' · ').first,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
