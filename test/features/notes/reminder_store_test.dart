import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/features/notes/checklist.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/features/notes/reminder_calendar.dart';
import 'package:my_little_budget/features/notes/reminder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();

  test('월말은 원래 기준일로 돌아오고 윤년 날짜도 복원된다', () {
    final monthly = reminderResets(
      const NoteScheduleDraft(
        type: NoteScheduleType.monthly,
        resetTime: '09:00',
        dayOfMonth: 31,
      ),
      tz.UTC,
      DateTime.utc(2027, 1, 31, 10),
      anchor: DateTime.utc(2027, 1, 31),
      count: 3,
    );
    expect(monthly.map((d) => d.day).take(3), [31, 28, 31]);
    final yearly = reminderResets(
      const NoteScheduleDraft(
        type: NoteScheduleType.yearly,
        resetTime: '09:00',
        dayOfMonth: 29,
      ),
      tz.UTC,
      DateTime.utc(2027, 1),
      anchor: DateTime.utc(2024, 2, 29),
      count: 3,
    );
    expect(yearly.where((d) => d.year == 2027).single.day, 28);
    expect(yearly.where((d) => d.year == 2028).single.day, 29);
  });

  test('DST 결손은 다음 유효 분, 중복은 첫 번째 시각이다', () {
    final zone = tz.getLocation('America/New_York');
    final gap = reminderWallTime(zone, DateTime.utc(2026, 3, 8), 2, 30);
    expect([gap.hour, gap.minute], [3, 0]);
    final fold = reminderWallTime(zone, DateTime.utc(2026, 11, 1), 1, 30);
    expect(fold.toUtc(), DateTime.utc(2026, 11, 1, 5, 30));
  });

  test('2주 월·수와 2개월 간격은 기준 주·월을 유지하고 종료일을 포함한다', () {
    final weekly = reminderResets(
      const NoteScheduleDraft(
        type: NoteScheduleType.weekly,
        resetTime: '09:00',
        weekdays: [1, 3],
      ),
      tz.UTC,
      DateTime.utc(2026, 10, 5),
      anchor: DateTime.utc(2026, 10, 5),
      every: 2,
      count: 4,
      until: DateTime.utc(2026, 10, 21),
    );
    expect(weekly.where((d)=>!d.isBefore(DateTime.utc(2026,10,5))).map(noteDateKey), [
      '2026-10-05',
      '2026-10-07',
      '2026-10-19',
      '2026-10-21',
    ]);
    final monthly = reminderResets(
      const NoteScheduleDraft(
        type: NoteScheduleType.monthly,
        resetTime: '09:00',
        dayOfMonth: 31,
      ),
      tz.UTC,
      DateTime.utc(2026, 1, 1),
      anchor: DateTime.utc(2026, 1, 31),
      every: 2,
      count: 3,
    );
    expect(
      monthly
          .where((d) => d.isAfter(DateTime.utc(2026, 1, 1)))
          .take(3)
          .map((d) => d.month),
      [1, 3, 5],
    );
  });

  group('SQLite 예약', () {
    late AppDatabase db;
    late ReminderStore store;
    final now = DateTime.utc(2026, 10, 15, 12);
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      store = ReminderStore(db);
    });
    tearDown(() => db.close());
    Future<int> create() => db.notesDao.saveNote(
      title: '할 일',
      content: '',
      schedule: NoteScheduleDraft(
        type: NoteScheduleType.once,
        oneTimeAt: now.add(const Duration(hours: 1)),
        notificationEnabled: true,
      ),
    );
    Future<List<Map<String, Object?>>> plan() async =>
        store.plan(await db.notesDao.listNotificationEntries(), now, 'UTC');

    test('목록 순서가 바뀌어도 ID 유지, 미루기는 재조정 후 보존', () async {
      await create();
      final first = (await plan()).single;
      await db.customStatement(
        'UPDATE reminder_jobs SET snoozed_until=? WHERE id=?',
        [
          now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
          first['jobId'],
        ],
      );
      await create();
      final jobs = await plan();
      final same = jobs.singleWhere((j) => j['jobId'] == first['jobId']);
      expect(same['id'], first['id']);
      expect(same['generation'], first['generation']);
      expect(
        same['triggerAt'],
        now.add(const Duration(hours: 2)).millisecondsSinceEpoch,
      );
    });

    test('메모 수정은 커밋 시 구세대 무효화, 새 예약은 같은 ID', () async {
      final id = await create();
      final first = (await plan()).single;
      await db.customStatement('UPDATE notes SET title=? WHERE id=?', [
        '수정',
        id,
      ]);
      final row = await db
          .customSelect('SELECT * FROM reminder_jobs')
          .getSingle();
      expect(row.read<String>('state'), 'cancelled');
      final second = (await plan()).single;
      expect(second['id'], first['id']);
      expect(
        second['generation'] as int,
        greaterThan(first['generation'] as int),
      );
      expect(second['title'], '수정');
    });

    test('오늘 체크리스트 완료가 내일 회차 알림을 없애지 않는다', () async {
      final id = await db.notesDao.saveNote(
        title: '매일',
        content: '',
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.daily,
          resetTime: '09:00',
          notificationEnabled: true,
          notificationTime: '13:00',
        ),
        checklistItems: const [ChecklistItemDraft(text: '확인', isChecked: true)],
      );
      final entry = (await db.notesDao.getNoteWithChecklist(id))!;
      await store.captureCurrent(entry, now, deviceZone: 'UTC');
      final jobs = await plan();
      expect(jobs, isNotEmpty);
      expect(
        jobs.every(
          (j) =>
              (j['triggerAt'] as int) >
              DateTime.utc(2026, 10, 16).millisecondsSinceEpoch,
        ),
        isTrue,
      );
      final completed = await db
          .customSelect(
            "SELECT * FROM reminder_occurrences WHERE status='completed'",
          )
          .get();
      expect(completed, isNotEmpty);
    });

    test('완료 취소는 과거 알림을 재발송하지 않는다', () async {
      final id = await create();
      await plan();
      final entry = (await db.notesDao.getNoteWithChecklist(id))!;
      await store.captureCurrent(entry, now, completed: true);
      expect(await plan(), isEmpty);
      final later = now.add(const Duration(days: 1));
      await store.captureCurrent(entry, later, completed: false);
      expect(
        await store.plan(
          await db.notesDao.listNotificationEntries(),
          later,
          'UTC',
        ),
        isEmpty,
      );
    });

    test('삭제 후 예약 행이 남지 않고 같은 ID가 재사용되지 않는다', () async {
      final id = await create();
      final first = (await plan()).single;
      await db.notesDao.deleteNote(id);
      expect(
        await db.customSelect('SELECT * FROM reminder_jobs').get(),
        isEmpty,
      );
      await create();
      expect((await plan()).single['jobId'], isNot(first['jobId']));
    });

    test('오래 지난 예약은 missed, 실패 예약은 재시도 의도 유지', () async {
      await create();
      await plan();
      await db.customStatement(
        "UPDATE reminder_jobs SET state='failed',last_error='test'",
      );
      expect((await plan()).length, 1);
      await store.plan(
        await db.notesDao.listNotificationEntries(),
        now.add(const Duration(days: 2)),
        'UTC',
      );
      expect(
        (await db.customSelect('SELECT state FROM reminder_jobs').getSingle())
            .read<String>('state'),
        'missed',
      );
    });

    test('이미 처리된 알림은 rebuild로 되살리지 않는다', () async {
      await create();
      await plan();
      await db.customStatement("UPDATE reminder_jobs SET state='dismissed'");
      expect(await plan(), isEmpty);
      final row = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM reminder_jobs',
            variables: <Variable>[],
          )
          .getSingle();
      expect(row.read<int>('n'), 1);
    });

    test('마감일만 저장하면 알림을 생성하지 않고 백업에서 보존한다', () async {
      final id = await db.notesDao.saveNote(title: '마감만', content: '');
      await store.saveOptions(
        id,
        const ReminderOptions(dueDate: '2026-10-31', timeZone: 'Asia/Seoul'),
      );
      expect(await plan(), isEmpty);
      final backup = await db.backupDao.exportBackup();
      await db.backupDao.importBackup(backup);
      expect((await store.options(id)).dueDate, '2026-10-31');
      expect((await store.options(id)).timeZone, 'Asia/Seoul');
    });

    test('종료일 뒤에는 예약하지 않으며 일반 알림 선택을 payload에 반영한다', () async {
      final id = await db.notesDao.saveNote(
        title: '반복',
        content: '',
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.daily,
          resetTime: '09:00',
          notificationTime: '13:00',
          notificationEnabled: true,
        ),
      );
      await store.saveOptions(
        id,
        const ReminderOptions(until: '2026-10-16', timeZone: 'UTC'),
      );
      final jobs = await plan();
      expect(jobs, isNotEmpty);
      expect(jobs.every((j) => j['alarmMode'] == false), isTrue);
      expect(
        jobs.every(
          (j) =>
              (j['triggerAt'] as int) <
              DateTime.utc(2026, 10, 17).millisecondsSinceEpoch,
        ),
        isTrue,
      );
    });

    test('체크리스트 없는 할 일도 완료·완료 취소할 수 있다', () async {
      final id = await create();
      await db.notesDao.setOccurrenceCompleted(id, true);
      expect(await plan(), isEmpty);
      await db.notesDao.setOccurrenceCompleted(id, false);
      expect((await plan()).length, 1);
    });
  });
}
