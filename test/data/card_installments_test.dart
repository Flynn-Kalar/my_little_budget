import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/presets/validation.dart';
import 'package:my_little_budget/features/transactions/transaction_csv.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;
  late Account card;
  late Account bank;
  late Category category;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    card = accounts.firstWhere((a) => a.kind == 'card');
    bank = accounts.firstWhere((a) => a.kind == 'bank');
    category = (await db.categoriesDao.getActiveCategories('expense')).first;
    await db.accountsDao.saveAccount(
      id: card.id,
      currentBalance: 0,
      draft: AccountDraft(
        name: card.name,
        kind: 'card',
        initialBalance: 0,
        color: card.color,
        excludeFromTotal: false,
        isInvestment: false,
        cardPaymentDay: 14,
        cardClosingDay: 31,
      ),
    );
  });
  tearDown(() => db.close());
  TransactionDraft draft({
    int? months = 3,
    int? accountId,
    int amount = 90000,
    String type = 'expense',
  }) => TransactionDraft(
    type: type,
    amount: amount,
    occurredOn: '2026-10-31',
    occurredTime: '12:00',
    accountId: accountId ?? card.id,
    categoryId: category.id,
    installmentMonths: months,
    memo: '노트북',
  );

  test(
    'one purchase is stored, all queries keep months and billing alone splits principal',
    () async {
      final id = await db.transactionsDao.saveTransaction(draft: draft());
      expect(await db.select(db.transactions).get(), hasLength(1));
      expect(
        (await db.transactionsDao.getTransactionById(id))!.installmentMonths,
        3,
      );
      expect(
        (await db.transactionsDao.listTransactionsByMonth(
          '2026-10',
        )).single.installmentMonths,
        3,
      );
      expect(
        (await db.transactionsDao.listTransactionsByAccount(
          card.id,
        )).single.installmentMonths,
        3,
      );
      expect(
        (await db.transactionsDao.recentInputEntries())
            .single
            .installmentMonths,
        3,
      );
      final account = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 10, 31),
      ))!;
      expect(account.balance, -90000);
      expect(account.cardSpendingToDate, 90000);
      expect(account.cardMonthSpending, 90000);
      expect(account.cardBilling!.dueAmount, 30000);
      expect(account.cardBilling!.laterAmount, 60000);
      expect(account.cardInstallmentCount, 1);
    },
  );

  test(
    'editing months recomputes schedule; single-payment and deletion remove it',
    () async {
      final id = await db.transactionsDao.saveTransaction(draft: draft());
      await db.transactionsDao.saveTransaction(id: id, draft: draft(months: 6));
      var account = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 10),
      ))!;
      expect(account.balance, -90000);
      expect(account.cardBilling!.dueAmount, 15000);
      expect(account.cardBilling!.laterAmount, 75000);
      await db.transactionsDao.saveTransaction(
        id: id,
        draft: draft(months: null),
      );
      account = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 10),
      ))!;
      expect(account.cardBilling!.dueAmount, 90000);
      expect(account.cardBilling!.installments, isEmpty);
      await db.transactionsDao.deleteTransaction(id);
      expect((await db.accountsDao.getAccountBalance(card.id))!.balance, 0);
    },
  );

  test(
    'DAO rejects cash/bank, non-expense and invalid installments without writing',
    () async {
      for (final invalid in [
        draft(accountId: bank.id),
        draft(type: 'income'),
        draft(months: 1),
        draft(months: 61),
        draft(amount: 2),
      ]) {
        await expectLater(
          db.transactionsDao.saveTransaction(draft: invalid),
          throwsArgumentError,
        );
      }
      expect(await db.select(db.transactions).get(), isEmpty);
    },
  );

  test(
    'card kind cannot change while installment transactions remain',
    () async {
      await db.transactionsDao.saveTransaction(draft: draft());
      await expectLater(
        db.accountsDao.saveAccount(
          id: card.id,
          currentBalance: -90000,
          draft: AccountDraft(
            name: card.name,
            kind: 'bank',
            initialBalance: 0,
            color: card.color,
            excludeFromTotal: false,
            isInvestment: false,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'presets preserve months when reused and reject non-card installments',
    () async {
      final preset = TransactionPresetDraft(
        type: 'expense',
        amount: 90000,
        accountId: card.id,
        categoryId: category.id,
        installmentMonths: 3,
      );
      await db.transactionPresetsDao.savePreset(draft: preset);
      final item = (await db.transactionPresetsDao.listPresets()).single;
      expect(item.isUsable, isTrue);
      expect(item.toDraft().installmentMonths, 3);
      final id = await db.transactionsDao.saveTransaction(
        draft: item.toDraft().toTransactionDraft(DateTime(2026, 10, 31)),
      );
      expect(
        (await db.transactionsDao.getTransactionById(id))!.installmentMonths,
        3,
      );
      await expectLater(
        db.transactionPresetsDao.savePreset(
          draft: TransactionPresetDraft(
            type: 'expense',
            amount: 90000,
            accountId: bank.id,
            categoryId: category.id,
            installmentMonths: 3,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'backup roundtrip preserves installments and old backups read as single-payment',
    () async {
      await db.transactionsDao.saveTransaction(draft: draft());
      await db.transactionPresetsDao.savePreset(
        draft: TransactionPresetDraft(
          type: 'expense',
          amount: 90000,
          accountId: card.id,
          categoryId: category.id,
          installmentMonths: 3,
        ),
      );
      final backup = await db.backupDao.exportBackup();
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.backupDao.importBackup(
        parseBackup(backup.toJsonString()).backup!,
      );
      expect(
        (await target.select(target.transactions).get())
            .single
            .installmentMonths,
        3,
      );
      expect(
        (await target.select(target.transactionPresets).get())
            .single
            .installmentMonths,
        3,
      );
      final old = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      for (final key in ['transactions', 'transactionPresets']) {
        for (final item in old['data'][key] as List) {
          (item as Map).remove('installmentMonths');
        }
      }
      final parsed = parseBackup(jsonEncode(old));
      expect(parsed.isOk, isTrue, reason: parsed.error);
      await target.backupDao.importBackup(parsed.backup!);
      expect(
        (await target.select(target.transactions).get())
            .single
            .installmentMonths,
        isNull,
      );
      expect(
        (await target.select(target.transactionPresets).get())
            .single
            .installmentMonths,
        isNull,
      );
    },
  );

  test(
    'sync carries months, keeps missing legacy values, and allows explicit clearing',
    () async {
      await db.transactionsDao.saveTransaction(draft: draft());
      await db.transactionPresetsDao.savePreset(
        draft: TransactionPresetDraft(
          type: 'expense',
          amount: 90000,
          accountId: card.id,
          categoryId: category.id,
          installmentMonths: 3,
        ),
      );
      final source = LocalSyncStore(db);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      // Restoring the account/category identities isolates the optional-field contract.
      await target.backupDao.importBackup(await db.backupDao.exportBackup());
      await target.customStatement('DELETE FROM sync_outbox');
      final store = LocalSyncStore(target);
      final entities = {
        'transactions': (await db.select(db.transactions).get()).single.uuid,
        'transaction_presets':
            (await db.select(db.transactionPresets).get()).single.uuid,
      };
      for (final entry in entities.entries) {
        final payload = (await source.buildPayload(entry.key, entry.value))!;
        expect(payload['installment_months'], 3);
        Future<void> apply(Map<String, Object?> data, int revision) =>
            store.applyRemotePage(
              entity: entry.key,
              rows: [
                RemoteSyncRow(
                  uuid: entry.value,
                  payload: data,
                  updatedAt: '2026-11-19T00:00:00Z',
                  deletedAt: null,
                  revision: revision,
                ),
              ],
              bootstrap: false,
            );
        await apply({...payload, 'installment_months': 6}, 1);
        expect(
          (await store.buildPayload(
            entry.key,
            entry.value,
          ))!['installment_months'],
          6,
        );
        final legacy = Map<String, Object?>.from(payload)
          ..remove('installment_months');
        await apply(legacy, 2);
        expect(
          (await store.buildPayload(
            entry.key,
            entry.value,
          ))!['installment_months'],
          6,
        );
        await apply({...payload, 'installment_months': null}, 3);
        expect(
          (await store.buildPayload(
            entry.key,
            entry.value,
          ))!['installment_months'],
          isNull,
        );
      }
    },
  );

  test(
    'CSV roundtrip preserves months and marks non-card installment rows invalid',
    () async {
      await db.transactionsDao.saveTransaction(draft: draft());
      final rows = parseTransactionCsv(
        exportTransactionCsv(await db.backupDao.exportBackup()),
      );
      final mapping = {
        for (var i = 0; i < rows.first.length; i++) rows.first[i]: i,
      };
      final service = TransactionCsvService(db);
      expect((await service.preview(rows, mapping)).duplicates, 1);
      await db.transactionsDao.deleteTransaction(
        (await db.select(db.transactions).get()).single.id,
      );
      expect(await service.importRows(rows, mapping), 1);
      expect(
        (await db.select(db.transactions).get()).single.installmentMonths,
        3,
      );
      rows[1][mapping['계좌']!] = bank.name;
      expect((await service.preview(rows, mapping)).invalid, 1);
    },
  );

  test(
    'v28 upgrade retains records and adds nullable months on both tables',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget-installments-test-',
      );
      final file = File('${directory.path}/legacy.sqlite');
      final before = AppDatabase.forTesting(NativeDatabase(file));
      await before.backupDao.importBackup(await db.backupDao.exportBackup());
      await before.transactionsDao.saveTransaction(draft: draft(months: null));
      await before.close();
      final upgraded = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            raw.execute(
              'ALTER TABLE transactions DROP COLUMN installment_months',
            );
            raw.execute(
              'ALTER TABLE transaction_presets DROP COLUMN installment_months',
            );
            raw.execute('PRAGMA user_version = 28');
          },
        ),
      );
      try {
        final tx = (await upgraded.select(upgraded.transactions).get()).single;
        expect(tx.amount, 90000);
        expect(tx.installmentMonths, isNull);
        expect(
          await upgraded.select(upgraded.transactionPresets).get(),
          isEmpty,
        );
        expect(
          (await upgraded.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          29,
        );
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
