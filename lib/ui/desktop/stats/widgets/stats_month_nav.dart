import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../features/stats/providers.dart';

class StatsMonthNav extends ConsumerWidget {
  const StatsMonthNav({super.key, required this.month});

  final String month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = parseMonthKey(month);

    void shift(int delta) {
      ref.read(statsMonthProvider.notifier).state = shiftMonth(month, delta);
      ref.read(statsSelectedCategoryProvider.notifier).state = null;
      ref.read(statsSelectedTagProvider.notifier).state = null;
      ref.read(statsDetailPanelOpenProvider.notifier).state = false;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        OutlinedButton.icon(
          onPressed: () {
            ref.read(statsMonthProvider.notifier).state = currentMonthKey();
            ref.read(statsSelectedCategoryProvider.notifier).state = null;
            ref.read(statsSelectedTagProvider.notifier).state = null;
            ref.read(statsDetailPanelOpenProvider.notifier).state = false;
          },
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text('${d.year}-${d.month.toString().padLeft(2, '0')}'),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}
