import 'dart:convert';

import 'package:flutter/material.dart';

/// SPEC §2.2 — 사용자가 변경 가능한 7개 테마 토큰. theme.ts 와 1:1 대응.
enum ThemeToken {
  income,
  expense,
  transfer,
  background,
  surface,
  accent,
  warning,
}

class ThemeColors {
  const ThemeColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.background,
    required this.surface,
    required this.accent,
    required this.warning,
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color background;
  final Color surface;
  final Color accent;
  final Color warning;

  @override
  bool operator ==(Object other) {
    return other is ThemeColors &&
        other.income.toARGB32() == income.toARGB32() &&
        other.expense.toARGB32() == expense.toARGB32() &&
        other.transfer.toARGB32() == transfer.toARGB32() &&
        other.background.toARGB32() == background.toARGB32() &&
        other.surface.toARGB32() == surface.toARGB32() &&
        other.accent.toARGB32() == accent.toARGB32() &&
        other.warning.toARGB32() == warning.toARGB32();
  }

  @override
  int get hashCode => Object.hash(
    income.toARGB32(),
    expense.toARGB32(),
    transfer.toARGB32(),
    background.toARGB32(),
    surface.toARGB32(),
    accent.toARGB32(),
    warning.toARGB32(),
  );

  Color of(ThemeToken token) => switch (token) {
    ThemeToken.income => income,
    ThemeToken.expense => expense,
    ThemeToken.transfer => transfer,
    ThemeToken.background => background,
    ThemeToken.surface => surface,
    ThemeToken.accent => accent,
    ThemeToken.warning => warning,
  };

  ThemeColors withColor(ThemeToken token, Color color) => ThemeColors(
    income: token == ThemeToken.income ? color : income,
    expense: token == ThemeToken.expense ? color : expense,
    transfer: token == ThemeToken.transfer ? color : transfer,
    background: token == ThemeToken.background ? color : background,
    surface: token == ThemeToken.surface ? color : surface,
    accent: token == ThemeToken.accent ? color : accent,
    warning: token == ThemeToken.warning ? color : warning,
  );

  Map<String, String> toJson() => {
    for (final t in ThemeToken.values) t.name: _toHex(of(t)),
  };

  String toJsonString() => jsonEncode(toJson());

  /// 저장된 부분 JSON 과 기본값 merge.
  static ThemeColors fromJsonString(
    String s, {
    ThemeColors base = defaultTheme,
  }) {
    try {
      final j = jsonDecode(s);
      if (j is! Map) return base;
      var result = base;
      for (final t in ThemeToken.values) {
        final v = j[t.name];
        if (v is String) {
          final c = _parseHex(v);
          if (c != null) result = result.withColor(t, c);
        }
      }
      return result;
    } catch (_) {
      return base;
    }
  }
}

/// SPEC §2.2 의 기본값.
const defaultTheme = ThemeColors(
  income: Color(0xFF2563EB),
  expense: Color(0xFFDC2626),
  transfer: Color(0xFFFFAE00),
  background: Color(0xFFECFEEF),
  surface: Color(0xFFF5FFF7),
  accent: Color(0xFF646464),
  warning: Color(0xFF5E00D1),
);

const darkDefaultTheme = ThemeColors(
  income: Color(0xFF60A5FA),
  expense: Color(0xFFF87171),
  transfer: Color(0xFFFBBF24),
  background: Color(0xFF35384D),
  surface: Color(0xFF3D4056),
  accent: Color(0xFF8B8CFF),
  warning: Color(0xFFA78BFA),
);

String _toHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

Color? _parseHex(String hex) {
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}
