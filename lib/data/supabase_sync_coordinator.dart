import 'dart:async';

import 'package:drift/drift.dart';

import 'database.dart';
import 'supabase_backup_settings.dart';
import 'supabase_incremental_sync_service.dart';
import 'supabase_operation_status.dart';
import 'sync_metadata.dart';
import 'sync_models.dart';

typedef SyncSettingsLoader = Future<SupabaseBackupSettings?> Function();
typedef SyncResultListener = void Function(SyncRunResult result);

const _defaultRetryDelays = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
  Duration(minutes: 1),
];

/// Runs one sync operation at a time, debounces local writes, and keeps failed
/// outbox entries durable while retrying with a bounded backoff.
class SupabaseSyncCoordinator {
  SupabaseSyncCoordinator({
    required AppDatabase database,
    required SupabaseIncrementalSyncService service,
    required SyncSettingsLoader loadSettings,
    SupabaseSyncStatusRecorder? statusRecorder,
    List<Duration> retryDelays = _defaultRetryDelays,
  }) : _database = database,
       _service = service,
       _loadSettings = loadSettings,
       _statusRecorder = statusRecorder,
       _retryDelays = retryDelays,
       assert(retryDelays.isNotEmpty);

  final AppDatabase _database;
  final SupabaseIncrementalSyncService _service;
  final SyncSettingsLoader _loadSettings;
  final SupabaseSyncStatusRecorder? _statusRecorder;
  final List<Duration> _retryDelays;

  StreamSubscription<Set<TableUpdate>>? _updatesSubscription;
  Timer? _debounceTimer;
  Timer? _retryTimer;
  Future<SyncRunResult>? _activeRun;
  SyncResultListener? _listener;
  Future<void> Function()? _afterFullSync;
  final Set<SyncProgressListener> _progressListeners = {};
  SyncProgress? _currentProgress;
  Completer<SyncRunResult>? _queuedFullSync;
  Completer<SyncRunResult>? _queuedPush;
  bool _retryFullSync = false;
  bool _disposed = false;
  int _retryAttempt = 0;

