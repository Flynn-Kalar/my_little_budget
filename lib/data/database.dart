import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'daos/accounts_dao.dart';
import 'daos/backup_dao.dart';
import 'daos/budget_dao.dart';
import 'daos/calendar_events_dao.dart';
import 'daos/categories_dao.dart';
import 'daos/investments_dao.dart';
import 'daos/notes_dao.dart';
import 'daos/recurring_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/transaction_presets_dao.dart';
import 'daos/transactions_dao.dart';
import 'seed.dart';
import 'sync_metadata.dart';
import 'tables/accounts.dart';
import 'tables/budget_groups.dart';
import 'tables/calendar_events.dart';
import 'tables/categories.dart';
import 'tables/investments.dart';
import 'tables/monthly_income.dart';
import 'tables/note_checklist_items.dart';
import 'tables/notes.dart';
import 'tables/recurring_transactions.dart';
import 'tables/tags.dart';
import 'tables/transaction_presets.dart';
import 'tables/transactions.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Transactions,
    BudgetGroups,
    BudgetGroupCategories,
    MonthlyIncome,
    Investments,
    RecurringTransactions,
    Tags,
    TransactionTags,
    Notes,
    NoteChecklistItems,
    CalendarEvents,
    TransactionPresets,
  ],
  daos: [
    AccountsDao,
    TransactionsDao,
    CategoriesDao,
    TagsDao,
    InvestmentsDao,
    RecurringDao,
    BudgetDao,
    BackupDao,
    NotesDao,
    CalendarEventsDao,
    TransactionPresetsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 16;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(tags, tags.usageCount);
        await m.addColumn(tags, tags.lastUsedAt);
        await m.addColumn(tags, tags.isPinned);
      }
      if (from < 3) {
        await _upgradeToV3SyncMetadata();
      }
      if (from < 4) {
        await m.createTable(notes);
      } else if (from < 5) {
        await m.addColumn(notes, notes.scheduleType);
        await m.addColumn(notes, notes.resetTime);
        await m.addColumn(notes, notes.notificationEnabled);
        await m.addColumn(notes, notes.notificationTime);
        await m.addColumn(notes, notes.resetWeekday);
        await m.addColumn(notes, notes.resetDayOfMonth);
        await m.addColumn(notes, notes.intervalDays);
        await m.addColumn(notes, notes.anchorDate);
        await m.addColumn(notes, notes.nextResetAt);
        await customStatement('''
UPDATE notes
SET schedule_type = 'once', notification_enabled = 1
WHERE reminder_at IS NOT NULL
''');
      }
      if (from < 6) {
        await m.createTable(noteChecklistItems);
      }
      if (from >= 4 && from < 7) {
        await m.addColumn(notes, notes.alarmSoundKind);
        await m.addColumn(notes, notes.alarmSoundUri);
        await m.addColumn(notes, notes.alarmSoundName);
        await m.addColumn(notes, notes.alarmClipStartMs);
        await m.addColumn(notes, notes.alarmClipEndMs);
        await m.addColumn(notes, notes.alarmVibrationEnabled);
      }
      if (from >= 4 && from < 8) {
        await m.addColumn(notes, notes.notificationDaysBefore);
      }
      if (from >= 4 && from < 9) {
        await m.addColumn(notes, notes.resetWeekdays);
        await m.addColumn(notes, notes.notificationExtraDaysBefore);
        await m.addColumn(notes, notes.notificationLeadMinutes);
        await m.addColumn(notes, notes.snoozeMinutes);
      }
      if (from >= 4 && from < 10) {
        await m.addColumn(notes, notes.richContent);
      }
      if (from < 11 && await _tableExists('tags')) {
        await m.addColumn(tags, tags.sortOrder);
        await _initializeTagSortOrder();
      }
      if (from < 12) {
        await m.createTable(calendarEvents);
      }
      if (from < 13 && await _tableExists('accounts')) {
        await m.addColumn(accounts, accounts.cardLimit);
      }
      if (from >= 4 && from < 14 && await _tableExists('notes')) {
        await m.addColumn(notes, notes.showOnCalendar);
      }
      if (from >= 12 && from < 15 && await _tableExists('calendar_events')) {
        await _addSyncMetadataColumns(
          tableName: 'calendar_events',
          idColumn: 'id',
        );
      }
      if (from < 16) {
        await m.createTable(transactionPresets);
      }
    },
    beforeOpen: (details) async {
      // SPEC §3 의 외래키 제약을 실제 SQLite 에서 강제하려면 PRAGMA 필요.
      await customStatement('PRAGMA foreign_keys = ON');
      await _ensureSyncInfrastructure();
      await _repairRequiredTagFields();
      // SPEC §5.3 — 첫 생성 시 기본 자산·카테고리 시드.
      if (details.wasCreated) {
        await seedDefaults(this);
      }
    },
  );

  /// Hard deletes stay invisible to all existing queries, while this durable
  /// outbox preserves the information needed to create a server tombstone.
  Future<void> _ensureSyncInfrastructure() async {
    await customStatement('''
CREATE TABLE IF NOT EXISTS sync_outbox (
  entity TEXT NOT NULL,
  uuid TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('upsert', 'delete')),
  generation INTEGER NOT NULL DEFAULT 1,
  changed_at TEXT NOT NULL,
  tombstone_payload TEXT,
  PRIMARY KEY (entity, uuid)
)
''');
    if (!await _columnExists('sync_outbox', 'tombstone_payload')) {
      await customStatement(
        'ALTER TABLE sync_outbox ADD COLUMN tombstone_payload TEXT',
      );
    }
    await customStatement('''
CREATE TABLE IF NOT EXISTS sync_state (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''');

    for (final tableName in localSyncTableNames) {
      if (!await _tableExists(tableName) ||
          !await _columnExists(tableName, 'uuid') ||
          !await _columnExists(tableName, 'sync_status')) {
        continue;
      }
      final tombstonePayload = switch (tableName) {
        'accounts' => "json_object('name', OLD.name)",
        'categories' => "json_object('name', OLD.name, 'type', OLD.type)",
        'budget_groups' => "json_object('name', OLD.name, 'month', OLD.month)",
        'monthly_income' => "json_object('month', OLD.month)",
        'tags' => "json_object('name', OLD.name)",
        _ => "'{}'",
      };
      await customStatement('DROP TRIGGER IF EXISTS sync_${tableName}_insert');
      await customStatement('DROP TRIGGER IF EXISTS sync_${tableName}_update');
      await customStatement('DROP TRIGGER IF EXISTS sync_${tableName}_delete');
      await customStatement('''
CREATE TRIGGER sync_${tableName}_insert
AFTER INSERT ON $tableName
WHEN NEW.uuid IS NOT NULL AND NEW.sync_status = '$syncStatusPending'
BEGIN
  INSERT INTO sync_outbox(
    entity, uuid, operation, generation, changed_at, tombstone_payload
  )
  VALUES(
    '$tableName', NEW.uuid, 'upsert', 1,
    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), null
  )
  ON CONFLICT(entity, uuid) DO UPDATE SET
    operation = 'upsert',
    generation = sync_outbox.generation + 1,
    changed_at = excluded.changed_at,
    tombstone_payload = null;
END
''');
      await customStatement('''
CREATE TRIGGER sync_${tableName}_update
AFTER UPDATE ON $tableName
WHEN NEW.uuid IS NOT NULL AND NEW.sync_status = '$syncStatusPending'
BEGIN
  INSERT INTO sync_outbox(
    entity, uuid, operation, generation, changed_at, tombstone_payload
  )
  VALUES(
    '$tableName', NEW.uuid, 'upsert', 1,
    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), null
  )
  ON CONFLICT(entity, uuid) DO UPDATE SET
    operation = 'upsert',
    generation = sync_outbox.generation + 1,
    changed_at = excluded.changed_at,
    tombstone_payload = null;
END
''');
      await customStatement('''
CREATE TRIGGER sync_${tableName}_delete
AFTER DELETE ON $tableName
WHEN OLD.uuid IS NOT NULL AND OLD.sync_status <> '$syncStatusRemoteDelete'
BEGIN
  INSERT INTO sync_outbox(
    entity, uuid, operation, generation, changed_at, tombstone_payload
  )
  VALUES(
    '$tableName', OLD.uuid, 'delete', 1,
    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), $tombstonePayload
  )
  ON CONFLICT(entity, uuid) DO UPDATE SET
    operation = 'delete',
    generation = sync_outbox.generation + 1,
    changed_at = excluded.changed_at,
    tombstone_payload = excluded.tombstone_payload;
END
''');
      await customStatement('''
INSERT OR IGNORE INTO sync_outbox(
  entity, uuid, operation, generation, changed_at, tombstone_payload
)
SELECT
  '$tableName', uuid, 'upsert', 1,
  strftime('%Y-%m-%dT%H:%M:%fZ', 'now'), null
FROM $tableName
WHERE uuid IS NOT NULL AND sync_status = '$syncStatusPending'
''');
    }
  }

  /// Re-enqueues every live row after a destructive restore/reset or when the
  /// configured Supabase project changes.
  Future<void> enqueueAllRowsForSync() async {
    for (final tableName in localSyncTableNames) {
      if (!await _tableExists(tableName) ||
          !await _columnExists(tableName, 'sync_status')) {
        continue;
      }
      await customStatement(
        "UPDATE $tableName SET sync_status = '$syncStatusPending'",
      );
    }
  }

  Future<void> _repairRequiredTagFields() async {
    if (!await _tableExists('tags')) return;

    await customStatement(
      "UPDATE tags SET color = '#64748b' WHERE color IS NULL OR color = ''",
    );
    await customStatement(
      'UPDATE tags SET usage_count = 0 WHERE usage_count IS NULL',
    );
    await customStatement(
      'UPDATE tags SET is_pinned = 0 WHERE is_pinned IS NULL',
    );
    await customStatement(
      'UPDATE tags SET sort_order = id WHERE sort_order IS NULL',
    );
    await customStatement(
      "UPDATE tags SET created_at = datetime('now') WHERE created_at IS NULL",
    );
    await customStatement(
      "UPDATE tags SET updated_at = COALESCE(created_at, datetime('now')) "
      'WHERE updated_at IS NULL',
    );
    await customStatement(
      "UPDATE tags SET sync_status = '$syncStatusPending' "
      'WHERE sync_status IS NULL',
    );

    final rows = await customSelect(
      'SELECT id FROM tags WHERE uuid IS NULL OR uuid = ?',
      variables: const [Variable<String>('')],
    ).get();
    for (final row in rows) {
      await customStatement('UPDATE tags SET uuid = ? WHERE id = ?', [
        newSyncUuid(),
        row.read<int>('id'),
      ]);
    }
  }

  Future<bool> _tableExists(String tableName) async {
    final row = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable<String>(tableName)],
    ).getSingleOrNull();
    return row != null;
  }

  Future<bool> _columnExists(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.read<String>('name') == columnName);
  }

  Future<void> _initializeTagSortOrder() async {
    await customStatement('''
UPDATE tags
SET sort_order = (
  SELECT rank - 1
  FROM (
    SELECT id, ROW_NUMBER() OVER (ORDER BY name, id) AS rank
    FROM tags
  ) ordered_tags
  WHERE ordered_tags.id = tags.id
)
''');
  }

  static QueryExecutor _openConnection() {
    // 모바일·데스크톱 모두: path_provider 의 application documents directory 에 budget.db
    return driftDatabase(name: 'budget');
  }

  Future<void> _upgradeToV3SyncMetadata() async {
    await _addSyncMetadataColumns(
      tableName: 'accounts',
      idColumn: 'id',
      addUpdatedAt: true,
      updatedAtFallback: 'created_at',
    );
    await _addSyncMetadataColumns(
      tableName: 'categories',
      idColumn: 'id',
      addUpdatedAt: true,
      updatedAtFallback: 'created_at',
    );
    await _addSyncMetadataColumns(tableName: 'transactions', idColumn: 'id');
    await _addSyncMetadataColumns(tableName: 'budget_groups', idColumn: 'id');
    await _addSyncMetadataColumns(
      tableName: 'monthly_income',
      idColumn: 'month',
    );
    await _addSyncMetadataColumns(tableName: 'investments', idColumn: 'id');
    await _addSyncMetadataColumns(
      tableName: 'recurring_transactions',
      idColumn: 'id',
    );
    await _addSyncMetadataColumns(
      tableName: 'tags',
      idColumn: 'id',
      addUpdatedAt: true,
      updatedAtFallback: 'created_at',
    );
  }

  Future<void> _addSyncMetadataColumns({
    required String tableName,
    required String idColumn,
    bool addUpdatedAt = false,
    String? updatedAtFallback,
  }) async {
    await customStatement('ALTER TABLE $tableName ADD COLUMN uuid TEXT');
    if (addUpdatedAt) {
      await customStatement(
        'ALTER TABLE $tableName ADD COLUMN updated_at TEXT',
      );
    }
    await customStatement('ALTER TABLE $tableName ADD COLUMN deleted_at TEXT');
    await customStatement(
      "ALTER TABLE $tableName ADD COLUMN sync_status TEXT NOT NULL DEFAULT '$syncStatusPending'",
    );

    final rows = await customSelect('SELECT $idColumn FROM $tableName').get();
    for (final row in rows) {
      final id = row.data[idColumn]!;
      await customStatement(
        'UPDATE $tableName SET uuid = ? WHERE $idColumn = ?',
        [newSyncUuid(), id],
      );
    }

    if (addUpdatedAt) {
      final fallback = updatedAtFallback == null
          ? "datetime('now')"
          : "$updatedAtFallback, datetime('now')";
      await customStatement(
        'UPDATE $tableName SET updated_at = COALESCE(updated_at, $fallback)',
      );
    }

    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_${tableName}_uuid ON $tableName(uuid)',
    );
  }
}
