import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/date.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database.dart';
import '../../features/calendar/calendar_dday.dart';
import '../../features/calendar/calendar_schedule.dart';

class CalendarDdayList extends StatefulWidget {
  const CalendarDdayList({
    super.key,
    required this.events,
    required this.onOpen,
    required this.onAdd,
  });
  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onOpen;
  final VoidCallback onAdd;
  @override
  State<CalendarDdayList> createState() => _CalendarDdayListState();
}

class _CalendarDdayListState extends State<CalendarDdayList> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final events = calendarDdayEvents(widget.events);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'D-day 모아보기',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: widget.onAdd,
              icon: const Icon(Icons.add),
              label: const Text('D-day 추가'),
            ),
          ],
        ),
        const Text('전체 일정 · 시작 날짜 기준으로 남은 날과 지난 날을 표시합니다.'),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('등록한 D-day가 없습니다. 일정 추가·수정에서 D-day를 켜보세요.'),
          ),
        for (final event in events)
          Card(
            child: ListTile(
              onTap: () => widget.onOpen(event),
              leading: Container(
                width: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.appAccent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  calendarDdayLabel(calendarEventStart(event)),
                  style: TextStyle(
                    color: context.appAccent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              title: Text(event.title),
              subtitle: Text(toDateKey(calendarEventStart(event))),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),
      ],
    );
  }
}
