import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/colors.dart';

void main() {
  group('colorPalette', () {
    test('16색 (Tauri colors.ts 와 동일)', () {
      expect(colorPalette.length, 16);
      // 마지막 색 — Tauri 와 동일하게 #0891b2 포함되어야 함
      expect(colorPalette, contains('#0891b2'));
    });
  });

  group('randomColor', () {
    test('exclude 가 비어있으면 팔레트 내 색 반환', () {
      final c = randomColor();
      expect(colorPalette, contains(c));
    });

    test('exclude 에 있는 색은 가능한 한 피함', () {
      // 거의 모든 색을 exclude → 남은 한 색만 가능
      final exclude = colorPalette.where((c) => c != '#16a34a').toList();
      for (var i = 0; i < 20; i++) {
        expect(randomColor(exclude: exclude), '#16a34a');
      }
    });

    test('exclude 가 전체면 팔레트 전체에서 다시 뽑음 (예외 던지지 않음)', () {
      final c = randomColor(exclude: colorPalette);
      expect(colorPalette, contains(c));
    });

    test('대소문자 무시 매칭', () {
      // 대문자 hex 를 exclude 에 넣어도 동일 색 회피
      final exclude = colorPalette.where((c) => c != '#16a34a')
          .map((c) => c.toUpperCase()).toList();
      expect(
        randomColor(exclude: exclude, rng: Random(0)),
        '#16a34a',
      );
    });
  });
}
