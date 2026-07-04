import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/ui/shared/calendar_entries.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('saves calendar events and expands monthly repeats', () async {
    await db.calendarEventsDao.saveEvent(
      title: 'Payday',
      description: 'Budget reset',
      startAt: DateTime(2026, 7, 3, 9),
      endAt: DateTime(2026, 7, 3, 10),
      schedule: const NoteScheduleDraft(type: NoteScheduleType.weekly),
    );

    final events = await db.calendarEventsDao.listEvents();
    expect(events.single.title, 'Payday');
    expect(events.single.scheduleType, NoteScheduleType.weekly.storageValue);

    final entries = calendarOccurrencesByDate(events, '2026-07');
    expect(entries.keys, containsAll(['2026-07-03', '2026-07-10']));
    expect(entries['2026-07-03']!.single.event.title, 'Payday');
  });

  test('rejects blank titles and inverted date ranges', () async {
    expect(
      () => db.calendarEventsDao.saveEvent(
        title: '  ',
        startAt: DateTime(2026, 7, 3),
      ),
      throwsArgumentError,
    );
    expect(
      () => db.calendarEventsDao.saveEvent(
        title: 'Broken',
        startAt: DateTime(2026, 7, 3, 10),
        endAt: DateTime(2026, 7, 3, 9),
      ),
      throwsArgumentError,
    );
  });
}
