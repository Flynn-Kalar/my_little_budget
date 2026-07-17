import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_sync_store.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_incremental_sync_service.dart';
import 'package:my_little_budget/data/supabase_sync_coordinator.dart';
import 'package:my_little_budget/data/sync_metadata.dart';
import 'package:my_little_budget/data/sync_models.dart';

const _settings = SupabaseBackupSettings(
  url: 'https://unit-test.supabase.co',
  anonKey: 'anon-key',
  bucket: '',
  authEmail: 'user@example.com',
);

void main() {
  test('a successful push does not cancel a pending full-sync retry', () async {
    final db = await _openDatabase();
    addTearDown(db.close);
    await _markAllSyncedAndClearOutbox(db);
    final remote = _FailFirstFetchGateway();
    final coordinator = _coordinator(db, remote);
    addTearDown(coordinator.dispose);

    final failedPull = await coordinator.synchronizeNow();
    final successfulPush = await coordinator.pushNow();

    expect(failedPull.isOk, isFalse);
    expect(successfulPush.isOk, isTrue);
    await expectLater(
      remote.secondFetch.timeout(const Duration(seconds: 1)),
      completes,
    );
    expect(remote.fetchCount, greaterThan(1));
  });

  testWidgets(
    'actual initial route does not backfill before a successful startup pull',
    (tester) async {
      final db = await _openDatabase();
      addTearDown(db.close);
      final coordinator = _FailedStartupCoordinator(db);
      var backfillRuns = 0;

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            supabaseSyncCoordinatorProvider.overrideWithValue(coordinator),
            recurringBackfillProvider.overrideWith((ref) async {
              backfillRuns++;
              return 0;
            }),
          ],
          child: const MyLittleBudgetApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());

      expect(backfillRuns, 0);
      expect(coordinator.pushCount, 0);
    },
  );

  testWidgets(
    'actual initial route backfills once after startup pull and once per resume',
    (tester) async {
      final db = await _openDatabase();
      addTearDown(db.close);
      final coordinator = _SuccessfulLifecycleCoordinator(db);
      var backfillRuns = 0;

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            supabaseSyncCoordinatorProvider.overrideWithValue(coordinator),
            recurringBackfillProvider.overrideWith((ref) async {
              backfillRuns++;
              return 0;
            }),
          ],
          child: const MyLittleBudgetApp(),
        ),
      );
      await tester.pump();

      expect(backfillRuns, 0);
      expect(coordinator.syncCount, 1);

      coordinator.completeStartupPull();
      await tester.pump();
      await tester.pump();

      expect(backfillRuns, 1);
      expect(coordinator.pushCount, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(coordinator.syncCount, 2);
      expect(backfillRuns, 2);
      expect(coordinator.pushCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _FailedStartupCoordinator extends SupabaseSyncCoordinator {
  _FailedStartupCoordinator(AppDatabase db)
    : super(
        database: db,
        service: SupabaseIncrementalSyncService(
          local: LocalSyncStore(db),
          remote: _FailFirstFetchGateway(),
        ),
        loadSettings: () async => _settings,
      );

  var pushCount = 0;

  @override
  void start({SyncResultListener? onResult}) {}

  @override
  Future<SyncRunResult> synchronizeNow() async {
    return const SyncRunResult(error: 'pull failed');
  }

  @override
  Future<SyncRunResult> pushNow() async {
    pushCount++;
    return const SyncRunResult();
  }
}

class _SuccessfulLifecycleCoordinator extends SupabaseSyncCoordinator {
  _SuccessfulLifecycleCoordinator(AppDatabase db)
    : super(
        database: db,
        service: SupabaseIncrementalSyncService(
          local: LocalSyncStore(db),
          remote: _FailFirstFetchGateway(),
        ),
        loadSettings: () async => _settings,
      );

  final _startupPull = Completer<SyncRunResult>();
  var syncCount = 0;
  var pushCount = 0;

  void completeStartupPull() {
    if (!_startupPull.isCompleted) {
      _startupPull.complete(const SyncRunResult());
    }
  }

  @override
  void start({SyncResultListener? onResult}) {}

  @override
  Future<SyncRunResult> synchronizeNow() {
    syncCount++;
    if (syncCount == 1) return _startupPull.future;
    return Future.value(const SyncRunResult());
  }

  @override
  Future<SyncRunResult> pushNow() async {
    pushCount++;
    return const SyncRunResult();
  }
}

SupabaseSyncCoordinator _coordinator(
  AppDatabase db,
  SupabaseSyncGateway remote, {
  List<Duration> retryDelays = const [Duration(milliseconds: 10)],
}) {
  return SupabaseSyncCoordinator(
    database: db,
    service: SupabaseIncrementalSyncService(
      local: LocalSyncStore(db),
      remote: remote,
    ),
    loadSettings: () async => _settings,
    retryDelays: retryDelays,
  );
}

Future<AppDatabase> _openDatabase() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  return db;
}

Future<void> _markAllSyncedAndClearOutbox(AppDatabase db) async {
  for (final table in localSyncTableNames) {
    await db.customStatement("UPDATE $table SET sync_status = 'synced'");
  }
  await db.customStatement('DELETE FROM sync_outbox');
}

class _FailFirstFetchGateway implements SupabaseSyncGateway {
  final _firstFetch = Completer<void>();
  final _secondFetch = Completer<void>();
  var fetchCount = 0;
  var upsertCount = 0;
  var _revision = 1;

  Future<void> get firstFetch => _firstFetch.future;
  Future<void> get secondFetch => _secondFetch.future;

  @override
  Future<List<RemoteSyncRow>> fetchChanges({
    required SupabaseBackupSettings settings,
    required String entity,
    required int afterRevision,
    required int limit,
  }) async {
    fetchCount++;
    if (!_firstFetch.isCompleted) {
      _firstFetch.complete();
      throw StateError('pull failed');
    }
    if (!_secondFetch.isCompleted) _secondFetch.complete();
    return const [];
  }

  @override
  Future<RemoteSyncRow> upsert({
    required SupabaseBackupSettings settings,
    required String entity,
    required String uuid,
    required Map<String, Object?> payload,
    required String? deletedAt,
  }) async {
    upsertCount++;
    final revision = _revision++;
    return RemoteSyncRow(
      uuid: uuid,
      payload: payload,
      updatedAt: DateTime.utc(
        2026,
        7,
        13,
      ).add(Duration(seconds: revision)).toIso8601String(),
      deletedAt: deletedAt,
      revision: revision,
    );
  }
}
