import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database.dart';
import '../../data/daos/notes_dao.dart';
import 'checklist.dart';
import 'note_alarm.dart';
import 'note_schedule.dart';
import 'reminder_calendar.dart';
import '../calendar/calendar_reminder_store.dart';

class ReminderOptions {
  const ReminderOptions({
    this.dueDate,
    this.every = 1,
    this.until,
    this.timeZone,
    this.alarmMode = false,
    this.anchorDate,
  });
  final String? dueDate;
  final int every;
  final String? until;
  final String? timeZone;
  final bool alarmMode;
  final String? anchorDate;
}

/// Durable scheduling intent. Native Android reads these same tables when the
/// Flutter engine is absent; it never creates or migrates the application DB.
class ReminderStore {
  ReminderStore(this.db) {
    if (!_zonesReady) {
      tzdata.initializeTimeZones();
      _zonesReady = true;
    }
  }
  static bool _zonesReady = false;
  final AppDatabase db;
  Future<void> prepareSeries(List<Note> notes, String deviceZone) async {
    for (final note in notes) {
      if (note.scheduleType != 'none') await _series(note, deviceZone);
    }
  }

  tz.Location _zone(String name) =>
      name == 'UTC' ? tz.UTC : tz.getLocation(name);
  String? validateOptions(ReminderOptions value) {
    if (value.every < 1 || value.every > 365) return '반복 간격은 1~365입니다.';
    for (final date in [value.dueDate, value.until]) {
      if (date != null && parseNoteDate(date) == null) return '올바른 날짜를 입력하세요.';
    }
    try {
      if (value.timeZone != null) _zone(value.timeZone!);
    } catch (_) {
      return '시간대는 Asia/Seoul 같은 IANA 이름으로 입력하세요.';
    }
    return null;
  }

  Future<(tz.Location, DateTime)> _series(Note note, String deviceZone) async {
    final existing = await db
        .customSelect(
          'SELECT * FROM reminder_series WHERE note_id=?',
          variables: [Variable(note.id)],
        )
        .getSingleOrNull();
    if (existing != null) {
      return (
        _zone(existing.read<String>('time_zone')),
        parseNoteDate(note.anchorDate ?? existing.read<String>('anchor_date'))!,
      );
    }
    if (deviceZone.isEmpty) {
      // Do not invoke platform channels while holding a SQLite transaction.
      // Android's UI/notification adapter supplies the IANA zone explicitly.
      final hours = DateTime.now().timeZoneOffset.inHours;
      deviceZone = hours == 0
          ? 'UTC'
          : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
    }
    final created = DateTime.tryParse(note.createdAt) ?? DateTime.now();
    final initialZone = _zone(deviceZone);
    final anchor =
        parseNoteDate(note.anchorDate) ??
        tz.TZDateTime.from(created, initialZone);
    await db.customStatement(
      'INSERT OR IGNORE INTO reminder_series(note_id,time_zone,anchor_date) VALUES (?, ?, ?)',
      [note.id, deviceZone, noteDateKey(anchor)],
    );
    final row = await db
        .customSelect(
          'SELECT * FROM reminder_series WHERE note_id=?',
          variables: [Variable(note.id)],
        )
        .getSingle();
    return (
      _zone(row.read<String>('time_zone')),
      parseNoteDate(note.anchorDate ?? row.read<String>('anchor_date'))!,
    );
  }

  Future<ReminderOptions> options(int noteId) async {
    final row = await db
        .customSelect(
          'SELECT * FROM reminder_series WHERE note_id=?',
          variables: [Variable(noteId)],
        )
        .getSingleOrNull();
    if (row == null) return const ReminderOptions();
    return ReminderOptions(
      dueDate: row.readNullable<String>('due_date'),
      every: row.read<int>('repeat_every'),
      until: row.readNullable<String>('until_date'),
      timeZone: row.read<String>('time_zone'),
      alarmMode: row.read<int>('alarm_mode') != 0,
      anchorDate: row.read<String>('anchor_date'),
    );
  }

