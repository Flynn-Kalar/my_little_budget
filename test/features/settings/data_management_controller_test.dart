import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/data/backup.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_backup_service.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/supabase_backup_service.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_operation_status.dart';
import 'package:my_little_budget/features/notes/providers.dart';
import 'package:my_little_budget/features/settings/data_management_controller.dart';
import 'package:my_little_budget/features/sync/invalidate_synced_data.dart';

const _settings = SupabaseBackupSettings(
  url: 'https://example.supabase.co',
  anonKey: 'anon-key',
  bucket: 'backups',
  authEmail: 'user@example.com',
);

void main() {
  late AppDatabase db;
  late Directory directory;
  late LocalBackupService local;
  late _Storage storage;
  late ProviderContainer container;
  late DataManagementController controller;
  late List<String> refreshedTitles;
  late int invalidations;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp(
      'budget-controller-test-',
    );
    local = LocalBackupService(db, directory: directory);
    storage = _Storage();
    invalidations = 0;
    refreshedTitles = [];
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        localBackupServiceProvider.overrideWithValue(local),
        supabaseBackupServiceProvider.overrideWithValue(storage),
        invalidateSyncedDataProvider.overrideWithValue(() => invalidations++),
        rebuildNoteNotificationsProvider.overrideWithValue(() async {
          refreshedTitles = (await db.notesDao.listNotes())
              .map((note) => note.title)
              .toList();
        }),
      ],
    );
    await container.read(supabaseBackupSettingsProvider.notifier).whenReady;
    await container.read(supabaseOperationStatusProvider.notifier).whenReady;
    controller = container.read(dataManagementControllerProvider);
  });

  tearDown(() async {
    container.dispose();
    local.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'restore snapshots current data before replacing and refreshing it',
    () async {
      await db.notesDao.saveNote(title: '백업에 있는 메모', content: '');
      final backup = controller.parseBackupContent(
        (await controller.exportBackup()).toJsonString(),
      );
      await db.notesDao.saveNote(title: '백업 이후에 추가한 메모', content: '');

      await controller.restoreBackup(backup);

      final safetyBackup = await local.read((await local.list()).single);
      expect(
        safetyBackup.notes.map((note) => note.title),
        containsAll(['백업에 있는 메모', '백업 이후에 추가한 메모']),
      );
      expect((await controller.exportBackup()).notes.single.title, '백업에 있는 메모');
      expect(invalidations, 1);
      expect(refreshedTitles, ['백업에 있는 메모']);
    },
  );

  test(
    'failed safety snapshot leaves current data and restore status intact',
    () async {
      final emptyBackup = await controller.exportBackup();
      await db.notesDao.saveNote(title: '유지할 메모', content: '');
      // A regular file cannot be used as a backup directory.
      final blocked = File('${directory.path}${Platform.pathSeparator}blocked');
      await blocked.writeAsString('not a directory');
      final failingLocal = LocalBackupService(
        db,
        directory: Directory(blocked.path),
      );
      container.updateOverrides([
        appDatabaseProvider.overrideWithValue(db),
        localBackupServiceProvider.overrideWithValue(failingLocal),
        supabaseBackupServiceProvider.overrideWithValue(storage),
        invalidateSyncedDataProvider.overrideWithValue(() => invalidations++),
        rebuildNoteNotificationsProvider.overrideWithValue(() async {}),
      ]);
      addTearDown(failingLocal.dispose);

      await expectLater(
        controller.restoreRemoteBackup(emptyBackup, _settings),
        throwsA(isA<FileSystemException>()),
      );

      expect((await controller.exportBackup()).notes.single.title, '유지할 메모');
      expect(invalidations, 0);
      expect(
        container.read(supabaseBackupSettingsProvider).lastRestoreAt,
        isNull,
      );
      expect(
        container.read(supabaseOperationStatusProvider).storageCheckResult,
        StorageCheckResult.failure,
      );
    },
  );

  test(
    'invalid remote JSON does not alter data or create a recovery point',
    () async {
      await db.notesDao.saveNote(title: '유지할 메모', content: '');
      storage.download = 'invalid json';

      await expectLater(
        controller.downloadBackup(_settings),
        throwsA(isA<DataManagementException>()),
      );

      expect((await controller.exportBackup()).notes.single.title, '유지할 메모');
      expect(await local.list(), isEmpty);
      expect(invalidations, 0);
      expect(
        container.read(supabaseBackupSettingsProvider).lastRestoreAt,
        isNull,
      );
    },
  );

  test(
    'remote restore records success only after replacement and refresh',
    () async {
      await container
          .read(supabaseBackupSettingsProvider.notifier)
          .save(_settings);
      final backup = await controller.exportBackup();
      await db.notesDao.saveNote(title: '교체할 메모', content: '');
      storage.download = backup.toJsonString();

      final downloaded = await controller.downloadBackup(_settings);
      expect((await controller.exportBackup()).notes, hasLength(1));
      await controller.restoreRemoteBackup(downloaded, _settings);

      expect((await controller.exportBackup()).notes, isEmpty);
      expect(invalidations, 1);
      expect(refreshedTitles, isEmpty);
      expect(
        container.read(supabaseBackupSettingsProvider).lastRestoreAt,
        isNotNull,
      );
      expect(
        container.read(supabaseOperationStatusProvider).storageCheckResult,
        StorageCheckResult.exists,
      );
    },
  );

  test('failed upload does not record a successful backup timestamp', () async {
    storage.uploadError = 'upload failed';

    await expectLater(
      controller.uploadBackup(_settings),
      throwsA(isA<DataManagementException>()),
    );

    expect(container.read(supabaseBackupSettingsProvider).lastBackupAt, isNull);
    expect(
      container.read(supabaseOperationStatusProvider).storageCheckResult,
      StorageCheckResult.failure,
    );
    expect(invalidations, 0);
  });

  test(
    'reset refreshes screens and notifications after restoring defaults',
    () async {
      await db.notesDao.saveNote(title: '지울 메모', content: '');

      await controller.resetAllData();

      final backup = await controller.exportBackup();
      expect(backup.notes, isEmpty);
      expect(backup.accounts, isNotEmpty);
      expect(backup.categories, isNotEmpty);
      expect(invalidations, 1);
      expect(refreshedTitles, isEmpty);
    },
  );
}

class _Storage implements SupabaseBackupService {
  String download = '';
  String? uploadError;

  @override
  Future<SupabaseBackupResult<String>> downloadLatestBackup(
    SupabaseBackupSettings settings,
  ) async => SupabaseBackupResult.ok(download);

  @override
  Future<SupabaseBackupResult<SupabaseBackupRemoteStatus>> getRemoteStatus(
    SupabaseBackupSettings settings,
  ) async => const SupabaseBackupResult.ok(
    SupabaseBackupRemoteStatus(latestPath: 'latest.json', exists: true),
  );

  @override
  Future<SupabaseBackupResult<void>> testConnection(
    SupabaseBackupSettings settings,
  ) async => const SupabaseBackupResult.ok(null);

  @override
  Future<SupabaseBackupResult<SupabaseBackupUpload>> uploadBackup({
    required SupabaseBackupSettings settings,
    required Backup backup,
    DateTime? now,
  }) async => uploadError != null
      ? SupabaseBackupResult.fail(uploadError!)
      : const SupabaseBackupResult.ok(
          SupabaseBackupUpload(
            latestPath: 'latest.json',
            historyPath: 'history.json',
          ),
        );
}
