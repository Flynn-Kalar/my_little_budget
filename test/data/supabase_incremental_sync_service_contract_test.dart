import 'dart:async';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_incremental_sync_service.dart';
import 'package:my_little_budget/data/sync_metadata.dart';
import 'package:my_little_budget/data/sync_models.dart';

const _settings = SupabaseBackupSettings(
  url: 'https://unit-test.supabase.co',
  anonKey: 'anon-key',
  bucket: '',
  authEmail: 'user@example.com',
);

void main() {
  test(
    'full sync reports monotonic percentage through the upload phase',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      await _markAllSyncedAndClearOutbox(db);
      final remote = _FakeSupabaseSyncGateway();
      final service = SupabaseIncrementalSyncService(
        local: LocalSyncStore(db),
        remote: remote,
      );
      await db.tagsDao.createTag('progress-one', '#123456');
      await db.tagsDao.createTag('progress-two', '#654321');
      final progress = <SyncProgress>[];

      final result = await service.synchronize(
        _settings,
        onProgress: progress.add,
      );

      expect(result.isOk, isTrue, reason: result.error);
      expect(progress.first.percent, 0);
      expect(progress.map((item) => item.percent), contains(60));
      expect(
        progress.any((item) => item.percent > 60 && item.percent < 100),
        isTrue,
      );
      expect(progress.last.percent, 100);
      for (var index = 1; index < progress.length; index++) {
        expect(
          progress[index].percent,
          greaterThanOrEqualTo(progress[index - 1].percent),
        );
      }
    },
  );

  test('failed upload keeps the outbox entry for a later retry', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final local = LocalSyncStore(db);
    final remote = _FakeSupabaseSyncGateway();
    final service = SupabaseIncrementalSyncService(
      local: local,
      remote: remote,
    );

    final tagId = await db.tagsDao.createTag('offline-tag', '#123456');
    final uuid = await _uuidForId(db, 'tags', tagId);
    final original = await local.currentEntry('tags', uuid);
    remote.nextUpsertFailure = StateError('offline');

    final failed = await service.pushPending(_settings);

    expect(failed.isOk, isFalse);
    expect(failed.error, contains('offline'));
    expect(failed.uploaded, 0);
    expect(await local.currentEntry('tags', uuid), isNotNull);
    expect(
      (await local.currentEntry('tags', uuid))!.generation,
      original!.generation,
    );

    final retried = await service.pushPending(_settings);

    expect(retried.isOk, isTrue, reason: retried.error);
    expect(retried.uploaded, 1);
    expect(await local.currentEntry('tags', uuid), isNull);
    expect(await _syncStatus(db, 'tags', uuid), syncStatusSynced);
  });

  test(
    'an edit during upload survives the stale ACK and retries in the same run',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      await _markAllSyncedAndClearOutbox(db);
      final local = LocalSyncStore(db);
      final remote = _FakeSupabaseSyncGateway();
      final service = SupabaseIncrementalSyncService(
        local: local,
        remote: remote,
      );

      final tagId = await db.tagsDao.createTag('first-name', '#123456');
      final uuid = await _uuidForId(db, 'tags', tagId);
      final release = Completer<void>();
      final started = remote.blockNextUpsert(release);

      final firstPush = service.pushPending(_settings);
      await started;
      await db.tagsDao.updateTag(tagId, 'second-name', '#654321');
      release.complete();

      final firstResult = await firstPush;
      final newerEntry = await local.currentEntry('tags', uuid);
      expect(firstResult.isOk, isTrue, reason: firstResult.error);
      expect(firstResult.uploaded, 1);
      expect(newerEntry, isNull);
      expect(await _syncStatus(db, 'tags', uuid), syncStatusSynced);
      expect(remote.upsertCalls.first.payload['name'], 'first-name');
      expect(remote.upsertCalls.last.payload['name'], 'second-name');

      final secondResult = await service.pushPending(_settings);

      expect(secondResult.isOk, isTrue, reason: secondResult.error);
      expect(secondResult.uploaded, 0);
      expect(await local.currentEntry('tags', uuid), isNull);
    },
  );

  test('a new edit jumps ahead of an active full-sync backlog', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final remote = _FakeSupabaseSyncGateway();
    final service = SupabaseIncrementalSyncService(
      local: LocalSyncStore(db),
      remote: remote,
      uploadChunkSize: 1,
    );
    await db.tagsDao.createTag('older-one', '#111111');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.tagsDao.createTag('older-two', '#222222');
    final release = Completer<void>();
    final started = remote.blockNextUpsert(release);

    final push = service.pushPending(_settings);
    await started;
    await db.tagsDao.createTag('new-user-edit', '#333333');
    release.complete();

    final result = await push;

    expect(result.isOk, isTrue, reason: result.error);
    expect(remote.upsertCalls[1].payload['name'], 'new-user-edit');
  });

  test(
    'bootstrap merges random-UUID seed rows by natural key and then uses a cursor',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      final local = LocalSyncStore(db);
      final remote = _FakeSupabaseSyncGateway();
      final service = SupabaseIncrementalSyncService(
        local: local,
        remote: remote,
      );
      const remoteCashUuid = '00000000-0000-4000-8000-000000000001';
      remote.seed(
        'accounts',
        const RemoteSyncRow(
          uuid: remoteCashUuid,
          payload: {
            'name': '현금',
            'kind': 'cash',
            'initial_balance': 12345,
            'card_limit': null,
            'color': '#010203',
            'exclude_from_total': false,
            'is_investment': false,
            'sort_order': 2,
            'archived_at': null,
            'created_at': '2026-01-01T00:00:00.000Z',
          },
          updatedAt: '2026-07-13T00:00:07.000Z',
          deletedAt: null,
          revision: 7,
        ),
      );

      final first = await service.synchronize(_settings);

      expect(first.isOk, isTrue, reason: first.error);
      expect(first.downloaded, 1);
      final cashRows = await db
          .customSelect(
            'SELECT uuid, color, initial_balance, sync_status '
            'FROM accounts WHERE name = ?',
            variables: const [Variable<String>('현금')],
          )
          .get();
      expect(cashRows, hasLength(1));
      expect(cashRows.single.read<String>('uuid'), remoteCashUuid);
      expect(cashRows.single.read<String>('color'), '#010203');
      expect(cashRows.single.read<int>('initial_balance'), 12345);
      expect(cashRows.single.read<String>('sync_status'), syncStatusSynced);
      expect(
        remote.upsertCalls.where((call) => call.uuid == remoteCashUuid),
        isEmpty,
      );
      expect(await local.cursor('accounts'), 7);

      remote.fetchCalls.clear();
      final second = await service.synchronize(_settings);

      expect(second.isOk, isTrue, reason: second.error);
      final accountFetch = remote.fetchCalls.firstWhere(
        (call) => call.entity == 'accounts',
      );
      expect(accountFetch.afterRevision, 7);
    },
  );

  test('bootstrap preserves a locally edited default row', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final local = LocalSyncStore(db);
    final remote = _FakeSupabaseSyncGateway();
    final service = SupabaseIncrementalSyncService(
      local: local,
      remote: remote,
    );
    const remoteCashUuid = '00000000-0000-4000-8000-000000000011';

    final originalCash = await db
        .customSelect(
          'SELECT id, uuid FROM accounts WHERE name = ?',
          variables: const [Variable<String>('현금')],
        )
        .getSingle();
    final localCashUuid = originalCash.read<String>('uuid');
    await db.customStatement(
      'UPDATE accounts SET color = ?, sync_status = ? WHERE id = ?',
      ['#fedcba', syncStatusPending, originalCash.read<int>('id')],
    );
    remote.seed(
      'accounts',
      const RemoteSyncRow(
        uuid: remoteCashUuid,
        payload: {
          'name': '현금',
          'kind': 'cash',
          'initial_balance': 0,
          'card_limit': null,
          'color': '#16a34a',
          'exclude_from_total': false,
          'is_investment': false,
          'sort_order': 2,
          'archived_at': null,
          'created_at': '2026-01-01T00:00:00.000Z',
        },
        updatedAt: '2026-07-13T00:00:12.000Z',
        deletedAt: null,
        revision: 12,
      ),
    );

    final result = await service.synchronize(_settings);

    expect(result.isOk, isTrue, reason: result.error);
    final cash = await db
        .customSelect(
          'SELECT uuid, color FROM accounts WHERE name = ?',
          variables: const [Variable<String>('현금')],
        )
        .getSingle();
    expect(cash.read<String>('uuid'), localCashUuid);
    expect(cash.read<String>('color'), '#fedcba');
    expect(await _rowByUuid(db, 'accounts', remoteCashUuid), isNull);
    expect(
      remote.upsertCalls.any(
        (call) =>
            call.uuid == localCashUuid && call.payload['color'] == '#fedcba',
      ),
      isTrue,
    );
  });

  test('a mismatched tombstone response is not acknowledged', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final local = LocalSyncStore(db);
    final remote = _FakeSupabaseSyncGateway();
    final service = SupabaseIncrementalSyncService(
      local: local,
      remote: remote,
    );

    final tagId = await db.tagsDao.createTag('restore-me', '#123456');
    final uuid = await _uuidForId(db, 'tags', tagId);
    remote.rejectNextLiveUpsertWithTombstone = true;

    final rejected = await service.pushPending(_settings);

    expect(rejected.isOk, isFalse);
    expect(rejected.error, contains('최신 버전'));
    expect(await local.currentEntry('tags', uuid), isNotNull);
    expect(await _syncStatus(db, 'tags', uuid), syncStatusPending);

    final retried = await service.pushPending(_settings);
    expect(retried.isOk, isTrue, reason: retried.error);
    expect(retried.uploaded, 1);
    expect(await local.currentEntry('tags', uuid), isNull);
  });

  test('a delete upload carries its durable natural-key payload', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final local = LocalSyncStore(db);
    final remote = _FakeSupabaseSyncGateway();
    final service = SupabaseIncrementalSyncService(
      local: local,
      remote: remote,
    );

    final tagId = await db.tagsDao.createTag('delete-snapshot', '#123456');
    final uuid = await _uuidForId(db, 'tags', tagId);
    final inserted = await local.currentEntry('tags', uuid);
    expect(await local.acknowledge(inserted!), isTrue);
    await db.tagsDao.deleteTag(tagId);

    final result = await service.pushPending(_settings);

    expect(result.isOk, isTrue, reason: result.error);
    final call = remote.upsertCalls.single;
    expect(call.deletedAt, isNotNull);
    expect(call.payload, {'name': 'delete-snapshot'});
  });

  test(
    'a remote tombstone deletes locally without creating a delete echo',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      await _markAllSyncedAndClearOutbox(db);
      final local = LocalSyncStore(db);
      final remote = _FakeSupabaseSyncGateway();
      final service = SupabaseIncrementalSyncService(
        local: local,
        remote: remote,
      );

      final tagId = await db.tagsDao.createTag('remote-delete-tag', '#123456');
      final uuid = await _uuidForId(db, 'tags', tagId);
      final created = await local.currentEntry('tags', uuid);
      expect(created, isNotNull);
      expect(await local.acknowledge(created!), isTrue);

      await local.prepareRemote(_settings.normalized().url);
      await local.markBootstrapComplete();
      await _markAllSyncedAndClearOutbox(db);
      remote.seed(
        'tags',
        RemoteSyncRow(
          uuid: uuid,
          payload: const {},
          updatedAt: '2026-07-13T00:00:42.000Z',
          deletedAt: '2026-07-13T00:00:41.000Z',
          revision: 42,
        ),
      );

      final result = await service.synchronize(_settings);

      expect(result.isOk, isTrue, reason: result.error);
      expect(result.downloaded, 1);
      expect(await _rowByUuid(db, 'tags', uuid), isNull);
      expect(await local.currentEntry('tags', uuid), isNull);
      expect(await local.cursor('tags'), 42);
      expect(
        remote.upsertCalls.where(
          (call) => call.entity == 'tags' && call.uuid == uuid,
        ),
        isEmpty,
      );
    },
  );

  test(
    'remote tombstones delete children before parents with foreign keys',
    () async {
      final db = await _openDatabase();
      addTearDown(db.close);
      await _markAllSyncedAndClearOutbox(db);
      final local = LocalSyncStore(db);
      final remote = _FakeSupabaseSyncGateway();
      final service = SupabaseIncrementalSyncService(
        local: local,
        remote: remote,
      );
      const accountUuid = '00000000-0000-4000-8000-000000000101';
      const transactionUuid = '00000000-0000-4000-8000-000000000102';

      await db.customStatement(
        '''
INSERT INTO accounts(uuid, name, kind, sync_status)
VALUES (?, ?, 'bank', ?)
''',
        [accountUuid, 'tombstone-parent', syncStatusSynced],
      );
      final account = await _rowByUuid(db, 'accounts', accountUuid);
      await db.customStatement(
        '''
INSERT INTO transactions(
  uuid, type, occurred_on, amount, account_id, sync_status
)
VALUES (?, 'adjustment', '2026-07-13', 1, ?, ?)
''',
        [transactionUuid, account!['id'], syncStatusSynced],
      );
      await db.customStatement('DELETE FROM sync_outbox');
      await local.prepareRemote(_settings.normalized().url);
      await local.markBootstrapComplete();
      await _markAllSyncedAndClearOutbox(db);

      remote.seed(
        'accounts',
        const RemoteSyncRow(
          uuid: accountUuid,
          payload: {},
          updatedAt: '2026-07-13T00:01:01.000Z',
          deletedAt: '2026-07-13T00:01:00.000Z',
          revision: 101,
        ),
      );
      remote.seed(
        'transactions',
        const RemoteSyncRow(
          uuid: transactionUuid,
          payload: {},
          updatedAt: '2026-07-13T00:01:02.000Z',
          deletedAt: '2026-07-13T00:01:01.000Z',
          revision: 102,
        ),
      );

      final result = await service.synchronize(_settings);

      expect(result.isOk, isTrue, reason: result.error);
      expect(result.downloaded, 2);
      expect(await _rowByUuid(db, 'transactions', transactionUuid), isNull);
      expect(await _rowByUuid(db, 'accounts', accountUuid), isNull);
      expect(await local.cursor('transactions'), 102);
      expect(await local.cursor('accounts'), 101);
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

Future<String> _uuidForId(AppDatabase db, String table, int id) async {
  final row = await db
      .customSelect(
        'SELECT uuid FROM $table WHERE id = ?',
        variables: [Variable<int>(id)],
      )
      .getSingle();
  return row.read<String>('uuid');
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

class _FakeSupabaseSyncGateway implements SupabaseSyncGateway {
  final _rows = <String, Map<String, RemoteSyncRow>>{};
  final fetchCalls = <_FetchCall>[];
  final upsertCalls = <_UpsertCall>[];
  int _nextRevision = 1;
  Object? nextUpsertFailure;
  bool rejectNextLiveUpsertWithTombstone = false;
  Completer<void>? _blockedUpsertRelease;
  Completer<void>? _blockedUpsertStarted;

  void seed(String entity, RemoteSyncRow row) {
    (_rows[entity] ??= {})[row.uuid] = row;
    if (_nextRevision <= row.revision) _nextRevision = row.revision + 1;
  }

  Future<void> blockNextUpsert(Completer<void> release) {
    final started = Completer<void>();
    _blockedUpsertRelease = release;
    _blockedUpsertStarted = started;
    return started.future;
  }

  @override
  Future<List<RemoteSyncRow>> fetchChanges({
    required SupabaseBackupSettings settings,
    required String entity,
    required int afterRevision,
    required int limit,
  }) async {
    fetchCalls.add(
      _FetchCall(entity: entity, afterRevision: afterRevision, limit: limit),
    );
    final rows =
        (_rows[entity]?.values ?? const <RemoteSyncRow>[])
            .where((row) => row.revision > afterRevision)
            .toList()
          ..sort((a, b) => a.revision.compareTo(b.revision));
    return rows.take(limit).toList(growable: false);
  }

  @override
  Future<RemoteSyncRow> upsert({
    required SupabaseBackupSettings settings,
    required String entity,
    required String uuid,
    required Map<String, Object?> payload,
    required String? deletedAt,
  }) async {
    upsertCalls.add(
      _UpsertCall(
        entity: entity,
        uuid: uuid,
        payload: Map<String, Object?>.from(payload),
        deletedAt: deletedAt,
      ),
    );

    final failure = nextUpsertFailure;
    if (failure != null) {
      nextUpsertFailure = null;
      throw failure;
    }

    final release = _blockedUpsertRelease;
    if (release != null) {
      final started = _blockedUpsertStarted;
      _blockedUpsertRelease = null;
      _blockedUpsertStarted = null;
      if (started != null && !started.isCompleted) started.complete();
      await release.future;
    }

    final revision = _nextRevision++;
    var acceptedDeletedAt = deletedAt;
    if (deletedAt == null && rejectNextLiveUpsertWithTombstone) {
      rejectNextLiveUpsertWithTombstone = false;
      acceptedDeletedAt = '2026-07-13T00:00:00.000Z';
    }
    final row = RemoteSyncRow(
      uuid: uuid,
      payload: Map<String, Object?>.from(payload),
      updatedAt: DateTime.utc(
        2026,
        7,
        13,
      ).add(Duration(seconds: revision)).toIso8601String(),
      deletedAt: acceptedDeletedAt,
      revision: revision,
    );
    (_rows[entity] ??= {})[uuid] = row;
    return row;
  }
}

class _FetchCall {
  const _FetchCall({
    required this.entity,
    required this.afterRevision,
    required this.limit,
  });

  final String entity;
  final int afterRevision;
  final int limit;
}

class _UpsertCall {
  const _UpsertCall({
    required this.entity,
    required this.uuid,
    required this.payload,
    required this.deletedAt,
  });

  final String entity;
  final String uuid;
  final Map<String, Object?> payload;
  final String? deletedAt;
}
