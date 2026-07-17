import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';
import 'defaults.dart';
import 'sync_metadata.dart';
import 'sync_models.dart';

class LocalSyncStore {
  LocalSyncStore(this._db);

  final AppDatabase _db;

  static const _bootstrapCompleteKey = 'bootstrap_complete';
  static const _remoteIdentityKey = 'remote_identity';

  Future<bool> prepareRemote(String identity) async {
    return _db.transaction(() async {
      final current = await _state(_remoteIdentityKey);
      if (current != identity) {
        await _db.customStatement('DELETE FROM sync_state');
        await _setState(_remoteIdentityKey, identity);
        await _setState(_bootstrapCompleteKey, '0');
        await _db.enqueueAllRowsForSync();
        return true;
      }
      return await _state(_bootstrapCompleteKey) != '1';
    });
  }

  Future<void> markBootstrapComplete() => _setState(_bootstrapCompleteKey, '1');

  Future<int> cursor(String entity) async {
    final value = await _state(_cursorKey(entity));
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> initializeCursor(String entity, int value) async {
    if (await _state(_cursorKey(entity)) == null) {
      await _setState(_cursorKey(entity), value.toString());
    }
  }

  Future<List<SyncOutboxEntry>> pendingEntries() async {
    final rows = await _db.customSelect('''
SELECT entity, uuid, operation, generation, changed_at, tombstone_payload
FROM sync_outbox
ORDER BY changed_at, entity, uuid
''').get();
    return rows.map(_outboxFromRow).toList(growable: false);
  }

  Future<SyncOutboxEntry?> currentEntry(String entity, String uuid) async {
    final row = await _db
        .customSelect(
          '''
SELECT entity, uuid, operation, generation, changed_at, tombstone_payload
FROM sync_outbox
WHERE entity = ? AND uuid = ?
''',
          variables: [Variable<String>(entity), Variable<String>(uuid)],
        )
        .getSingleOrNull();
    return row == null ? null : _outboxFromRow(row);
  }

  Future<bool> acknowledge(SyncOutboxEntry entry) async {
    return _db.transaction(() async {
      final removed = await _db.customUpdate(
        '''
DELETE FROM sync_outbox
WHERE entity = ? AND uuid = ? AND generation = ? AND operation = ?
''',
        variables: [
          Variable<String>(entry.entity),
          Variable<String>(entry.uuid),
          Variable<int>(entry.generation),
          Variable<String>(entry.operation),
        ],
      );
      if (removed == 0) return false;

      if (!entry.isDelete) {
        await _db.customStatement(
          '''
UPDATE ${entry.entity}
SET sync_status = ?
WHERE uuid = ?
  AND NOT EXISTS (
    SELECT 1 FROM sync_outbox o
    WHERE o.entity = ? AND o.uuid = ?
  )
''',
          [syncStatusSynced, entry.uuid, entry.entity, entry.uuid],
        );
      }
      return true;
    });
  }

  Future<Map<String, Object?>?> buildPayload(String entity, String uuid) async {
    _checkEntity(entity);
    final row = await _db
        .customSelect(
          'SELECT * FROM $entity WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
        )
        .getSingleOrNull();
    if (row == null) return null;

    final payload = <String, Object?>{};
    for (final column in _payloadColumns[entity]!) {
      final value = row.data[column];
      payload[column] = _boolColumns[entity]!.contains(column)
          ? value == 1
          : value;
    }

    switch (entity) {
      case 'transactions':
        payload['account_uuid'] = await _uuidForId(
          'accounts',
          row.data['account_id'] as int?,
        );
        payload['category_uuid'] = await _uuidForId(
          'categories',
          row.data['category_id'] as int?,
        );
        payload['from_account_uuid'] = await _uuidForId(
          'accounts',
          row.data['from_account_id'] as int?,
        );
        payload['to_account_uuid'] = await _uuidForId(
          'accounts',
          row.data['to_account_id'] as int?,
        );
        payload['tag_uuids'] = await _transactionTagUuids(
          row.data['id']! as int,
        );
        break;
      case 'budget_groups':
        payload['account_uuid'] = await _uuidForId(
          'accounts',
          row.data['account_id'] as int?,
        );
        payload['category_uuids'] = await _budgetCategoryUuids(
          row.data['id']! as int,
        );
        break;
      case 'investments':
        payload['account_uuid'] = await _uuidForId(
          'accounts',
          row.data['account_id'] as int?,
        );
        break;
      case 'recurring_transactions':
        payload['account_uuid'] = await _uuidForId(
          'accounts',
          row.data['account_id'] as int?,
        );
        payload['category_uuid'] = await _uuidForId(
          'categories',
          row.data['category_id'] as int?,
        );
        payload['from_account_uuid'] = await _uuidForId(
          'accounts',
          row.data['from_account_id'] as int?,
        );
        payload['to_account_uuid'] = await _uuidForId(
          'accounts',
          row.data['to_account_id'] as int?,
        );
        break;
    }
    return payload;
  }

  Future<int> applyRemotePage({
    required String entity,
    required List<RemoteSyncRow> rows,
    required bool bootstrap,
    bool updateCursor = true,
  }) async {
    _checkEntity(entity);
    if (rows.isEmpty) return 0;
    var applied = 0;
    await _db.transaction(() async {
      for (final row in rows) {
        if (await _applyRemoteRow(entity, row, bootstrap: bootstrap)) {
          applied++;
        }
      }
      if (updateCursor) {
        final maxRevision = rows
            .map((row) => row.revision)
            .reduce((a, b) => a > b ? a : b);
        await _setState(_cursorKey(entity), maxRevision.toString());
      }
    });
    if (applied > 0) _db.notifyUpdates({TableUpdate(entity)});
    return applied;
  }

  Future<void> commitCursors(Map<String, int> cursors) {
    for (final entity in cursors.keys) {
      _checkEntity(entity);
    }
    return _db.transaction(() async {
      for (final entry in cursors.entries) {
        await _setState(_cursorKey(entry.key), entry.value.toString());
      }
    });
  }

  Future<bool> _applyRemoteRow(
    String entity,
    RemoteSyncRow remote, {
    required bool bootstrap,
  }) async {
    final directOutbox = await currentEntry(entity, remote.uuid);
    final directLocal = await _rowByUuid(entity, remote.uuid);
    if (directOutbox != null &&
        (!bootstrap ||
            directLocal == null ||
            !_isPristineDefaultRow(entity, directLocal))) {
      return false;
    }

    if (remote.isDeleted) {
      var local = directLocal;
      if (local == null && bootstrap && remote.payload.isNotEmpty) {
        local = await _rowByNaturalKey(entity, {
          for (final column in _payloadColumns[entity]!)
            if (remote.payload.containsKey(column))
              column: remote.payload[column],
        });
      }
      final localUuid = local?.data['uuid'] as String?;
      if (bootstrap &&
          local != null &&
          localUuid != remote.uuid &&
          await currentEntry(entity, localUuid!) != null &&
          !_isPristineDefaultRow(entity, local)) {
        return false;
      }
      if (localUuid != null) {
        await _db.customStatement(
          'UPDATE $entity SET sync_status = ? WHERE uuid = ?',
          [syncStatusRemoteDelete, localUuid],
        );
        await _db.customStatement('DELETE FROM $entity WHERE uuid = ?', [
          localUuid,
        ]);
        await _deleteOutbox(entity, localUuid);
      }
      await _deleteOutbox(entity, remote.uuid);
      return true;
    }

    final values = await _localValues(entity, remote.payload);
    var existing = directLocal;
    existing ??= await _rowByNaturalKey(entity, values);
    final existingUuid = existing?.data['uuid'] as String?;
    if (existing != null && existingUuid != null) {
      final pending = existingUuid == remote.uuid
          ? directOutbox
          : await currentEntry(entity, existingUuid);
      if (pending != null &&
          (!bootstrap || !_isPristineDefaultRow(entity, existing))) {
        return false;
      }
    }

    if (existing == null) {
      await _insertRemote(entity, remote, values);
    } else {
      await _updateRemote(entity, existing, remote, values);
    }

    final stored = await _rowByUuid(entity, remote.uuid);
    if (stored == null) {
      throw StateError('$entity/${remote.uuid} 원격 행을 로컬에 저장하지 못했습니다.');
    }
    await _replaceEmbeddedRelations(entity, stored, remote.payload);
    await _deleteOutbox(entity, remote.uuid);
    if (existingUuid != null && existingUuid != remote.uuid) {
      await _deleteOutbox(entity, existingUuid);
    }
    await _db.customStatement(
      'UPDATE $entity SET sync_status = ? WHERE uuid = ?',
      [syncStatusSynced, remote.uuid],
    );
    return true;
  }

  Future<void> _insertRemote(
    String entity,
    RemoteSyncRow remote,
    Map<String, Object?> values,
  ) async {
    final columns = <String>[
      'uuid',
      ...values.keys,
      'updated_at',
      'deleted_at',
      'sync_status',
    ];
    final parameters = <Object?>[
      remote.uuid,
      ...values.values.map(_sqliteValue),
      _normalizeTimestamp(remote.updatedAt),
      null,
      syncStatusRemote,
    ];
    await _db.customStatement(
      'INSERT INTO $entity (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      parameters,
    );
  }

  Future<void> _updateRemote(
    String entity,
    QueryRow existing,
    RemoteSyncRow remote,
    Map<String, Object?> values,
  ) async {
    final primaryKey = _primaryKeys[entity]!;
    final assignments = <String>[
      'uuid = ?',
      for (final column in values.keys) '$column = ?',
      'updated_at = ?',
      'deleted_at = ?',
      'sync_status = ?',
    ];
    await _db.customStatement(
      'UPDATE $entity SET ${assignments.join(', ')} WHERE $primaryKey = ?',
      [
        remote.uuid,
        ...values.values.map(_sqliteValue),
        _normalizeTimestamp(remote.updatedAt),
        null,
        syncStatusRemote,
        existing.data[primaryKey],
      ],
    );
  }

  Future<Map<String, Object?>> _localValues(
    String entity,
    Map<String, Object?> payload,
  ) async {
    final values = <String, Object?>{};
    for (final column in _payloadColumns[entity]!) {
      if (!payload.containsKey(column)) {
        throw FormatException('$entity payload에 $column 값이 없습니다.');
      }
      values[column] = payload[column];
    }

    switch (entity) {
      case 'transactions':
        values['account_id'] = await _idForUuid(
          'accounts',
          payload['account_uuid'] as String?,
        );
        values['category_id'] = await _idForUuid(
          'categories',
          payload['category_uuid'] as String?,
        );
        values['from_account_id'] = await _idForUuid(
          'accounts',
          payload['from_account_uuid'] as String?,
        );
        values['to_account_id'] = await _idForUuid(
          'accounts',
          payload['to_account_uuid'] as String?,
        );
        break;
      case 'budget_groups':
        values['account_id'] = await _idForUuid(
          'accounts',
          payload['account_uuid'] as String?,
        );
        break;
      case 'investments':
        values['account_id'] = await _idForUuid(
          'accounts',
          payload['account_uuid'] as String?,
        );
        break;
      case 'recurring_transactions':
        values['account_id'] = await _idForUuid(
          'accounts',
          payload['account_uuid'] as String?,
        );
        values['category_id'] = await _idForUuid(
          'categories',
          payload['category_uuid'] as String?,
        );
        values['from_account_id'] = await _idForUuid(
          'accounts',
          payload['from_account_uuid'] as String?,
        );
        values['to_account_id'] = await _idForUuid(
          'accounts',
          payload['to_account_uuid'] as String?,
        );
        break;
    }
    return values;
  }

  Future<void> _replaceEmbeddedRelations(
    String entity,
    QueryRow stored,
    Map<String, Object?> payload,
  ) async {
    if (entity == 'transactions') {
      final transactionId = stored.data['id']! as int;
      await _db.customStatement(
        'DELETE FROM transaction_tags WHERE transaction_id = ?',
        [transactionId],
      );
      for (final uuid in _stringList(payload['tag_uuids'])) {
        final tagId = await _idForUuid('tags', uuid);
        if (tagId == null) {
          throw StateError('거래 태그 $uuid 를 로컬에서 찾을 수 없습니다.');
        }
        await _db.customStatement(
          'INSERT OR IGNORE INTO transaction_tags(transaction_id, tag_id) '
          'VALUES (?, ?)',
          [transactionId, tagId],
        );
      }
    } else if (entity == 'budget_groups') {
      final groupId = stored.data['id']! as int;
      await _db.customStatement(
        'DELETE FROM budget_group_categories WHERE group_id = ?',
        [groupId],
      );
      for (final uuid in _stringList(payload['category_uuids'])) {
        final categoryId = await _idForUuid('categories', uuid);
        if (categoryId == null) {
          throw StateError('예산 카테고리 $uuid 를 로컬에서 찾을 수 없습니다.');
        }
        await _db.customStatement(
          'INSERT OR IGNORE INTO budget_group_categories(group_id, category_id) '
          'VALUES (?, ?)',
          [groupId, categoryId],
        );
      }
    }
  }

  Future<QueryRow?> _rowByUuid(String entity, String uuid) {
    return _db
        .customSelect(
          'SELECT * FROM $entity WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
        )
        .getSingleOrNull();
  }

  Future<QueryRow?> _rowByNaturalKey(
    String entity,
    Map<String, Object?> values,
  ) async {
    final keys = _naturalKeys[entity];
    if (keys == null || keys.any((key) => values[key] == null)) return null;
    return _db
        .customSelect(
          'SELECT * FROM $entity WHERE '
          '${keys.map((key) => '$key = ?').join(' AND ')} LIMIT 1',
          variables: [for (final key in keys) _variable(values[key])],
        )
        .getSingleOrNull();
  }

  Future<String?> _uuidForId(String table, int? id) async {
    if (id == null) return null;
    final row = await _db
        .customSelect(
          'SELECT uuid FROM $table WHERE id = ?',
          variables: [Variable<int>(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw StateError('$table id=$id 관계를 UUID로 변환할 수 없습니다.');
    }
    return row.read<String>('uuid');
  }

  Future<int?> _idForUuid(String table, String? uuid) async {
    if (uuid == null) return null;
    final row = await _db
        .customSelect(
          'SELECT id FROM $table WHERE uuid = ?',
          variables: [Variable<String>(uuid)],
        )
        .getSingleOrNull();
    return row?.read<int>('id');
  }

  Future<List<String>> _transactionTagUuids(int transactionId) async {
    final rows = await _db
        .customSelect(
          '''
SELECT tags.uuid AS uuid
FROM transaction_tags
JOIN tags ON tags.id = transaction_tags.tag_id
WHERE transaction_tags.transaction_id = ?
ORDER BY tags.sort_order, tags.id
''',
          variables: [Variable<int>(transactionId)],
        )
        .get();
    return rows.map((row) => row.read<String>('uuid')).toList();
  }

  Future<List<String>> _budgetCategoryUuids(int groupId) async {
    final rows = await _db
        .customSelect(
          '''
SELECT categories.uuid AS uuid
FROM budget_group_categories
JOIN categories ON categories.id = budget_group_categories.category_id
WHERE budget_group_categories.group_id = ?
ORDER BY categories.sort_order, categories.id
''',
          variables: [Variable<int>(groupId)],
        )
        .get();
    return rows.map((row) => row.read<String>('uuid')).toList();
  }

  Future<String?> _state(String key) async {
    final row = await _db
        .customSelect(
          'SELECT value FROM sync_state WHERE key = ?',
          variables: [Variable<String>(key)],
        )
        .getSingleOrNull();
    return row?.read<String>('value');
  }

  Future<void> _setState(String key, String value) {
    return _db.customStatement(
      '''
INSERT INTO sync_state(key, value) VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''',
      [key, value],
    );
  }

  Future<void> _deleteOutbox(String entity, String uuid) {
    return _db.customStatement(
      'DELETE FROM sync_outbox WHERE entity = ? AND uuid = ?',
      [entity, uuid],
    );
  }

  static SyncOutboxEntry _outboxFromRow(QueryRow row) {
    return SyncOutboxEntry(
      entity: row.read<String>('entity'),
      uuid: row.read<String>('uuid'),
      operation: row.read<String>('operation'),
      generation: row.read<int>('generation'),
      changedAt: row.read<String>('changed_at'),
      tombstonePayload: _decodeTombstonePayload(
        row.readNullable<String>('tombstone_payload'),
      ),
    );
  }

  static Map<String, Object?> _decodeTombstonePayload(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const <String, Object?>{};
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map
          ? Map<String, Object?>.from(decoded)
          : const <String, Object?>{};
    } catch (_) {
      return const <String, Object?>{};
    }
  }

  static bool _isPristineDefaultRow(String entity, QueryRow row) {
    if (entity == 'accounts') {
      final name = row.data['name'];
      final index = defaultAccounts.indexWhere((item) => item.name == name);
      if (index < 0) return false;
      final item = defaultAccounts[index];
      return row.data['kind'] == item.kind &&
          row.data['initial_balance'] == 0 &&
          row.data['card_limit'] == null &&
          row.data['color'] == item.color &&
          !_sqliteBool(row.data['exclude_from_total']) &&
          _sqliteBool(row.data['is_investment']) == item.isInvestment &&
          row.data['sort_order'] == index &&
          row.data['archived_at'] == null;
    }
    if (entity == 'categories') {
      final name = row.data['name'];
      final type = row.data['type'];
      final defaults = type == 'expense'
          ? defaultExpenseCategories
          : type == 'income'
          ? defaultIncomeCategories
          : const <DefaultCategory>[];
      final index = defaults.indexWhere((item) => item.name == name);
      if (index < 0) return false;
      final item = defaults[index];
      return row.data['color'] == item.color &&
          row.data['icon'] == null &&
          row.data['sort_order'] == index &&
          row.data['archived_at'] == null;
    }
    return false;
  }

  static bool _sqliteBool(Object? value) => value == true || value == 1;

  static Variable<Object> _variable(Object? value) {
    if (value == null) throw ArgumentError.notNull('value');
    return Variable<Object>(value);
  }

  static Object? _sqliteValue(Object? value) =>
      value is bool ? (value ? 1 : 0) : value;

  static String _normalizeTimestamp(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed?.toUtc().toIso8601String() ?? value;
  }

  static List<String> _stringList(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('UUID 배열 형식이 올바르지 않습니다.');
    return value.map((item) => item as String).toList(growable: false);
  }

  static String _cursorKey(String entity) => 'cursor:$entity';

  static void _checkEntity(String entity) {
    if (!localSyncTableNames.contains(entity)) {
      throw ArgumentError.value(entity, 'entity', 'Unknown sync entity');
    }
  }
}

const _primaryKeys = <String, String>{
  'accounts': 'id',
  'categories': 'id',
  'transactions': 'id',
  'budget_groups': 'id',
  'monthly_income': 'month',
  'investments': 'id',
  'recurring_transactions': 'id',
  'tags': 'id',
  'calendar_events': 'id',
};

const _naturalKeys = <String, List<String>>{
  'accounts': ['name'],
  'categories': ['name', 'type'],
  'budget_groups': ['name', 'month'],
  'monthly_income': ['month'],
  'tags': ['name'],
};

const _payloadColumns = <String, List<String>>{
  'accounts': [
    'name',
    'kind',
    'initial_balance',
    'card_limit',
    'color',
    'exclude_from_total',
    'is_investment',
    'sort_order',
    'archived_at',
    'created_at',
  ],
  'categories': [
    'name',
    'type',
    'color',
    'icon',
    'sort_order',
    'archived_at',
    'created_at',
  ],
  'transactions': [
    'type',
    'occurred_on',
    'occurred_time',
    'amount',
    'memo',
    'created_at',
  ],
  'budget_groups': [
    'name',
    'month',
    'amount',
    'adjustment',
    'carry_forward',
    'percentage',
    'created_at',
  ],
  'monthly_income': ['month', 'expected_income'],
  'investments': [
    'side',
    'occurred_on',
    'occurred_time',
    'ticker',
    'quantity',
    'total_amount',
    'memo',
    'created_at',
  ],
  'recurring_transactions': [
    'name',
    'type',
    'amount',
    'memo',
    'frequency',
    'day_of_month',
    'day_of_week',
    'occurred_time',
    'start_date',
    'end_date',
    'last_generated_on',
    'tag_names',
    'active',
    'created_at',
  ],
  'tags': [
    'name',
    'color',
    'sort_order',
    'usage_count',
    'last_used_at',
    'is_pinned',
    'created_at',
  ],
  'calendar_events': [
    'title',
    'description',
    'start_at',
    'end_at',
    'all_day',
    'color',
    'location',
    'link_url',
    'schedule_type',
    'notification_lead_minutes',
    'notification_enabled',
    'created_at',
  ],
};

const _boolColumns = <String, Set<String>>{
  'accounts': {'exclude_from_total', 'is_investment'},
  'categories': {},
  'transactions': {},
  'budget_groups': {'carry_forward'},
  'monthly_income': {},
  'investments': {},
  'recurring_transactions': {'active'},
  'tags': {'is_pinned'},
  'calendar_events': {'all_day', 'notification_enabled'},
};
