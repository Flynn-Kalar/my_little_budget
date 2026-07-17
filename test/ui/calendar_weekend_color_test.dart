import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/desktop/calendar/calendar_screen.dart';
import 'package:my_little_budget/ui/mobile/calendar/mobile_calendar_screen.dart';

const holidayRed = Color(0xFFDC2626);
const saturdayBlue = Color(0xFF2563EB);

void main() {
  testWidgets('데스크톱 캘린더 요일 헤더에서 일요일과 토요일을 구분한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textColor(tester, 'desktop-calendar-weekday-0'), holidayRed);
    expect(_textColor(tester, 'desktop-calendar-weekday-6'), saturdayBlue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });

  testWidgets('모바일 캘린더 요일 헤더에서 일요일과 토요일을 구분한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: MobileCalendarScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(_textColor(tester, 'mobile-calendar-weekday-0'), holidayRed);
    expect(_textColor(tester, 'mobile-calendar-weekday-6'), saturdayBlue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
    await db.close();
  });
}

Color? _textColor(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(ValueKey(key))).style?.color;
}
