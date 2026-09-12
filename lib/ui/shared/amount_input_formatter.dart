import 'package:flutter/services.dart';

import '../../core/money.dart';

/// 금액과 금액 계산식의 숫자 토큰에 천 단위 구분점을 표시한다.
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return formatAmountEditingValue(newValue);
  }
}

const amountInputFormatter = AmountInputFormatter();

TextEditingValue formatAmountEditingValue(TextEditingValue value) {
  final formatted = formatAmountInput(value.text);
  if (formatted == value.text) return value;

  int mapOffset(int offset) {
    if (offset < 0) return offset;
    final safeOffset = offset.clamp(0, value.text.length).toInt();
    return formatAmountInput(value.text.substring(0, safeOffset)).length;
  }

  final selection = value.selection;
  return value.copyWith(
    text: formatted,
    selection: selection.isValid
        ? TextSelection(
            baseOffset: mapOffset(selection.baseOffset),
            extentOffset: mapOffset(selection.extentOffset),
            affinity: selection.affinity,
            isDirectional: selection.isDirectional,
          )
        : TextSelection.collapsed(offset: formatted.length),
    composing: TextRange.empty,
  );
}