  void start({
    SyncResultListener? onResult,
    Future<void> Function()? afterFullSync,
  }) {
    _listener = onResult ?? _listener;
    _afterFullSync = afterFullSync ?? _afterFullSync;
    if (_updatesSubscription != null || _disposed) return;
    final query = TableUpdateQuery.allOf([
      for (final table in localSyncTableNames)
        TableUpdateQuery.onTableName(table),
    ]);
    _updatesSubscription = _database.tableUpdates(query).listen((_) {
      if (_debounceTimer == null) {
        unawaited(pushNow());
      }
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 250), () {
        _debounceTimer = null;
        unawaited(pushNow());
      });
    });
  }

  Future<SyncRunResult> synchronizeNow() => _run(fullSync: true);

  Future<SyncRunResult> synchronizeNowWithProgress(
    SyncProgressListener onProgress,
  ) {
    final joiningActiveRun = _activeRun != null;
    _progressListeners.add(onProgress);
    if (joiningActiveRun && _currentProgress != null) {
      onProgress(_currentProgress!);
    }
    return _run(fullSync: true).whenComplete(() {
      _progressListeners.remove(onProgress);
    });
  }

  Future<SyncRunResult> pushNow() => _run(fullSync: false);

  Future<SyncRunResult> _run({required bool fullSync}) {
    if (_disposed) {
      return Future.value(const SyncRunResult(error: '동기화가 종료되었습니다.'));
    }
    final active = _activeRun;
    if (active != null) {
      if (fullSync) {
        return (_queuedFullSync ??= Completer<SyncRunResult>()).future;
      }
      return (_queuedPush ??= Completer<SyncRunResult>()).future;
    }

    if (fullSync) _currentProgress = null;
    final future = _executeSafely(fullSync: fullSync);
    _activeRun = future;
    future.whenComplete(() {
      _activeRun = null;
      final full = _queuedFullSync;
      final push = _queuedPush;
      _queuedFullSync = null;
      _queuedPush = null;
      if (full != null || push != null) {
        // A queued caller waits for its own run, not the preceding upload.
        final next = _run(fullSync: full != null);
        full?.complete(next);
        push?.complete(next);
      }
    });
    return future;
  }

  Future<SyncRunResult> _executeSafely({required bool fullSync}) async {
    try {
      return await _execute(fullSync: fullSync);
    } catch (error) {
      final result = SyncRunResult(
        error: error.toString(),
        errorStage: fullSync ? 'fullSync' : 'upload',
      );
      await _recordResult(fullSync: fullSync, result: result);
      _listener?.call(result);
      _retryFullSync = _retryFullSync || fullSync;
      _scheduleRetry();
      return result;
    }
  }

  Future<SyncRunResult> _execute({required bool fullSync}) async {
    final settings = await _loadSettings();
    if (settings == null || !settings.isTableSyncConfigured) {
      if (fullSync && !_disposed) await _afterFullSync?.call();
      _clearRetryState();
      return const SyncRunResult();
    }

    await _recordStarted(fullSync: fullSync);

    final result = fullSync
        ? await _service.synchronize(settings, onProgress: _emitProgress)
        : await _service.pushPending(settings);
    await _recordResult(fullSync: fullSync, result: result);
    _listener?.call(result);
    if (result.isOk) {
      // Includes automatic retries with zero downloaded rows. The callback
      // may write local data, but must not await another coordinator run.
      if (fullSync && !_disposed) await _afterFullSync?.call();
      // A push-only success does not prove that a failed pull recovered.
      // Keep that full-sync retry pending until a full sync succeeds.
      if (fullSync || !_retryFullSync) {
        _clearRetryState();
      }
    } else {
      _retryFullSync = _retryFullSync || fullSync;
      _scheduleRetry();
    }
    return result;
  }

  Future<void> _recordStarted({required bool fullSync}) async {
    final recorder = _statusRecorder;
    if (recorder == null) return;
    try {
      if (fullSync) {
        await recorder.recordFullSyncStarted();
      } else {
        await recorder.recordAutoUploadStarted();
      }
    } catch (_) {
      // Diagnostic persistence must never prevent synchronization.
    }
  }

  Future<void> _recordResult({
    required bool fullSync,
    required SyncRunResult result,
  }) async {
    final recorder = _statusRecorder;
    if (recorder == null) return;
    final pendingUploadCount = await _pendingUploadCount();
    try {
      if (fullSync) {
        await recorder.recordFullSyncResult(
          result,
          pendingUploadCount: pendingUploadCount,
        );
      } else {
        await recorder.recordAutoUploadResult(
          result,
          pendingUploadCount: pendingUploadCount,
        );
      }
    } catch (_) {
      // Diagnostic persistence must never prevent synchronization.
    }
  }

  Future<int?> _pendingUploadCount() async {
    try {
      final row = await _database
          .customSelect('SELECT COUNT(*) AS count FROM sync_outbox')
          .getSingle();
      return row.read<int>('count');
    } catch (_) {
      return null;
    }
  }

  void _emitProgress(SyncProgress progress) {
    _currentProgress = progress;
    for (final listener in List<SyncProgressListener>.of(_progressListeners)) {
      listener(progress);
    }
  }

  void _clearRetryState() {
    _retryAttempt = 0;
    _retryFullSync = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _scheduleRetry() {
    if (_retryTimer != null || _disposed) return;
    final index = _retryAttempt.clamp(0, _retryDelays.length - 1);
    _retryAttempt++;
    _retryTimer = Timer(_retryDelays[index], () {
      _retryTimer = null;
      unawaited(_run(fullSync: _retryFullSync));
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    await _updatesSubscription?.cancel();
  }
}