  Future<void> saveOptions(int noteId, ReminderOptions options) =>
      db.transaction(() async {
        if (options.every < 1 || options.every > 365) {
          throw ArgumentError('반복 간격은 1~365입니다.');
        }
        for (final date in [options.dueDate, options.until]) {
          if (date != null && parseNoteDate(date) == null) {
            throw ArgumentError('올바른 날짜를 입력하세요.');
          }
        }
        if (options.timeZone != null) _zone(options.timeZone!);
        final entry = await db.notesDao.getNoteWithChecklist(noteId);
        if (entry == null) return;
        await _series(entry.note, '');
        await db.customStatement(
          '''UPDATE reminder_series SET due_date=?,repeat_every=?,
      until_date=?,time_zone=COALESCE(?,time_zone),alarm_mode=? WHERE note_id=?''',
          [
            options.dueDate,
            options.every,
            options.until,
            options.timeZone,
            options.alarmMode ? 1 : 0,
            noteId,
          ],
        );
        await db.customStatement(
          '''UPDATE reminder_jobs SET state='cancelled',generation=generation+1
      WHERE occurrence_id IN (SELECT id FROM reminder_occurrences WHERE note_id=?)''',
          [noteId],
        );
        final next = await nextReset(entry.note, DateTime.now());
        await (db.update(db.notes)..where((n) => n.id.equals(noteId))).write(
          NotesCompanion(nextResetAt: Value(next?.toUtc().toIso8601String())),
        );
      });

  Future<int> _occurrence(Note note, DateTime at) async {
    // The civil date identifies a repeating occurrence; alarm time edits keep it.
    final key = note.scheduleType == 'once'
        ? 'once:${note.reminderAt}'
        : noteDateKey(at);
    final template = await (db.select(
      db.noteChecklistItems,
    )..where((i) => i.noteId.equals(note.id))).get();
    final snapshot = jsonEncode(
      template
          .map((i) => {'id': i.id, 'text': i.itemText, 'checked': false})
          .toList(),
    );
    await db.customStatement(
      '''INSERT OR IGNORE INTO reminder_occurrences
      (note_id, occurrence_key, scheduled_at,checklist_json) VALUES (?, ?, ?, ?)''',
      [note.id, key, at.millisecondsSinceEpoch, snapshot],
    );
    await db.customStatement(
      '''UPDATE reminder_occurrences SET scheduled_at=?
      WHERE note_id=? AND occurrence_key=? AND status='pending' ''',
      [at.millisecondsSinceEpoch, note.id, key],
    );
    return (await db
            .customSelect(
              '''SELECT id FROM reminder_occurrences
      WHERE note_id=? AND occurrence_key=?''',
              variables: [Variable(note.id), Variable(key)],
            )
            .getSingle())
        .read<int>('id');
  }

