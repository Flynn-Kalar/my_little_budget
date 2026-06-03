import '../../core/validation.dart';

/// SPEC §4.8.3 / §5.4 — 태그 입력 검증. name 1~20, color hex.

class TagDraft {
  const TagDraft({required this.name, required this.color});
  final String name;
  final String color;
}

ValidationResult<TagDraft> validateTag({
  required String name,
  String color = '#64748b',
}) {
  final errors = <String, String>{};
  final cleaned = name.trim();
  if (cleaned.isEmpty || cleaned.length > 20) {
    errors['name'] = '이름은 1~20자여야 합니다';
  }
  if (!isHexColor(color)) {
    errors['color'] = '색상은 #RRGGBB 형식이어야 합니다';
  }
  if (errors.isNotEmpty) return ValidationResult.fail(errors);
  return ValidationResult.ok(TagDraft(name: cleaned, color: color));
}
