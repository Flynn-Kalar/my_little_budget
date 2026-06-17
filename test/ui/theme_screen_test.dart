import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/ui/desktop/settings/theme_screen.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_theme_screen.dart';
import 'package:my_little_budget/ui/shared/prism_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('desktop theme color chip opens prism picker', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ThemeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('theme-color-picker-income')));
    await tester.pumpAndSettle();

    expect(find.byType(PrismColorPicker), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Hex'), findsOneWidget);
  });

  testWidgets('mobile theme token opens shared prism picker sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: MobileThemeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(PrismColorPicker), findsOneWidget);
    expect(find.text('R'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Hex'), findsOneWidget);
  });
}
