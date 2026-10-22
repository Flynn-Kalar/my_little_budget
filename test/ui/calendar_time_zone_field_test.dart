import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/ui/shared/calendar_time_zone_field.dart';
import 'package:my_little_budget/ui/shared/calendar_schedule_options.dart';
import 'package:my_little_budget/features/calendar/calendar_schedule.dart';

void main() {
  for (final width in [320.0, 1000.0]) {
    testWidgets('editable timezone dropdown works at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final draft = CalendarScheduleDraft(
        const CalendarScheduleSettings(timeZone: 'Etc/GMT-9'),
      );
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: CalendarScheduleOptions(
                draft: draft,
                date: DateTime(2026, 1, 15),
                repeating: false,
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byType(CalendarTimeZoneField),
        matching: find.byType(TextField),
      );
      expect(
        tester.widget<TextField>(input).controller!.text,
        '고정 시간대 / UTC +9',
      );
      expect(draft.zone.text, 'Etc/GMT-9');
      await tester.tap(input);
      await tester.enterText(input, '東京');
      await tester.pumpAndSettle();
      await tester.tap(find.text('도쿄 / UTC +9').last);
      await tester.pumpAndSettle();
      expect(
        draft.settings(start: DateTime(2026, 1, 15), allDay: false).timeZone,
        'Asia/Tokyo',
      );
      expect(tester.widget<TextField>(input).controller!.text, '도쿄 / UTC +9');
      await tester.tap(input);
      await tester.enterText(input, 'UTC +5:45');
      await tester.pumpAndSettle();
      expect(find.text('카트만두 / UTC +5:45'), findsWidgets);
      await tester.tap(find.text('카트만두 / UTC +5:45').last);
      await tester.pumpAndSettle();
      expect(draft.zone.text, 'Asia/Kathmandu');
      await tester.enterText(input, 'unknown-zone');
      await tester.pumpAndSettle();
      expect(
        draft.settings(start: DateTime(2026), allDay: false).validationError,
        isNotNull,
      );
      draft.zone.text = 'Asia/Seoul';
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(input).controller!.text, '서울 / UTC +9');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
