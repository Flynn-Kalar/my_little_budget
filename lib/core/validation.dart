// SPEC §5.4 — 검증 공용 타입 + 포맷 헬퍼. 의존성 없는 plain Dart.

/// 검증 결과. 성공이면 value 보유, 실패면 field→메시지 맵.
class ValidationResult<T> {
  const ValidationResult.ok(T this.value) : errors = const {};
  const ValidationResult.fail(this.errors) : value = null;

  final T? value;
  final Map<String, String> errors;

  bool get isOk => errors.isEmpty;
  bool get isFail => errors.isNotEmpty;
}

final RegExp _dateKeyRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _timeKeyRe = RegExp(r'^\d{2}:\d{2}$');
final RegExp _monthKeyRe = RegExp(r'^\d{4}-\d{2}$');
final RegExp _hexColorRe = RegExp(r'^#[0-9a-fA-F]{6}$');

bool isDateKey(String s) => _dateKeyRe.hasMatch(s);
bool isTimeKey(String s) => _timeKeyRe.hasMatch(s);
bool isMonthKey(String s) => _monthKeyRe.hasMatch(s);
bool isHexColor(String s) => _hexColorRe.hasMatch(s);
