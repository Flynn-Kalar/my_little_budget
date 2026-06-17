import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/theme/app_theme.dart';
import 'package:my_little_budget/core/theme/theme_colors.dart';
import 'package:my_little_budget/core/theme/theme_notifier.dart';
import 'package:my_little_budget/ui/shared/prism_color_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('first load uses default light and dark palettes', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    final palettes = container.read(themeProvider);
    expect(palettes.light, defaultTheme);
    expect(palettes.dark, darkDefaultTheme);
  });

  test('setColor changes and persists only the selected brightness', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    await container.read(themeProvider.notifier).setColor(
      ThemeToken.income,
      const Color(0xFF112233),
      brightness: Brightness.light,
    );

    final palettes = container.read(themeProvider);
    expect(palettes.light.income, const Color(0xFF112233));
    expect(palettes.dark.income, darkDefaultTheme.income);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mlb-theme-palettes-v1');
    expect(raw, isNotNull);
    final json = jsonDecode(raw!) as Map<String, dynamic>;
    expect(json['light']['income'], '#112233');
    expect(json['dark']['income'], '#60a5fa');
  });

  test('reloads new light and dark palette storage', () async {
    SharedPreferences.setMockInitialValues({
      'mlb-theme-palettes-v1':
          '{"light":{"income":"#aabbcc"},"dark":{"expense":"#112233"}}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    final palettes = container.read(themeProvider);
    expect(palettes.light.income, const Color(0xFFAABBCC));
    expect(palettes.light.expense, defaultTheme.expense);
    expect(palettes.dark.expense, const Color(0xFF112233));
    expect(palettes.dark.income, darkDefaultTheme.income);
  });

  test('migrates legacy single palette storage into light palette', () async {
    SharedPreferences.setMockInitialValues({
      'mlb-theme-v1': '{"income":"#aabbcc"}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    final palettes = container.read(themeProvider);
    expect(palettes.light.income, const Color(0xFFAABBCC));
    expect(palettes.dark, darkDefaultTheme);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mlb-theme-palettes-v1'), isNotNull);
  });

  test('reset changes only the selected brightness palette', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    await container.read(themeProvider.notifier).setColor(
      ThemeToken.income,
      const Color(0xFF112233),
      brightness: Brightness.light,
    );
    await container.read(themeProvider.notifier).setColor(
      ThemeToken.income,
      const Color(0xFF445566),
      brightness: Brightness.dark,
    );
    await container
        .read(themeProvider.notifier)
        .reset(brightness: Brightness.light);

    final palettes = container.read(themeProvider);
    expect(palettes.light, defaultTheme);
    expect(palettes.dark.income, const Color(0xFF445566));
  });

  test('theme mode persists in SharedPreferences', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).whenReady;

    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    expect(container.read(themeModeProvider), ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mlb-theme-mode-v1'), 'dark');
  });

  test('theme mode reloads from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({'mlb-theme-mode-v1': 'light'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeModeProvider.notifier).whenReady;

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('buildAppTheme uses explicit light and dark palettes', () {
    final light = buildAppTheme(colors: defaultTheme);
    final dark = buildAppTheme(
      colors: darkDefaultTheme,
      brightness: Brightness.dark,
    );
    final customLight = defaultTheme.withColor(
      ThemeToken.background,
      const Color(0xFFFFFFFF),
    );

    expect(light.scaffoldBackgroundColor, defaultTheme.background);
    expect(dark.scaffoldBackgroundColor, darkDefaultTheme.background);
    expect(
      buildAppTheme(colors: customLight).scaffoldBackgroundColor,
      const Color(0xFFFFFFFF),
    );
    expect(
      buildAppTheme(
        colors: darkDefaultTheme,
        brightness: Brightness.dark,
      ).scaffoldBackgroundColor,
      darkDefaultTheme.background,
    );
  });

  test('color parser and RGB helpers validate expected formats', () {
    expect(colorFromHex('#AABBCC'), const Color(0xFFAABBCC));
    expect(colorFromHex('aabbcc'), const Color(0xFFAABBCC));
    expect(colorFromHex('#abc'), isNull);
    expect(colorFromHex('#zzzzzz'), isNull);
    expect(isValidRgbChannel(0), isTrue);
    expect(isValidRgbChannel(255), isTrue);
    expect(isValidRgbChannel(256), isFalse);
    expect(hexFromColor(const Color(0xFF112233)), '#112233');
    expect(rgbFromColor(const Color(0xFF112233)), (17, 34, 51));
  });
}
