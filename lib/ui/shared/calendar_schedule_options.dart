import 'package:flutter/material.dart';
import '../../features/calendar/calendar_schedule.dart';
import '../../features/notes/note_schedule.dart';
import '../../features/notes/reminder_calendar.dart';
import 'calendar_time_zone_field.dart';

class CalendarScheduleDraft extends ChangeNotifier {
  CalendarScheduleDraft(CalendarScheduleSettings settings)
    : original = settings,
      every = TextEditingController(text: '${settings.every}'),
      zone = TextEditingController(text: settings.timeZone ?? ''),
      until = settings.until,
      isDday = settings.isDday {
    every.addListener(notifyListeners);
    zone.addListener(notifyListeners);
  }
  CalendarScheduleSettings original;
  final TextEditingController every, zone;
  String? until;
  bool isDday;
  CalendarScheduleSettings settings({
    required DateTime start,
    required bool allDay,
  }) => CalendarScheduleSettings(
    every: int.tryParse(every.text) ?? 0,
    until: until,
    timeZone: zone.text.trim().isEmpty ? original.timeZone : zone.text.trim(),
    allDayDate: allDay ? noteDateKey(start) : null,
    exceptions: original.exceptions,
    isDday: isDday,
  );
  @override
  void dispose() {
    every.dispose();
    zone.dispose();
    super.dispose();
  }
}

class CalendarRecurrencePreview extends StatelessWidget {
  const CalendarRecurrencePreview({
    super.key,
    required this.draft,
    required this.start,
    required this.type,
    required this.allDay,
  });
  final CalendarScheduleDraft draft;
  final DateTime start;
  final NoteScheduleType type;
  final bool allDay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: draft,
    builder: (context, _) {
      if (!type.isRepeating) return const SizedBox.shrink();
      final settings = draft.settings(start: start, allDay: allDay);
      if (settings.validationError != null) {
        return Text(
          settings.validationError!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        );
      }
      final now = DateTime.now();
      final dates = reminderResets(
        NoteScheduleDraft(
          type: type,
          resetTime: noteTimeKey(start),
          dayOfMonth: start.day,
          weekday: start.weekday,
          weekdays: [start.weekday],
        ),
        calendarZone(settings.timeZone ?? 'UTC'),
        now.isBefore(start) ? start.subtract(const Duration(seconds: 1)) : now,
        anchor: start,
        count: 4,
        every: settings.every,
        until: parseNoteDate(settings.until),
      ).where((d) => !d.isBefore(start) && d.isAfter(now)).take(3).toList();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          dates.isEmpty
              ? '예정된 반복 일정 없음'
              : '다음 일정: ${dates.map(noteDateKey).join(' · ')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    },
  );
}

class CalendarScheduleOptions extends StatelessWidget {
  const CalendarScheduleOptions({
    super.key,
    required this.draft,
    required this.repeating,
    required this.onChanged,
    this.busy = false,
    required this.date,
  });
  final CalendarScheduleDraft draft;
  final bool repeating, busy;
  final DateTime date;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (repeating) ...[
        TextField(
          controller: draft.every,
          enabled: !busy,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '반복 간격',
            helperText: '선택한 반복 단위마다 적용합니다. 예: 매월 + 3 → 3개월마다',
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('반복 종료일'),
          subtitle: Text(draft.until ?? '종료일 없음'),
          trailing: draft.until == null
              ? const Icon(Icons.calendar_month_outlined)
              : IconButton(
                  tooltip: '종료일 지우기',
                  onPressed: busy
                      ? null
                      : () {
                          draft.until = null;
                          onChanged();
                        },
                  icon: const Icon(Icons.clear),
                ),
          onTap: busy
              ? null
              : () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: parseNoteDate(draft.until) ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    draft.until = noteDateKey(date);
                    onChanged();
                  }
                },
        ),
      ],
      CalendarTimeZoneField(
        controller: draft.zone,
        enabled: !busy,
        date: date,
        onChanged: onChanged,
      ),
    ],
  );
}
