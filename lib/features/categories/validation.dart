import '../../core/validation.dart';

/// SPEC §5.4 — 카테고리 입력 검증.

class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.type,
    required this.color,
  });
  final String name;
  final String type; // income | expense
  final String color;
}

ValidationResult<CategoryDraft> validateCategory({
  required String name,
  required String type,
  String color = '#64748b',
}) {
  final errors = <String, String>{};

  final cleaned = name.trim();
  if (cleaned.isEmpty || cleaned.length > 20) {
    errors['name'] = '이름은 1~20자여야 합니다';
  }
  if (type != 'income' && type != 'expense') {
    errors['type'] = '카테고리 종류가 올바르지 않습니다';
  }
  if (!isHexColor(color)) {
    errors['color'] = '색상은 #RRGGBB 형식이어야 합니다';
  }

  if (errors.isNotEmpty) return ValidationResult.fail(errors);
  return ValidationResult.ok(
    CategoryDraft(name: cleaned, type: type, color: color),
  );
}
