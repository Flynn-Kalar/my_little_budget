import '../../data/database.dart';
import 'note_schedule.dart';

DateTime? noteReminderDate(Note note) {
  final value = note.reminderAt;
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}

bool isNoteOverdue(
  Note note, {
  required bool hasIncompleteItems,
  DateTime? now,
}) {
  final reminder = noteReminderDate(note);
  return hasIncompleteItems &&
      reminder != null &&
      !reminder.isAfter(now ?? DateTime.now());
}

String formatNoteReminder(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  final local = value.toLocal();
  return '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

DateTime? noteNextResetDate(Note note) {
  final value = note.nextResetAt;
  return value == null ? null : DateTime.tryParse(value)?.toLocal();
}

DateTime? noteDdayDate(Note note) {
  final type = NoteScheduleTypeStorage.parse(note.scheduleType);
  return switch (type) {
    NoteScheduleType.once => noteReminderDate(note),
    NoteScheduleType.yearly ||
    NoteScheduleType.interval => noteNextResetDate(note),
    _ => null,
  };
}

int noteDday(DateTime target, {DateTime? now}) {
  final localTarget = target.toLocal();
  final localNow = (now ?? DateTime.now()).toLocal();
  final targetDate = DateTime(
    localTarget.year,
    localTarget.month,
    localTarget.day,
  );
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  return targetDate.difference(today).inDays;
}

String formatNoteDday(DateTime target, {DateTime? now}) {
  final days = noteDday(target, now: now);
  if (days == 0) return 'D-day';
  return days > 0 ? 'D-$days' : 'D+${-days}';
}

String noteScheduleLabel(NoteScheduleType type) => switch (type) {
  NoteScheduleType.none => '일정 없음',
  NoteScheduleType.once => '1회 일정',
  NoteScheduleType.daily => '매일',
  NoteScheduleType.weekly => '매주',
  NoteScheduleType.weekdays => '평일',
  NoteScheduleType.weekends => '주말',
  NoteScheduleType.monthly => '매월',
  NoteScheduleType.yearly => '매년',
  NoteScheduleType.interval => 'N일마다',
};

String noteScheduleSummary(Note note) {
  final type = NoteScheduleTypeStorage.parse(note.scheduleType);
  switch (type) {
    case NoteScheduleType.none:
      return '일정 없음';
    case NoteScheduleType.once:
      final reminder = noteReminderDate(note);
      return reminder == null ? '1회 일정' : '1회 ${formatNoteReminder(reminder)}';
    case NoteScheduleType.daily:
      return '매일 ${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.weekly:
      final weekdays = parseNoteIntList(note.resetWeekdays);
      final label = weekdays.isEmpty
          ? noteWeekdayLabel(note.resetWeekday)
          : weekdays.map(noteWeekdayLabel).join(', ');
      return '매주 $label ${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.weekdays:
      return '평일 ${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.weekends:
      return '주말 ${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.monthly:
      return '매월 ${note.resetDayOfMonth ?? 1}일 ${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.yearly:
      final anchor = parseNoteDate(note.anchorDate);
      final month = anchor?.month ?? 1;
      return '매년 $month월 ${note.resetDayOfMonth ?? 1}일 '
          '${note.resetTime ?? ''} 리셋';
    case NoteScheduleType.interval:
      return '${note.intervalDays ?? 2}일마다 ${note.resetTime ?? ''} 리셋';
  }
}

String noteNotificationSummary(Note note) {
  final type = NoteScheduleTypeStorage.parse(note.scheduleType);
  if (!note.notificationEnabled) return '알림 꺼짐';
  if (type == NoteScheduleType.once) {
    final reminder = noteReminderDate(note);
    final leads = parseNoteIntList(
      note.notificationLeadMinutes,
    ).where((value) => value > 0).map(_leadLabel).toList();
    final suffix = leads.isEmpty ? '' : ' (${leads.join(', ')} 전 추가)';
    return reminder == null
        ? '1회 알림$suffix'
        : '1회 알림 ${formatNoteReminder(reminder)}$suffix';
  }
  final time = note.notificationTime ?? '09:00';
  final days = <int>{
    note.notificationDaysBefore,
    ...parseNoteIntList(note.notificationExtraDaysBefore),
  }.toList()..sort();
  if (days.length == 1 && days.first <= 0) return '알림 $time';
  final labels = days.map((day) => day <= 0 ? '당일' : '$day일 전').join(', ');
  return '$labels $time 알림';
}

String noteWeekdayLabel(int? weekday) => switch (weekday) {
  DateTime.monday => '월',
  DateTime.tuesday => '화',
  DateTime.wednesday => '수',
  DateTime.thursday => '목',
  DateTime.friday => '금',
  DateTime.saturday => '토',
  DateTime.sunday => '일',
  _ => '-',
};

String _leadLabel(int minutes) {
  if (minutes % (24 * 60) == 0) return '${minutes ~/ (24 * 60)}일';
  if (minutes % 60 == 0) return '${minutes ~/ 60}시간';
  return '$minutes분';
}
