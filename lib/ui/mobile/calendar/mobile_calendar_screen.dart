import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../../../features/notes/note_schedule.dart';
import '../../shared/calendar_entries.dart';
import '../../shared/calendar_providers.dart';
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
            final entries = calendarOccurrencesByDate(value, _month);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MobileCalendarGrid(month: _month, entries: entries),
                const SizedBox(height: 12),
                _MobileAgendaList(entries: entries),
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
  final Map<String, List<CalendarOccurrence>> entries;

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
              final count = entries[toDateKey(day)]?.length ?? 0;
              return _MobileDayCell(
                day: day,
                inMonth: day.month == currentMonth,
                count: count,
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
  const _MobileAgendaList({required this.entries});

  final Map<String, List<CalendarOccurrence>> entries;

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
              calendarDayLabel(parseDateKey(key)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          for (final entry in entries[key]!)
            MobileCard(
              child: InkWell(
                onTap: () =>
                    _MobileCalendarEventSheet.show(context, event: entry.event),
                child: Row(
                  children: [
                    Icon(Icons.event_outlined, color: _eventColor(entry.event)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.event.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.event.allDay
                                ? '종일'
                                : calendarTimeLabel(entry.start),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
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
  late DateTime _date = widget.event == null
      ? DateTime.now()
      : DateTime.parse(widget.event!.startAt).toLocal();
  late TimeOfDay _startTime = TimeOfDay.fromDateTime(_date);
  late bool _allDay = widget.event?.allDay ?? false;
  late NoteScheduleType _repeat = widget.event == null
      ? NoteScheduleType.none
      : NoteScheduleTypeStorage.parse(widget.event!.scheduleType);
  late bool _notify = widget.event?.notificationEnabled ?? false;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
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
    setState(() => _busy = true);
    try {
      await ref
          .read(calendarEventsDaoProvider)
          .saveEvent(
            id: widget.event?.id,
            title: _title.text,
            description: _description.text,
            startAt: start,
            endAt: _allDay ? null : start.add(const Duration(hours: 1)),
            allDay: _allDay,
            color: widget.event?.color ?? '#2563eb',
            schedule: NoteScheduleDraft(
              type: _repeat,
              notificationEnabled: _notify,
              notificationLeadMinutes: _notify ? const [10] : const [],
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
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickTime,
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(_startTime.format(context)),
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
              title: const Text('10분 전 알림'),
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

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (value != null) setState(() => _startTime = value);
  }
}

Color _eventColor(CalendarEvent event) {
  final value = event.color.replaceFirst('#', '');
  final parsed = int.tryParse(value, radix: 16) ?? 0x2563eb;
  return Color(0xFF000000 | parsed);
}
