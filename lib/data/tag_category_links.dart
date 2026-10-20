import 'dart:convert';

List<int> readTagCategoryIds(String json) {
  final value = jsonDecode(json);
  if (value is! List || value.any((id) => id is! int || id <= 0)) {
    throw const FormatException('태그 카테고리 형식이 올바르지 않습니다.');
  }
  return value.cast<int>().toSet().toList()..sort();
}

String encodeTagCategoryIds(Iterable<int> ids) =>
    jsonEncode(ids.toSet().toList()..sort());
