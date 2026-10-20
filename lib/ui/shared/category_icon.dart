import 'package:flutter/material.dart';
import '../../core/category_icons.dart';
import '../../core/theme/app_theme.dart';

class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    super.key,
    this.name,
    this.iconId,
    this.colorHex,
    this.type = 'expense',
    this.size = 36,
  });
  final String? name;
  final String? iconId;
  final String? colorHex;
  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = type == 'income'
        ? context.appIncome
        : type == 'transfer'
        ? context.appTransfer
        : context.appAccent;
    final parsed = int.tryParse(
      (colorHex ?? '').replaceFirst('#', ''),
      radix: 16,
    );
    final color = type == 'transfer' || parsed == null
        ? fallback
        : Color(0xff000000 | parsed);
    return Semantics(
      label: type == 'transfer' ? '이체' : name ?? '카테고리',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(
          resolveCategoryIcon(id: iconId, name: name, type: type),
          size: size * .58,
          color: color,
        ),
      ),
    );
  }
}
