import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/ui/shared/amount_input_formatter.dart';

void main() {
  test(
    'formats amount expressions and keeps the cursor after inserted digits',
    () {
      const oldValue = TextEditingValue(
        text: '999',
        selection: TextSelection.collapsed(offset: 3),
      );
      const newValue = TextEditingValue(
        text: '9999',
        selection: TextSelection.collapsed(offset: 4),
      );

      final formatted = amountInputFormatter.formatEditUpdate(
        oldValue,
        newValue,
      );

      expect(formatted.text, '9,999');
      expect(formatted.selection, const TextSelection.collapsed(offset: 5));
    },
  );

  test('formats each operand without changing operators', () {
    const value = TextEditingValue(
      text: '1000+2000×3',
      selection: TextSelection.collapsed(offset: 11),
    );

    final formatted = amountInputFormatter.formatEditUpdate(value, value);

    expect(formatted.text, '1,000+2,000×3');
    expect(formatted.selection.extentOffset, formatted.text.length);
  });
}
