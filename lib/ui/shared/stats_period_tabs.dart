import 'package:flutter/material.dart';

class StatsPeriodTabs extends StatelessWidget {
  const StatsPeriodTabs({
    super.key,
    required this.yearly,
    required this.onChanged,
  });
  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
    segments: const [
      ButtonSegment(value: false, label: Text('월간')),
      ButtonSegment(value: true, label: Text('연간')),
    ],
    selected: {yearly},
    showSelectedIcon: false,
    onSelectionChanged: (selection) => onChanged(selection.single),
  );
}
