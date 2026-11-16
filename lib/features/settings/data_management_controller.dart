import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup.dart';
import '../../data/local_backup_service.dart';
import '../../data/providers.dart';
import '../../data/supabase_backup_service.dart';
import '../../data/supabase_backup_settings.dart';
import '../../data/supabase_operation_status.dart';
import '../../data/supabase_sync_auth.dart';
import '../../data/supabase_table_sync_service.dart';
import '../../data/sync_models.dart';
import '../notes/providers.dart';
import '../sync/invalidate_synced_data.dart';

final dataManagementControllerProvider = Provider<DataManagementController>(
  DataManagementController.new,
);

/// Data operations shared by desktop, mobile and local recovery points.
/// File pickers, confirmation dialogs and screen state belong to the UI.
class DataManagementController {
  DataManagementController(this._ref);

  final Ref _ref;

  SupabaseBackupSettingsNotifier get _settings =>
      _ref.read(supabaseBackupSettingsProvider.notifier);
  SupabaseOperationStatusNotifier get _status =>
      _ref.read(supabaseOperationStatusProvider.notifier);

  Future<Backup> exportBackup() => _ref.read(backupDaoProvider).exportBackup();

  Backup parseBackupContent(String content) {
    final parsed = parseBackup(content);
    if (!parsed.isOk) {
      throw DataManagementException(parsed.error ?? '백업 파일 형식이 올바르지 않습니다.');
    }
    return parsed.backup!;
  }

  /// The caller must obtain confirmation before invoking this method.
  /// A failed safety snapshot aborts the restore before any data is replaced.
  Future<void> restoreBackup(Backup backup) async {
    await _ref.read(localBackupServiceProvider).captureFresh();
    await _ref.read(backupDaoProvider).importBackup(backup);
    await _refreshLocalData();
  }

  Future<void> resetAllData() async {
    await _ref.read(backupDaoProvider).resetAllData();
    await _refreshLocalData();
  }

  Future<void> _refreshLocalData() async {
    _ref.read(invalidateSyncedDataProvider)();
    await _ref.read(rebuildNoteNotificationsProvider)();
  }

  Future<void> _resetStatusForChangedIdentity(
    SupabaseBackupSettings next,
  ) async {
    final previous = _ref.read(supabaseBackupSettingsProvider).normalized();
    final value = next.normalized();
    if (previous.url != value.url ||
        previous.anonKey != value.anonKey ||
        previous.authEmail != value.authEmail) {
      await _status.resetDbStatus();
    }
    if (previous.url != value.url ||
        previous.anonKey != value.anonKey ||
        previous.bucket != value.bucket) {
      await _status.resetStorageStatus();
    }
  }

  Future<SyncRunResult> saveSupabaseSettings(
    SupabaseBackupSettings settings, {
    required String password,
    required void Function(SyncProgress) onProgress,
    void Function()? onSaved,
  }) async {
    _requireValid(validateSupabaseConnectionSettings(settings));
    try {
      await _status.recordFullSyncStarted();
      await _ref
          .read(supabaseSyncAuthServiceProvider)
          .signInWithPassword(
            settings,
            email: settings.authEmail,
            password: password,
          );
      await _resetStatusForChangedIdentity(settings);
      await _settings.save(settings);
      onSaved?.call();
      return await synchronize(settings, onProgress: onProgress);
    } catch (error) {
      await _status.recordFullSyncResult(
        SyncRunResult(error: error.toString(), errorStage: 'auth'),
      );
      rethrow;
    }
  }

  Future<SyncRunResult> synchronize(
    SupabaseBackupSettings settings, {
    required void Function(SyncProgress) onProgress,
  }) {
    _requireValid(validateSupabaseSyncSettings(settings));
    return _ref
        .read(supabaseSyncCoordinatorProvider)
        .synchronizeNowWithProgress(onProgress);
  }

  Future<void> clearSupabaseSettings() async {
    await _ref.read(supabaseSyncAuthServiceProvider).disconnect();
    await _settings.clear();
    await _status.resetAll();
  }

  Future<void> refreshRemoteStatus(SupabaseBackupSettings settings) async {
    final error = validateSupabaseBackupSettings(settings);
    if (error != null) {
      await _status.recordStorageFailure(error);
      return;
    }
    final result = await _ref
        .read(supabaseBackupServiceProvider)
        .getRemoteStatus(settings);
    if (result.isOk) {
      await _status.recordStorageCheck(
        exists: result.value!.exists,
        remoteUpdatedAt: result.value!.updatedAt,
      );
    } else {
      await _status.recordStorageFailure(result.error!);
    }
  }

  Future<void> testStorage(SupabaseBackupSettings settings) async {
    _requireValid(validateSupabaseBackupSettings(settings));
    final result = await _ref
        .read(supabaseBackupServiceProvider)
        .testConnection(settings);
    if (!result.isOk) {
      await _status.recordStorageFailure(result.error!);
      throw DataManagementException(sanitizeSupabaseError(result.error)!);
    }
    await refreshRemoteStatus(settings);
  }

  Future<int> testTables(SupabaseBackupSettings settings) async {
    _requireValid(validateSupabaseSyncSettings(settings));
    final result = await _ref
        .read(supabaseTableSyncServiceProvider)
        .testConnection(settings);
    if (!result.isOk) {
      await _status.recordDbConnectionFailure(result.error!);
      throw DataManagementException(sanitizeSupabaseError(result.error)!);
    }
    final count = result.value!.tables.length;
    await _status.recordDbConnectionSuccess(count);
    return count;
  }

  Future<SupabaseBackupUpload> uploadBackup(
    SupabaseBackupSettings settings,
  ) async {
    _requireValid(validateSupabaseBackupSettings(settings));
    try {
      await _resetStatusForChangedIdentity(settings);
      await _settings.save(settings);
      final result = await _ref
          .read(supabaseBackupServiceProvider)
          .uploadBackup(settings: settings, backup: await exportBackup());
      if (!result.isOk) {
        throw DataManagementException(sanitizeSupabaseError(result.error)!);
      }
      await _settings.markBackupNow();
      await refreshRemoteStatus(settings);
      return result.value!;
    } catch (error) {
      await _status.recordStorageFailure(error.toString());
      rethrow;
    }
  }

  Future<Backup> downloadBackup(SupabaseBackupSettings settings) async {
    _requireValid(validateSupabaseBackupSettings(settings));
    try {
      final result = await _ref
          .read(supabaseBackupServiceProvider)
          .downloadLatestBackup(settings);
      if (!result.isOk) {
        throw DataManagementException(sanitizeSupabaseError(result.error)!);
      }
      return parseBackupContent(result.value!);
    } catch (error) {
      await _status.recordStorageFailure(error.toString());
      rethrow;
    }
  }

  Future<void> restoreRemoteBackup(
    Backup backup,
    SupabaseBackupSettings settings,
  ) async {
    try {
      await restoreBackup(backup);
      await _settings.markRestoreNow();
      await refreshRemoteStatus(settings);
    } catch (error) {
      await _status.recordStorageFailure(error.toString());
      rethrow;
    }
  }

  void _requireValid(String? error) {
    if (error != null) throw DataManagementException(error);
  }
}

class DataManagementException implements Exception {
  const DataManagementException(this.message);
  final String message;
  @override
  String toString() => message;
}
