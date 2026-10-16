import 'database.dart';

/// Shared with Android's ReminderRepository. Only Drift migrates this schema.
Future<void> createReminderSchema(AppDatabase db) async {
  for (final sql in [
    '''CREATE TABLE IF NOT EXISTS reminder_series (
      note_id INTEGER PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
      time_zone TEXT NOT NULL, anchor_date TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS reminder_occurrences (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      note_id INTEGER NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
      occurrence_key TEXT NOT NULL, scheduled_at INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending', completed_at INTEGER,
      checklist_json TEXT NOT NULL DEFAULT '[]',
      UNIQUE(note_id, occurrence_key))''',
    '''CREATE TABLE IF NOT EXISTS reminder_jobs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      occurrence_id INTEGER NOT NULL REFERENCES reminder_occurrences(id) ON DELETE CASCADE,
      rule_key TEXT NOT NULL, fire_at INTEGER NOT NULL,
      generation INTEGER NOT NULL DEFAULT 1,
      state TEXT NOT NULL DEFAULT 'pending',
      payload TEXT NOT NULL, snoozed_until INTEGER,
      last_error TEXT, delivered_at INTEGER,
      UNIQUE(occurrence_id, rule_key))''',
    'CREATE INDEX IF NOT EXISTS idx_reminder_jobs_fire ON reminder_jobs(state, fire_at)',
    '''CREATE TRIGGER IF NOT EXISTS reminder_note_update
      AFTER UPDATE OF title, schedule_type, reminder_at, reset_time,
        notification_enabled, notification_time, notification_days_before,
        notification_extra_days_before, notification_lead_minutes,
        reset_weekday, reset_weekdays, reset_day_of_month, interval_days,
        anchor_date, alarm_sound_kind, alarm_sound_uri, alarm_clip_start_ms,
        alarm_clip_end_ms, alarm_vibration_enabled, snooze_minutes ON notes
      BEGIN
        UPDATE reminder_jobs SET state='cancelled', generation=generation+1
        WHERE occurrence_id IN (SELECT id FROM reminder_occurrences WHERE note_id=NEW.id);
      END''',
  ]) {
    await db.customStatement(sql);
  }
  final columns =
      (await db.customSelect('PRAGMA table_info(reminder_series)').get())
          .map((r) => r.read<String>('name'))
          .toSet();
  for (final field in {
    'due_date': 'TEXT',
    'repeat_every': 'INTEGER NOT NULL DEFAULT 1',
    'until_date': 'TEXT',
    'alarm_mode': 'INTEGER NOT NULL DEFAULT 1',
  }.entries) {
    if (!columns.contains(field.key)) {
      await db.customStatement(
        'ALTER TABLE reminder_series ADD COLUMN ${field.key} ${field.value}',
      );
    }
  }
}
