import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/sync_metadata.dart';

void main() {
  test(
    'repairs nullable tag fields before reading latest schema rows',
    () async {
      final executor = NativeDatabase.memory(
        setup: (raw) {
          raw.execute('''
CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid TEXT UNIQUE,
  name TEXT,
  color TEXT,
  usage_count INTEGER,
  last_used_at TEXT,
  is_pinned INTEGER,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT,
  sync_status TEXT
)
''');
          raw.execute('''
INSERT INTO tags (
  id, uuid, name, color, usage_count, is_pinned,
  created_at, updated_at, sync_status
) VALUES (
  1, NULL, 'broken-tag', NULL, NULL, NULL, NULL, NULL, NULL
)
''');
          raw.execute('PRAGMA user_version = 10');
        },
      );
      final db = AppDatabase.forTesting(executor);
      addTearDown(db.close);

      final tags = await db.tagsDao.getTags();

      expect(tags.single.name, 'broken-tag');
      expect(tags.single.uuid, isNotEmpty);
      expect(tags.single.color, '#64748b');
      expect(tags.single.usageCount, 0);
      expect(tags.single.isPinned, isFalse);
      expect(tags.single.createdAt, isNotEmpty);
      expect(tags.single.updatedAt, isNotEmpty);
      expect(tags.single.syncStatus, syncStatusPending);
    },
  );

  test('schema v2 upgrades entity rows with sync metadata', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL,
  initial_balance INTEGER NOT NULL DEFAULT 0,
  color TEXT NOT NULL DEFAULT '#94a3b8',
  exclude_from_total INTEGER NOT NULL DEFAULT 0,
  is_investment INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  archived_at TEXT,
  created_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  color TEXT NOT NULL DEFAULT '#64748b',
  icon TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  archived_at TEXT,
  created_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  occurred_on TEXT NOT NULL,
  occurred_time TEXT NOT NULL DEFAULT '00:00',
  amount INTEGER NOT NULL,
  memo TEXT,
  account_id INTEGER,
  category_id INTEGER,
  from_account_id INTEGER,
  to_account_id INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE budget_groups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  month TEXT NOT NULL,
  amount INTEGER NOT NULL,
  adjustment INTEGER NOT NULL DEFAULT 0,
  carry_forward INTEGER NOT NULL DEFAULT 0,
  account_id INTEGER,
  percentage INTEGER,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE monthly_income (
  month TEXT PRIMARY KEY NOT NULL,
  expected_income INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE investments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  side TEXT NOT NULL,
  occurred_on TEXT NOT NULL,
  occurred_time TEXT NOT NULL DEFAULT '00:00',
  ticker TEXT NOT NULL,
  quantity REAL NOT NULL DEFAULT 0,
  total_amount INTEGER NOT NULL,
  account_id INTEGER,
  memo TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE recurring_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  memo TEXT,
  account_id INTEGER,
  category_id INTEGER,
  from_account_id INTEGER,
  to_account_id INTEGER,
  frequency TEXT NOT NULL,
  day_of_month INTEGER,
  day_of_week INTEGER,
  occurred_time TEXT NOT NULL DEFAULT '00:00',
  start_date TEXT NOT NULL,
  end_date TEXT,
  last_generated_on TEXT,
  tag_names TEXT,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');
        raw.execute('''
CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL DEFAULT '#64748b',
  usage_count INTEGER NOT NULL DEFAULT 0,
  last_used_at TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
)
''');
        raw.execute('''
INSERT INTO accounts (
  id, name, kind, initial_balance, color, exclude_from_total,
  is_investment, sort_order, archived_at, created_at
) VALUES (
  1, '현금', 'cash', 0, '#94a3b8', 0, 0, 0, NULL, '2026-06-01 00:00:00'
)
''');
        raw.execute('PRAGMA user_version = 2');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    final row = await db.customSelect('''
SELECT uuid, updated_at, deleted_at, sync_status
FROM accounts
WHERE id = 1
''').getSingle();

    expect(row.read<String>('uuid'), isNotEmpty);
    expect(row.read<String>('updated_at'), '2026-06-01 00:00:00');
    expect(row.readNullable<String>('deleted_at'), isNull);
    expect(row.read<String>('sync_status'), syncStatusPending);

    final notesTable = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'notes'",
        )
        .getSingleOrNull();
    expect(notesTable?.read<String>('name'), 'notes');
    final noteColumns = await db.customSelect('PRAGMA table_info(notes)').get();
    final columnNames = noteColumns.map((row) => row.read<String>('name'));
    expect(
      columnNames,
      containsAll([
        'schedule_type',
        'next_reset_at',
        'notification_days_before',
        'notification_extra_days_before',
        'notification_lead_minutes',
        'reset_weekdays',
        'snooze_minutes',
        'rich_content',
        'alarm_sound_kind',
        'alarm_clip_start_ms',
        'alarm_vibration_enabled',
      ]),
    );
    final checklistTable = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'note_checklist_items'",
        )
        .getSingleOrNull();
    expect(checklistTable?.read<String>('name'), 'note_checklist_items');
  });

  test('schema v5 creates checklist table and preserves notes', () async {
    final executor = NativeDatabase.memory(
      setup: (raw) {
        raw.execute('''
CREATE TABLE notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  reminder_at TEXT,
  schedule_type TEXT NOT NULL DEFAULT 'none',
  reset_time TEXT,
  notification_enabled INTEGER NOT NULL DEFAULT 0,
  notification_time TEXT,
  reset_weekday INTEGER,
  reset_day_of_month INTEGER,
  interval_days INTEGER,
  anchor_date TEXT,
  next_reset_at TEXT,
  completed INTEGER NOT NULL DEFAULT 0,
  pinned INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
)
''');
        raw.execute('''
INSERT INTO notes (id, title, content, schedule_type, reset_time)
VALUES (7, '기존 반복 메모', '보존할 본문', 'daily', '06:00')
''');
        raw.execute('PRAGMA user_version = 5');
      },
    );
    final db = AppDatabase.forTesting(executor);
    addTearDown(db.close);

    final note = await db.notesDao.getNote(7);
    expect(note?.title, '기존 반복 메모');
    expect(note?.content, '보존할 본문');
    expect(note?.scheduleType, 'daily');

    final checklistTable = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'table' AND name = 'note_checklist_items'",
        )
        .getSingleOrNull();
    expect(checklistTable?.read<String>('name'), 'note_checklist_items');
    expect(await db.select(db.noteChecklistItems).get(), isEmpty);
  });
}
