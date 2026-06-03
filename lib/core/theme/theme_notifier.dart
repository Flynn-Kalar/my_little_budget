import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_colors.dart';

/// SPEC §2.2 — 사용자 테마 색을 SharedPreferences 에 영속.
/// Tauri 의 localStorage 'mlb-theme-v1' 키와 의미 동등.
class ThemeNotifier extends Notifier<ThemeColors> {
  static const _key = 'mlb-theme-v1';

  final _ready = Completer<void>();

  /// 초기 비동기 로드 완료를 기다리는 데 사용 (테스트·런처 등).
  Future<void> get whenReady => _ready.future;

  @override
  ThemeColors build() {
    // 동기 build: 기본값 즉시 반환 + 비동기 로드 시작.
    unawaited(_load());
    return defaultTheme;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = ThemeColors.fromJsonString(raw);
      }
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> setColor(ThemeToken token, Color color) async {
    state = state.withColor(token, color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.toJsonString());
  }

  Future<void> reset() async {
    state = defaultTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeColors>(
  ThemeNotifier.new,
);
