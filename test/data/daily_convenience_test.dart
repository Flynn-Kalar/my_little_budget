import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_backup_service.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/providers.dart';
import 'package:my_little_budget/features/transactions/transaction_csv.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/budget/daily_allowance.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late int account;
  late int category;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    account = (await db.accountsDao.getActiveAccounts()).first.id;
    category = (await db.categoriesDao.getActiveCategories('expense')).first.id;
  });
  tearDown(() => db.close());

  TransactionDraft draft({
    String type = 'expense',
    String memo = '편의점',
    int amount = 5000,
  }) => TransactionDraft(
    type: type,
    amount: amount,
    occurredOn: '2026-10-17',
    occurredTime: '12:30',
    accountId: account,
    categoryId: category,
    memo: memo,
  );

  test('recent input includes tags and excludes archived references', () async {
    await db.transactionsDao.saveTransaction(draft: draft(), tagNames: ['점심']);
    final entries = await db.transactionsDao.recentInputEntries();
    expect(entries.single.tags.single.name, '점심');
    await (db.update(db.accounts)..where((a) => a.id.equals(account))).write(
      const AccountsCompanion(archivedAt: Value('2026-10-17')),
    );
    expect(await db.transactionsDao.recentInputEntries(), isEmpty);
  });

  test(
    'cached suggestions update when account metadata is refreshed',
    () async {
      await db.transactionsDao.saveTransaction(draft: draft());
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(recentInputEntriesProvider.future),
        hasLength(1),
      );
      await (db.update(db.accounts)..where((a) => a.id.equals(account))).write(
        const AccountsCompanion(archivedAt: Value('2026-10-17')),
      );
      container.invalidate(activeAccountsProvider);
      expect(await container.read(recentInputEntriesProvider.future), isEmpty);
    },
  );

  test(
    'bulk editing preserves amounts, can clear tags, and rolls back invalid selection',
    () async {
      final first = await db.transactionsDao.saveTransaction(
        draft: draft(),
        tagNames: ['기존'],
      );
      final second = await db.transactionsDao.saveTransaction(
        draft: draft(amount: 8000),
      );
      final otherCategory = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).last.id;
      await db.transactionsDao.bulkEditTransactions(
        ids: {first, second},
        categoryId: otherCategory,
        tagNames: ['공통'],
      );
      expect(
        (await db.transactionsDao.getTransactionById(first))!.categoryId,
        otherCategory,
      );
      expect(
        (await db.transactionsDao.getTransactionById(second))!.amount,
        8000,
      );
      expect(
        (await db.transactionsDao.getTransactionById(second))!.tags.single.name,
        '공통',
      );
      final incomeCategory = (await db.categoriesDao.getActiveCategories(
        'income',
      )).first.id;
      await expectLater(
        db.transactionsDao.bulkEditTransactions(
          ids: {first, second},
          categoryId: incomeCategory,
          tagNames: ['잘못됨'],
        ),
        throwsStateError,
      );
      expect(
        (await db.transactionsDao.getTransactionById(first))!.tags.single.name,
        '공통',
      );
      await expectLater(
        db.transactionsDao.bulkEditTransactions(
          ids: {first, 999999},
          tagNames: [],
        ),
        throwsStateError,
      );
      await db.transactionsDao.bulkEditTransactions(
        ids: {first, second},
        tagNames: [],
      );
      expect(
        (await db.transactionsDao.getTransactionById(first))!.tags,
        isEmpty,
      );
    },
  );

  test(
    'CSV parser preserves quoted commas, quotes, newlines and rejects broken quoting',
    () {
      final rows = parseTransactionCsv(
        '\uFEFFa,b\r\n"one, two","say ""hi""\nnext"\r\n',
      );
      expect(rows[1], ['one, two', 'say "hi"\nnext']);
      expect(
        () => parseTransactionCsv('a,b\n"unclosed'),
        throwsFormatException,
      );
      expect(() => parseTransactionCsv('a,a\n1,2'), throwsFormatException);
    },
  );

  test(
    'CSV export roundtrips formula-like memo and tags and detects duplicates',
    () async {
      await db.transactionsDao.saveTransaction(
        draft: draft(memo: '=SUM(A1), "메모"\n다음 줄'),
        tagNames: ['태그;하나', '다른 태그'],
      );
      final exported = exportTransactionCsv(await db.backupDao.exportBackup());
      expect(exported, contains("'=SUM"));
      final rows = parseTransactionCsv(exported);
      final mapping = {
        for (var i = 0; i < transactionCsvColumns.length; i++)
          transactionCsvColumns[i]: i,
      };
      final service = TransactionCsvService(db);
      final checked = await service.preview(rows, mapping);
      expect(checked.invalid, 0);
      expect(checked.duplicates, 1);
      expect(await service.importRows(rows, mapping), 0);
      // Change the date and repeat the row: only the first new copy is imported.
      rows[1][0] = '2026-10-18';
      rows.add(List.of(rows[1]));
      expect((await service.preview(rows, mapping)).duplicates, 1);
      expect(await service.importRows(rows, mapping), 1);
      final imported = (await db.transactionsDao.listTransactionsByMonth(
        '2026-10',
      )).firstWhere((r) => r.occurredOn == '2026-10-18');
      expect(imported.memo, '=SUM(A1), "메모"\n다음 줄');
      expect(imported.tags.map((t) => t.name).toSet(), {'태그;하나', '다른 태그'});
    },
  );

  test('CSV invalid dates and missing accounts abort all imports', () async {
    await db.transactionsDao.saveTransaction(draft: draft());
    final rows = parseTransactionCsv(
      exportTransactionCsv(await db.backupDao.exportBackup()),
    );
    final mapping = {
      for (var i = 0; i < transactionCsvColumns.length; i++)
        transactionCsvColumns[i]: i,
    };
    rows[1][0] = '2026-10-18';
    rows.add(List.of(rows[1])..[0] = '2026-02-30');
    final service = TransactionCsvService(db);
    expect((await service.preview(rows, mapping)).invalid, 1);
    await expectLater(service.importRows(rows, mapping), throwsStateError);
    expect(
      (await db.transactionsDao.listTransactionsByMonth('2026-10')).length,
      1,
    );
    rows.removeLast();
    rows[1][4] = '없는 계좌';
    expect((await service.preview(rows, mapping)).invalid, 1);
  });

  test(
    'daily allowance counts today, floors remainder, handles past, future and leap day',
    () {
      final allowance = dailyAllowance(
        month: '2026-10',
        budget: 100001,
        spent: 10000,
        now: DateTime(2026, 10, 17),
      )!;
      expect(allowance.days, 15);
      expect(allowance.daily, 6000);
      expect(
        dailyAllowance(
          month: '2026-09',
          budget: 10,
          spent: 0,
          now: DateTime(2026, 10, 17),
        ),
        isNull,
      );
      expect(
        dailyAllowance(
          month: '2026-11',
          budget: 300,
          spent: 0,
          now: DateTime(2026, 10, 17),
        )!.days,
        30,
      );
      expect(
        dailyAllowance(
          month: '2024-02',
          budget: 10,
          spent: 11,
          now: DateTime(2024, 2, 29),
        )!.daily,
        0,
      );
    },
  );

  test(
    'local backup keeps seven atomic recovery points and safety capture preserves current state',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'budget-backup-test-',
      );
      final service = LocalBackupService(db, directory: folder);
      addTearDown(() async {
        service.dispose();
        await folder.delete(recursive: true);
      });
      await db.transactionsDao.saveTransaction(draft: draft());
      await service.capture();
      final firstFile = (await service.list()).single;
      final saved = await service.read(firstFile);
      expect(saved.transactions.length, 1);
      await service.captureIfDue();
      expect((await service.list()).length, 1);
      for (var i = 0; i < 8; i++) {
        await service.capture();
      }
      expect((await service.list()).length, 7);
      expect(
        await folder.list().where((f) => f.path.endsWith('.tmp')).isEmpty,
        isTrue,
      );
      await db.transactionsDao.saveTransaction(draft: draft(amount: 9000));
      final safety = await service.captureFresh();
      await db.backupDao.importBackup(saved);
      expect((await db.backupDao.exportBackup()).transactions.length, 1);
      expect((await service.read(safety!)).transactions.length, 2);
      await service.setEnabled(false);
      expect(await service.enabled, isFalse);
    },
  );

  test(
    'automatic backup failure is reported without removing a recovery point',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'budget-backup-failure-',
      );
      final working = LocalBackupService(db, directory: folder);
      final failing = _FailingBackupService(db, directory: folder);
      addTearDown(() async {
        working.dispose();
        failing.dispose();
        await folder.delete(recursive: true);
      });
      final saved = (await working.capture())!;
      final original = await saved.readAsString();
      await saved.setLastModified(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      await failing.captureIfDue();
      expect(failing.lastError, contains('disk full'));
      expect(await saved.readAsString(), original);
      expect(await working.list(), hasLength(1));
      await expectLater(
        failing.captureFresh(),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}

class _FailingBackupService extends LocalBackupService {
  _FailingBackupService(super.database, {super.directory});
  @override
  Future<File?> capture() =>
      Future.error(const FileSystemException('disk full'));
}
