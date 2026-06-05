import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/theme/theme_colors.dart';
import 'package:my_little_budget/core/theme/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('첫 로드 — SharedPreferences 비었으면 defaultTheme', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;
    expect(container.read(themeProvider).income, defaultTheme.income);
  });

  test('setColor → 상태 변경 + SharedPreferences 영속', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    await container
        .read(themeProvider.notifier)
        .setColor(ThemeToken.income, const Color(0xFF112233));
    expect(container.read(themeProvider).income, const Color(0xFF112233));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mlb-theme-v1');
    expect(raw, contains('"income":"#112233"'));
  });

  test('reload from prefs (Tauri 호환 부분 키)', () async {
    SharedPreferences.setMockInitialValues({
      'mlb-theme-v1': '{"income":"#aabbcc"}', // 일부만 저장된 경우 나머지는 defaults
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    final t = container.read(themeProvider);
    expect(t.income, const Color(0xFFAABBCC));
    expect(t.expense, defaultTheme.expense); // 그대로
  });

  test('reset → defaultTheme + prefs 키 제거', () async {
    SharedPreferences.setMockInitialValues({
      'mlb-theme-v1': '{"income":"#aabbcc"}',
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(themeProvider.notifier).whenReady;

    await container.read(themeProvider.notifier).reset();
    expect(container.read(themeProvider).income, defaultTheme.income);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mlb-theme-v1'), isNull);
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
}
