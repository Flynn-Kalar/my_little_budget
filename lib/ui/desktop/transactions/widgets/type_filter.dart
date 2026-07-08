import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_little_budget/features/transactions/providers.dart';

class TypeFilter extends ConsumerWidget {
  const TypeFilter({super.key});

  static const _options = <(String, String)>[
    ('income', '수입'),
    ('expense', '지출'),
    ('transfer', '이체'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(typeFilterProvider);
    return Wrap(
      spacing: 8,
      children: _options.map((option) {
        final selected = current == option.$1;
        return ChoiceChip(
          label: Text(option.$2, softWrap: false),
          selected: selected,
          onSelected: (value) => ref.read(typeFilterProvider.notifier).state =
              value ? option.$1 : null,
        );
      }).toList(),
    );
  }
}
