import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/router/app_router.dart';

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
}
