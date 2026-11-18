import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;
  late Account bank;
  late Account card;
  final today = DateTime(2026, 11, 10);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = await db.accountsDao.getActiveAccounts();
    bank = accounts.firstWhere((a) => a.kind == 'bank');
    card = accounts.firstWhere((a) => a.kind == 'card');
  });
  tearDown(() => db.close());

  AccountDraft draft(Account account, {bool configured = false}) =>
      AccountDraft(
        name: account.name,
        kind: account.kind,
        initialBalance: 0,
        color: account.color,
        excludeFromTotal: false,
        isInvestment: false,
        cardPaymentDay: configured ? 14 : null,
        cardClosingDay: configured ? 31 : null,
        cardPaymentAccountUuid: configured ? bank.uuid : null,
      );

  Future<void> expense(Account account, int amount, String date) async {
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: amount,
        occurredOn: date,
        occurredTime: '12:00',
        accountId: account.id,
        categoryId: category.id,
      ),
    );
  }

  test('card spending excludes prior months and repayment transfers', () async {
    await expense(card, 100000, '2026-10-31');
    await expense(card, 30000, '2026-11-05');
    await expense(card, 50000, '2026-11-20');
    await expense(card, 90000, '2026-12-01');
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'transfer',
        amount: 100000,
        occurredOn: '2026-11-06',
        occurredTime: '09:00',
        fromAccountId: bank.id,
        toAccountId: card.id,
      ),
    );
    final result = (await db.accountsDao.getAccountBalance(
      card.id,
      asOf: today,
    ))!;
    expect(result.cardSpendingToDate, 30000);
    expect(result.cardMonthSpending, 80000);
    expect(result.balance, -30000);
    final nextMonth = (await db.accountsDao.getAccountBalance(
      card.id,
      asOf: DateTime(2026, 12, 2),
    ))!;
    expect(nextMonth.cardSpendingToDate, 90000);
    expect(nextMonth.cardMonthSpending, 90000);
  });

  test(
    'card spending correction changes today usage and preserves prior bill and future transactions',
    () async {
      await expense(card, 100000, '2026-10-31');
      await expense(card, 30000, '2026-11-05');
      await expense(card, 50000, '2026-11-20');
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: 0,
        currentCardSpending: 20000,
        asOf: today,
      );
      final result = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      expect(result.cardSpendingToDate, 20000);
      expect(result.cardMonthSpending, 70000);
      expect(result.balance, -120000);
      expect(result.projectedBalance, -170000);
      expect(result.cardBilling!.dueAmount, 100000);
      expect(result.cardBilling!.laterAmount, 70000);
      final count = (await db.select(db.transactions).get()).length;
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: 0,
        currentCardSpending: 20000,
        asOf: today,
      );
      expect(await db.select(db.transactions).get(), hasLength(count));
    },
  );

  test(
    'card spending obeys custom period and deducts card refund income',
    () async {
      await expense(card, 100000, '2026-10-29');
      await expense(card, 20000, '2026-10-30');
      await expense(card, 30000, '2026-11-05');
      await expense(card, 40000, '2026-11-28');
      await expense(card, 50000, '2026-11-29');
      final income = (await db.categoriesDao.getActiveCategories(
        'income',
      )).first;
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'income',
          amount: 5000,
          occurredOn: '2026-11-06',
          occurredTime: '09:00',
          accountId: card.id,
          categoryId: income.id,
        ),
      );
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card),
        currentBalance: 0,
        currentCardSpending: 40000,
        asOf: today,
        statementStart: '2026-10-30',
        statementEnd: '2026-11-28',
      );
      final result = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
        statementStart: '2026-10-30',
        statementEnd: '2026-11-28',
      ))!;
      expect(result.cardSpendingToDate, 40000);
      expect(result.cardMonthSpending, 80000);
      expect(result.balance, -140000);
    },
  );

  test(
    'new card records entered usage on today and it does not carry into next month spending',
    () async {
      await db.accountsDao.saveAccount(
        draft: const AccountDraft(
          name: '새 카드',
          kind: 'card',
          initialBalance: 0,
          color: '#000000',
          excludeFromTotal: false,
          isInvestment: false,
        ),
        currentBalance: 0,
        currentCardSpending: 55000,
        asOf: today,
      );
      final account = (await db.accountsDao.getActiveAccounts()).singleWhere(
        (a) => a.name == '새 카드',
      );
      final result = (await db.accountsDao.getAccountBalance(
        account.id,
        asOf: today,
      ))!;
      expect(result.cardSpendingToDate, 55000);
      expect(result.cardMonthSpending, 55000);
      expect(result.balance, -55000);
      final nextMonth = (await db.accountsDao.getAccountBalance(
        account.id,
        asOf: DateTime(2026, 12, 2),
      ))!;
      expect(nextMonth.cardSpendingToDate, 0);
      expect(nextMonth.balance, -55000);
    },
  );

  test(
    'editing card balance uses today and keeps upcoming spending unchanged',
    () async {
      await expense(card, 100000, '2026-11-05');
      await expense(card, 50000, '2026-11-20');
      await expense(card, 90000, '2026-12-01');
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card),
        currentBalance: -80000,
        asOf: today,
      );
      final result = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      expect(result.balance, -80000);
      expect(result.projectedBalance, -130000);
      final adjustments = await (db.select(
        db.transactions,
      )..where((t) => t.type.equals('adjustment'))).get();
      expect(adjustments.single.amount, 20000);
      expect(adjustments.single.occurredOn, '2026-11-10');
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: -80000,
        asOf: today,
      );
      expect(
        await (db.select(
          db.transactions,
        )..where((t) => t.type.equals('adjustment'))).get(),
        hasLength(1),
      );
    },
  );

  test(
    'bank transfer only affects expected balances before its scheduled day',
    () async {
      await db.accountsDao.saveAccount(
        id: bank.id,
        draft: draft(bank),
        currentBalance: 1000000,
        asOf: today,
      );
      await expense(card, 200000, '2026-10-30');
      await expense(card, 50000, '2026-11-05');
      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'transfer',
          amount: 200000,
          occurredOn: '2026-11-16',
          occurredTime: '09:00',
          fromAccountId: bank.id,
          toAccountId: card.id,
        ),
      );
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: -250000,
        asOf: today,
      );
      final balances = await db.accountsDao.getAccountBalances(asOf: today);
      final bankBalance = balances.singleWhere((a) => a.accountId == bank.id);
      final cardBalance = balances.singleWhere((a) => a.accountId == card.id);
      expect(bankBalance.balance, 1000000);
      expect(bankBalance.projectedBalance, 800000);
      expect(cardBalance.balance, -250000);
      expect(cardBalance.projectedBalance, -50000);
      expect(cardBalance.cardBilling!.dueAmount, 200000);
      expect(cardBalance.cardBilling!.laterAmount, 50000);
      expect(cardBalance.cardPaymentAccountName, bank.name);
      expect(
        balances.fold<int>(0, (sum, a) => sum + a.balance),
        balances.fold<int>(0, (sum, a) => sum + a.projectedBalance),
      );
      final paid = (await db.accountsDao.getAccountBalance(
        card.id,
        asOf: DateTime(2026, 11, 16),
      ))!;
      expect(paid.cardBilling!.dueAmount, 0);
      expect(paid.cardBilling!.laterAmount, 50000);
    },
  );

  test(
    'custom statement end applies to projections for every asset type',
    () async {
      await expense(bank, 10000, '2026-11-20');
      await expense(bank, 20000, '2026-11-29');
      final result = (await db.accountsDao.getAccountBalances(
        asOf: today,
        statementEnd: '2026-11-28',
      )).singleWhere((a) => a.accountId == bank.id);
      expect(result.balance, 0);
      expect(result.projectedBalance, -10000);
    },
  );

  test(
    'unconfigured cards do not show an invented bill; linked accounts are protected',
    () async {
      expect(
        (await db.accountsDao.getAccountBalance(
          card.id,
          asOf: today,
        ))!.cardBilling,
        isNull,
      );
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: 0,
        asOf: today,
      );
      expect(await db.accountsDao.getAccountUsageCount(bank.id), 1);
      await db.accountsDao.archiveAccount(bank.id);
      expect(
        (await db.accountsDao.getAccountBalance(
          card.id,
          asOf: today,
        ))!.cardPaymentAccountName,
        '${bank.name} (보관됨)',
      );
    },
  );

  test(
    'backup preserves card settings and older backups leave settings empty',
    () async {
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: 0,
        asOf: today,
      );
      final backup = await db.backupDao.exportBackup();
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.backupDao.importBackup(
        parseBackup(backup.toJsonString()).backup!,
      );
      final restored = (await target.accountsDao.getAccountBalance(
        card.id,
        asOf: today,
      ))!;
      expect(restored.cardPaymentDay, 14);
      expect(restored.cardClosingDay, 31);
      expect(restored.cardPaymentAccountUuid, bank.uuid);
      expect(restored.cardPaymentAccountName, bank.name);
      final legacy = jsonDecode(backup.toJsonString()) as Map<String, dynamic>;
      for (final account in legacy['data']['accounts'] as List) {
        (account as Map).removeWhere(
          (key, value) => [
            'cardPaymentDay',
            'cardClosingDay',
            'cardPaymentAccountUuid',
          ].contains(key),
        );
      }
      final parsed = parseBackup(jsonEncode(legacy));
      expect(parsed.isOk, isTrue, reason: parsed.error);
      expect(
        parsed.backup!.accounts
            .firstWhere((a) => a.id == card.id)
            .cardPaymentDay,
        isNull,
      );
    },
  );

  test(
    'sync preserves UUID connection across different local IDs and old clients',
    () async {
      await db.accountsDao.saveAccount(
        id: card.id,
        draft: draft(card, configured: true),
        currentBalance: 0,
        asOf: today,
      );
      final sourceStore = LocalSyncStore(db);
      final target = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(target.close);
      await target.accountsDao.getActiveAccounts();
      await target.customStatement('DELETE FROM accounts');
      await target.customStatement('DELETE FROM sync_outbox');
      final targetStore = LocalSyncStore(target);
      RemoteSyncRow remote(
        Account account,
        Map<String, Object?> payload,
        int revision,
      ) => RemoteSyncRow(
        uuid: account.uuid,
        payload: payload,
        updatedAt: '2026-11-10T12:00:00Z',
        deletedAt: null,
        revision: revision,
      );
      final bankPayload = (await sourceStore.buildPayload(
        'accounts',
        bank.uuid,
      ))!;
      final cardPayload = (await sourceStore.buildPayload(
        'accounts',
        card.uuid,
      ))!;
      await targetStore.applyRemotePage(
        entity: 'accounts',
        rows: [remote(card, cardPayload, 1), remote(bank, bankPayload, 2)],
        bootstrap: false,
      );
      final result = (await target.accountsDao.getAccountBalances(
        asOf: today,
      )).singleWhere((a) => a.uuid == card.uuid);
      expect(result.accountId, isNot(card.id));
      expect(result.cardPaymentAccountName, bank.name);
      final legacyPayload = Map<String, Object?>.from(cardPayload)
        ..removeWhere(
          (key, _) =>
              key.startsWith('card_payment_') || key == 'card_closing_day',
        );
      legacyPayload['name'] = '이전 앱에서 이름 변경';
      await targetStore.applyRemotePage(
        entity: 'accounts',
        rows: [remote(card, legacyPayload, 3)],
        bootstrap: false,
      );
      final updated = (await target.accountsDao.getAccountBalances(
        asOf: today,
      )).singleWhere((a) => a.uuid == card.uuid);
      expect(updated.name, '이전 앱에서 이름 변경');
      expect(updated.cardPaymentDay, 14);
      expect(updated.cardPaymentAccountUuid, bank.uuid);
    },
  );
}
