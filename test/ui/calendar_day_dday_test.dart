import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/date.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';
import 'package:my_little_budget/features/calendar/korean_holidays.dart';
import 'package:my_little_budget/ui/desktop/calendar/calendar_screen.dart';
import 'package:my_little_budget/ui/mobile/calendar/mobile_calendar_screen.dart';

void main() {
  for (final mobile in [false, true]) {
    Future<void> mount(WidgetTester tester, AppDatabase db) async {
      await tester.binding.setSurfaceSize(
        mobile ? const Size(390, 844) : const Size(1100, 900),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: mobile
                  ? const MobileCalendarScreen()
                  : const CalendarScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await db.close();
      });
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Future<void> openDday(WidgetTester tester) async {
      if (mobile) {
        await tester.drag(find.byType(ListView).first, const Offset(0, 1500));
        await tester.pumpAndSettle();
      }
      await tap(tester, find.text('D-day').first);
    }

    Future<void> unmount(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
    }

    final prefix = mobile ? 'mobile' : 'desktop';
    testWidgets('$prefix empty date prefills editor and saves a D-day', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await mount(tester, db);
      final now = DateTime.now();
      final holidays = koreanHolidaysForMonth(currentMonthKey());
      final date = [
        for (var day = 1; day <= 12; day++) DateTime(now.year, now.month, day),
      ].firstWhere((date) => !holidays.containsKey(toDateKey(date)));
      await tap(
        tester,
        find.byKey(ValueKey('$prefix-calendar-cell-${toDateKey(date)}')),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '제목',
        ),
        findsOneWidget,
      );
      expect(
        find.text(mobile ? toDateKey(date) : '날짜: ${toDateKey(date)}'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == '제목',
        ),
        '기념일',
      );
      await tap(tester, find.byKey(const ValueKey('calendar-dday-switch')));
      await tap(tester, find.widgetWithText(FilledButton, '저장'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      final event = (await db.calendarEventsDao.listEvents()).single;
      expect(toDateKey(calendarEventStart(event)), toDateKey(date));
      expect(CalendarScheduleSettings.fromEvent(event).isDday, isTrue);
      await openDday(tester);
      expect(find.text('D-day 모아보기'), findsOneWidget);
      expect(find.text('기념일'), findsOneWidget);
      await tap(tester, find.text('기념일'));
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('calendar-dday-switch')),
            )
            .value,
        isTrue,
      );
      await tap(tester, find.byKey(const ValueKey('calendar-dday-switch')));
      await tap(tester, find.widgetWithText(FilledButton, '저장'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(find.text('기념일'), findsNothing);
      await tap(tester, find.text('D-day 추가'));
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('calendar-dday-switch')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });

    testWidgets('$prefix occupied date lists every event and can add another', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now(),
          date = DateTime(DateTime.now().year, DateTime.now().month, 8, 9);
      for (final title in ['오전 약속', '오후 약속']) {
        await db.calendarEventsDao.saveEvent(title: title, startAt: date);
      }
      await db.calendarEventsDao.saveEvent(
        title: '다음 해 D-day',
        startAt: DateTime(now.year + 1, 2, 1),
        allDay: true,
        settings: const CalendarScheduleSettings(isDday: true),
      );
      await mount(tester, db);
      await tap(
        tester,
        find.byKey(ValueKey('$prefix-calendar-cell-${toDateKey(date)}')),
      );
      expect(find.text('${toDateKey(date)} 일정'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('오전 약속'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('오후 약속'),
        ),
        findsOneWidget,
      );
      await tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('오전 약속'),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '오전 약속',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('취소').last);
      await tap(
        tester,
        find.byKey(ValueKey('$prefix-calendar-cell-${toDateKey(date)}')),
      );
      await tap(tester, find.widgetWithText(FilledButton, '일정 추가').last);
      expect(
        find.text(mobile ? toDateKey(date) : '날짜: ${toDateKey(date)}'),
        findsOneWidget,
      );
      await tap(tester, find.text('취소'));
      await openDday(tester);
      expect(find.text('다음 해 D-day'), findsOneWidget);
      expect(find.text('오전 약속'), findsNothing);
      await tap(tester, find.text('다음 해 D-day'));
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '다음 해 D-day',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('삭제').last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(find.text('다음 해 D-day'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
