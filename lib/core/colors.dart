import 'dart:math';

/// SPEC §4.8 / colors.ts — 자산·카테고리·태그 신규 색 자동 선택용 팔레트.
/// Tailwind 500 계열 위주로 가독성·구분성 좋은 16색.
const colorPalette = <String>[
  '#2563eb', // blue
  '#dc2626', // red
  '#16a34a', // green
  '#f97316', // orange
  '#0ea5e9', // sky
  '#a855f7', // purple
  '#ec4899', // pink
  '#14b8a6', // teal
  '#f59e0b', // amber
  '#6366f1', // indigo
  '#84cc16', // lime
  '#06b6d4', // cyan
  '#7c3aed', // violet
  '#22c55e', // emerald
  '#ef4444', // red-500
  '#0891b2', // cyan-600
];

final _defaultRng = Random();

/// 팔레트에서 랜덤 색 반환.
/// [exclude] 가 주어지면 그 색은 우선순위에서 뒤로 (가능하면 새 색을 고르고, 다 쓰였으면 전체에서 다시 뽑음).
String randomColor({Iterable<String> exclude = const [], Random? rng}) {
  final r = rng ?? _defaultRng;
  final used = exclude.map((c) => c.toLowerCase()).toSet();
  final available =
      colorPalette.where((c) => !used.contains(c.toLowerCase())).toList();
  final pool = available.isNotEmpty ? available : colorPalette;
  return pool[r.nextInt(pool.length)];
}
