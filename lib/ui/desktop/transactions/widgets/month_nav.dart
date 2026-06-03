import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers.dart';
import 'month_picker_popup.dart';

class MonthNav extends ConsumerStatefulWidget {
  const MonthNav({super.key});

  @override
  ConsumerState<MonthNav> createState() => _MonthNavState();
}

class _MonthNavState extends ConsumerState<MonthNav> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final d = parseMonthKey(month);
    final label = '${d.year}년 ${d.month}월';

    void shift(int delta) {
      ref.read(selectedMonthProvider.notifier).state = shiftMonth(month, delta);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => shift(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        MenuAnchor(
          controller: _menu,
          alignmentOffset: const Offset(0, 8),
          style: const MenuStyle(
            elevation: WidgetStatePropertyAll(8),
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          menuChildren: [
            MonthPickerPopup(
              currentMonth: month,
              onPick: (next) {
                ref.read(selectedMonthProvider.notifier).state = next;
                _menu.close();
              },
            ),
          ],
          builder: (context, controller, _) => OutlinedButton(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
        IconButton(
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () =>
              ref.read(selectedMonthProvider.notifier).state = currentMonthKey(),
          style: TextButton.styleFrom(foregroundColor: AppTokens.muted),
          child: const Text('오늘'),
        ),
      ],
    );
  }
}
