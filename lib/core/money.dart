import 'package:intl/intl.dart';

/// SPEC §2.3. 정수 원(KRW) 입력만 받는다.
final NumberFormat _krw = NumberFormat.currency(
  locale: 'ko_KR',
  symbol: '₩',
  decimalDigits: 0,
);

String formatKRW(int amount) => _krw.format(amount);

/// KRW 금액 입력. 콤마/원 표기를 허용하고 사칙연산 식은 계산한다. 빈 입력은 0.
int parseKRW(String input) {
  final expression = input
      .replaceAll(RegExp(r'[\s,₩원]'), '')
      .replaceAll('×', '*')
      .replaceAll('÷', '/')
      .replaceAll('x', '*')
      .replaceAll('X', '*');
  if (expression.isEmpty || expression == '-') return 0;
  if (RegExp(r'[^0-9+\-*/().]').hasMatch(expression)) return 0;

  final value = _AmountExpressionParser(expression).parse();
  if (value == null || !value.isFinite) return 0;
  return value.round();
}

class _AmountExpressionParser {
  _AmountExpressionParser(this._source);

  final String _source;
  int _index = 0;

  double? parse() {
    final value = _parseExpression();
    if (value == null || _index != _source.length) return null;
    return value;
  }

  double? _parseExpression() {
    final first = _parseTerm();
    if (first == null) return null;
    var value = first;

    while (_match('+') || _match('-')) {
      final operator = _source[_index - 1];
      final right = _parseTerm();
      if (right == null) return null;
      value = operator == '+' ? value + right : value - right;
    }
    return value;
  }

  double? _parseTerm() {
    final first = _parseFactor();
    if (first == null) return null;
    var value = first;

    while (_match('*') || _match('/')) {
      final operator = _source[_index - 1];
      final right = _parseFactor();
      if (right == null) return null;
      if (operator == '/') {
        if (right == 0) return null;
        value /= right;
      } else {
        value *= right;
      }
    }
    return value;
  }

  double? _parseFactor() {
    if (_match('+')) return _parseFactor();
    if (_match('-')) {
      final value = _parseFactor();
      return value == null ? null : -value;
    }

    if (_match('(')) {
      final value = _parseExpression();
      if (value == null || !_match(')')) return null;
      return value;
    }

    return _parseNumber();
  }

  double? _parseNumber() {
    final start = _index;
    while (_index < _source.length && _isDigit(_source.codeUnitAt(_index))) {
      _index++;
    }
    if (_match('.')) {
      while (_index < _source.length && _isDigit(_source.codeUnitAt(_index))) {
        _index++;
      }
    }
    if (start == _index) return null;
    return double.tryParse(_source.substring(start, _index));
  }

  bool _match(String token) {
    if (_index >= _source.length || _source[_index] != token) return false;
    _index++;
    return true;
  }

  bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}
