import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';

void main() {
  testWidgets('App boots and shows sidebar + 내역 화면', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 사이드바
    expect(find.text('my_little_budget'), findsOneWidget);
    // 내역 화면이 첫 라우트로 떠야 함 (제목 + 요약 라벨)
    expect(find.text('내역'), findsWidgets);
    expect(find.text('순수입'), findsOneWidget);
    // 비어있는 달 → 안내문
    expect(find.text('이 달엔 아직 기록이 없어요.'), findsOneWidget);
  });
  testWidgets('MVP main routes render without exceptions', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    final routes = [
      '/transactions',
      '/accounts',
      '/budget',
      '/stats',
      '/stats/yearly',
      '/investments',
      '/settings',
      '/settings/theme',
      '/settings/backup',
    ];

    for (final route in routes) {
      final context = tester.element(find.text('my_little_budget'));
      GoRouter.of(context).go(route);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: route);
    }
  });
}
