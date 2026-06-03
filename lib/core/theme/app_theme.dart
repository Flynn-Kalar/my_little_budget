import 'package:flutter/material.dart';

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

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTokens.income,
      surface: AppTokens.surface,
    ),
    scaffoldBackgroundColor: AppTokens.background,
  );
}
