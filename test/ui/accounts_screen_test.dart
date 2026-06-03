import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/app.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';

void main() {
  testWidgets('/accounts: 총 순자산 + 기본 자산 5개 + 자산 클릭 → 상세 이동',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MyLittleBudgetApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 사이드바 → 자산
    await tester.tap(find.text('자산').first);
    await tester.pumpAndSettle();

    expect(find.text('총 순자산'), findsOneWidget);
    // 시드된 5개 자산명이 모두 보여야 함
    // 일부 이름은 kind 라벨/사이드바와 겹치므로 findsWidgets 사용.
    for (final name in const ['주거래 통장', '신용카드', '현금', '비상금', '투자']) {
      expect(find.text(name), findsWidgets, reason: '$name 행이 보여야 함');
    }

    // "주거래 통장" 행 클릭 → 상세
    await tester.tap(
      find.ancestor(of: find.text('주거래 통장'), matching: find.byType(InkWell)).first,
    );
    await tester.pumpAndSettle();

    // 상세 화면: 뒤로 링크 + "초기" 헤더가 빈 상태에도 보임
    expect(find.text('초기'), findsOneWidget);
    expect(find.text('초기 잔액'), findsOneWidget);
    expect(find.text('거래 내역이 없습니다.'), findsOneWidget);
  });
}
