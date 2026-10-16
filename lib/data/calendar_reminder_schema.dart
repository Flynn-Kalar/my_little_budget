import 'dart:convert';
import 'database.dart';

Future<void> createCalendarReminderSchema(AppDatabase db) async {
  for (final sql in [
    '''CREATE TABLE IF NOT EXISTS calendar_occurrences (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      event_id INTEGER NOT NULL REFERENCES calendar_events(id) ON DELETE CASCADE,
      occurrence_key TEXT NOT NULL, scheduled_at INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', UNIQUE(event_id,occurrence_key))''',
    '''CREATE TABLE IF NOT EXISTS calendar_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      occurrence_id INTEGER NOT NULL REFERENCES calendar_occurrences(id) ON DELETE CASCADE,
      rule_key TEXT NOT NULL, fire_at INTEGER NOT NULL, generation INTEGER NOT NULL DEFAULT 1,
      state TEXT NOT NULL DEFAULT 'pending', payload TEXT NOT NULL,
      snoozed_until INTEGER, last_error TEXT, delivered_at INTEGER,
      UNIQUE(occurrence_id,rule_key))''',
    'CREATE INDEX IF NOT EXISTS idx_calendar_jobs_fire ON calendar_jobs(state,fire_at)',
    '''CREATE TRIGGER IF NOT EXISTS calendar_event_reminder_update
      AFTER UPDATE OF title,start_at,end_at,all_day,schedule_type,schedule_data,
        notification_enabled,notification_lead_minutes ON calendar_events
      BEGIN UPDATE calendar_jobs SET state='cancelled',generation=generation+1
      WHERE occurrence_id IN (SELECT id FROM calendar_occurrences WHERE event_id=NEW.id); END''',
    // Negative job tokens distinguish calendars from notes without changing any
    // existing IDs, FKs, generations, or pending Android intents.
    '''CREATE VIEW IF NOT EXISTS reminder_dispatch_jobs AS
      SELECT j.id,j.generation,j.payload,COALESCE(j.snoozed_until,j.fire_at) AS trigger_at,j.state
      FROM reminder_jobs j JOIN reminder_occurrences o ON o.id=j.occurrence_id
      JOIN notes n ON n.id=o.note_id
      WHERE o.status='pending' AND n.notification_enabled=1
      UNION ALL
      SELECT -j.id,j.generation,j.payload,COALESCE(j.snoozed_until,j.fire_at),j.state
      FROM calendar_jobs j JOIN calendar_occurrences o ON o.id=j.occurrence_id
      JOIN calendar_events e ON e.id=o.event_id
      WHERE o.status='pending' AND e.notification_enabled=1 AND e.deleted_at IS NULL''',
  ]) {
    await db.customStatement(sql);
  }
  // Freeze old all-day civil dates once, in the device's current zone. Never
  // reinterpret already frozen dates when travelling or restoring a backup.
  final legacy = await db
      .customSelect(
        "SELECT id,start_at FROM calendar_events WHERE all_day=1 AND schedule_data='{}'",
      )
      .get();
  for (final row in legacy) {
    final start = DateTime.tryParse(row.read<String>('start_at'))?.toLocal();
    if (start == null) continue;
    final date =
        '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    await db.customStatement(
      "UPDATE calendar_events SET schedule_data=?,updated_at=?,sync_status='pending' WHERE id=?",
      [
        jsonEncode({'date': date}),
        DateTime.now().toUtc().toIso8601String(),
        row.read<int>('id'),
      ],
    );
  }
}
