import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../features/calendar/calendar_schedule.dart';
import '../../features/calendar/providers.dart';
import '../../features/notes/note_schedule.dart';
import '../../features/notes/providers.dart';
import '../../features/notes/reminder_calendar.dart';
import '../../features/notes/reminder_device_zone.dart';
import 'calendar_entries.dart';

/// Returns true when the caller should open the original series editor.
Future<bool> calendarOccurrenceActions(
  BuildContext context,
  CalendarOccurrence occurrence,
) async {
  if (!NoteScheduleTypeStorage.parse(
    occurrence.event.scheduleType,
  ).isRepeating) {
    return true;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text('${occurrence.title} · ${occurrence.originalDate}'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'one'),
          child: const Text('이번 일정만 수정'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'all'),
          child: const Text('전체 일정 수정'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, 'skip'),
          child: const Text('이번 일정 건너뛰기'),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  if (choice == 'all') return true;
  if (choice == 'one' || choice == 'skip') {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _OccurrenceDialog(occurrence: occurrence, skip: choice == 'skip'),
    );
  }
  return false;
}

class _OccurrenceDialog extends ConsumerStatefulWidget {
  const _OccurrenceDialog({required this.occurrence, required this.skip});
  final CalendarOccurrence occurrence;
  final bool skip;
  @override
  ConsumerState<_OccurrenceDialog> createState() => _OccurrenceDialogState();
}

class _OccurrenceDialogState extends ConsumerState<_OccurrenceDialog> {
  late final title = TextEditingController(text: widget.occurrence.title);
  late DateTime start = widget.occurrence.start;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      final settings = CalendarScheduleSettings.fromEvent(
        widget.occurrence.event,
      );
      final zone = calendarZone(
        settings.timeZone ?? await reminderDeviceZone(),
      );
      final resolvedStart = widget.occurrence.event.allDay
          ? start
          : reminderWallTime(zone, start, start.hour, start.minute);
      await ref
          .read(calendarEventsDaoProvider)
          .saveOccurrence(
            widget.occurrence.event.id,
            widget.occurrence.originalDate,
            skipped: widget.skip,
            startAt: resolvedStart,
            title: title.text,
          );
      refreshCalendarEvents(ref);
      unawaited(rebuildNoteNotifications(ref));
      if (mounted) Navigator.pop(context);
    } catch (failure, stack) {
      debugPrint('Calendar occurrence save failed: $failure\n$stack');
      if (mounted) setState(() => error = '일정을 저장하지 못했습니다. 제목과 날짜를 확인하세요.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.skip ? '이번 일정 건너뛰기' : '이번 일정만 수정'),
    content: SizedBox(
      width: 400,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.skip)
              Text(
                '${widget.occurrence.originalDate} 회차만 제외합니다. 다음 반복 일정은 유지됩니다.',
              )
            else ...[
              TextField(
                controller: title,
                enabled: !busy,
                decoration: const InputDecoration(labelText: '제목'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('날짜'),
                subtitle: Text(noteDateKey(start)),
                onTap: busy
                    ? null
                    : () async {
                        final value = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (value != null) {
                          setState(
                            () => start = DateTime(
                              value.year,
                              value.month,
                              value.day,
                              start.hour,
                              start.minute,
                            ),
                          );
                        }
                      },
              ),
              if (!widget.occurrence.event.allDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('시각'),
                  subtitle: Text(noteTimeKey(start)),
                  onTap: busy
                      ? null
                      : () async {
                          final value = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(start),
                          );
                          if (value != null) {
                            setState(
                              () => start = DateTime(
                                start.year,
                                start.month,
                                start.day,
                                value.hour,
                                value.minute,
                              ),
                            );
                          }
                        },
                ),
            ],
            if (error != null) Text(error!),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('취소'),
      ),
      FilledButton(
        onPressed: busy ? null : save,
        child: Text(widget.skip ? '건너뛰기' : '저장'),
      ),
    ],
  );
}

class CalendarExceptionList extends ConsumerWidget {
  const CalendarExceptionList({
    super.key,
    required this.event,
    required this.onChanged,
  });
  final CalendarEvent event;
  final Future<void> Function() onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest =
        ref
            .watch(calendarEventsProvider)
            .value
            ?.where((e) => e.id == event.id)
            .firstOrNull ??
        event;
    final exceptions = CalendarScheduleSettings.fromEvent(latest).exceptions;
    if (exceptions.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('변경·건너뛴 회차'),
      children: [
        for (final entry in exceptions.entries)
          ListTile(
            title: Text(entry.key),
            subtitle: Text(
              entry.value['skipped'] == true ? '건너뜀' : '이번 회차만 변경',
            ),
            trailing: TextButton(
              child: const Text('원래대로'),
              onPressed: () async {
                try {
                  await ref
                      .read(calendarEventsDaoProvider)
                      .saveOccurrence(event.id, entry.key, restore: true);
                  await onChanged();
                  refreshCalendarEvents(ref);
                  unawaited(rebuildNoteNotifications(ref));
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('회차를 복원하지 못했습니다.')),
                    );
                  }
                }
              },
            ),
          ),
      ],
    );
  }
}
