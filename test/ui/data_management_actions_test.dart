import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/local_backup_service.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/supabase_backup_service.dart';
import 'package:my_little_budget/data/supabase_backup_settings.dart';
import 'package:my_little_budget/data/supabase_table_sync_service.dart';
import 'package:my_little_budget/features/notes/providers.dart';
import 'package:my_little_budget/ui/desktop/settings/data_management_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_data_management_screen.dart';

void main() {
  for (final mobile in [false, true]) {
    final label = mobile ? 'mobile' : 'desktop';
    final prefix = mobile ? 'mobile-settings' : 'settings';

    Future<AppDatabase> pumpScreen(
      WidgetTester tester, {
      SupabaseTableSyncService? tables,
      SupabaseBackupService? storage,
    }) async {
      SharedPreferences.setMockInitialValues({
        'mlb-supabase-backup-url-v1': 'https://example.supabase.co',
        'mlb-supabase-backup-anon-key-v1': 'anon-key',
        'mlb-supabase-backup-bucket-v1': 'backups',
        'mlb-supabase-auth-email-v1': 'user@example.com',
      });
      await tester.binding.setSurfaceSize(Size(mobile ? 390 : 1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final directory = Directory.systemTemp.createTempSync('budget-ui-test-');
      final backups = LocalBackupService(db, directory: directory);
      addTearDown(() async {
        backups.dispose();
        await db.close();
        await directory.delete(recursive: true);
      });
      await db.notesDao.saveNote(title: '보존할 메모', content: '');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            localBackupServiceProvider.overrideWithValue(backups),
            rebuildNoteNotificationsProvider.overrideWithValue(() async {}),
            if (tables != null)
              supabaseTableSyncServiceProvider.overrideWithValue(tables),
            if (storage != null)
              supabaseBackupServiceProvider.overrideWithValue(storage),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: mobile
                  ? const MobileDataManagementScreen()
                  : const DataManagementScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return db;
    }

    Future<void> reveal(WidgetTester tester, Finder finder) async {
      final scrollable = find.byType(Scrollable).first;
      for (var attempt = 0; attempt < 30; attempt++) {
        if (finder.evaluate().isNotEmpty) {
          await tester.ensureVisible(finder);
          await tester.pump(const Duration(milliseconds: 200));
          if (finder.hitTestable().evaluate().isNotEmpty) return;
        }
        final dy =
            finder.evaluate().isNotEmpty && tester.getCenter(finder).dy < 0
            ? 350.0
            : -350.0;
        await tester.drag(scrollable, Offset(0, dy));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(finder.hitTestable(), findsOneWidget);
    }

    testWidgets(
      '$label reset cancellation preserves data; confirmation resets it',
      (tester) async {
        final db = await pumpScreen(tester);
        final reset = find.text('기기 초기화');
        await reveal(tester, reset);
        await reveal(tester, reset);
        await tester.tap(reset);
        // The busy indicator remains active while the confirmation is open.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        expect((await db.notesDao.listNotes()).single.title, '보존할 메모');

        await reveal(tester, reset);
        await tester.tap(reset);
        // The busy indicator remains active while the confirmation is open.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('초기화'));
        await tester.pumpAndSettle();
        expect(await db.notesDao.listNotes(), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$label handles a failed request and allows retry', (
      tester,
    ) async {
      final tables = _PendingTables();
      await pumpScreen(tester, tables: tables);
      final button = find.byKey(ValueKey('$prefix-supabase-table-test-button'));
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pump();
      tables.request.completeError(StateError('connection lost'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Supabase DB 테이블 확인에 실패했습니다'), findsOneWidget);
      expect(tester.takeException(), isNull);

      tables.request = Completer();
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pump();
      tables.request.complete(
        const SupabaseTableSyncResult.ok(
          SupabaseTableConnectionStatus(tables: ['mlb_notes']),
        ),
      );
      await tester.pumpAndSettle();
      expect(tables.calls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$label can leave the screen while a request finishes', (
      tester,
    ) async {
      final tables = _PendingTables();
      await pumpScreen(tester, tables: tables);
      final button = find.byKey(ValueKey('$prefix-supabase-table-test-button'));
      await reveal(tester, button);
      await tester.tap(button);
      await tester.pump();
      // Keep the app's ProviderScope alive while disposing only the screen.
      final context = tester.element(button);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('다른 화면')),
        ),
      );
      await tester.pumpAndSettle();
      tables.request.complete(
        const SupabaseTableSyncResult.ok(
          SupabaseTableConnectionStatus(tables: ['mlb_notes']),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('다른 화면'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$label blocks duplicate requests and mode changes while busy',
      (tester) async {
        final tables = _PendingTables();
        await pumpScreen(tester, tables: tables);
        final button = find.byKey(
          ValueKey('$prefix-supabase-table-test-button'),
        );
        await reveal(tester, button);
        // A second tap before rebuilding must also be ignored.
        await tester.tap(button);
        await tester.tap(button);
        await tester.pump();
        expect(tables.calls, 1);

        final windowsMode = find.text('Windows 버전 설치');
        // Mobile ListView may have disposed the selector above the viewport.
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pump(const Duration(milliseconds: 200));
        await reveal(tester, windowsMode);
        await tester.tap(windowsMode);
        await tester.pump();
        expect(find.byKey(ValueKey('$prefix-auto-sync-panel')), findsOneWidget);
        expect(
          find.byKey(ValueKey('$prefix-windows-download-panel')),
          findsNothing,
        );

        tables.request.complete(
          const SupabaseTableSyncResult.ok(
            SupabaseTableConnectionStatus(tables: ['mlb_notes']),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(windowsMode);
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('$prefix-windows-download-panel')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$label cancelling remote restore leaves data untouched', (
      tester,
    ) async {
      final storage = _PendingBackup();
      final db = await pumpScreen(tester, storage: storage);
      final backup = await db.backupDao.exportBackup();
      await db.notesDao.saveNote(title: '백업 이후에 추가한 메모', content: '');
      final restore = find.byKey(ValueKey('$prefix-supabase-restore-button'));
      await reveal(tester, restore);
      final container = ProviderScope.containerOf(tester.element(restore));
      final local = container.read(localBackupServiceProvider);
      await reveal(tester, restore);
      await tester.tap(restore);
      await tester.pump();
      storage.request.complete(SupabaseBackupResult.ok(backup.toJsonString()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('백업 복원 미리보기'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();

      expect(await db.notesDao.listNotes(), hasLength(2));
      expect(local.directory!.listSync(), isEmpty);
      expect(
        container.read(supabaseBackupSettingsProvider).lastRestoreAt,
        isNull,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _PendingBackup extends SupabaseStorageBackupService {
  final request = Completer<SupabaseBackupResult<String>>();

  @override
  Future<SupabaseBackupResult<String>> downloadLatestBackup(
    SupabaseBackupSettings settings,
  ) => request.future;
}

class _PendingTables implements SupabaseTableSyncService {
  var request =
      Completer<SupabaseTableSyncResult<SupabaseTableConnectionStatus>>();
  int calls = 0;

  @override
  Future<SupabaseTableSyncResult<SupabaseTableConnectionStatus>> testConnection(
    SupabaseBackupSettings settings,
  ) {
    calls++;
    return request.future;
  }
}
