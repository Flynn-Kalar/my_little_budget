import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_table_sync_service.dart';

void main() {
  const settings = SupabaseBackupSettings(
    url: 'https://example.supabase.co',
    anonKey: 'anon-key',
    bucket: '',
    authEmail: 'user@example.com',
  );

  test('checks every entity table in order', () async {
    final probe = _FakeTableProbe();
    final service = SupabasePostgrestTableSyncService(probe: probe);

    final result = await service.testConnection(settings);

    expect(result.isOk, true, reason: result.error);
    expect(probe.tables, supabaseSyncTableNames);
    expect(probe.tables, contains('mlb_calendar_events'));
    expect(result.value!.tables, supabaseSyncTableNames);
  });

  test('reports the table that is missing or inaccessible', () async {
    final probe = _FakeTableProbe(
      failingTable: 'mlb_transactions',
      failure: StateError('permission denied'),
    );
    final service = SupabasePostgrestTableSyncService(probe: probe);

    final result = await service.testConnection(settings);

    expect(result.isOk, false);
    expect(result.error, contains('mlb_transactions'));
    expect(result.error, contains('permission denied'));
    expect(probe.tables, [
      'mlb_accounts',
      'mlb_categories',
      'mlb_transactions',
    ]);
  });

  test('allows table sync without a Storage bucket', () async {
    final result = await SupabasePostgrestTableSyncService(
      probe: _FakeTableProbe(),
    ).testConnection(settings);

    expect(result.isOk, true, reason: result.error);
  });
}

class _FakeTableProbe implements SupabaseTableProbe {
  _FakeTableProbe({this.failingTable, this.failure});

  final String? failingTable;
  final Object? failure;
  final tables = <String>[];

  @override
  Future<void> selectOne({
    required SupabaseBackupSettings settings,
    required String table,
  }) async {
    tables.add(table);
    if (table == failingTable) throw failure ?? StateError('failed');
  }
}
