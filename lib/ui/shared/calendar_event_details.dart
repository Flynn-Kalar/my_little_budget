import 'package:flutter/material.dart';

import '../../core/date.dart';
import '../../features/calendar/calendar_dday.dart';
import '../../features/calendar/calendar_schedule.dart';
import '../../features/notes/note_schedule.dart';
import 'calendar_entries.dart';

/// Read-only content shared by the desktop dialog and mobile detail sheet.
class CalendarEventDetails extends StatelessWidget {
  const CalendarEventDetails({super.key, required this.occurrence});

  final CalendarOccurrence occurrence;

  @override
  Widget build(BuildContext context) {
    final event = occurrence.event;
    final settings = CalendarScheduleSettings.fromEvent(event);
    final type = NoteScheduleTypeStorage.parse(event.scheduleType);
    final end = event.endAt == null || event.allDay
        ? null
        : occurrence.start.add(
            DateTime.parse(
              event.endAt!,
            ).difference(DateTime.parse(event.startAt)),
          );
    String dateTime(DateTime value) =>
        '${toDateKey(value)} · ${calendarTimeLabel(value)}';
    final repeat = switch (type) {
      NoteScheduleType.daily => '${settings.every}일마다',
      NoteScheduleType.weekly => '${settings.every}주마다',
      NoteScheduleType.monthly => '${settings.every}개월마다',
      NoteScheduleType.yearly => '${settings.every}년마다',
      NoteScheduleType.weekdays => '평일마다',
      NoteScheduleType.weekends => '주말마다',
      NoteScheduleType.interval => '${settings.every}일마다',
      _ => '반복 안 함',
    };
    final leads = parseNoteIntList(event.notificationLeadMinutes);
    final notificationBase = event.allDay ? '당일 오전 9시' : '일정 시작 시';

    Widget section(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          SelectableText(value),
        ],
      ),
    );

    return Column(
      key: const ValueKey('calendar-event-details'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          occurrence.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        if (settings.isDday)
          section('D-day', calendarDdayLabel(calendarEventStart(event))),
        section(
          '일시',
          event.allDay
              ? '${toDateKey(occurrence.start)} · 종일'
              : '${dateTime(occurrence.start)}${end == null ? '' : '\n~ ${dateTime(end)}'}',
        ),
        section(
          '내용',
          event.description.trim().isEmpty ? '내용이 없습니다.' : event.description,
        ),
        if (event.location?.trim().isNotEmpty ?? false)
          section('장소', event.location!),
        if (event.linkUrl?.trim().isNotEmpty ?? false)
          section('링크', event.linkUrl!),
        section(
          '반복',
          '$repeat${type.isRepeating && settings.until != null ? ' · ${settings.until}까지' : ''}',
        ),
        if (type.isRepeating &&
            settings.exceptions.containsKey(occurrence.originalDate))
          section('회차', '${occurrence.originalDate} 회차에서 변경된 일정'),
        if (settings.timeZone != null) section('시간대', settings.timeZone!),
        section(
          '알림',
          !event.notificationEnabled
              ? '알림 꺼짐'
              : leads.isEmpty
              ? notificationBase
              : leads
                    .map(
                      (minutes) => minutes == 0
                          ? notificationBase
                          : '$notificationBase $minutes분 전',
                    )
                    .join(' · '),
        ),
      ],
    );
  }
}
