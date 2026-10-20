import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/tag_category_links.dart';
import '../../features/settings/providers.dart';

class TagCategorySelector extends ConsumerWidget {
  const TagCategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.maxHeight = 180,
  });
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  final bool enabled;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              '우선 추천 카테고리',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: enabled && selected.isNotEmpty
                ? () => onChanged({})
                : null,
            child: const Text('모두 해제'),
          ),
        ],
      ),
      const Text(
        '거래 입력 시 이 카테고리를 선택하면 먼저 추천합니다. 여러 개 지정할 수 있어요.',
        style: TextStyle(fontSize: 12),
      ),
      const SizedBox(height: 8),
      ref
          .watch(allCategoriesProvider)
          .when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => TextButton(
              onPressed: () => ref.invalidate(allCategoriesProvider),
              child: const Text('카테고리 다시 불러오기'),
            ),
            data: (categories) {
              final visible = categories
                  .where(
                    (c) =>
                        c.deletedAt == null &&
                        (c.archivedAt == null || selected.contains(c.id)),
                  )
                  .toList();
              if (visible.isEmpty) return const Text('지정할 카테고리가 없습니다.');
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final category in visible)
                        FilterChip(
                          key: ValueKey('tag-category-${category.id}'),
                          selected: selected.contains(category.id),
                          label: Text(
                            '${category.type == 'income' ? '수입' : '지출'} · ${category.name}${category.archivedAt == null ? '' : ' (보관)'}',
                          ),
                          onSelected: enabled
                              ? (value) {
                                  final next = {...selected};
                                  if (value) {
                                    next.add(category.id);
                                  } else {
                                    next.remove(category.id);
                                  }
                                  onChanged(next);
                                }
                              : null,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
    ],
  );
}

class TagCategorySummary extends ConsumerWidget {
  const TagCategorySummary({super.key, required this.categoryIdsJson});
  final String categoryIdsJson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = readTagCategoryIds(categoryIdsJson).toSet();
    final categories = ref.watch(allCategoriesProvider).asData?.value;
    final names = categories
        ?.where((c) => ids.contains(c.id) && c.deletedAt == null)
        .map((c) => '${c.type == 'income' ? '수입' : '지출'} · ${c.name}')
        .join(', ');
    final label = ids.isEmpty
        ? '카테고리 미지정'
        : categories == null
        ? '카테고리 불러오는 중'
        : (names?.isEmpty ?? true)
        ? '카테고리 미지정'
        : names!;
    return Tooltip(
      message: label,
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
        ),
      ),
    );
  }
}
