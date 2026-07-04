import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/notes_calendar.dart';
import '../../shared/notes_providers.dart';
import '../mobile_widgets.dart';

class MobileNotesCalendarScreen extends ConsumerStatefulWidget {
  const MobileNotesCalendarScreen({super.key});

  @override
  ConsumerState<MobileNotesCalendarScreen> createState() =>
      _MobileNotesCalendarScreenState();
}

class _MobileNotesCalendarScreenState
    extends ConsumerState<MobileNotesCalendarScreen> {
  String _month = currentMonthKey();

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
    return MobilePageScaffold(
      title: '캘린더',
      actions: [
        FilledButton.tonalIcon(
          key: const ValueKey('mobile-notes-calendar-back-button'),
          onPressed: () => context.go('/notes'),
          icon: const Icon(Icons.note_alt_outlined, size: 18),
          label: const Text('메모장'),
        ),
      ],
      children: [
        MobileMonthNav(
          month: _month,
          onChanged: (value) => setState(() => _month = value),
        ),
        MobileAsync(
          value: notes,
          builder: (value) {
            final entries = noteCalendarEntriesByDate(value, _month);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MobileCalendarGrid(month: _month, entries: entries),
                const SizedBox(height: 12),
                _MobileAgendaList(month: _month, entries: entries),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MobileCalendarGrid extends StatelessWidget {
  const _MobileCalendarGrid({required this.month, required this.entries});

  final String month;
  final Map<String, List<NoteCalendarEntry>> entries;

  @override
  Widget build(BuildContext context) {
    final days = calendarVisibleDays(month);
    final currentMonth = parseMonthKey(month).month;
    return MobileCard(
      child: Column(
        children: [
          Row(
            children: [
              for (final label in ['일', '월', '화', '수', '목', '금', '토'])
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final day = days[index];
              final key = toDateKey(day);
              return _MobileDayCell(
                day: day,
                inMonth: day.month == currentMonth,
                count: entries[key]?.length ?? 0,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MobileDayCell extends StatelessWidget {
  const _MobileDayCell({
    required this.day,
    required this.inMonth,
    required this.count,
  });

  final DateTime day;
  final bool inMonth;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
        color: inMonth
            ? theme.cardTheme.color
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: inMonth
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.appIncome.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: context.appIncome,
                ),
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MobileAgendaList extends StatelessWidget {
  const _MobileAgendaList({required this.month, required this.entries});

  final String month;
  final Map<String, List<NoteCalendarEntry>> entries;

  @override
  Widget build(BuildContext context) {
    final keys = entries.keys.toList()..sort();
    if (keys.isEmpty) return const EmptyMobileCard('이번 달 일정이 없습니다.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              noteCalendarDayLabel(parseDateKey(key)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          for (final entry in entries[key]!)
            MobileCard(
              child: Row(
                children: [
                  Icon(
                    entry.overdue
                        ? Icons.notification_important_outlined
                        : Icons.event_available_outlined,
                    color: entry.overdue
                        ? context.appExpense
                        : context.appIncome,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.note.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(entry.label),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
