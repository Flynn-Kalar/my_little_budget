import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/features/presets/validation.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'preset stores transaction values and applies the supplied current time',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final result = validateTransactionPreset(
        name: '',
        type: 'expense',
        amount: 12000,
        memo: '점심 식사',
        accountId: account.id,
        categoryId: category.id,
        tagNames: const ['식사', '자주'],
      );
      expect(result.isOk, isTrue);

      await db.transactionPresetsDao.savePreset(draft: result.value!);
      final item = (await db.transactionPresetsDao.listPresets()).single;

      expect(item.displayName, '점심 식사');
      expect(item.isUsable, isTrue);
      expect(item.tagNames, unorderedEquals(['식사', '자주']));
      final payload = await LocalSyncStore(
        db,
      ).buildPayload('transaction_presets', item.preset.uuid);
      expect(payload?['account_uuid'], account.uuid);
      expect(payload?['category_uuid'], category.uuid);
      final transaction = item.toDraft().toTransactionDraft(
        DateTime(2026, 7, 23, 21, 9),
      );
      expect(transaction.occurredOn, '2026-07-23');
      expect(transaction.occurredTime, '21:09');
      expect(transaction.amount, 12000);
    },
  );

  test(
    'archived references make a preset unavailable and restore repairs it',
    () async {
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final category = (await db.categoriesDao.getActiveCategories(
        'expense',
      )).first;
      final result = validateTransactionPreset(
        type: 'expense',
        amount: 1000,
        accountId: account.id,
        categoryId: category.id,
      );
      await db.transactionPresetsDao.savePreset(draft: result.value!);

      await db.accountsDao.archiveAccount(account.id);
      expect(
        (await db.transactionPresetsDao.listPresets()).single.isUsable,
        isFalse,
      );

      await db.accountsDao.restoreAccount(account.id);
      expect(
        (await db.transactionPresetsDao.listPresets()).single.isUsable,
        isTrue,
      );

      expect(await db.categoriesDao.deleteCategory(category.id), isNull);
      final unavailable = (await db.transactionPresetsDao.listPresets()).single;
      expect(unavailable.preset.categoryId, isNull);
      expect(unavailable.isUsable, isFalse);
    },
  );

  test('deleting a tag removes it from preset tag names', () async {
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final category = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    final tagId = await db.tagsDao.createTag('삭제할 태그', '#123456');
    final result = validateTransactionPreset(
      type: 'expense',
      amount: 1000,
      accountId: account.id,
      categoryId: category.id,
      tagNames: const ['삭제할 태그', '유지'],
    );
    await db.transactionPresetsDao.savePreset(draft: result.value!);

    await db.tagsDao.deleteTag(tagId);

    expect((await db.transactionPresetsDao.listPresets()).single.tagNames, [
      '유지',
    ]);
  });
}
