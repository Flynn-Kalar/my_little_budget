import 'package:flutter/material.dart';

import 'theme_colors.dart';

/// SPEC §2.2 의 7개 테마 토큰. 일단 정적 기본값.
/// 추후 ThemeProvider + SharedPreferences 영속 추가.
class AppTokens {
  static const income = Color(0xFF2563EB);
  static const expense = Color(0xFFDC2626);
  static const transfer = Color(0xFFFFAE00);
  static const background = Color(0xFFECFEEF);
  static const surface = Color(0xFFF5FFF7);
  static const accent = Color(0xFF646464);
  static const warning = Color(0xFF5E00D1);

  // 사이드바 보조 색
  static const sidebarBg = Color(0xFFF5FFF7);
  static const sidebarBorder = Color(0xFFD8E8DC);
  static const sidebarActive = Color(0xFFE3F5E8);
  static const muted = Color(0xFF6B7280);
}

ThemeData buildAppTheme({
  ThemeColors colors = defaultTheme,
  Brightness brightness = Brightness.light,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.income,
    brightness: brightness,
    surface: brightness == Brightness.light ? colors.surface : null,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? colors.background
        : scheme.surface,
    cardTheme: CardThemeData(
      color: brightness == Brightness.light ? colors.surface : null,
    ),
  );
}
