import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/sync_metadata.dart';
import 'package:my_little_budget/data/sync_models.dart';
import 'package:my_little_budget/features/accounts/validation.dart';
import 'package:my_little_budget/features/categories/validation.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  test(
    'insert, update, and hard delete leave a durable outbox operation',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      await _markAllSyncedAndClearOutbox(db);
      final store = LocalSyncStore(db);

      final tagId = await db.tagsDao.createTag('outbox-tag', '#123456');
      final tag = await _rowById(db, 'tags', tagId);
      final uuid = tag['uuid']! as String;

      final inserted = await store.currentEntry('tags', uuid);
      expect(inserted, isNotNull);
      expect(inserted!.operation, 'upsert');
      expect(inserted.generation, 1);
      expect(await store.acknowledge(inserted), isTrue);
      expect(await _syncStatus(db, 'tags', uuid), syncStatusSynced);

      await db.tagsDao.updateTag(tagId, 'outbox-tag-updated', '#654321');
      final updated = await store.currentEntry('tags', uuid);
      expect(updated, isNotNull);
      expect(updated!.operation, 'upsert');
      expect(updated.generation, 1);
      expect(await store.acknowledge(updated), isTrue);

      await db.tagsDao.deleteTag(tagId);
      expect(await _rowByUuid(db, 'tags', uuid), isNull);

      final deleted = await store.currentEntry('tags', uuid);
      expect(deleted, isNotNull);
      expect(deleted!.operation, 'delete');
      expect(deleted.generation, 1);
      expect(deleted.changedAt, isNotEmpty);
      expect(deleted.tombstonePayload, {'name': 'outbox-tag-updated'});
      expect(await store.buildPayload('tags', uuid), isNull);
    },
  );

  test('a stale ACK cannot remove a newer generation', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final store = LocalSyncStore(db);

    final tagId = await db.tagsDao.createTag('generation-one', '#123456');
    final uuid = (await _rowById(db, 'tags', tagId))['uuid']! as String;
    final generationOne = await store.currentEntry('tags', uuid);
    expect(generationOne, isNotNull);
    expect(generationOne!.generation, 1);

    await db.tagsDao.updateTag(tagId, 'generation-two', '#abcdef');
    final generationTwo = await store.currentEntry('tags', uuid);
    expect(generationTwo, isNotNull);
    expect(generationTwo!.generation, 2);

    expect(await store.acknowledge(generationOne), isFalse);
    final stillPending = await store.currentEntry('tags', uuid);
    expect(stillPending, isNotNull);
    expect(stillPending!.generation, 2);
    expect(await _syncStatus(db, 'tags', uuid), syncStatusPending);
  });

  test(
    'relation payloads use UUIDs and resolve to target-local integer IDs',
    () async {
      final source = await _openDatabase();
      var sourceClosed = false;
      addTearDown(() async {
        if (!sourceClosed) await source.close();
      });

      await source.accountsDao.saveAccount(
        draft: const AccountDraft(
          name: 'source-account',
          kind: 'bank',
          initialBalance: 0,
          color: '#102030',
          excludeFromTotal: false,
          isInvestment: false,
        ),
        currentBalance: 10000,
      );
      await source.categoriesDao.saveCategory(
        draft: const CategoryDraft(
          name: 'source-category',
          type: 'expense',
          color: '#203040',
        ),
      );
      final sourceTagId = await source.tagsDao.createTag(
        'source-tag',
        '#304050',
      );
      final sourceAccount = await _rowByNaturalKey(
        source,
        'accounts',
        'name = ?',
        ['source-account'],
      );
      final sourceCategory = await _rowByNaturalKey(
        source,
        'categories',
        'name = ? AND type = ?',
        ['source-category', 'expense'],
      );
      final sourceTag = await _rowById(source, 'tags', sourceTagId);
      final transactionId = await source.transactionsDao.saveTransaction(
        draft: TransactionDraft(
          type: 'expense',
          amount: 4321,
          occurredOn: '2026-07-13',
          occurredTime: '09:30',
          accountId: sourceAccount['id']! as int,
          categoryId: sourceCategory['id']! as int,
        ),
        tagNames: const ['source-tag'],
      );
      final sourceTransaction = await _rowById(
        source,
        'transactions',
        transactionId,
      );

      final sourceStore = LocalSyncStore(source);
      final accountUuid = sourceAccount['uuid']! as String;
      final categoryUuid = sourceCategory['uuid']! as String;
      final tagUuid = sourceTag['uuid']! as String;
      final transactionUuid = sourceTransaction['uuid']! as String;
      final accountPayload = (await sourceStore.buildPayload(
        'accounts',
        accountUuid,
      ))!;
      final categoryPayload = (await sourceStore.buildPayload(
        'categories',
        categoryUuid,
      ))!;
      final tagPayload = (await sourceStore.buildPayload('tags', tagUuid))!;
      final transactionPayload = await sourceStore.buildPayload(
        'transactions',
        transactionUuid,
      );
      await source.close();
      sourceClosed = true;

      final target = await _openDatabase();
      addTearDown(target.close);

      // Shift target-local IDs so a successful import cannot accidentally rely
      // on source SQLite primary keys.
      await target.accountsDao.saveAccount(
        draft: const AccountDraft(
          name: 'target-dummy-account',
          kind: 'bank',
          initialBalance: 0,
          color: '#405060',
          excludeFromTotal: false,
          isInvestment: false,
        ),
        currentBalance: 0,
      );
      await target.categoriesDao.saveCategory(
        draft: const CategoryDraft(
          name: 'target-dummy-cat',
          type: 'expense',
          color: '#506070',
        ),
      );
      await target.tagsDao.createTag('target-dummy-tag', '#607080');

      final targetStore = LocalSyncStore(target);
      expect(transactionPayload, isNotNull);
      final encodedTransaction = transactionPayload!;
      expect(encodedTransaction.containsKey('id'), isFalse);
      expect(encodedTransaction.containsKey('account_id'), isFalse);
      expect(encodedTransaction.containsKey('category_id'), isFalse);
      expect(encodedTransaction['account_uuid'], accountUuid);
      expect(encodedTransaction['category_uuid'], categoryUuid);
      expect(encodedTransaction['tag_uuids'], [tagUuid]);

      await targetStore.applyRemotePage(
        entity: 'accounts',
        rows: [
          _remoteRow(uuid: accountUuid, payload: accountPayload, revision: 1),
        ],
        bootstrap: true,
      );
      await targetStore.applyRemotePage(
        entity: 'categories',
        rows: [
          _remoteRow(uuid: categoryUuid, payload: categoryPayload, revision: 2),
        ],
        bootstrap: true,
      );
      await targetStore.applyRemotePage(
        entity: 'tags',
        rows: [_remoteRow(uuid: tagUuid, payload: tagPayload, revision: 3)],
        bootstrap: true,
      );
      await targetStore.applyRemotePage(
        entity: 'transactions',
        rows: [
          _remoteRow(
            uuid: transactionUuid,
            payload: encodedTransaction,
            revision: 4,
          ),
        ],
        bootstrap: true,
      );

      final targetAccount = await _rowByUuid(target, 'accounts', accountUuid);
      final targetCategory = await _rowByUuid(
        target,
        'categories',
        categoryUuid,
      );
      final targetTag = await _rowByUuid(target, 'tags', tagUuid);
      final imported = await target
          .customSelect(
            '''
SELECT t.account_id, t.category_id, tt.tag_id
FROM transactions t
JOIN transaction_tags tt ON tt.transaction_id = t.id
WHERE t.uuid = ?
''',
            variables: [Variable<String>(transactionUuid)],
          )
          .getSingle();

      expect(targetAccount!['id'], isNot(sourceAccount['id']));
      expect(targetCategory!['id'], isNot(sourceCategory['id']));
      expect(targetTag!['id'], isNot(sourceTag['id']));
      expect(imported.read<int>('account_id'), targetAccount['id']);
      expect(imported.read<int>('category_id'), targetCategory['id']);
      expect(imported.read<int>('tag_id'), targetTag['id']);
    },
  );
}

