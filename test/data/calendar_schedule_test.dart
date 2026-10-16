import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';
import 'package:my_little_budget/features/calendar/calendar_reminder_store.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/features/notes/reminder_store.dart';
import 'package:my_little_budget/ui/shared/calendar_entries.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'editing another cycle keeps an already snoozed reminder whose original time is past',
    () async {
      final now = DateTime.utc(2026, 10, 16, 9);
      final id = await db.calendarEventsDao.saveEvent(
        title: '매일 확인',
        startAt: now.subtract(const Duration(minutes: 1)),
        settings: const CalendarScheduleSettings(timeZone: 'UTC'),
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.daily,
          notificationEnabled: true,
        ),
      );
      final first = await CalendarReminderStore(db).plan(now, 'UTC');
      final current = first.singleWhere(
        (j) => j['originalDate'] == '2026-10-16',
      );
      final jobId = -(current['jobId'] as int);
      final snooze = now.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      await db.customStatement(
        "UPDATE calendar_jobs SET state='pending',snoozed_until=? WHERE id=?",
        [snooze, jobId],
      );
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-10-17',
        skipped: true,
      );
      final next = await CalendarReminderStore(db).plan(now, 'UTC');
      expect(
        next.singleWhere((j) => j['jobId'] == -jobId)['triggerAt'],
        snooze,
      );
      expect(next.any((j) => j['originalDate'] == '2026-10-17'), false);
    },
  );

  test(
    'long recurrence intervals and future one-time events remain schedulable',
    () async {
      final now = DateTime.utc(2026, 10, 16);
      final recurring = await db.calendarEventsDao.saveEvent(
        title: '3년마다 확인',
        startAt: DateTime.utc(2026, 1, 20, 9),
        settings: const CalendarScheduleSettings(every: 3, timeZone: 'UTC'),
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.yearly,
          notificationEnabled: true,
        ),
      );
      final once = await db.calendarEventsDao.saveEvent(
        title: '미래 만기',
        startAt: DateTime.utc(2035, 1, 20, 9),
        settings: const CalendarScheduleSettings(timeZone: 'UTC'),
        schedule: const NoteScheduleDraft(notificationEnabled: true),
      );
      final jobs = await CalendarReminderStore(db).plan(now, 'UTC');
      expect(
        jobs.any(
          (j) =>
              j['calendarEventId'] == recurring &&
              DateTime.fromMillisecondsSinceEpoch(
                    j['triggerAt'] as int,
                    isUtc: true,
                  ).year ==
                  2029,
        ),
        true,
      );
      expect(jobs.any((j) => j['calendarEventId'] == once), true);
    },
  );

  test(
    'calendar recurrence and exceptions sync in payloads and older payloads default safely',
    () async {
      final id = await db.calendarEventsDao.saveEvent(
        title: '서버 일정',
        startAt: DateTime.utc(2026, 10, 20, 9),
        settings: const CalendarScheduleSettings(
          every: 2,
          timeZone: 'Asia/Seoul',
        ),
      );
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-10-20',
        skipped: true,
      );
      final event = (await db.calendarEventsDao.getEvent(id))!;
      final payload = (await LocalSyncStore(
        db,
      ).buildPayload('calendar_events', event.uuid))!;
      expect(payload['schedule_data'], event.scheduleData);
      final second = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final store = LocalSyncStore(second);
        await store.applyRemotePage(
          entity: 'calendar_events',
          rows: [
            RemoteSyncRow(
              uuid: event.uuid,
              payload: payload,
              updatedAt: event.updatedAt,
              deletedAt: null,
              revision: 1,
            ),
          ],
          bootstrap: true,
        );
        expect(
          (await second.calendarEventsDao.listEvents()).single.scheduleData,
          event.scheduleData,
        );
        final legacy = {...payload}..remove('schedule_data');
        await store.applyRemotePage(
          entity: 'calendar_events',
          rows: [
            RemoteSyncRow(
              uuid: 'legacy-calendar',
              payload: legacy,
              updatedAt: event.updatedAt,
              deletedAt: null,
              revision: 2,
            ),
          ],
          bootstrap: false,
        );
        expect(
          (await second.calendarEventsDao.listEvents())
              .where((e) => e.uuid == 'legacy-calendar')
              .single
              .scheduleData,
          '{}',
        );
      } finally {
        await second.close();
      }
    },
  );

  test(
    'acknowledged calendar occurrences survive backup while device jobs are rebuilt',
    () async {
      final now = DateTime.utc(2026, 10, 16);
      final id = await db.calendarEventsDao.saveEvent(
        title: '확인한 일정',
        startAt: now.add(const Duration(hours: 1)),
        settings: const CalendarScheduleSettings(timeZone: 'UTC'),
        schedule: const NoteScheduleDraft(notificationEnabled: true),
      );
      await CalendarReminderStore(db).plan(now, 'UTC');
      await db.customStatement(
        "UPDATE calendar_occurrences SET status='completed' WHERE event_id=?",
        [id],
      );
      final backup = (await db.backupDao.exportBackup()).toJsonString();
      await db.backupDao.importBackup(parseBackup(backup).backup!);
      expect(
        await db.customSelect('SELECT * FROM calendar_jobs').get(),
        isEmpty,
      );
      expect(await CalendarReminderStore(db).plan(now, 'UTC'), isEmpty);
      expect(
        (await db.customSelect('SELECT status FROM calendar_occurrences').get())
            .single
            .read<String>('status'),
        'completed',
      );
    },
  );

  test(
    'monthly exceptions move across months, skip, restore, and retain later dates',
    () async {
      final id = await db.calendarEventsDao.saveEvent(
        title: '월세',
        startAt: DateTime.utc(2026, 1, 31, 0),
        settings: const CalendarScheduleSettings(timeZone: 'Asia/Seoul'),
        schedule: const NoteScheduleDraft(type: NoteScheduleType.monthly),
      );
      var event = (await db.calendarEventsDao.getEvent(id))!;
      expect(
        calendarOccurrencesByDate([event], '2026-02').keys,
        contains('2026-02-28'),
      );
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-02-28',
        startAt: DateTime.utc(2026, 3, 2, 0),
        title: '이번 달 월세',
      );
      event = (await db.calendarEventsDao.getEvent(id))!;
      expect(calendarOccurrencesByDate([event], '2026-02'), isEmpty);
      final march = calendarOccurrencesByDate([event], '2026-03');
      expect(march.keys, containsAll(['2026-03-02', '2026-03-31']));
      expect(march['2026-03-02']!.single.originalDate, '2026-02-28');
      expect(march['2026-03-02']!.single.title, '이번 달 월세');
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-03-31',
        skipped: true,
      );
      event = (await db.calendarEventsDao.getEvent(id))!;
      expect(
        calendarOccurrencesByDate([event], '2026-03').keys,
        isNot(contains('2026-03-31')),
      );
      expect(
        calendarOccurrencesByDate([event], '2026-04').keys,
        contains('2026-04-30'),
      );
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-03-31',
        restore: true,
      );
      event = (await db.calendarEventsDao.getEvent(id))!;
      expect(
        calendarOccurrencesByDate([event], '2026-03').keys,
        contains('2026-03-31'),
      );
      final backup = await db.backupDao.exportBackup();
      await db.backupDao.importBackup(
        parseBackup(backup.toJsonString()).backup!,
      );
      expect(
        (await db.calendarEventsDao.getEvent(id))!.scheduleData,
        event.scheduleData,
      );
    },
  );

  test('all-day dates stay civil and interval/end date apply', () async {
    final id = await db.calendarEventsDao.saveEvent(
      title: '보험 만기',
      startAt: DateTime(2026, 10, 20),
      allDay: true,
      settings: const CalendarScheduleSettings(
        timeZone: 'America/Los_Angeles',
        every: 2,
        until: '2027-02-20',
      ),
      schedule: const NoteScheduleDraft(type: NoteScheduleType.monthly),
    );
    var event = (await db.calendarEventsDao.getEvent(id))!;
    expect(calendarEventStart(event), DateTime(2026, 10, 20));
    final seoul = CalendarScheduleSettings(
      every: 2,
      until: '2027-02-20',
      timeZone: 'Asia/Seoul',
      allDayDate: '2026-10-20',
    );
    event = event.copyWith(scheduleData: seoul.encode());
    expect(
      calendarOccurrencesByDate([event], '2026-10').keys,
      contains('2026-10-20'),
    );
    expect(calendarOccurrencesByDate([event], '2026-11'), isEmpty);
    expect(
      calendarOccurrencesByDate([event], '2026-12').keys,
      contains('2026-12-20'),
    );
    expect(calendarOccurrencesByDate([event], '2027-04'), isEmpty);
  });

  test('timed daily repeats keep wall time over DST', () async {
    final id = await db.calendarEventsDao.saveEvent(
      title: '확인',
      startAt: DateTime.utc(2026, 3, 7, 14),
      settings: const CalendarScheduleSettings(timeZone: 'America/New_York'),
      schedule: const NoteScheduleDraft(type: NoteScheduleType.daily),
    );
    final event = (await db.calendarEventsDao.getEvent(id))!;
    final dates = calendarInstances(
      event,
      DateTime(2026, 3, 7),
      DateTime(2026, 3, 10),
    );
    expect(dates.map((d) => d.start.hour), everyElement(9));
    expect(dates[1].start.toUtc().hour, 13);
  });

  test(
    'calendar alarms share budget with notes, cancel stale generations and preserve snoozes',
    () async {
      final now = DateTime.utc(2026, 10, 16, 0);
      final id = await db.calendarEventsDao.saveEvent(
        title: '납부',
        startAt: now.add(const Duration(hours: 1)),
        settings: const CalendarScheduleSettings(timeZone: 'Asia/Seoul'),
        schedule: const NoteScheduleDraft(
          notificationEnabled: true,
          notificationLeadMinutes: [0, 30],
        ),
      );
      final note = await db.notesDao.saveNote(
        title: '메모 알림',
        content: '본문',
        schedule: NoteScheduleDraft(
          type: NoteScheduleType.once,
          oneTimeAt: now.add(const Duration(hours: 1)),
          notificationEnabled: true,
        ),
      );
      final planned = await ReminderStore(
        db,
      ).plan(await db.notesDao.listNotificationEntries(), now, 'Asia/Seoul');
      expect(planned.any((j) => j['noteId'] == note), isTrue);
      final calendar = planned
          .where((j) => j['calendarEventId'] == id)
          .toList();
      expect(calendar, hasLength(2));
      expect(
        calendar.every((j) => (j['jobId'] as int) < 0 && (j['id'] as int) < 0),
        isTrue,
      );
      final jobId = -(calendar.last['jobId'] as int);
      final snooze = now.add(const Duration(hours: 3)).millisecondsSinceEpoch;
      await db.customStatement(
        "UPDATE calendar_jobs SET state='pending',snoozed_until=? WHERE id=?",
        [snooze, jobId],
      );
      final replanned = await CalendarReminderStore(db).plan(now, 'Asia/Seoul');
      expect(
        replanned.singleWhere((j) => j['jobId'] == -jobId)['triggerAt'],
        snooze,
      );
      final oldGeneration = calendar.first['generation'] as int;
      await db.calendarEventsDao.saveOccurrence(
        id,
        '2026-10-16',
        skipped: true,
      );
      final cancelled = await CalendarReminderStore(db).plan(now, 'Asia/Seoul');
      expect(cancelled, isEmpty);
      final states = await db
          .customSelect('SELECT state,generation FROM calendar_jobs')
          .get();
      expect(
        states.every((r) => r.read<String>('state') == 'cancelled'),
        isTrue,
      );
      expect(
        states.every((r) => r.read<int>('generation') > oldGeneration),
        isTrue,
      );
      expect(await db.select(db.transactions).get(), isEmpty);
      final dispatched = await db
          .customSelect(
            "SELECT id FROM reminder_dispatch_jobs WHERE state IN ('pending','scheduled')",
          )
          .get();
      expect(dispatched.every((r) => r.read<int>('id') > 0), isTrue);
      await db.calendarEventsDao.deleteEvent(id);
      expect(
        await db.customSelect('SELECT * FROM calendar_jobs').get(),
        isEmpty,
      );
    },
  );

  test('old backups without scheduleData stay readable', () async {
    await db.calendarEventsDao.saveEvent(
      title: '기존',
      startAt: DateTime(2026, 10, 20),
    );
    final data =
        jsonDecode((await db.backupDao.exportBackup()).toJsonString())
            as Map<String, dynamic>;
    for (final event in data['data']['calendarEvents']) {
      (event as Map).remove('scheduleData');
    }
    final parsed = parseBackup(jsonEncode(data));
    expect(parsed.isOk, isTrue);
    expect(parsed.backup!.calendarEvents.single.scheduleData, '{}');
  });

  test(
    'v21 migration keeps notes and reminder IDs and freezes all-day dates',
    () async {
      final dir = await Directory.systemTemp.createTemp('calendar_v21_');
      final file = File('${dir.path}/db.sqlite');
      var old = AppDatabase.forTesting(NativeDatabase(file));
      final id = await old.calendarEventsDao.saveEvent(
        title: '기존 종일',
        startAt: DateTime(2026, 10, 20),
        allDay: true,
      );
      final note = await old.notesDao.saveNote(title: '보존', content: '본문');
      await old.customStatement('DROP TRIGGER calendar_event_reminder_update');
      await old.customStatement(
        'ALTER TABLE calendar_events DROP COLUMN schedule_data',
      );
      await old.customStatement('PRAGMA user_version=21');
      await old.close();
      old = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final event = (await old.calendarEventsDao.getEvent(id))!;
        expect(calendarEventStart(event), DateTime(2026, 10, 20));
        expect((await old.notesDao.getNote(note))!.content, '본문');
        expect(
          (await old.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty,
        );
      } finally {
        await old.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
