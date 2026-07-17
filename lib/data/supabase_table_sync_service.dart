import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

import 'supabase_backup_settings.dart';
import 'supabase_sync_auth.dart';

const supabaseSyncTableNames = <String>[
  'mlb_accounts',
  'mlb_categories',
  'mlb_transactions',
  'mlb_budget_groups',
  'mlb_monthly_income',
  'mlb_investments',
  'mlb_recurring_transactions',
  'mlb_tags',
  'mlb_calendar_events',
];

final supabaseTableSyncServiceProvider = Provider<SupabaseTableSyncService>((
  ref,
) {
  return SupabasePostgrestTableSyncService(
    authService: ref.watch(supabaseSyncAuthServiceProvider),
  );
});

class SupabaseTableConnectionStatus {
  const SupabaseTableConnectionStatus({required this.tables});

  final List<String> tables;
}

class SupabaseTableSyncResult<T> {
  const SupabaseTableSyncResult.ok(this.value) : error = null;
  const SupabaseTableSyncResult.fail(String this.error) : value = null;

  final T? value;
  final String? error;

  bool get isOk => error == null;
}

abstract class SupabaseTableSyncService {
  Future<SupabaseTableSyncResult<SupabaseTableConnectionStatus>> testConnection(
    SupabaseBackupSettings settings,
  );
}

abstract class SupabaseTableProbe {
  Future<void> selectOne({
    required SupabaseBackupSettings settings,
    required String table,
  });
}

class SupabasePostgrestTableSyncService implements SupabaseTableSyncService {
  SupabasePostgrestTableSyncService({
    SupabaseTableProbe? probe,
    SupabaseSyncAuthService? authService,
  }) : _probe =
           probe ??
           _SupabaseClientTableProbe(
             authService ??
                 (throw ArgumentError(
                   'authService is required without a probe',
                 )),
           );

  final SupabaseTableProbe _probe;

  @override
  Future<SupabaseTableSyncResult<SupabaseTableConnectionStatus>> testConnection(
    SupabaseBackupSettings settings,
  ) async {
    final error = validateSupabaseSyncSettings(settings);
    if (error != null) return SupabaseTableSyncResult.fail(error);

    for (final table in supabaseSyncTableNames) {
      try {
        await _probe.selectOne(settings: settings.normalized(), table: table);
      } catch (error) {
        return SupabaseTableSyncResult.fail(
          '$table 확인 실패: ${_describeError(error)}',
        );
      }
    }

    return const SupabaseTableSyncResult.ok(
      SupabaseTableConnectionStatus(tables: supabaseSyncTableNames),
    );
  }

  static String _describeError(Object error) {
    if (error is PostgrestException) {
      final code = error.code == null ? '' : ' (${error.code})';
      return '${error.message}$code';
    }
    return error.toString();
  }
}

class _SupabaseClientTableProbe implements SupabaseTableProbe {
  const _SupabaseClientTableProbe(this._authService);

  final SupabaseSyncAuthService _authService;

  @override
  Future<void> selectOne({
    required SupabaseBackupSettings settings,
    required String table,
  }) async {
    final client = await _authService.restoreClient(settings);
    await client.from(table).select('uuid').limit(1);
  }
}
