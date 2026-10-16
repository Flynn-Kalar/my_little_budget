import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';
import 'package:my_little_budget/features/notes/note_schedule.dart';
import 'package:my_little_budget/ui/mobile/calendar/mobile_calendar_screen.dart';
import 'package:my_little_budget/ui/desktop/calendar/calendar_screen.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} edits one calendar occurrence, skips and restores without changing series',
      (tester) async {
        await tester.binding.setSurfaceSize(
          mobile ? const Size(390, 844) : const Size(1400, 950),
        );
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final now = DateTime.now(),
            date = DateTime(DateTime.now().year, DateTime.now().month, 20, 9);
        final id = await db.calendarEventsDao.saveEvent(
          title: '월세 회차',
          startAt: date,
          settings: const CalendarScheduleSettings(timeZone: 'Asia/Seoul'),
          schedule: const NoteScheduleDraft(type: NoteScheduleType.monthly),
        );
        Widget app({String? request}) => ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: mobile
                  ? MobileCalendarScreen(
                      openEventId: request == null ? null : id,
                      openRequest: request,
                    )
                  : CalendarScreen(
                      openEventId: request == null ? null : id,
                      openRequest: request,
                    ),
            ),
          ),
        );
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        Future<void> waitForSave() async {
          for (
            var i = 0;
            i < 50 && find.byType(AlertDialog).evaluate().isNotEmpty;
            i++
          ) {
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        }

        try {
          await tester.pumpWidget(app());
          await tester.pumpAndSettle();
          await tap(find.text('월세 회차').first);
          await tap(find.text('이번 일정만 수정'));
          final title = find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == '제목',
          );
          await tester.enterText(title, '이번만 변경');
          await tap(find.widgetWithText(FilledButton, '저장'));
          await waitForSave();
          var event = (await db.calendarEventsDao.getEvent(id))!;
          expect(event.title, '월세 회차');
          final key = noteDateKey(date);
          expect(
            CalendarScheduleSettings.fromEvent(event).exceptions[key]?['title'],
            '이번만 변경',
          );
          await tap(find.text('이번만 변경').first);
          await tap(find.text('이번 일정 건너뛰기'));
          await tap(find.widgetWithText(FilledButton, '건너뛰기'));
          await waitForSave();
          event = (await db.calendarEventsDao.getEvent(id))!;
          expect(
            CalendarScheduleSettings.fromEvent(
              event,
            ).exceptions[key]?['skipped'],
            true,
          );
          await tester.pumpWidget(app(request: 'restore'));
          await tester.pumpAndSettle();
          await tap(find.text('변경·건너뛴 회차'));
          await tap(find.text('원래대로'));
          await tap(find.widgetWithText(FilledButton, '저장'));
          await waitForSave();
          event = (await db.calendarEventsDao.getEvent(id))!;
          expect(CalendarScheduleSettings.fromEvent(event).exceptions, isEmpty);
          expect(event.title, '월세 회차');
          final future = calendarInstances(
            event,
            DateTime(now.year, now.month + 1),
            DateTime(now.year, now.month + 2),
          );
          expect(future.single.title, '월세 회차');
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 1));
          await tester.pumpAndSettle();
          await db.close();
          await tester.binding.setSurfaceSize(null);
        }
      },
    );
  }
}
