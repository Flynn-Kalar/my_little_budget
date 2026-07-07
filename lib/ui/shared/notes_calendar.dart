import '../../core/date.dart';
import '../../data/daos/notes_dao.dart';
import '../../data/database.dart';
import '../../features/notes/checklist.dart';
import '../../features/notes/note_format.dart';
import '../../features/notes/note_schedule.dart';

class NoteCalendarEntry {
  const NoteCalendarEntry({
    required this.date,
    required this.note,
    required this.entry,
    required this.label,
    required this.overdue,
  });

  final DateTime date;
  final Note note;
  final NoteWithChecklist entry;
  final String label;
  final bool overdue;

  String get dateKey => toDateKey(date);
}

Map<String, List<NoteCalendarEntry>> noteCalendarEntriesByDate(
  List<NoteWithChecklist> notes,
  String monthKey,
) {
  final month = parseMonthKey(monthKey);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 1);
  final result = <String, List<NoteCalendarEntry>>{};

  void add(NoteWithChecklist entry, DateTime date, String label) {
    final local = date.toLocal();
    if (local.isBefore(start) || !local.isBefore(end)) return;
    final key = toDateKey(local);
    (result[key] ??= []).add(
      NoteCalendarEntry(
        date: local,
        note: entry.note,
        entry: entry,
        label: label,
        overdue: isNoteOverdue(
          entry.note,
          hasIncompleteItems: entry.hasIncompleteItems,
        ),
      ),
    );
  }

  for (final entry in notes) {
    final note = entry.note;
    if (!note.showOnCalendar) continue;
    final type = NoteScheduleTypeStorage.parse(note.scheduleType);
    if (type == NoteScheduleType.none) continue;
    if (type == NoteScheduleType.once) {
      final reminder = noteReminderDate(note);
      if (reminder != null) add(entry, reminder, '알림');
      continue;
    }

    final schedule = noteScheduleFromNote(note);
    var cursor = start.subtract(const Duration(minutes: 1));
    for (var i = 0; i < 80; i++) {
      final next = nextNoteResetAfter(schedule, cursor);
      if (next == null || !next.isBefore(end)) break;
      add(entry, next, '리셋');
      cursor = next.add(const Duration(minutes: 1));
    }
  }

  for (final entries in result.values) {
    entries.sort((a, b) {
      final time = a.date.compareTo(b.date);
      if (time != 0) return time;
      return a.note.title.compareTo(b.note.title);
    });
  }
  return result;
}

List<DateTime> calendarVisibleDays(String monthKey) {
  final month = parseMonthKey(monthKey);
  final first = DateTime(month.year, month.month, 1);
  final leading = first.weekday % 7;
  final gridStart = first.subtract(Duration(days: leading));
  return List.generate(42, (index) {
    return DateTime(gridStart.year, gridStart.month, gridStart.day + index);
  });
}

String noteCalendarMonthLabel(String monthKey) {
  final month = parseMonthKey(monthKey);
  return '${month.year}년 ${month.month}월';
}

String noteCalendarDayLabel(DateTime date) {
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  return '${date.month}.${date.day} (${weekdays[date.weekday % 7]})';
}
