import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';

void main() {
  testWidgets('내역 화면: 거래 표시 + 행 클릭 시 편집 다이얼로그 + 필터 패널', (tester) async {
    // 데스크톱 크기 (기본 800×600 이면 행이 화면 밖으로 밀려남)
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final accId = (await db.accountsDao.getActiveAccounts()).first.id;
    final cat = (await db.categoriesDao.getActiveCategories('expense')).first;
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 12345,
        occurredOn: currentDateKey(),
        occurredTime: '00:00',
        accountId: accId,
        categoryId: cat.id,
      ),
      tagNames: const ['테스트태그'],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 필터 패널 존재
    expect(find.text('필터'), findsOneWidget);
    // 거래가 목록에 표시 (카테고리명 + 태그칩)
    expect(find.text(cat.name), findsWidgets);
    // 행의 태그칩 + 입력창 제안칩 양쪽에 나타남
    expect(find.text('#테스트태그'), findsWidgets);

    // 행 클릭 → 편집 다이얼로그 (카테고리명의 InkWell 조상을 탭)
    final rowInk =
        find.ancestor(of: find.text(cat.name), matching: find.byType(InkWell)).first;
    await tester.ensureVisible(rowInk);
    await tester.pumpAndSettle();
    await tester.tap(rowInk);
    await tester.pumpAndSettle();
    expect(find.text('거래 편집'), findsOneWidget);
    expect(find.text('복제'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
  });
}
