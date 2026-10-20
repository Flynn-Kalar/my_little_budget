import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/recurring/validation.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<int> create(String name) async {
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    return db.recurringDao.saveRecurring(
      draft: RecurringDraft(
        name: name,
        type: 'expense',
        amount: 1000,
        frequency: 'monthly',
        dayOfMonth: 1,
        occurredTime: '09:00',
        startDate: '2026-10-01',
        accountId: account.id,
        categoryId: category.id,
      ),
    );
  }

  Future<List<int>> order() async =>
      (await db.recurringDao.listRecurringTransactions())
          .map((item) => item.recurring.id)
          .toList();

  test(
    'custom order survives toggling, updates and insertion without changing generation rules',
    () async {
      final a = await create('A'), b = await create('B'), c = await create('C');
      await db.recurringDao.toggleRecurringActive(c, false);
      final before = await db.select(db.recurringTransactions).get();
      await db.recurringDao.generateDueRecurringTransactions('2026-10-02');
      final transactions = await db.select(db.transactions).get();
      await db.recurringDao.updateRecurringOrder([c, a, b]);
      expect(await order(), [c, a, b]);
      await db.recurringDao.toggleRecurringActive(c, true);
      await db.recurringDao.toggleRecurringActive(a, false);
      expect(await order(), [c, a, b]);
      final after = await db.select(db.recurringTransactions).get();
      for (final row in after) {
        final original = before.singleWhere((item) => item.id == row.id);
        expect(row.amount, original.amount);
        expect(row.frequency, original.frequency);
        expect(row.startDate, original.startDate);
        expect(row.dayOfMonth, original.dayOfMonth);
      }
      expect(
        (await db.select(db.transactions).get()).map((row) => row.toJson()),
        transactions.map((row) => row.toJson()),
      );
      final d = await create('D');
      expect(await order(), [c, a, b, d]);
      final snapshot = parseBackup(
        (await db.backupDao.exportBackup()).toJsonString(),
      );
      expect(snapshot.isOk, isTrue, reason: snapshot.error);
      await db.backupDao.importBackup(snapshot.backup!);
      expect(await order(), [c, a, b, d]);
      final legacy = snapshot.backup!.toJson();
      for (final row
          in (legacy['data'] as Map)['recurringTransactions'] as List) {
        (row as Map).remove('sortOrder');
      }
      expect(
        parseBackup(
          jsonEncode(legacy),
        ).backup!.recurringTransactions.every((row) => row.sortOrder == 0),
        isTrue,
      );
    },
  );

  test(
    'stale or duplicate selections and a mid-save failure leave all positions untouched',
    () async {
      final a = await create('A'), b = await create('B'), c = await create('C');
      for (final invalid in [
        <int>[],
        [a, b],
        [a, a, c],
        [a, b, 999999],
      ]) {
        await expectLater(
          db.recurringDao.updateRecurringOrder(invalid),
          throwsStateError,
        );
        expect(await order(), [a, b, c]);
      }
      await db.customStatement(
        "CREATE TRIGGER reject_reorder BEFORE UPDATE OF sort_order ON recurring_transactions WHEN NEW.id = $b BEGIN SELECT RAISE(ABORT, 'blocked reorder'); END",
      );
      await expectLater(
        db.recurringDao.updateRecurringOrder([c, b, a]),
        throwsA(
          predicate((error) => error.toString().contains('blocked reorder')),
        ),
      );
      expect(await order(), [a, b, c]);
    },
  );

  test(
    'sync payload preserves saved order and old clients do not reset it',
    () async {
      final a = await create('A'), b = await create('B');
      await db.recurringDao.updateRecurringOrder([b, a]);
      final entry =
          (await db.recurringDao.listRecurringTransactions()).last.recurring;
      final store = LocalSyncStore(db);
      final payload = (await store.buildPayload(
        'recurring_transactions',
        entry.uuid,
      ))!;
      expect(payload['sort_order'], 1);
      expect(
        (await store.currentEntry(
          'recurring_transactions',
          entry.uuid,
        ))!.operation,
        'upsert',
      );
      // ACK the local rows before simulating an older client's remote update.
      for (final pending in await store.pendingEntries()) {
        await store.acknowledge(pending);
      }
      final legacy = {...payload}..remove('sort_order');
      await store.applyRemotePage(
        entity: 'recurring_transactions',
        bootstrap: false,
        rows: [
          RemoteSyncRow(
            uuid: entry.uuid,
            payload: legacy,
            updatedAt: '2026-10-22T00:00:00Z',
            deletedAt: null,
            revision: 1,
          ),
        ],
      );
      expect(await order(), [b, a]);
      expect(
        (await db.recurringDao.listRecurringTransactions())
            .last
            .recurring
            .sortOrder,
        1,
      );
    },
  );

  test(
    'v23 recurring rows acquire zero order without changing stored data',
    () async {
      final upgraded = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              '''CREATE TABLE recurring_transactions (
        id INTEGER PRIMARY KEY, uuid TEXT UNIQUE NOT NULL, name TEXT NOT NULL,
        type TEXT NOT NULL, amount INTEGER NOT NULL, memo TEXT,
        account_id INTEGER, category_id INTEGER, from_account_id INTEGER, to_account_id INTEGER,
        frequency TEXT NOT NULL, day_of_month INTEGER, day_of_week INTEGER,
        monthly_mode TEXT NOT NULL DEFAULT 'day', week_of_month INTEGER,
        non_business_day_adjustment TEXT NOT NULL DEFAULT 'same', include_non_business_days INTEGER NOT NULL DEFAULT 1,
        occurred_time TEXT NOT NULL DEFAULT '00:00', start_date TEXT NOT NULL, end_date TEXT,
        last_generated_on TEXT, tag_names TEXT, active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL, deleted_at TEXT, sync_status TEXT NOT NULL DEFAULT 'pending')''',
            );
            raw.execute(
              "INSERT INTO recurring_transactions (id,uuid,name,type,amount,frequency,day_of_month,start_date,created_at,updated_at) VALUES (42,'old','기존 규칙','expense',1000,'monthly',1,'2026-10-01','2026-10-01','2026-10-01')",
            );
            raw.execute('PRAGMA user_version = 23');
          },
        ),
      );
      try {
        final row =
            (await upgraded.select(upgraded.recurringTransactions).get())
                .single;
        expect(row.id, 42);
        expect(row.name, '기존 규칙');
        expect(row.amount, 1000);
        expect(row.sortOrder, 0);
      } finally {
        await upgraded.close();
      }
    },
  );
}
