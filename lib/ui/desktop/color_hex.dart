import 'package:flutter/material.dart';

/// "#RRGGBB" → Color. 잘못된 값은 기본 회색.
Color colorFromHex(String? hex) {
  if (hex == null) return const Color(0xFF94A3B8);
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h, radix: 16);
  if (v == null) return const Color(0xFF94A3B8);
  return Color(0xFF000000 | v);
}
