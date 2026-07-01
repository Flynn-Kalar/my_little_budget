import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_tags_screen.dart';

void main() {
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
}
