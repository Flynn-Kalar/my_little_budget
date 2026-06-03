import 'package:flutter/material.dart';

import '../../../../core/colors.dart';
import '../../color_hex.dart';

/// 16색 팔레트에서 한 색 선택. AccountForm, CategoryForm, TagForm 공용.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value; // current hex
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colorPalette.map((hex) {
        final selected = value.toLowerCase() == hex.toLowerCase();
        return InkWell(
          onTap: () => onChanged(hex),
          customBorder: const CircleBorder(),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorFromHex(hex),
              border: Border.all(
                color: selected ? Colors.black87 : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
