import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date.dart';
import '../../core/theme/app_theme.dart';

double mobileBottomPadding(BuildContext context, {double spacing = 0}) {
  final mediaQuery = MediaQuery.of(context);
  final obstruction =
      mediaQuery.viewInsets.bottom > mediaQuery.viewPadding.bottom
      ? mediaQuery.viewInsets.bottom
      : mediaQuery.viewPadding.bottom;
  return obstruction + spacing;
}

class MobilePage extends StatelessWidget {
  const MobilePage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            ...actions,
          ],
        ),
        const SizedBox(height: 16),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class MobilePageScaffold extends StatelessWidget {
  const MobilePageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.onAdd,
    this.addTooltip = '추가',
    this.actions = const [],
  });

  final String title;
  final List<Widget> children;
  final VoidCallback? onAdd;
  final String addTooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: MobilePage(title: title, actions: actions, children: children),
      floatingActionButton: onAdd == null
          ? null
          : SafeArea(
              child: FloatingActionButton(
                onPressed: onAdd,
                tooltip: addTooltip,
                child: const Icon(Icons.add),
              ),
            ),
    );
  }
}

class MobileCard extends StatelessWidget {
  const MobileCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.cardTheme.color,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

class MobileAsync<T> extends StatelessWidget {
  const MobileAsync({super.key, required this.value, required this.builder});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () =>
          const MobileCard(child: LinearProgressIndicator(minHeight: 3)),
      error: (error, _) => MobileCard(
        child: Text(
          error.toString(),
          style: TextStyle(color: context.appExpense),
        ),
      ),
    );
  }
}

class MobileMonthNav extends StatelessWidget {
  const MobileMonthNav({
    super.key,
    required this.month,
    required this.onChanged,
  });

  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final date = parseMonthKey(month);
    return MobileCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(shiftMonth(month, -1)),
            icon: const Icon(Icons.chevron_left),
            tooltip: '이전 달',
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final selected = await showMobileMonthPicker(
                  context,
                  initialMonth: month,
                );
                if (selected != null) onChanged(selected);
              },
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                '${date.year}년 ${date.month}월',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(shiftMonth(month, 1)),
            icon: const Icon(Icons.chevron_right),
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }
}

Future<String?> showMobileMonthPicker(
  BuildContext context, {
  required String initialMonth,
}) {
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (_) => _MobileMonthPicker(initialMonth: initialMonth),
  );
}

class _MobileMonthPicker extends StatefulWidget {
  const _MobileMonthPicker({required this.initialMonth});

  final String initialMonth;

  @override
  State<_MobileMonthPicker> createState() => _MobileMonthPickerState();
}

class _MobileMonthPickerState extends State<_MobileMonthPicker> {
  late int _year = parseMonthKey(widget.initialMonth).year;
  late int _selectedMonth = parseMonthKey(widget.initialMonth).month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        mobileBottomPadding(context, spacing: 20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _year -= 1),
                icon: const Icon(Icons.chevron_left),
                tooltip: '이전 연도',
              ),
              Expanded(
                child: Text(
                  '$_year년',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _year += 1),
                icon: const Icon(Icons.chevron_right),
                tooltip: '다음 연도',
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.7,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final selected = month == _selectedMonth;
              return FilledButton.tonal(
                onPressed: () {
                  setState(() => _selectedMonth = month);
                  Navigator.pop(context, toMonthKey(DateTime(_year, month, 1)));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surface,
                  foregroundColor: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('$month월', maxLines: 1),
              );
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}

class AmountLine extends StatelessWidget {
  const AmountLine({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyMobileCard extends StatelessWidget {
  const EmptyMobileCard(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MobileCard(
      child: Text(
        message,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
