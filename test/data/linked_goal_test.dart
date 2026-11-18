import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/goal_progress_store.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/notes/note_amount_goal.dart';
import 'package:my_little_budget/features/notes/note_goal_block.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  late AppDatabase db;
  late Account bank, cash;
  final today = DateTime(2026, 11, 18);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    bank = accounts.firstWhere((a) => a.kind == 'bank');
    cash = accounts.firstWhere((a) => a.kind == 'cash');
  });
  tearDown(() => db.close());

  NoteAmountGoal goal({
    String source = 'account',
    String? tag,
    String? account,
  }) => NoteAmountGoal(
    targetAmount: 1200000,
    currentAmount: 10000,
    startDate: DateTime(2026, 10, 15),
    dueDate: DateTime(2027, 1, 31),
    source: source,
    accountUuid: account ?? bank.uuid,
    tagUuid: tag,
  );

  Future<int> tx(
    String type,
    int amount,
    String date, {
    bool outgoing = false,
  }) async {
    final category = type == 'income' || type == 'expense'
        ? (await db.categoriesDao.getActiveCategories(type)).first.id
        : null;
    return db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: type,
        amount: amount,
        occurredOn: date,
        occurredTime: '12:00',
        accountId: type == 'transfer' ? null : bank.id,
        categoryId: category,
        fromAccountId: type == 'transfer'
            ? (outgoing ? bank.id : cash.id)
            : null,
        toAccountId: type == 'transfer' ? (outgoing ? cash.id : bank.id) : null,
      ),
    );
  }

  Future<void> purpose(String value, {int balance = 0}) =>
      db.accountsDao.saveAccount(
        id: bank.id,
        currentBalance: balance,
        asOf: today,
        draft: AccountDraft(
          name: bank.name,
          kind: 'bank',
          initialBalance: 0,
          color: bank.color,
          excludeFromTotal: false,
          isInvestment: false,
          fundPurpose: value,
        ),
      );

  test(
    'balance and transaction sources handle dates, transfers and signed adjustments',
    () async {
      await (db.update(db.accounts)..where((a) => a.id.equals(bank.id))).write(
        const AccountsCompanion(initialBalance: Value(100000)),
      );
      await tx('income', 50000, '2026-10-01'); // Before the goal's start.
      await tx('transfer', 200000, '2026-10-20');
      await tx('income', 100000, '2026-11-01');
      await tx('expense', 20000, '2026-11-02');
      await tx('transfer', 30000, '2026-11-03', outgoing: true);
      await tx('adjustment', -5000, '2026-11-18');
      await tx('income', 900000, '2026-11-19'); // Future excluded.
      final store = GoalProgressStore(db);
      final balance = await store.watch(goal(), today).first;
      expect(balance.goal.currentAmount, 395000);
      expect(balance.monthStartAmount, 350000);
      expect(
        balance.goal.monthlyNeeded(
          today,
          monthStartAmount: balance.monthStartAmount,
        ),
        238334,
      );
      final transactions = await store
          .watch(goal(source: 'transactions'), today)
          .first;
      expect(transactions.goal.currentAmount, 255000);
      expect(transactions.monthStartAmount, 210000);
      expect(
        transactions.goal.monthlyNeeded(
          today,
          monthStartAmount: transactions.monthStartAmount,
        ),
        285000,
      );
    },
  );

  test('tag filter never multiplies a transaction with several tags', () async {
    final tagId = await db.tagsDao.createTag('보험료', '#123456');
    final otherTag = await db.tagsDao.createTag('연간', '#654321');
    final tag = (await db.select(db.tags).get()).firstWhere(
      (t) => t.id == tagId,
    );
    final a = await tx('income', 100000, '2026-11-01');
    final b = await tx('expense', 20000, '2026-11-02');
    await tx('income', 700000, '2026-11-03');
    await db.tagsDao.setTransactionTags(a, [tagId, otherTag]);
    await db.tagsDao.setTransactionTags(b, [tagId]);
    final linked = goal(source: 'transactions', tag: tag.uuid);
    final result = await GoalProgressStore(db).watch(linked, today).first;
    expect(result.goal.currentAmount, 90000);
    expect(result.monthStartAmount, 10000);
    expect(result.tagName, '보험료');
  });

  test(
    'live aggregation reacts to edits, tag reassignment and deletion',
    () async {
      final tagId = await db.tagsDao.createTag('적립', '#123456');
      final tag = (await db.select(db.tags).get()).firstWhere(
        (t) => t.id == tagId,
      );
      final id = await tx('income', 100000, '2026-11-01');
      final stream = GoalProgressStore(db)
          .watch(goal(source: 'transactions', tag: tag.uuid), today)
          .asBroadcastStream();
      final subscription = stream.listen((_) {});
      addTearDown(subscription.cancel);
      expect((await stream.first).goal.currentAmount, 10000);
      var changed = stream.firstWhere((p) => p.goal.currentAmount == 110000);
      await db.tagsDao.setTransactionTags(id, [tagId]);
      await changed.timeout(const Duration(seconds: 5));
      changed = stream.firstWhere((p) => p.goal.currentAmount == 60000);
      await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
        const TransactionsCompanion(amount: Value(50000)),
      );
      await changed.timeout(const Duration(seconds: 5));
      changed = stream.firstWhere((p) => p.goal.currentAmount == 10000);
      await db.transactionsDao.deleteTransaction(id);
      await changed.timeout(const Duration(seconds: 5));
      final missing = stream.firstWhere((p) => p.issue != null);
      await db.tagsDao.deleteTag(tagId);
      expect(
        (await missing.timeout(const Duration(seconds: 5))).issue,
        contains('태그'),
      );
    },
  );

  test(
    'purpose and balance edits refresh goals; archived accounts retain progress',
    () async {
      await purpose('emergency', balance: 300000);
      final result = await GoalProgressStore(db).watch(goal(), today).first;
      expect(result.goal.currentAmount, 300000);
      expect(result.fundPurpose, 'emergency');
      await db.accountsDao.archiveAccount(bank.id);
      final archived = await GoalProgressStore(db).watch(goal(), today).first;
      expect(archived.archived, isTrue);
      expect(archived.goal.currentAmount, 300000);
      expect(
        (await GoalProgressStore(
          db,
        ).watch(goal(account: 'missing'), today).first).issue,
        contains('계좌'),
      );
      final card = (await db.accountsDao.getActiveAccounts()).firstWhere(
        (a) => a.kind == 'card',
      );
      expect(
        (await GoalProgressStore(
          db,
        ).watch(goal(account: card.uuid), today).first).issue,
        isNotNull,
      );
    },
  );

  test(
    'fund purpose and rich goal links survive backup and legacy backup defaults',
    () async {
      await purpose('annual', balance: 800000);
      final block = newNoteGoalBlock('연간 지출', goal(source: 'transactions'));
      final rich = jsonEncode([
        {
          'insert': {noteGoalBlockType: block.encode()},
        },
        {'insert': '\n'},
      ]);
      await db.notesDao.saveNote(
        title: '준비금',
        content: block.plainText,
        richContent: rich,
      );
      final backup = await db.backupDao.exportBackup();
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.backupDao.importBackup(
        parseBackup(backup.toJsonString()).backup!,
      );
      final restored = (await target.accountsDao.getAccountBalance(
        bank.id,
        asOf: today,
      ))!;
      expect(restored.fundPurpose, 'annual');
      expect(restored.balance, 800000);
      expect((await target.notesDao.listNotes()).single.richContent, rich);
      final legacy = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      for (final row in legacy['data']['accounts'] as List) {
        (row as Map).remove('fundPurpose');
      }
      final parsed = parseBackup(jsonEncode(legacy));
      expect(parsed.isOk, isTrue, reason: parsed.error);
      await target.backupDao.importBackup(parsed.backup!);
      expect(
        (await target.accountsDao.getAccountBalance(
          bank.id,
          asOf: today,
        ))!.fundPurpose,
        'living',
      );
    },
  );

  test(
    'sync preserves purpose and UUID goal links when local IDs differ',
    () async {
      await purpose('emergency', balance: 0);
      final block = newNoteGoalBlock('비상금', goal());
      final rich = jsonEncode([
        {
          'insert': {noteGoalBlockType: block.encode()},
        },
        {'insert': '\n'},
      ]);
      final noteId = await db.notesDao.saveNote(
        title: '목표',
        content: block.plainText,
        richContent: rich,
      );
      final note = (await db.notesDao.getNote(noteId))!;
      final source = LocalSyncStore(db);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.accountsDao.getActiveAccounts();
      await target.customStatement('DELETE FROM accounts');
      await target.customStatement('DELETE FROM sync_outbox');
      final targetStore = LocalSyncStore(target);
      var revision = 0;
      Future<void> transfer(
        String entity,
        String uuid,
        Map<String, Object?> payload,
      ) => targetStore.applyRemotePage(
        entity: entity,
        rows: [
          RemoteSyncRow(
            uuid: uuid,
            payload: payload,
            updatedAt: '2026-11-18T12:00:00Z',
            deletedAt: null,
            revision: ++revision,
          ),
        ],
        bootstrap: false,
      );
      final payload = (await source.buildPayload('accounts', bank.uuid))!;
      expect(payload['fund_purpose'], 'emergency');
      await transfer('accounts', bank.uuid, payload);
      await transfer(
        'notes',
        note.uuid,
        (await source.buildPayload('notes', note.uuid))!,
      );
      final account = (await target.accountsDao.getActiveAccounts()).single;
      expect(account.id, isNot(bank.id));
      expect(account.fundPurpose, 'emergency');
      expect((await target.notesDao.listNotes()).single.richContent, rich);
      expect(
        (await GoalProgressStore(
          target,
        ).watch(goal(), today).first).accountName,
        bank.name,
      );
      final old = Map<String, Object?>.from(payload)..remove('fund_purpose');
      old['name'] = '이름 변경';
      await transfer('accounts', bank.uuid, old);
      expect(
        (await target.accountsDao.getActiveAccounts()).single.fundPurpose,
        'emergency',
      );
    },
  );
}
