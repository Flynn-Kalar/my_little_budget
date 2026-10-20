import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/calendar/calendar_dday.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';
import 'package:my_little_budget/features/calendar/calendar_reminder_store.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';

void main() {
  test(
    'D-day uses civil dates across midnight, leap day, and year boundaries',
    () {
      expect(
        calendarDdayLabel(
          DateTime(2026, 10, 21, 23),
          today: DateTime(2026, 10, 21),
        ),
        'D-day',
      );
      expect(
        calendarDdayLabel(
          DateTime(2027, 1, 1),
          today: DateTime(2026, 12, 31, 23, 59),
        ),
        'D-1',
      );
      expect(
        calendarDdayLabel(DateTime(2024, 2, 28), today: DateTime(2024, 3, 1)),
        'D+2',
      );
      expect(CalendarScheduleSettings.decode('{}').isDday, isFalse);
    },
  );

  test(
    'D-day persists through edits, occurrence changes, reminder zone adoption, backup and sync',
    () async {
      final source = AppDatabase.forTesting(NativeDatabase.memory());
      var closed = false;
      addTearDown(() async {
        if (!closed) await source.close();
      });
      final date = DateTime(2026, 10, 21, 9);
      final id = await source.calendarEventsDao.saveEvent(
        title: '기념일',
        startAt: date,
        settings: const CalendarScheduleSettings(isDday: true),
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.yearly,
          notificationEnabled: true,
        ),
      );
      await source.calendarEventsDao.saveOccurrence(
        id,
        '2026-10-21',
        title: '올해 기념일',
      );
      await CalendarReminderStore(
        source,
      ).plan(DateTime.utc(2026, 10, 20), 'Asia/Seoul');
      var event = (await source.calendarEventsDao.getEvent(id))!;
      expect(CalendarScheduleSettings.fromEvent(event).isDday, isTrue);
      await source.calendarEventsDao.saveEvent(
        id: id,
        title: '수정 기념일',
        startAt: date,
      );
      event = (await source.calendarEventsDao.getEvent(id))!;
      expect(CalendarScheduleSettings.fromEvent(event).isDday, isTrue);
      final backup = parseBackup(
        (await source.backupDao.exportBackup()).toJsonString(),
      );
      expect(backup.isOk, isTrue, reason: backup.error);
      expect(
        CalendarScheduleSettings.fromEvent(
          backup.backup!.calendarEvents.single,
        ).isDday,
        isTrue,
      );
      final payload = (await LocalSyncStore(
        source,
      ).buildPayload('calendar_events', event.uuid))!;
      await source.close();
      closed = true;
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await LocalSyncStore(target).applyRemotePage(
        entity: 'calendar_events',
        bootstrap: true,
        rows: [
          RemoteSyncRow(
            uuid: event.uuid,
            payload: payload,
            updatedAt: event.updatedAt,
            deletedAt: null,
            revision: 1,
          ),
        ],
      );
      expect(
        CalendarScheduleSettings.fromEvent(
          (await target.calendarEventsDao.listEvents()).single,
        ).isDday,
        isTrue,
      );
    },
  );

  test(
    'D-day list includes all months; today and nearest future precede recent past',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      for (final (title, date, marked) in [
        ('먼 미래', DateTime(2027, 3, 1), true),
        ('과거', DateTime(2026, 1, 1), true),
        ('오늘', DateTime(2026, 10, 21), true),
        ('가까운 미래', DateTime(2026, 10, 22), true),
        ('일반 일정', DateTime(2026, 10, 21), false),
        ('최근 과거', DateTime(2026, 10, 20), true),
      ]) {
        await db.calendarEventsDao.saveEvent(
          title: title,
          startAt: date,
          allDay: true,
          settings: CalendarScheduleSettings(isDday: marked),
        );
      }
      expect(
        calendarDdayEvents(
          await db.calendarEventsDao.listEvents(),
          today: DateTime(2026, 10, 21),
        ).map((e) => e.title),
        ['오늘', '가까운 미래', '먼 미래', '최근 과거', '과거'],
      );
    },
  );
}
