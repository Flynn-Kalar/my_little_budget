import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/notes_calendar.dart';
import 'package:my_little_budget/features/notes/providers.dart';

class NotesCalendarScreen extends ConsumerStatefulWidget {
  const NotesCalendarScreen({super.key});

  @override
  ConsumerState<NotesCalendarScreen> createState() =>
      _NotesCalendarScreenState();
}

class _NotesCalendarScreenState extends ConsumerState<NotesCalendarScreen> {
  String _month = currentMonthKey();

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '메모 캘린더',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('알림과 반복 메모 일정을 월별로 확인합니다.'),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('desktop-notes-calendar-back-button'),
              onPressed: () => context.go('/notes'),
              icon: const Icon(Icons.note_alt_outlined, size: 18),
              label: const Text('메모장'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _CalendarMonthNav(
          month: _month,
          onChanged: (value) => setState(() => _month = value),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: notes.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('캘린더를 불러오지 못했습니다: $error')),
            data: (value) {
              final entries = noteCalendarEntriesByDate(value, _month);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _CalendarGrid(month: _month, entries: entries),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 340,
                    child: _AgendaList(month: _month, entries: entries),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CalendarMonthNav extends StatelessWidget {
  const _CalendarMonthNav({required this.month, required this.onChanged});

  final String month;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => onChanged(shiftMonth(month, -1)),
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 달',
        ),
        SizedBox(
          width: 180,
          child: Center(
            child: Text(
              noteCalendarMonthLabel(month),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        IconButton(
          onPressed: () => onChanged(shiftMonth(month, 1)),
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 달',
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.month, required this.entries});

  final String month;
  final Map<String, List<NoteCalendarEntry>> entries;

  @override
  Widget build(BuildContext context) {
    final days = calendarVisibleDays(month);
    final currentMonth = parseMonthKey(month).month;
    return Column(
      children: [
        Row(
          children: [
            for (final label in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        ),
        Expanded(
          child: GridView.builder(
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final key = toDateKey(day);
              return _DayCell(
                day: day,
                inMonth: day.month == currentMonth,
                entries: entries[key] ?? const [],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.entries,
  });

  final DateTime day;
  final bool inMonth;
  final List<NoteCalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: inMonth
            ? theme.cardTheme.color
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: inMonth
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in entries.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _EntryPill(entry: entry),
            ),
          if (entries.length > 3)
            Text(
              '+${entries.length - 3}',
              style: TextStyle(fontSize: 11, color: context.desktopMuted),
            ),
        ],
      ),
    );
  }
}

class _EntryPill extends StatelessWidget {
  const _EntryPill({required this.entry});

  final NoteCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.overdue ? context.appExpense : context.appIncome;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        entry.note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({required this.month, required this.entries});

  final String month;
  final Map<String, List<NoteCalendarEntry>> entries;

  @override
  Widget build(BuildContext context) {
    final keys = entries.keys.toList()..sort();
    if (keys.isEmpty) {
      return const Center(child: Text('이번 달 일정이 없습니다.'));
    }
    return ListView(
      children: [
        for (final key in keys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              noteCalendarDayLabel(parseDateKey(key)),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          for (final entry in entries[key]!)
            Card(
              elevation: 0,
              child: ListTile(
                dense: true,
                leading: Icon(
                  entry.overdue
                      ? Icons.notification_important_outlined
                      : Icons.event_available_outlined,
                ),
                title: Text(entry.note.title),
                subtitle: Text(entry.label),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
