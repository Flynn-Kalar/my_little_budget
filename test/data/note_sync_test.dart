import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_incremental_sync_service.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/notes/checklist.dart';
import 'package:my_little_budget/features/notes/note_alarm.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/features/notes/reminder_store.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late AppDatabase a, b;
  late LocalSyncStore sa, sb;
  setUp(() async {
    a = AppDatabase.forTesting(NativeDatabase.memory());
    b = AppDatabase.forTesting(NativeDatabase.memory());
    sa = LocalSyncStore(a);
    sb = LocalSyncStore(b);
    await a.customSelect('SELECT 1').get();
    await b.customSelect('SELECT 1').get();
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  Future<void> transfer(
    AppDatabase source,
    LocalSyncStore from,
    LocalSyncStore to,
    String uuid,
    int revision,
  ) async {
    final entry = await from.currentEntry('notes', uuid);
    expect(entry, isNotNull);
    final payload = await from.buildPayload('notes', uuid);
    await from.acknowledge(entry!);
    await to.applyRemotePage(
      entity: 'notes',
      rows: [
        RemoteSyncRow(
          uuid: uuid,
          payload: payload ?? {},
          updatedAt: DateTime.now().toUtc().toIso8601String(),
          deletedAt: entry.isDelete
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          revision: revision,
        ),
      ],
      bootstrap: false,
    );
  }

  test(
    'two devices sync rich notes, goals, checklist changes and deletion without copying alarms',
    () async {
      final remote = _MemoryServer();
      final ca = SupabaseIncrementalSyncService(local: sa, remote: remote);
      final cb = SupabaseIncrementalSyncService(local: sb, remote: remote);
      const settings = SupabaseBackupSettings(
        url: 'https://example.supabase.co',
        anonKey: 'publishable-key',
        authEmail: 'owner@example.com',
        bucket: 'backups',
      );
      final date = DateTime.now().add(const Duration(days: 5));
      final id = await a.notesDao.saveNote(
        title: '함께 보는 메모',
        content: '본문',
        richContent: '[{"insert":"본문\\n"}]',
        pinned: true,
        amountGoal: Value(
          NoteAmountGoal(
            targetAmount: 100000,
            currentAmount: 30000,
            startDate: DateTime(2026, 10, 1),
          ),
        ),
        showOnCalendar: true,
        schedule: NoteScheduleDraft(
          type: NoteScheduleType.once,
          oneTimeAt: date,
          notificationEnabled: true,
          notificationLeadMinutes: const [30],
          snoozeMinutes: 15,
        ),
        alarmSettings: const NoteAlarmSettings(
          soundKind: NoteAlarmSoundKind.custom,
          soundUri: 'content://private/audio',
          soundName: '내 알림',
          vibrationEnabled: false,
        ),
        checklistItems: const [
          ChecklistItemDraft(text: '준비'),
          ChecklistItemDraft(text: '확인', isChecked: true),
        ],
      );
      final uuid = (await a.notesDao.getNote(id))!.uuid;
      expect((await ca.synchronize(settings)).isOk, isTrue);
      expect((await cb.synchronize(settings)).isOk, isTrue);
      final received = (await b.notesDao.listNotes()).single;
      expect(received.uuid, uuid);
      expect(received.content, '본문');
      expect(received.richContent, '[{"insert":"본문\\n"}]');
      expect(received.pinned, isTrue);
      expect(received.goalTargetAmount, 100000);
      expect(received.goalCurrentAmount, 30000);
      expect(received.showOnCalendar, isTrue);
      expect(received.reminderAt, date.toUtc().toIso8601String());
      expect(received.notificationEnabled, isFalse);
      expect(received.notificationLeadMinutes, '');
      expect(received.alarmSoundUri, isNull);
      final items = (await b.notesDao.getNoteWithChecklist(received.id))!.items;
      expect(items.map((i) => i.isChecked), [false, true]);
      final payload = await sa.buildPayload('notes', uuid);
      expect(
        payload!.keys.any(
          (k) =>
              k.contains('notification') ||
              k.contains('alarm') ||
              k == 'snooze_minutes',
        ),
        isFalse,
      );
      expect(payload.containsKey('next_reset_at'), isFalse);
      await b.notesDao.toggleChecklistItem(items.first.id, true);
      expect((await cb.synchronize(settings)).isOk, isTrue);
      expect((await ca.synchronize(settings)).isOk, isTrue);
      final source = (await a.notesDao.getNoteWithChecklist(id))!;
      expect(source.items.every((i) => i.isChecked), isTrue);
      expect(source.note.notificationEnabled, isTrue);
      expect(source.note.notificationLeadMinutes, '30');
      expect(source.note.alarmSoundUri, 'content://private/audio');
      await b.notesDao.deleteNote(received.id);
      expect((await cb.synchronize(settings)).isOk, isTrue);
      expect((await ca.synchronize(settings)).isOk, isTrue);
      expect(await a.notesDao.getNote(id), isNull);
      expect(await a.select(a.noteChecklistItems).get(), isEmpty);
    },
  );

  test(
    'alarm-only edits stay local and content updates preserve every receiving alarm preference',
    () async {
      final id = await a.notesDao.saveNote(
        title: '매일 확인',
        content: '원본',
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.daily,
          resetTime: '00:00',
        ),
      );
      await ReminderStore(a).saveOptions(
        id,
        const ReminderOptions(
          every: 3,
          timeZone: 'Asia/Seoul',
          until: '2030-12-31',
          alarmMode: true,
        ),
      );
      final uuid = (await a.notesDao.getNote(id))!.uuid;
      await transfer(a, sa, sb, uuid, 1);
      final received = (await b.notesDao.listNotes()).single;
      await (b.update(b.notes)..where((n) => n.id.equals(received.id))).write(
        const NotesCompanion(
          notificationEnabled: Value(true),
          notificationTime: Value('08:25'),
          notificationDaysBefore: Value(2),
          notificationExtraDaysBefore: Value('1,3'),
          notificationLeadMinutes: Value('10'),
          snoozeMinutes: Value(20),
          alarmSoundKind: Value('custom'),
          alarmSoundUri: Value('device://own'),
          alarmSoundName: Value('내 소리'),
          alarmClipStartMs: Value(1000),
          alarmClipEndMs: Value(4000),
          alarmVibrationEnabled: Value(false),
        ),
      );
      await b.customStatement(
        'UPDATE reminder_series SET alarm_mode=1 WHERE note_id=?',
        [received.id],
      );
      expect(await sb.currentEntry('notes', uuid), isNull);
      final before = await b.notesDao.getNote(received.id);
      await a.notesDao.saveNote(
        id: id,
        title: '수정한 메모',
        content: '새 내용',
        schedule: const NoteScheduleDraft(
          type: NoteScheduleType.daily,
          resetTime: '00:00',
        ),
      );
      await transfer(a, sa, sb, uuid, 2);
      final after = (await b.notesDao.getNote(received.id))!;
      expect(after.title, '수정한 메모');
      for (final key in before!.toJson().keys.where(
        (k) =>
            k.startsWith('notification') ||
            k.startsWith('alarm') ||
            k == 'snoozeMinutes',
      )) {
        expect(after.toJson()[key], before.toJson()[key], reason: key);
      }
      final options = await ReminderStore(b).options(received.id);
      expect(options.every, 3);
      expect(options.until, '2030-12-31');
      expect(options.alarmMode, isTrue);
      expect(await sb.currentEntry('notes', uuid), isNull);
      await b.notesDao.setPinned(received.id, true);
      expect(await sb.currentEntry('notes', uuid), isNotNull);
    },
  );

  test(
    'malformed remote checklist rolls back note and cursor; incoming alarm fields are ignored',
    () async {
      final id = await a.notesDao.saveNote(
        title: '원본',
        content: '보존',
        checklistItems: const [ChecklistItemDraft(text: '원래 항목')],
      );
      final uuid = (await a.notesDao.getNote(id))!.uuid;
      await transfer(a, sa, sb, uuid, 1);
      final payload = (await sa.buildPayload('notes', uuid))!;
      RemoteSyncRow row(Map<String, Object?> data) => RemoteSyncRow(
        uuid: uuid,
        payload: data,
        updatedAt: '2026-10-21T12:00:00Z',
        deletedAt: null,
        revision: 2,
      );
      await expectLater(
        sb.applyRemotePage(
          entity: 'notes',
          rows: [
            row({
              ...payload,
              'title': '잘못된 변경',
              'checklist_items': [
                {'text': 123},
              ],
            }),
          ],
          bootstrap: false,
        ),
        throwsFormatException,
      );
      final received = (await b.notesDao.listNotes()).single;
      expect(received.title, '원본');
      expect(
        (await b.notesDao.getNoteWithChecklist(
          received.id,
        ))!.items.single.itemText,
        '원래 항목',
      );
      expect(await sb.cursor('notes'), 1);
      await sb.applyRemotePage(
        entity: 'notes',
        rows: [
          row({
            ...payload,
            'notification_enabled': true,
            'alarm_sound_uri': 'foreign://audio',
            'snooze_minutes': 9,
          }),
        ],
        bootstrap: false,
      );
      final after = (await b.notesDao.getNote(received.id))!;
      expect(after.notificationEnabled, isFalse);
      expect(after.alarmSoundUri, isNull);
      expect(after.snoozeMinutes, 0);
    },
  );

  test(
    'legacy backups receive UUIDs while retaining local alarm settings',
    () async {
      final id = await a.notesDao.saveNote(
        title: '이전 백업',
        content: '내용',
        reminderAt: DateTime.now().add(const Duration(days: 1)),
      );
      final backup = (await a.backupDao.exportBackup()).toJson();
      final data = backup['data']! as Map<String, Object?>;
      final notes = data['notes']! as List;
      (notes.single as Map).remove('uuid');
      (notes.single as Map).remove('syncStatus');
      final parsed = parseBackup(const JsonEncoder().convert(backup));
      expect(parsed.isOk, isTrue);
      expect(parsed.backup!.notes.single.uuid, isNotEmpty);
      expect(parsed.backup!.notes.single.notificationEnabled, isTrue);
      expect((await a.notesDao.getNote(id))!.notificationEnabled, isTrue);
    },
  );

  test(
    'derived reset and alarm writes do not supersede an in-flight note upload',
    () async {
      final id = await a.notesDao.saveNote(title: '전송 중', content: '내용');
      final uuid = (await a.notesDao.getNote(id))!.uuid;
      final entry = (await sa.currentEntry('notes', uuid))!;
      await (a.update(a.notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(nextResetAt: Value('2030-01-01T00:00:00Z')),
      );
      await (a.update(a.notes)..where((n) => n.id.equals(id))).write(
        const NotesCompanion(
          notificationEnabled: Value(true),
          notificationTime: Value('09:00'),
          snoozeMinutes: Value(10),
        ),
      );
      expect(
        (await sa.currentEntry('notes', uuid))!.generation,
        entry.generation,
      );
      expect(await sa.acknowledge(entry), isTrue);
      await a.notesDao.setPinned(id, true);
      expect(await sa.currentEntry('notes', uuid), isNotNull);
    },
  );

  test(
    'v24 migration preserves notes, checklist IDs and device alarms while enqueuing notes',
    () async {
      final columns = await a.customSelect('PRAGMA table_info(notes)').get();
      final definitions = columns
          .where(
            (c) => ![
              'uuid',
              'deleted_at',
              'sync_status',
            ].contains(c.read<String>('name')),
          )
          .map((c) {
            final name = c.read<String>('name'), type = c.read<String>('type');
            final defaultValue = c.readNullable<String>('dflt_value');
            return '"$name" $type ${c.read<int>('pk') == 1
                ? 'PRIMARY KEY'
                : c.read<int>('notnull') == 1
                ? 'NOT NULL'
                : ''}${defaultValue == null ? '' : ' DEFAULT ($defaultValue)'}';
          })
          .join(',');
      final checklistSql =
          (await a
                  .customSelect(
                    "SELECT sql FROM sqlite_master WHERE name='note_checklist_items'",
                  )
                  .getSingle())
              .read<String>('sql');
      final upgraded = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('CREATE TABLE notes ($definitions)');
            raw.execute(checklistSql);
            raw.execute(
              "INSERT INTO notes(id,title,content,notification_enabled,notification_time,alarm_sound_uri,alarm_vibration_enabled) VALUES(42,'이전 메모','기존 내용',1,'08:00','device://kept',0)",
            );
            raw.execute(
              "INSERT INTO note_checklist_items(id,note_id,text,is_checked) VALUES(17,42,'기존 체크',1)",
            );
            raw.execute('PRAGMA user_version=24');
          },
        ),
      );
      try {
        final migrated = (await upgraded.notesDao.getNoteWithChecklist(42))!;
        expect(migrated.note.uuid, isNotEmpty);
        expect(migrated.note.content, '기존 내용');
        expect(migrated.note.notificationEnabled, isTrue);
        expect(migrated.note.notificationTime, '08:00');
        expect(migrated.note.alarmSoundUri, 'device://kept');
        expect(migrated.note.alarmVibrationEnabled, isFalse);
        expect(migrated.items.single.id, 17);
        expect(migrated.items.single.isChecked, isTrue);
        expect(
          await LocalSyncStore(
            upgraded,
          ).currentEntry('notes', migrated.note.uuid),
          isNotNull,
        );
      } finally {
        await upgraded.close();
      }
    },
  );
}

class _MemoryServer implements SupabaseSyncGateway {
  final rows = <String, Map<String, RemoteSyncRow>>{};
  int revision = 0;
  @override
  Future<List<RemoteSyncRow>> fetchChanges({
    required SupabaseBackupSettings settings,
    required String entity,
    required int afterRevision,
    required int limit,
  }) async =>
      ((rows[entity]?.values ?? [])
              .where((r) => r.revision > afterRevision)
              .toList()
            ..sort((a, b) => a.revision.compareTo(b.revision)))
          .take(limit)
          .toList();
  @override
  Future<RemoteSyncRow> upsert({
    required SupabaseBackupSettings settings,
    required String entity,
    required String uuid,
    required Map<String, Object?> payload,
    required String? deletedAt,
  }) async {
    final row = RemoteSyncRow(
      uuid: uuid,
      payload: payload,
      updatedAt: DateTime.now().toUtc().toIso8601String(),
      deletedAt: deletedAt,
      revision: ++revision,
    );
    (rows[entity] ??= {})[uuid] = row;
    return row;
  }
}
