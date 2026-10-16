import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/database.dart';
import '../../data/sync_metadata.dart';
import '../notes/note_schedule.dart';
import '../notes/reminder_calendar.dart';
import 'calendar_schedule.dart';

/// Calendar jobs use the same Android delivery contract, but their own durable
/// occurrences. Acknowledging an event never creates a financial transaction.
class CalendarReminderStore {
  CalendarReminderStore(this.db);
  final AppDatabase db;

  Future<List<Map<String, Object?>>> plan(
    DateTime now,
    String deviceZone,
  ) async {
    final wanted = <int>{};
    for (var event in await db.calendarEventsDao.listEvents()) {
      if (!event.notificationEnabled || event.deletedAt != null) continue;
      var settings = CalendarScheduleSettings.fromEvent(event);
      if (settings.validationError != null) continue;
      if (settings.timeZone == null) {
        settings = CalendarScheduleSettings(
          every: settings.every,
          until: settings.until,
          timeZone: deviceZone,
          allDayDate: settings.allDayDate,
          exceptions: settings.exceptions,
        );
        await (db.update(
          db.calendarEvents,
        )..where((e) => e.id.equals(event.id))).write(
          CalendarEventsCompanion(
            scheduleData: Value(settings.encode()),
            updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
        event = event.copyWith(scheduleData: settings.encode());
      }
      final leads = parseNoteIntList(event.notificationLeadMinutes);
      final leadValues = leads.isEmpty ? [0] : leads;
      final maxLead = leadValues.reduce((a, b) => a > b ? a : b);
      final zone = calendarZone(settings.timeZone ?? deviceZone);
      final local = tz.TZDateTime.from(now, zone);
      // Keep a rolling set of future cycles, rather than a fixed two-year
      // cutoff that would silently omit a 3-year or long weekly recurrence.
      final type = NoteScheduleTypeStorage.parse(event.scheduleType);
      var horizon = switch (type) {
        NoteScheduleType.yearly => DateTime(
          local.year + settings.every * 31,
          local.month,
          local.day,
        ),
        NoteScheduleType.monthly => DateTime(
          local.year,
          local.month + settings.every * 31,
          local.day,
        ),
        NoteScheduleType.weekly => DateTime(
          local.year,
          local.month,
          local.day + settings.every * 31 * 7,
        ),
        _ => DateTime(local.year, local.month, local.day + settings.every * 31),
      };
      final anchor = calendarEventStart(event);
      if (horizon.isBefore(anchor)) {
        horizon = DateTime(anchor.year, anchor.month, anchor.day + 1);
      }
      for (final exception in settings.exceptions.values) {
        final moved = DateTime.tryParse(exception['start'] as String? ?? '');
        if (exception['skipped'] != true &&
            moved != null &&
            horizon.isBefore(moved)) {
          horizon = DateTime(moved.year, moved.month, moved.day + 1);
        }
      }
      for (final instance in calendarInstances(
        event,
        DateTime(
          local.year,
          local.month,
          local.day,
        ).subtract(Duration(days: 1, minutes: maxLead)),
        horizon.add(Duration(minutes: maxLead)),
      )) {
        final at = event.allDay
            ? reminderWallTime(zone, instance.start, 9, 0)
            : instance.start;
        await db.customStatement(
          '''INSERT OR IGNORE INTO calendar_occurrences
          (event_id,occurrence_key,scheduled_at) VALUES(?,?,?)''',
          [event.id, instance.originalDate, at.millisecondsSinceEpoch],
        );
        final occurrence = await db
            .customSelect(
              'SELECT * FROM calendar_occurrences WHERE event_id=? AND occurrence_key=?',
              variables: [Variable(event.id), Variable(instance.originalDate)],
            )
            .getSingle();
        if (occurrence.read<String>('status') != 'pending') continue;
        final occurrenceId = occurrence.read<int>('id');
        await db.customStatement(
          'UPDATE calendar_occurrences SET scheduled_at=? WHERE id=?',
          [at.millisecondsSinceEpoch, occurrenceId],
        );
        for (final minutes in leadValues) {
          final fire = at.subtract(Duration(minutes: minutes));
          final payload = jsonEncode({
            'calendarEventId': event.id,
            'occurrenceId': occurrenceId,
            'title': instance.title,
            'alarmMode': false,
            'triggerAt': fire.millisecondsSinceEpoch,
            'snoozeMinutes': 10,
            'originalDate': instance.originalDate,
          });
          await db.customStatement(
            '''INSERT OR IGNORE INTO calendar_jobs
            (occurrence_id,rule_key,fire_at,payload) VALUES(?,?,?,?)''',
            [
              occurrenceId,
              'minutes:$minutes',
              fire.millisecondsSinceEpoch,
              payload,
            ],
          );
          final job = await db
              .customSelect(
                'SELECT * FROM calendar_jobs WHERE occurrence_id=? AND rule_key=?',
                variables: [
                  Variable(occurrenceId),
                  Variable('minutes:$minutes'),
                ],
              )
              .getSingle();
          final id = job.read<int>('id');
          wanted.add(id);
          if (job.read<String>('state') == 'cancelled' &&
              job.read<String>('payload') == payload &&
              (job.readNullable<int>('snoozed_until') ?? 0) >
                  now.millisecondsSinceEpoch) {
            await db.customStatement(
              "UPDATE calendar_jobs SET state='pending' WHERE id=?",
              [id],
            );
          } else if (job.read<String>('state') == 'cancelled' &&
              !fire.isAfter(now)) {
            await db.customStatement(
              "UPDATE calendar_jobs SET state='dismissed',last_error='past_cancelled' WHERE id=?",
              [id],
            );
          } else if (job.read<String>('payload') != payload ||
              job.read<String>('state') == 'cancelled') {
            await db.customStatement(
              '''UPDATE calendar_jobs SET fire_at=?,payload=?,state='pending',
              generation=generation+1,snoozed_until=NULL,last_error=NULL,delivered_at=NULL WHERE id=?''',
              [fire.millisecondsSinceEpoch, payload, id],
            );
          }
        }
      }
    }
    for (final job
        in await db
            .customSelect('SELECT id,state,snoozed_until FROM calendar_jobs')
            .get()) {
      if (!wanted.contains(job.read<int>('id')) &&
          (job.readNullable<int>('snoozed_until') ?? 0) <=
              now.millisecondsSinceEpoch &&
          ![
            'cancelled',
            'dismissed',
            'delivered',
            'missed',
          ].contains(job.read<String>('state'))) {
        await db.customStatement(
          "UPDATE calendar_jobs SET state='cancelled',generation=generation+1 WHERE id=?",
          [job.read<int>('id')],
        );
      }
    }
    await db.customStatement(
      "UPDATE calendar_jobs SET state='missed' WHERE state IN ('pending','scheduled','blocked','failed') AND COALESCE(snoozed_until,fire_at)<?",
      [now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch],
    );
    final jobs = await db
        .customSelect(
          "SELECT * FROM calendar_jobs WHERE state IN ('pending','scheduled','blocked','failed') ORDER BY COALESCE(snoozed_until,fire_at),id LIMIT 400",
        )
        .get();
    return jobs
        .map(
          (j) => <String, Object?>{
            ...jsonDecode(j.read<String>('payload')) as Map<String, dynamic>,
            'jobId': -j.read<int>('id'),
            'id': -740000 - j.read<int>('id'),
            'generation': j.read<int>('generation'),
            'triggerAt':
                j.readNullable<int>('snoozed_until') ?? j.read<int>('fire_at'),
          },
        )
        .toList();
  }
}
