import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/date.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/notes/note_schedule.dart';
import '../../shared/calendar_entries.dart';
import 'package:my_little_budget/features/calendar/providers.dart';
import '../../shared/notes_calendar.dart' as note_calendar;
import 'package:my_little_budget/features/notes/providers.dart';
import '../mobile_widgets.dart';

class MobileCalendarScreen extends ConsumerStatefulWidget {
  const MobileCalendarScreen({super.key});

  @override
  ConsumerState<MobileCalendarScreen> createState() =>
      _MobileCalendarScreenState();
}

class _MobileCalendarScreenState extends ConsumerState<MobileCalendarScreen> {
  String _month = currentMonthKey();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(calendarEventsProvider);
    final notes = ref.watch(notesProvider);
    return MobilePageScaffold(
      title: '캘린더',
      onAdd: () => _MobileCalendarEventSheet.show(context),
      addTooltip: '일정 추가',
      children: [
        MobileMonthNav(
          month: _month,
          onChanged: (value) => setState(() => _month = value),
        ),
        MobileAsync(
          value: events,
          builder: (value) {
            final eventEntries = calendarOccurrencesByDate(value, _month);
            return MobileAsync(
              value: notes,
              builder: (noteRows) {
                final noteEntries = note_calendar.noteCalendarEntriesByDate(
                  noteRows,
                  _month,
                );
                final entries = _combineCalendarEntries(
                  eventEntries,
                  noteEntries,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MobileCalendarGrid(month: _month, entries: entries),
                    const SizedBox(height: 12),
                    _MobileAgendaList(entries: entries),
                  ],
                );
              },
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
  final Map<String, List<_MobileCalendarEntry>> entries;

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
              final dayEntries = entries[toDateKey(day)] ?? const [];
              return _MobileDayCell(
                day: day,
                inMonth: day.month == currentMonth,
                entries: dayEntries,
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
    required this.entries,
  });

  final DateTime day;
  final bool inMonth;
  final List<_MobileCalendarEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeating = entries.where((entry) => entry.isRepeating).toList();
    final oneTime = entries.where((entry) => !entry.isRepeating).toList();
    final visible = [
      ...oneTime.take(repeating.isEmpty ? 2 : 1),
      if (repeating.isNotEmpty) repeating.first,
    ];
    final hiddenCount = entries.length - visible.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(6),
        color: inMonth
            ? theme.cardTheme.color
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${day.day}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: inMonth
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 3),
          for (final entry in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _CalendarEntryPill(entry: entry),
            ),
          if (hiddenCount > 0)
            Text(
              '+$hiddenCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarEntryPill extends StatelessWidget {
  const _CalendarEntryPill({required this.entry});

  final _MobileCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.color(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isRepeating) ...[
              Icon(Icons.repeat, size: 9, color: color),
              const SizedBox(width: 2),
            ],
            Expanded(
              child: Text(
                entry.shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileAgendaList extends StatelessWidget {
  const _MobileAgendaList({required this.entries});

  final Map<String, List<_MobileCalendarEntry>> entries;

  @override
  Widget build(BuildContext context) {
    final keys = entries.keys.toList()..sort();
    if (keys.isEmpty) return const _EmptyCalendarCard();
    final seenRepeating = <int>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final key in keys)
          _AgendaDaySection(
            dateKey: key,
            entries: entries[key]!,
            seenRepeating: seenRepeating,
          ),
      ],
    );
  }
}

class _AgendaDaySection extends StatelessWidget {
  const _AgendaDaySection({
    required this.dateKey,
    required this.entries,
    required this.seenRepeating,
  });

  final String dateKey;
  final List<_MobileCalendarEntry> entries;
  final Set<int> seenRepeating;

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries(entries, seenRepeating);
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            calendarDayLabel(parseDateKey(dateKey)),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        for (final entry in visible)
          MobileCard(
            child: InkWell(
              onTap: () => entry.open(context),
              child: Row(
                children: [
                  Icon(entry.icon, color: entry.color(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(entry.subtitle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<_MobileCalendarEntry> _visibleEntries(
    List<_MobileCalendarEntry> entries,
    Set<int> seenRepeating,
  ) {
    return entries.where((entry) {
      final event = entry.event;
      if (event == null || !entry.isRepeating) return true;
      return seenRepeating.add(event.id);
    }).toList();
  }
}

class _EmptyCalendarCard extends StatelessWidget {
  const _EmptyCalendarCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MobileCard(
      child: Row(
        children: [
          Icon(
            Icons.event_available_outlined,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이번 달 일정이 없습니다.',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '+ 버튼으로 일정을 추가하거나 메모에서 캘린더 표시를 켜세요.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileCalendarEventSheet extends ConsumerStatefulWidget {
  const _MobileCalendarEventSheet({this.event});

  final CalendarEvent? event;

  static Future<void> show(BuildContext context, {CalendarEvent? event}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _MobileCalendarEventSheet(event: event),
    );
  }

  @override
  ConsumerState<_MobileCalendarEventSheet> createState() =>
      _MobileCalendarEventSheetState();
}

class _MobileCalendarEventSheetState
    extends ConsumerState<_MobileCalendarEventSheet> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _description = TextEditingController(
    text: widget.event?.description ?? '',
  );
  late final _location = TextEditingController(
    text: widget.event?.location ?? '',
  );
  late final _link = TextEditingController(text: widget.event?.linkUrl ?? '');
  late DateTime _date = widget.event == null
      ? DateTime.now()
      : DateTime.parse(widget.event!.startAt).toLocal();
  late TimeOfDay _startTime = TimeOfDay.fromDateTime(_date);
  late TimeOfDay _endTime = TimeOfDay.fromDateTime(
    widget.event?.endAt == null
        ? _date.add(const Duration(hours: 1))
        : DateTime.parse(widget.event!.endAt!).toLocal(),
  );
  late bool _allDay = widget.event?.allDay ?? false;
  late String _color = widget.event?.color ?? '#2563eb';
  late NoteScheduleType _repeat = widget.event == null
      ? NoteScheduleType.none
      : NoteScheduleTypeStorage.parse(widget.event!.scheduleType);
  late bool _notify = widget.event?.notificationEnabled ?? false;
  late final Set<int> _leadMinutes = {
    ...parseNoteIntList(widget.event?.notificationLeadMinutes),
  };
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _allDay ? 0 : _startTime.hour,
      _allDay ? 0 : _startTime.minute,
    );
    final end = _allDay
        ? null
        : DateTime(
            _date.year,
            _date.month,
            _date.day,
            _endTime.hour,
            _endTime.minute,
          );
    setState(() => _busy = true);
    try {
      await ref
          .read(calendarEventsDaoProvider)
          .saveEvent(
            id: widget.event?.id,
            title: _title.text,
            description: _description.text,
            startAt: start,
            endAt: end,
            allDay: _allDay,
            color: _color,
            location: _location.text,
            linkUrl: _link.text,
            schedule: NoteScheduleDraft(
              type: _repeat,
              notificationEnabled: _notify,
              notificationLeadMinutes: _notify
                  ? _leadMinutes.toList()
                  : const [],
            ),
          );
      if (!mounted) return;
      refreshCalendarEvents(ref);
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final id = widget.event?.id;
    if (id == null) return;
    await ref.read(calendarEventsDaoProvider).deleteEvent(id);
    if (!mounted) return;
    refreshCalendarEvents(ref);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.event == null ? '일정 추가' : '일정 수정',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              enabled: !_busy,
              autofocus: true,
              decoration: const InputDecoration(labelText: '제목'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              enabled: !_busy,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '설명'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickDate,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(toDateKey(_date)),
            ),
            SwitchListTile(
              value: _allDay,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _allDay = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('종일'),
            ),
            if (!_allDay)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickTime(start: true),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('시작 ${_startTime.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pickTime(start: false),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('종료 ${_endTime.format(context)}'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoteScheduleType>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: '반복'),
              items: const [
                DropdownMenuItem(
                  value: NoteScheduleType.none,
                  child: Text('없음'),
                ),
                DropdownMenuItem(
                  value: NoteScheduleType.daily,
                  child: Text('매일'),
                ),
                DropdownMenuItem(
                  value: NoteScheduleType.weekly,
                  child: Text('매주'),
                ),
                DropdownMenuItem(
                  value: NoteScheduleType.monthly,
                  child: Text('매월'),
                ),
                DropdownMenuItem(
                  value: NoteScheduleType.yearly,
                  child: Text('매년'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _repeat = value!),
            ),
            SwitchListTile(
              value: _notify,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _notify = value),
              contentPadding: EdgeInsets.zero,
              title: const Text('알림'),
            ),
            if (_notify)
              _LeadMinuteChips(
                values: _leadMinutes,
                onChanged: () => setState(() {}),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _color,
              decoration: const InputDecoration(labelText: '색상'),
              items: const [
                DropdownMenuItem(value: '#2563eb', child: Text('파랑')),
                DropdownMenuItem(value: '#16a34a', child: Text('초록')),
                DropdownMenuItem(value: '#dc2626', child: Text('빨강')),
                DropdownMenuItem(value: '#9333ea', child: Text('보라')),
                DropdownMenuItem(value: '#f59e0b', child: Text('노랑')),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _color = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '장소'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              enabled: !_busy,
              decoration: const InputDecoration(labelText: '링크'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (widget.event != null)
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    child: Text(
                      '삭제',
                      style: TextStyle(color: context.appExpense),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _pickTime({required bool start}) async {
    final value = await showTimePicker(
      context: context,
      initialTime: start ? _startTime : _endTime,
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _startTime = value;
      } else {
        _endTime = value;
      }
    });
  }
}

class _LeadMinuteChips extends StatelessWidget {
  const _LeadMinuteChips({required this.values, required this.onChanged});

  final Set<int> values;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const options = {
      0: '정시',
      10: '10분 전',
      30: '30분 전',
      60: '1시간 전',
      1440: '1일 전',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final entry in options.entries)
            FilterChip(
              label: Text(entry.value),
              selected: values.contains(entry.key),
              onSelected: (selected) {
                if (selected) {
                  values.add(entry.key);
                } else {
                  values.remove(entry.key);
                }
                onChanged();
              },
            ),
        ],
      ),
    );
  }
}

Color _eventColor(CalendarEvent event) {
  final value = event.color.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16) ?? 0x2563eb;
  return Color(0xFF000000 | parsed);
}

class _MobileCalendarEntry {
  const _MobileCalendarEntry.event(this.eventEntry) : noteEntry = null;
  const _MobileCalendarEntry.note(this.noteEntry) : eventEntry = null;

  final CalendarOccurrence? eventEntry;
  final note_calendar.NoteCalendarEntry? noteEntry;

  CalendarEvent? get event => eventEntry?.event;
  DateTime get start => eventEntry?.start ?? noteEntry!.date;
  String get title => eventEntry?.event.title ?? noteEntry!.note.title;
  bool get isRepeating {
    final event = eventEntry?.event;
    if (event != null) return _isRepeating(event);
    return NoteScheduleTypeStorage.parse(
      noteEntry!.note.scheduleType,
    ).isRepeating;
  }

  String get shortLabel {
    final event = eventEntry?.event;
    if (event != null) {
      if (_isRepeating(event)) return '반복';
      return event.allDay
          ? event.title
          : '${calendarTimeLabel(start)} ${event.title}';
    }
    return isRepeating ? '반복 메모' : noteEntry!.note.title;
  }

  String get subtitle {
    final event = eventEntry?.event;
    if (event != null) {
      final time = event.allDay ? '종일' : calendarTimeLabel(start);
      final location = event.location?.trim();
      if (location != null && location.isNotEmpty) return '$time · $location';
      return _isRepeating(event) ? '반복 일정 · $time' : time;
    }
    return '메모 · ${noteEntry!.label}';
  }

  IconData get icon {
    final event = eventEntry?.event;
    if (event != null) {
      return _isRepeating(event) ? Icons.repeat : Icons.event_outlined;
    }
    return noteEntry!.overdue
        ? Icons.notification_important_outlined
        : Icons.note_alt_outlined;
  }

  Color color(BuildContext context) {
    final event = eventEntry?.event;
    if (event != null) return _eventColor(event);
    return noteEntry!.overdue ? context.appExpense : context.appIncome;
  }

  void open(BuildContext context) {
    final event = eventEntry?.event;
    if (event != null) {
      _MobileCalendarEventSheet.show(context, event: event);
      return;
    }
    final id = noteEntry!.note.id;
    context.go('/notes?open=$id&tap=${DateTime.now().microsecondsSinceEpoch}');
  }
}

bool _isRepeating(CalendarEvent event) {
  return NoteScheduleTypeStorage.parse(event.scheduleType).isRepeating;
}

Map<String, List<_MobileCalendarEntry>> _combineCalendarEntries(
  Map<String, List<CalendarOccurrence>> events,
  Map<String, List<note_calendar.NoteCalendarEntry>> notes,
) {
  final result = <String, List<_MobileCalendarEntry>>{};
  for (final entry in events.entries) {
    result[entry.key] = [
      ...?result[entry.key],
      for (final item in entry.value) _MobileCalendarEntry.event(item),
    ];
  }
  for (final entry in notes.entries) {
    result[entry.key] = [
      ...?result[entry.key],
      for (final item in entry.value) _MobileCalendarEntry.note(item),
    ];
  }
  for (final value in result.values) {
    value.sort((a, b) {
      final time = a.start.compareTo(b.start);
      if (time != 0) return time;
      return a.title.compareTo(b.title);
    });
  }
  return result;
}
