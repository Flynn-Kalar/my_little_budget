import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/sync_metadata.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/notes/checklist.dart';
import 'package:my_little_budget/features/recurring/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addExpense(int amount, String on, {String? memo}) async {
    final accId = (await db.accountsDao.getActiveAccounts()).first.id;
    final catId = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first.id;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: amount,
        occurredOn: on,
        occurredTime: '00:00',
        accountId: accId,
        categoryId: catId,
        memo: memo,
      ),
    );
  }

  group('export/import 라운드트립 (SPEC §5.2)', () {
    test('backup filename uses requested timestamp format', () {
      expect(
        buildBackupFilename(now: DateTime(2026, 6, 5, 9, 8, 7)),
        'my_little_budget-backup-20260605-090807.json',
      );
    });

    test('export → JSON → parse → import 후 데이터 일치', () async {
      await addExpense(5000, '2026-05-10', memo: '점심');
      await addExpense(3000, '2026-05-15', memo: '카페');

      await db.notesDao.saveNote(
        title: '백업할 메모',
        content: '메모 내용',
        reminderAt: DateTime.utc(2026, 6, 21, 9),
        pinned: true,
        checklistItems: const [
          ChecklistItemDraft(text: '백업 항목', isChecked: true),
        ],
      );
      await db.calendarEventsDao.saveEvent(
        title: '백업할 일정',
        description: '캘린더 백업 확인',
        startAt: DateTime(2026, 6, 22, 10),
        endAt: DateTime(2026, 6, 22, 11),
        allDay: false,
        color: '#2563eb',
      );

      final original = await db.backupDao.exportBackup();
      expect(original.transactions.length, 2);
      expect(original.accounts.length, 5);
      expect(original.categories.length, 14);
      expect(original.notes.length, 1);
      expect(original.noteChecklistItems.length, 1);
      expect(original.calendarEvents.length, 1);

      final json = original.toJsonString();
      final parsed = parseBackup(json);
      expect(parsed.isOk, true, reason: parsed.error);
      expect(parsed.backup!.calendarEvents.single.title, '백업할 일정');

      final db2 = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db2.close);
      await db2.backupDao.importBackup(parsed.backup!);

      final rows = await db2.transactionsDao.listTransactionsByMonth('2026-05');
      expect(rows.length, 2);
      expect(rows.map((r) => r.amount).toSet(), {5000, 3000});
      expect((await db2.accountsDao.getActiveAccounts()).length, 5);
      expect((await db2.categoriesDao.getAllCategories()).length, 14);
      final restoredNotes = await db2.notesDao.watchNotes().first;
      expect(restoredNotes.single.title, '백업할 메모');
      expect(restoredNotes.single.pinned, isTrue);
      final restoredEntry = await db2.notesDao.getNoteWithChecklist(
        restoredNotes.single.id,
      );
      expect(restoredEntry!.items.single.itemText, '백업 항목');
      expect(restoredEntry.items.single.isChecked, isTrue);
      final restoredEvents = await db2.calendarEventsDao.listEvents();
      expect(restoredEvents.single.title, '백업할 일정');
      expect(restoredEvents.single.description, '캘린더 백업 확인');
      expect(
        restoredEvents.single.startAt,
        DateTime(2026, 6, 22, 10).toUtc().toIso8601String(),
      );
    });

    test('bool 필드 0/1 호환 (구 Tauri export 호환)', () {
      const legacyJson = '''
{
  "version": 1,
  "appName": "my_little_budget",
  "exportedAt": "2026-05-01T00:00:00Z",
  "data": {
    "accounts": [
      {"id":1,"name":"테스트","kind":"bank","initialBalance":0,"color":"#000000",
       "excludeFromTotal":0,"isInvestment":1,"sortOrder":0,"archivedAt":null,
       "createdAt":"2026-05-01 00:00:00"}
    ],
    "categories":[], "budgetGroups":[], "budgetGroupCategories":[],
    "transactions":[], "investments":[], "tags":[], "transactionTags":[],
    "monthlyIncome":[], "recurringTransactions":[]
  }
}
''';
      final r = parseBackup(legacyJson);
      expect(r.isOk, true, reason: r.error);
      final acc = r.backup!.accounts.single;
      expect(acc.excludeFromTotal, false);
      expect(acc.isInvestment, true);
      expect(r.backup!.calendarEvents, isEmpty);
    });

    test('sync metadata 없는 기존 백업은 기본값으로 복원된다', () async {
      const legacyJson = '''
{
  "version": 1,
  "appName": "my_little_budget",
  "exportedAt": "2026-05-01T00:00:00Z",
  "data": {
    "accounts": [
      {"id":1,"name":"현금","kind":"cash","initialBalance":0,"color":"#000000",
       "excludeFromTotal":false,"isInvestment":false,"sortOrder":0,
       "archivedAt":null,"createdAt":"2026-05-01 00:00:00"}
    ],
    "categories":[], "budgetGroups":[], "budgetGroupCategories":[],
    "transactions":[], "investments":[], "tags":[], "transactionTags":[],
    "monthlyIncome":[], "recurringTransactions":[]
  }
}
''';

      final r = parseBackup(legacyJson);

      expect(r.isOk, true, reason: r.error);
      final acc = r.backup!.accounts.single;
      expect(acc.uuid, isNotEmpty);
      expect(acc.updatedAt, '2026-05-01 00:00:00');
      expect(acc.deletedAt, isNull);
      expect(acc.syncStatus, syncStatusPending);

      await db.backupDao.importBackup(r.backup!);
      final row = await db.customSelect('''
SELECT uuid, updated_at, deleted_at, sync_status
FROM accounts
WHERE id = 1
''').getSingle();
      expect(row.read<String>('uuid'), acc.uuid);
      expect(row.read<String>('updated_at'), '2026-05-01 00:00:00');
      expect(row.readNullable<String>('deleted_at'), isNull);
      expect(row.read<String>('sync_status'), syncStatusPending);
    });

    test('잘못된 JSON / 버전 / appName 거부', () {
      expect(parseBackup('not json').isOk, false);
      expect(
        parseBackup(
          '{"version":2,"appName":"my_little_budget","data":{}}',
        ).isOk,
        false,
      );
      expect(
        parseBackup('{"version":1,"appName":"other","data":{}}').isOk,
        false,
      );
    });
  });

  group('resetAllData (SPEC §4.8.5)', () {
    test('참조 테이블을 먼저 지우고 기본 자산/카테고리를 복구한다', () async {
      await addExpense(5000, '2026-05-10');

      final accId = (await db.accountsDao.getActiveAccounts()).first.id;
      final catId = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first.id;

      await db.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 7000,
          occurredOn: '2026-05-11',
          occurredTime: '08:30',
          accountId: accId,
          categoryId: catId,
        ),
        tagNames: const ['고정'],
      );
      await db.budgetDao.createBudgetGroup(
        name: '생활비',
        month: '2026-05',
        amount: 300000,
        categoryIds: [catId],
      );
      await db.recurringDao.saveRecurring(
        draft: RecurringDraft(
          name: '월세',
          type: 'expense',
          amount: 500000,
          frequency: 'monthly',
          occurredTime: '09:00',
          startDate: '2026-05-01',
          dayOfMonth: 1,
          accountId: accId,
          categoryId: catId,
          tagNames: const ['고정'],
        ),
      );
      await db.calendarEventsDao.saveEvent(
        title: '초기화할 일정',
        startAt: DateTime(2026, 5, 12, 9),
      );
      await db.accountsDao.saveAccount(
        draft: const AccountDraft(
          name: '사용자추가자산',
          kind: 'bank',
          initialBalance: 50000,
          color: '#123456',
          excludeFromTotal: false,
          isInvestment: false,
        ),
        currentBalance: 50000,
      );
      expect((await db.accountsDao.getActiveAccounts()).length, 6);

      await db.backupDao.resetAllData();

      final accts = await db.accountsDao.getActiveAccounts();
      expect(accts.length, 5);
      expect(accts.every((a) => a.initialBalance == 0), true);
      expect(accts.any((a) => a.name == '사용자추가자산'), false);
      expect(accts.where((a) => a.isInvestment).length, 1);
      expect(accts.firstWhere((a) => a.name == '투자').isInvestment, true);

      final cats = await db.categoriesDao.getAllCategories();
      expect(cats.length, 14);

      expect(
        await db.transactionsDao.listTransactionsByMonth('2026-05'),
        isEmpty,
      );
      expect(await db.budgetDao.listBudgetGroups('2026-05'), isEmpty);
      expect(await db.recurringDao.listRecurringTransactions(), isEmpty);
      expect(await db.tagsDao.getTags(), isEmpty);
      expect(await db.calendarEventsDao.listEvents(), isEmpty);
    });
  });

  test('일정 필드가 없는 기존 메모 백업을 1회 알림으로 변환한다', () {
    const legacyJson = '''
{
  "version": 1,
  "appName": "my_little_budget",
  "exportedAt": "2026-05-01T00:00:00Z",
  "data": {
    "accounts": [], "categories": [], "budgetGroups": [],
    "budgetGroupCategories": [], "transactions": [], "investments": [],
    "tags": [], "transactionTags": [], "monthlyIncome": [],
    "recurringTransactions": [],
    "notes": [
      {"id":1,"title":"기존 알림","content":"","reminderAt":"2026-06-01T09:00:00Z",
       "completed":0,"pinned":0,"createdAt":"2026-05-01 00:00:00",
       "updatedAt":"2026-05-01 00:00:00"}
    ]
  }
}
''';
    final result = parseBackup(legacyJson);
    expect(result.isOk, isTrue, reason: result.error);
    expect(result.backup!.notes.single.scheduleType, 'once');
    expect(result.backup!.notes.single.notificationEnabled, isTrue);
  });
}
