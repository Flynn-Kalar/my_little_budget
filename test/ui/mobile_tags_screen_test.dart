import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_tags_screen.dart';

void main() {
  testWidgets('모바일 태그 저장 버튼은 시스템 내비게이션 영역 위에 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            const systemNavigation = EdgeInsets.only(bottom: 48);
            return MediaQuery(
              data: mediaQuery.copyWith(
                padding: systemNavigation,
                viewPadding: systemNavigation,
              ),
              child: child!,
            );
          },
          home: const MobileTagsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('태그 추가'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, '저장');
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(844 - 48));
  });

  testWidgets('모바일 태그 추가 후 목록 갱신 및 중복 오류를 처리한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileTagsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('태그 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '고정비');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();

    expect(find.text('#고정비'), findsOneWidget);
    expect(find.text('태그를 추가했습니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('태그 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '고정비');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('이미 사용 중인 태그 이름입니다.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 태그 화면에서 PC와 동일하게 순서를 변경한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.tagsDao.createTag('A', '#111111');
    await db.tagsDao.createTag('B', '#222222');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileTagsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('위로 이동'));
    await tester.pumpAndSettle();

    final tags = await db.tagsDao.getTags();
    expect(tags.map((tag) => tag.name), ['B', 'A']);
  });
}
