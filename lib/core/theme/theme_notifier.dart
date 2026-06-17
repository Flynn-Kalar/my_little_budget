import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_colors.dart';

/// SPEC §2.2 — 사용자 테마 색을 SharedPreferences 에 영속.
class ThemeNotifier extends Notifier<ThemePalettes> {
  static const _key = 'mlb-theme-palettes-v1';
  static const _legacyKey = 'mlb-theme-v1';

  final _ready = Completer<void>();

  /// 초기 비동기 로드 완료를 기다리는 데 사용 (테스트·런처 등).
  Future<void> get whenReady => _ready.future;

  @override
  ThemePalettes build() {
    // 동기 build: 기본값 즉시 반환 + 비동기 로드 시작.
    unawaited(_load());
    return defaultPalettes;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        state = ThemePalettes.fromJsonString(raw);
        return;
      }
      final legacyRaw = prefs.getString(_legacyKey);
      if (legacyRaw != null) {
        state = ThemePalettes(
          light: ThemeColors.fromJsonString(legacyRaw),
          dark: darkDefaultTheme,
        );
        await prefs.setString(_key, state.toJsonString());
      }
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> setColor(
    ThemeToken token,
    Color color, {
    required Brightness brightness,
  }) async {
    state = state.withColor(brightness, token, color);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.toJsonString());
  }

  Future<void> reset({required Brightness brightness}) async {
    state = state.reset(brightness);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state.toJsonString());
  }

  Future<void> resetAll() async {
    state = defaultPalettes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_legacyKey);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemePalettes>(
  ThemeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'mlb-theme-mode-v1';

  final _ready = Completer<void>();

  Future<void> get whenReady => _ready.future;

  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      state = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  Future<void> reset() async {
    state = ThemeMode.system;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
