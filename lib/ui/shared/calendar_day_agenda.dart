import 'package:flutter/material.dart';
import '../../core/date.dart';

class CalendarDayAgendaItem {
  const CalendarDayAgendaItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
}

/// Returns an entry index, -1 for adding, or null for dismissing.
Future<int?> showCalendarDayAgenda(
  BuildContext context,
  DateTime date,
  List<CalendarDayAgendaItem> items,
) => showDialog<int>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('${toDateKey(date)} 일정'),
    content: SizedBox(
      width: 480,
      height: (MediaQuery.sizeOf(context).height * .5).clamp(160.0, 460.0),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            leading: Icon(item.icon, color: item.color),
            title: Text(item.title),
            subtitle: Text(item.subtitle),
            onTap: () => Navigator.pop(context, index),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('닫기'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.pop(context, -1),
        icon: const Icon(Icons.add),
        label: const Text('일정 추가'),
      ),
    ],
  ),
);
