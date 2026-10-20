import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/bulk_management.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/tag_category_links.dart';
import 'package:my_little_budget/features/categories/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/features/presets/validation.dart';
import 'package:my_little_budget/features/recurring/validation.dart';
import 'package:my_little_budget/features/investments/validation.dart';
import 'package:my_little_budget/features/notes/checklist.dart';

void main() {
  late AppDatabase db;
  late BulkManagement bulk;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bulk = BulkManagement(db);
  });
  tearDown(() => db.close());
  Future<int> expense(int category, {List<String> tags = const []}) async {
    final account = (await db.accountsDao.getActiveAccounts()).first;
    return db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 5000,
        occurredOn: '2026-10-21',
        occurredTime: '12:00',
        accountId: account.id,
        categoryId: category,
      ),
      tagNames: tags,
    );
  }

  test(
    'category batch rolls back earlier deletes and tag cleanup when one category is in use',
    () async {
      final used = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      await db.categoriesDao.saveCategory(
        draft: const CategoryDraft(
          name: '미사용',
          type: 'expense',
          color: '#123456',
        ),
      );
      final free = (await db.categoriesDao.getAllCategories()).singleWhere(
        (c) => c.name == '미사용',
      );
      await expense(used.id);
      await db.tagsDao.createTag(
        '보존',
        '#123456',
        categoryIds: [free.id, used.id],
      );
      final before = (await db.tagsDao.getTags()).single;
      final outbox = (await LocalSyncStore(db).pendingEntries()).length;
      await expectLater(
        bulk.apply(BulkEntity.categories, {
          free.id,
          used.id,
        }, BulkOperation.delete),
        throwsStateError,
      );
      expect(
        (await db.categoriesDao.getAllCategories()).any((c) => c.id == free.id),
        isTrue,
      );
      expect(
        (await db.tagsDao.getTags()).single.categoryIdsJson,
        before.categoryIdsJson,
      );
      expect((await LocalSyncStore(db).pendingEntries()).length, outbox);
      await bulk.apply(BulkEntity.categories, {free.id}, BulkOperation.delete);
      expect(
        readTagCategoryIds((await db.tagsDao.getTags()).single.categoryIdsJson),
        [used.id],
      );
    },
  );

  test(
    'tag category add/replace/remove preserves metadata; invalid selection changes nothing',
    () async {
      final categories = await db.categoriesDao.getActiveCategories('expense');
      final a = await db.tagsDao.createTag(
        'A',
        '#123456',
        categoryIds: [categories[0].id],
      );
      final b = await db.tagsDao.createTag(
        'B',
        '#654321',
        categoryIds: [categories[1].id],
      );
      await db.tagsDao.setTagPinned(a, true);
      await expense(categories[0].id, tags: ['A']);
      final original = (await db.tagsDao.getTags()).firstWhere(
        (t) => t.id == a,
      );
      await bulk.assignTagCategories(
        {a, b},
        {categories[2].id},
        BulkTagCategoryMode.add,
      );
      var tags = await db.tagsDao.getTags();
      expect(
        readTagCategoryIds(tags.firstWhere((t) => t.id == a).categoryIdsJson),
        unorderedEquals([categories[0].id, categories[2].id]),
      );
      expect(tags.firstWhere((t) => t.id == a).color, original.color);
      expect(tags.firstWhere((t) => t.id == a).isPinned, original.isPinned);
      expect(tags.firstWhere((t) => t.id == a).usageCount, original.usageCount);
      expect(tags.firstWhere((t) => t.id == a).lastUsedAt, original.lastUsedAt);
      await bulk.assignTagCategories(
        {a, b},
        {categories[2].id},
        BulkTagCategoryMode.remove,
      );
      expect(
        readTagCategoryIds((await db.tagsDao.getTags()).first.categoryIdsJson),
        [categories[0].id],
      );
      await bulk.assignTagCategories(
        {a, b},
        {categories[1].id},
        BulkTagCategoryMode.replace,
      );
      tags = await db.tagsDao.getTags();
      await expectLater(
        bulk.assignTagCategories({a, b}, {999999}, BulkTagCategoryMode.replace),
        throwsStateError,
      );
      expect(
        (await db.tagsDao.getTags()).map((t) => t.categoryIdsJson),
        tags.map((t) => t.categoryIdsJson),
      );
      await bulk.assignTagCategories({a, b}, {}, BulkTagCategoryMode.replace);
      expect(
        (await db.tagsDao.getTags()).every((t) => t.categoryIdsJson == '[]'),
        isTrue,
      );
      await expectLater(
        bulk.assignTagCategories({a}, {}, BulkTagCategoryMode.add),
        throwsArgumentError,
      );
    },
  );

  test(
    'tag batch removes transaction and preset links and leaves financial entries intact',
    () async {
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final tx = await expense(category.id, tags: ['A', 'B', 'C']);
      await db.transactionPresetsDao.savePreset(
        draft: TransactionPresetDraft(
          type: 'expense',
          amount: 5000,
          accountId: account.id,
          categoryId: category.id,
          tagNames: const ['A', 'B', 'C'],
        ),
      );
      final tags = await db.tagsDao.getTags();
      final selected = tags.where((t) => t.name != 'C').toList();
      await bulk.apply(
        BulkEntity.tags,
        selected.map((t) => t.id).toSet(),
        BulkOperation.delete,
      );
      final transaction = (await db.transactionsDao.getTransactionById(tx))!;
      expect(transaction.amount, 5000);
      expect(transaction.tags.map((t) => t.name), ['C']);
      expect((await db.transactionPresetsDao.listPresets()).single.tagNames, [
        'C',
      ]);
      for (final tag in selected) {
        expect(
          (await LocalSyncStore(db).currentEntry('tags', tag.uuid))!.operation,
          'delete',
        );
      }
    },
  );

  test(
    'account archive preserves history and stale selection does not archive any account',
    () async {
      final accounts = await db.accountsDao.getActiveAccounts();
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final tx = await expense(category.id);
      await expectLater(
        bulk.apply(BulkEntity.accounts, {
          accounts.first.id,
          999999,
        }, BulkOperation.archive),
        throwsStateError,
      );
      expect(
        (await db.accountsDao.getActiveAccounts()).length,
        accounts.length,
      );
      await bulk.apply(BulkEntity.accounts, {
        accounts[0].id,
        accounts[1].id,
      }, BulkOperation.archive);
      expect(
        (await db.accountsDao.getActiveAccounts()).length,
        accounts.length - 2,
      );
      expect(
        (await db.transactionsDao.getTransactionById(tx))!.accountId,
        accounts.first.id,
      );
      await expectLater(
        bulk.apply(BulkEntity.accounts, {}, BulkOperation.archive),
        throwsArgumentError,
      );
    },
  );

  test(
    'notes, calendar, recurring, presets, budget and investments support atomic batch actions',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final ids = <BulkEntity, Set<int>>{
        for (final entity in BulkEntity.values) entity: {},
      };
      for (var i = 0; i < 2; i++) {
        ids[BulkEntity.notes]!.add(
          await db.notesDao.saveNote(
            title: '메모$i',
            content: '내용',
            checklistItems: const [ChecklistItemDraft(text: '항목')],
          ),
        );
        ids[BulkEntity.calendar]!.add(
          await db.calendarEventsDao.saveEvent(
            title: '일정$i',
            startAt: DateTime(2026, 10, 21),
          ),
        );
        ids[BulkEntity.recurring]!.add(
          await db.recurringDao.saveRecurring(
            draft: RecurringDraft(
              name: '반복$i',
              type: 'expense',
              amount: 100,
              frequency: 'monthly',
              dayOfMonth: 1,
              occurredTime: '09:00',
              startDate: '2026-10-01',
              accountId: account.id,
              categoryId: category.id,
            ),
          ),
        );
        ids[BulkEntity.presets]!.add(
          await db.transactionPresetsDao.savePreset(
            draft: TransactionPresetDraft(
              name: '프리셋$i',
              type: 'expense',
              amount: 100,
              accountId: account.id,
              categoryId: category.id,
            ),
          ),
        );
        ids[BulkEntity.budgets]!.add(
          await db.budgetDao.createBudgetGroup(
            name: '예산$i',
            month: '2026-10',
            amount: 1000,
            categoryIds: [category.id],
          ),
        );
        ids[BulkEntity.investments]!.add(
          await db.investmentsDao.saveInvestment(
            draft: InvestmentDraft(
              side: 'buy',
              ticker: 'TEST$i',
              occurredOn: '2026-10-21',
              occurredTime: '09:00',
              quantity: 1,
              totalAmount: 100,
            ),
          ),
        );
      }
      await bulk.apply(
        BulkEntity.notes,
        ids[BulkEntity.notes]!,
        BulkOperation.pin,
      );
      expect(
        (await db.notesDao.listNotes()).every((note) => note.pinned),
        isTrue,
      );
      await bulk.apply(
        BulkEntity.notes,
        ids[BulkEntity.notes]!,
        BulkOperation.unpin,
      );
      expect(
        (await db.notesDao.listNotes()).every((note) => !note.pinned),
        isTrue,
      );
      await bulk.apply(
        BulkEntity.recurring,
        ids[BulkEntity.recurring]!,
        BulkOperation.disable,
      );
      expect(
        (await db.recurringDao.listRecurringTransactions()).every(
          (row) => !row.recurring.active,
        ),
        isTrue,
      );
      await bulk.apply(
        BulkEntity.recurring,
        ids[BulkEntity.recurring]!,
        BulkOperation.enable,
      );
      expect(
        (await db.recurringDao.listRecurringTransactions()).every(
          (row) => row.recurring.active,
        ),
        isTrue,
      );
      for (final entity in [
        BulkEntity.notes,
        BulkEntity.calendar,
        BulkEntity.recurring,
        BulkEntity.presets,
        BulkEntity.budgets,
        BulkEntity.investments,
      ]) {
        await expectLater(
          bulk.apply(entity, {...ids[entity]!, 999999}, BulkOperation.delete),
          throwsStateError,
        );
        expect(
          (await db.customSelect('SELECT id FROM ${entity.table}').get())
              .length,
          2,
        );
        await bulk.apply(entity, ids[entity]!, BulkOperation.delete);
        expect(
          await db.customSelect('SELECT id FROM ${entity.table}').get(),
          isEmpty,
        );
      }
      expect(
        await db.customSelect('SELECT id FROM note_checklist_items').get(),
        isEmpty,
      );
    },
  );
}
