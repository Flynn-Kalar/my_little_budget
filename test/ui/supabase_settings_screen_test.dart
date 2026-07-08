import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_table_sync_service.dart';
import 'package:my_little_budget/router/app_router.dart';

const _configuredSupabasePrefs = {
  'mlb-supabase-backup-url-v1': 'https://example.supabase.co',
  'mlb-supabase-backup-anon-key-v1': 'anon-key',
  'mlb-supabase-backup-bucket-v1': 'backups',
};

void main() {
  testWidgets('Mobile data management renders Supabase settings controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    container.read(appRouterProvider).go('/settings/backup');
    await tester.pumpAndSettle();
    await tester.tap(find.text('자동 동기화'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-url-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-save-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-test-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-table-test-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-upload-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-restore-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-supabase-status-panel')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Mobile data management defaults to local without Supabase setup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MyLittleBudgetApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyLittleBudgetApp)),
      );
      container.read(appRouterProvider).go('/settings/backup');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mobile-settings-local-sync-panel')),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('mobile-settings-auto-sync-panel')),
        findsNothing,
      );
    },
  );

  testWidgets('Mobile data management defaults to auto sync when configured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(_configuredSupabasePrefs);
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    container.read(appRouterProvider).go('/settings/backup');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mobile-settings-auto-sync-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mobile-settings-local-sync-panel')),
      findsNothing,
    );
  });

  testWidgets('Desktop data management renders DB table test button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    container.read(appRouterProvider).go('/settings/backup');
    await tester.pumpAndSettle();
    await tester.tap(find.text('자동 동기화'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-supabase-table-test-button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Desktop data management defaults to local without Supabase setup',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MyLittleBudgetApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyLittleBudgetApp)),
      );
      container.read(appRouterProvider).go('/settings/backup');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('settings-local-sync-panel')),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('settings-auto-sync-panel')),
        findsNothing,
      );
    },
  );

  testWidgets('Desktop data management defaults to auto sync when configured', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(_configuredSupabasePrefs);
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    container.read(appRouterProvider).go('/settings/backup');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('settings-auto-sync-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settings-local-sync-panel')),
      findsNothing,
    );
  });

  testWidgets('Mobile disables actions while DB table test is running', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = _PendingTableSyncService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          supabaseTableSyncServiceProvider.overrideWithValue(service),
        ],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MyLittleBudgetApp)),
    );
    container.read(appRouterProvider).go('/settings/backup');
    await tester.pumpAndSettle();
    await tester.tap(find.text('자동 동기화'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('mobile-settings-supabase-url-field')),
      'https://example.supabase.co',
    );
    await tester.enterText(
      find.byKey(const ValueKey('mobile-settings-supabase-anon-key-field')),
      'anon-key',
    );
    final tableButton = find.byKey(
      const ValueKey('mobile-settings-supabase-table-test-button'),
    );
    await tester.ensureVisible(tableButton);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(tableButton);
    await tester.pump();

    expect(tester.widget<OutlinedButton>(tableButton).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('mobile-settings-supabase-save-button')),
          )
          .onPressed,
      isNull,
    );

    service.complete();
    await tester.pumpAndSettle();
  });
}

class _PendingTableSyncService implements SupabaseTableSyncService {
  final _completer =
      Completer<SupabaseTableSyncResult<SupabaseTableConnectionStatus>>();

  void complete() {
    _completer.complete(
      const SupabaseTableSyncResult.ok(
        SupabaseTableConnectionStatus(tables: supabaseSyncTableNames),
      ),
    );
  }

  @override
  Future<SupabaseTableSyncResult<SupabaseTableConnectionStatus>> testConnection(
    SupabaseBackupSettings settings,
  ) {
    return _completer.future;
  }
}