  /// Called in the same transaction as checklist edits and before legacy reset.
  Future<void> captureCurrent(
    NoteWithChecklist entry,
    DateTime now, {
    String deviceZone = '',
    bool? completed,
  }) async {
    final note = entry.note;
    final schedule = noteScheduleFromNote(note);
    if (schedule.type == NoteScheduleType.none) return;
    final (zone, anchor) = await _series(note, deviceZone);
    final config = await options(note.id);
    final dates = schedule.type == NoteScheduleType.once
        ? [if (schedule.oneTimeAt != null) schedule.oneTimeAt!]
        : reminderResets(
            schedule,
            zone,
            now,
            anchor: anchor,
            count: 1,
            every: config.every,
            until: parseNoteDate(config.until),
          );
    if (dates.isEmpty) return;
    final id = await _occurrence(note, dates.first);
    final previous = await db
        .customSelect(
          'SELECT status FROM reminder_occurrences WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingle();
    final done =
        completed ??
        (previous.read<String>('status') == 'completed' ||
            (entry.hasChecklist ? entry.isChecklistComplete : note.completed));
    final snapshot = jsonEncode(
      entry.items
          .map(
            (i) => {
              'id': i.id,
              'text': i.itemText,
              'checked': done || i.isChecked,
            },
          )
          .toList(),
    );
    await db.customStatement(
      '''UPDATE reminder_occurrences SET status=?,
      completed_at=CASE WHEN status=? THEN completed_at ELSE ? END,
      checklist_json=? WHERE id=? AND status<>'skipped' ''',
      [
        done ? 'completed' : 'pending',
        done ? 'completed' : 'pending',
        done ? now.millisecondsSinceEpoch : null,
        snapshot,
        id,
      ],
    );
    if (done) {
      await db.customStatement(
        '''UPDATE reminder_jobs SET state='cancelled',
        generation=generation+1 WHERE occurrence_id=? AND state<>'cancelled' ''',
        [id],
      );
    }
  }

  Future<DateTime?> nextReset(Note note, DateTime now) async {
    final (zone, anchor) = await _series(note, '');
    final config = await options(note.id);
    return reminderResets(
      noteScheduleFromNote(note),
      zone,
      now,
      anchor: anchor,
      count: 1,
      every: config.every,
      until: parseNoteDate(config.until),
    ).where((d) => d.isAfter(now)).firstOrNull;
  }

  Future<void> setOccurrenceStatus(
    int id,
    String status,
  ) => db.transaction(() async {
    if (!['pending', 'completed', 'skipped'].contains(status)) {
      throw ArgumentError(status);
    }
    final row = await db
        .customSelect(
          'SELECT * FROM reminder_occurrences WHERE id=?',
          variables: [Variable(id)],
        )
        .getSingleOrNull();
    if (row == null) return;
    final noteId = row.read<int>('note_id');
    final current = await db
        .customSelect(
          '''SELECT id FROM reminder_occurrences
      WHERE note_id=? AND scheduled_at<=? ORDER BY scheduled_at DESC LIMIT 1''',
          variables: [
            Variable(noteId),
            Variable(DateTime.now().millisecondsSinceEpoch),
          ],
        )
        .getSingleOrNull();
    if (current?.read<int>('id') == id) {
      await db.notesDao.setOccurrenceCompleted(noteId, status == 'completed');
    }
    await db.customStatement(
      'UPDATE reminder_occurrences SET status=?,completed_at=? WHERE id=?',
      [
        status,
        status == 'completed' ? DateTime.now().millisecondsSinceEpoch : null,
        id,
      ],
    );
    if (status != 'pending') {
      await db.customStatement(
        "UPDATE reminder_jobs SET state='cancelled',generation=generation+1 WHERE occurrence_id=?",
        [id],
      );
    }
  });

  Future<List<Map<String, Object?>>> plan(
    List<NoteWithChecklist> entries,
    DateTime now,
    String deviceZone,
  ) => db.transaction(() async {
    final wanted = <int>{};
    for (final supplied in entries) {
      final entry = await db.notesDao.getNoteWithChecklist(supplied.note.id);
      if (entry == null) continue;
      final note = entry.note;
      final schedule = noteScheduleFromNote(note);
      if (!note.notificationEnabled || schedule.type == NoteScheduleType.none) {
        continue;
      }
      await captureCurrent(entry, now, deviceZone: deviceZone);
      final (zone, anchor) = await _series(note, deviceZone);
      final config = await options(note.id);
      final lead = schedule.notificationDaysBeforeValues.lastOrNull ?? 0;
      final extra = lead == 0
          ? 0
          : switch (schedule.type) {
              NoteScheduleType.yearly => lead ~/ 365 + 2,
              NoteScheduleType.monthly => lead ~/ 28 + 2,
              NoteScheduleType.interval =>
                lead ~/ (schedule.intervalDays ?? 1).clamp(1, 365) + 2,
              NoteScheduleType.daily => lead + 2,
              _ => lead * schedule.effectiveWeekdays.length ~/ 7 + 2,
            };
      final dates = schedule.type == NoteScheduleType.once
          ? [if (schedule.oneTimeAt != null) schedule.oneTimeAt!]
          : reminderResets(
              schedule,
              zone,
              now,
              anchor: anchor,
              every: config.every,
              count: 30 + extra,
              until: parseNoteDate(config.until),
            );
      for (final date in dates) {
        final occurrenceId = await _occurrence(note, date);
        final occurrence = await db
            .customSelect(
              'SELECT status FROM reminder_occurrences WHERE id=?',
              variables: [Variable(occurrenceId)],
            )
            .getSingle();
        if (occurrence.read<String>('status') != 'pending') continue;
        final times = <String, DateTime>{};
        if (schedule.type == NoteScheduleType.once) {
          for (final minutes in schedule.notificationLeadMinuteValues) {
            times['minutes:$minutes'] = date.subtract(
              Duration(minutes: minutes),
            );
          }
        } else {
          final clock = parseNoteTime(schedule.notificationTime);
          if (clock == null) continue;
          for (final days in schedule.notificationDaysBeforeValues) {
            times['days:$days'] = reminderWallTime(
              zone,
              DateTime.utc(date.year, date.month, date.day - days),
              clock.$1,
              clock.$2,
            );
          }
        }
        final alarm = noteAlarmSettingsFromNote(note);
        for (final item in times.entries) {
          final payload = jsonEncode({
            'noteId': note.id,
            'occurrenceId': occurrenceId,
            'title': note.title,
            'alarmMode': config.alarmMode,
            'triggerAt': item.value.millisecondsSinceEpoch,
            'soundKind': alarm.soundKind.name,
            'soundUri': alarm.soundUri,
            'clipStartMs': alarm.clipStartMs,
            'clipEndMs': alarm.clipEndMs,
            'vibrationEnabled': alarm.vibrationEnabled,
            'snoozeMinutes': alarm.snoozeMinutes > 0 ? alarm.snoozeMinutes : 10,
          });
          await db.customStatement(
            '''INSERT OR IGNORE INTO reminder_jobs
            (occurrence_id, rule_key, fire_at, payload) VALUES (?, ?, ?, ?)''',
            [
              occurrenceId,
              item.key,
              item.value.millisecondsSinceEpoch,
              payload,
            ],
          );
          final row = await db
              .customSelect(
                '''SELECT * FROM reminder_jobs
            WHERE occurrence_id=? AND rule_key=?''',
                variables: [Variable(occurrenceId), Variable(item.key)],
              )
              .getSingle();
          final id = row.read<int>('id');
          wanted.add(id);
          if (row.read<String>('state') == 'cancelled' &&
              !item.value.isAfter(now)) {
            await db.customStatement(
              "UPDATE reminder_jobs SET state='dismissed',last_error='past_cancelled' WHERE id=?",
              [id],
            );
            continue;
          }
          if (row.read<String>('payload') != payload ||
              row.read<String>('state') == 'cancelled') {
            await db.customStatement(
              '''UPDATE reminder_jobs SET payload=?, fire_at=?,
              generation=generation+1, state='pending', snoozed_until=NULL,
              last_error=NULL, delivered_at=NULL WHERE id=?''',
              [payload, item.value.millisecondsSinceEpoch, id],
            );
          }
        }
      }
    }
    final rows = await db
        .customSelect('SELECT id, state, snoozed_until FROM reminder_jobs')
        .get();
    for (final row in rows) {
      if (!wanted.contains(row.read<int>('id')) &&
          (row.readNullable<int>('snoozed_until') ?? 0) <=
              now.millisecondsSinceEpoch &&
          ![
            'cancelled',
            'dismissed',
            'delivered',
            'missed',
          ].contains(row.read<String>('state'))) {
        await db.customStatement(
          "UPDATE reminder_jobs SET state='cancelled', generation=generation+1 WHERE id=?",
          [row.read<int>('id')],
        );
      }
    }
    await db.customStatement(
      '''UPDATE reminder_jobs SET state='missed'
      WHERE COALESCE(snoozed_until,fire_at) < ?
      AND state IN ('pending','scheduled','blocked','failed')''',
      [now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch],
    );
    final jobs = await db
        .customSelect(
          '''SELECT * FROM reminder_jobs
      WHERE state IN ('pending','scheduled','blocked','failed')
      AND COALESCE(snoozed_until,fire_at)>=?
      ORDER BY COALESCE(snoozed_until,fire_at), id LIMIT 400''',
          variables: [
            Variable(
              now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
            ),
          ],
        )
        .get();
    final calendarJobs = await CalendarReminderStore(db).plan(now, deviceZone);
    final result = jobs
        .map(
          (r) => {
            ...jsonDecode(r.read<String>('payload')) as Map<String, dynamic>,
            'id': 740000 + r.read<int>('id'),
            'jobId': r.read<int>('id'),
            'generation': r.read<int>('generation'),
            'triggerAt':
                r.readNullable<int>('snoozed_until') ?? r.read<int>('fire_at'),
          },
        )
        .toList();
    result.addAll(calendarJobs);
    result.sort(
      (a, b) => (a['triggerAt'] as int).compareTo(b['triggerAt'] as int),
    );
    return result.take(400).toList();
  });
}