Future<AppDatabase> _openDatabase() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  return db;
}

Future<void> _markAllSyncedAndClearOutbox(AppDatabase db) async {
  for (final table in localSyncTableNames) {
    await db.customStatement('UPDATE $table SET sync_status = ?', [
      syncStatusSynced,
    ]);
  }
  await db.customStatement('DELETE FROM sync_outbox');
}

Future<Map<String, Object?>> _rowById(
  AppDatabase db,
  String table,
  int id,
) async {
  final row = await db
      .customSelect(
        'SELECT * FROM $table WHERE id = ?',
        variables: [Variable<int>(id)],
      )
      .getSingle();
  return row.data;
}

Future<Map<String, Object?>?> _rowByUuid(
  AppDatabase db,
  String table,
  String uuid,
) async {
  final row = await db
      .customSelect(
        'SELECT * FROM $table WHERE uuid = ?',
        variables: [Variable<String>(uuid)],
      )
      .getSingleOrNull();
  return row?.data;
}

Future<Map<String, Object?>> _rowByNaturalKey(
  AppDatabase db,
  String table,
  String predicate,
  List<Object> values,
) async {
  final row = await db
      .customSelect(
        'SELECT * FROM $table WHERE $predicate',
        variables: [for (final value in values) Variable<Object>(value)],
      )
      .getSingle();
  return row.data;
}

Future<String> _syncStatus(AppDatabase db, String table, String uuid) async {
  final row = await db
      .customSelect(
        'SELECT sync_status FROM $table WHERE uuid = ?',
        variables: [Variable<String>(uuid)],
      )
      .getSingle();
  return row.read<String>('sync_status');
}

RemoteSyncRow _remoteRow({
  required String uuid,
  required Map<String, Object?> payload,
  required int revision,
}) {
  return RemoteSyncRow(
    uuid: uuid,
    payload: payload,
    updatedAt: DateTime.utc(
      2026,
      7,
      13,
    ).add(Duration(seconds: revision)).toIso8601String(),
    deletedAt: null,
    revision: revision,
  );
}
