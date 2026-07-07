import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/mobile/accounts/mobile_accounts_screen.dart';
import 'package:my_little_budget/ui/mobile/calendar/mobile_calendar_screen.dart';
import 'package:my_little_budget/ui/mobile/stats/mobile_stats_screen.dart';

void main() {
  testWidgets('모바일 자산 화면은 총 자산, 총 부채, 순자산을 분리한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileAccountsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('총 자산'), findsOneWidget);
    expect(find.text('총 부채'), findsOneWidget);
    expect(find.text('순자산'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 통계 월별 추세는 범례를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = (await db.accountsDao.getActiveAccounts()).first;
    final incomeCategory = (await db.categoriesDao.getActiveCategories(
      'income',
    )).first;
    final expenseCategory = (await db.categoriesDao.getActiveCategories(
      'expense',
    )).first;
    final month = currentMonthKey();

    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'income',
        amount: 100000,
        occurredOn: '$month-01',
        occurredTime: '09:00',
        accountId: account.id,
        categoryId: incomeCategory.id,
      ),
    );
    await db.transactionsDao.saveTransaction(
      draft: TransactionDraft(
        type: 'expense',
        amount: 40000,
        occurredOn: '$month-02',
        occurredTime: '12:00',
        accountId: account.id,
        categoryId: expenseCategory.id,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileStatsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('수입'), findsWidgets);
    expect(find.text('지출'), findsWidgets);
    expect(find.text('순액'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('모바일 캘린더는 날짜 칸 라벨과 확장된 일정 입력 필드를 표시한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final month = currentMonthKey();
    await db.calendarEventsDao.saveEvent(
      title: '월세',
      description: '',
      startAt: DateTime.parse('$month-03 09:00:00'),
      endAt: DateTime.parse('$month-03 10:00:00'),
      allDay: false,
      color: '#2563eb',
      schedule: const NoteScheduleDraft(type: NoteScheduleType.none),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('월세'), findsWidgets);

    await tester.tap(find.byTooltip('일정 추가'));
    await tester.pumpAndSettle();

    expect(find.text('색상'), findsOneWidget);
    expect(find.widgetWithText(TextField, '장소'), findsOneWidget);
    expect(find.widgetWithText(TextField, '링크'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
}
