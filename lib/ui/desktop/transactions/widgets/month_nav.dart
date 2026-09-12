import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/date.dart';
import '../../../../shell/layout_policy.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
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
    final compact = isCompactDesktop(context);
    final month = ref.watch(selectedMonthProvider);
    final date = parseMonthKey(month);
    final label = '${date.year}\uB144 ${date.month}\uC6D4';

    void shift(int delta) {
      ref.read(selectedMonthProvider.notifier).state = shiftMonth(month, delta);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 32, height: 36)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          onPressed: () => shift(-1),
          icon: const Icon(Icons.chevron_left),
          tooltip: '\uC774\uC804 \uB2EC',
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
              minimumSize: Size(compact ? 100 : 140, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          constraints: compact
              ? const BoxConstraints.tightFor(width: 32, height: 36)
              : null,
          padding: compact ? EdgeInsets.zero : null,
          onPressed: () => shift(1),
          icon: const Icon(Icons.chevron_right),
          tooltip: '\uB2E4\uC74C \uB2EC',
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => ref.read(selectedMonthProvider.notifier).state =
              currentMonthKey(),
          style: TextButton.styleFrom(
            foregroundColor: context.desktopMuted,
            minimumSize: compact ? const Size(40, 36) : null,
            padding: compact ? const EdgeInsets.symmetric(horizontal: 4) : null,
          ),
          child: const Text('\uC624\uB298'),
        ),
      ],
    );
  }
}
