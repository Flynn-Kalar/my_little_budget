import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/ui/mobile/mobile_widgets.dart';
import 'package:my_little_budget/ui/shared/amount_input_formatter.dart';

const _displayKey = ValueKey('mobile-transaction-calculator-display');
Finder get _display => find.byKey(_displayKey);
TextField _field(WidgetTester tester) => tester.widget<TextField>(_display);

void main() {
  testWidgets(
    'touch cursor inserts digits, decimal, parentheses and operators',
    (tester) async {
      await _open(tester);
      final controller = _field(tester).controller!;
      for (final label in [
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        '00',
        '.',
        '+',
        '-',
        '×',
        '÷',
        '()',
      ]) {
        _setExpression(controller, '123+45');
        await tester.pump();
        await _tapCursor(tester, 3);
        expect(controller.selection.baseOffset, 3);
        await _key(tester, label);
        final inserted = label == '()' ? '(' : label;
        final expected = formatAmountEditingValue(
          TextEditingValue(
            text: '123$inserted+45',
            selection: TextSelection.collapsed(offset: 3 + inserted.length),
          ),
        );
        expect(controller.value, expected);
        expect(_field(tester).showCursor, isTrue);
      }
      _setExpression(controller, '(12+34');
      await tester.pump();
      await _tapCursor(tester, 3);
      await _key(tester, '()');
      expect(controller.text, '(12)+34');
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backspace deletes before touch cursor including grouping commas',
    (tester) async {
      await _open(tester);
      final controller = _field(tester).controller!;
      _setExpression(controller, '123+45');
      await tester.pump();
      await _tapCursor(tester, 3);
      await _key(tester, 'backspace');
      expect(controller.text, '12+45');
      expect(controller.selection.baseOffset, 2);
      await _tapCursor(tester, 0);
      await _key(tester, 'backspace');
      expect(controller.text, '12+45');
      _setExpression(controller, '1,234+56');
      await tester.pump();
      await _tapCursor(tester, 2);
      await _key(tester, 'backspace');
      expect(controller.text, '234+56');
      expect(controller.selection.baseOffset, 0);
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 3,
      );
      await _key(tester, '9');
      expect(controller.text, '9+56');
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      await _key(tester, 'backspace');
      expect(controller.text, '9');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('wraps first, shrinks only for height, then scrolls at 12', (
    tester,
  ) async {
    await _open(tester, size: const Size(390, 640));
    final controller = _field(tester).controller!;
    final defaultSize = _field(tester).style!.fontSize!;
    final defaultCursorHeight = _editable(tester).cursorHeight;
    final keypad = find.byKey(
      const ValueKey('mobile-transaction-amount-keypad'),
    );
    final keypadRect = tester.getRect(keypad);
    _setExpression(controller, List.filled(8, '12').join('+'));
    await tester.pump();
    expect(_field(tester).style!.fontSize, defaultSize);
    expect(_editable(tester).cursorHeight, defaultCursorHeight);
    expect(
      _editable(tester).getLocalRectForCaret(controller.selection.extent).top,
      greaterThan(_editable(tester).preferredLineHeight),
    );
    expect(_field(tester).scrollController!.position.maxScrollExtent, 0);

    _setExpression(controller, List.filled(24, '123+456').join('+'));
    await tester.pump();
    expect(_field(tester).style!.fontSize!, inExclusiveRange(12, defaultSize));
    expect(_editable(tester).cursorHeight, lessThan(defaultCursorHeight));
    expect(_field(tester).scrollController!.position.maxScrollExtent, 0);
    expect(tester.getRect(keypad), keypadRect);
    expect(tester.getRect(_display).bottom, lessThan(keypadRect.top));

    final longExpression = List.filled(400, '123+456').join('+');
    _setExpression(controller, longExpression);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_field(tester).style!.fontSize, 12);
    expect(_field(tester).maxLines, isNull);
    final scroll = _field(tester).scrollController!;
    expect(scroll.position.axis, Axis.vertical);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(controller.text, longExpression);
    _expectCursorVisible(tester);
    final smallCursorHeight = _editable(tester).cursorHeight;
    expect(smallCursorHeight, lessThan(defaultCursorHeight));
    expect(smallCursorHeight, _editable(tester).preferredLineHeight);
    scroll.jumpTo(0);
    await tester.pump();
    await _tapCursor(tester, 3);
    expect(controller.selection.baseOffset, 3);
    await _key(tester, '×');
    expect(controller.text, longExpression.replaceRange(3, 3, '×'));
    _expectCursorVisible(tester);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await tester.pump();
    _expectCursorVisible(tester);
    await _key(tester, '+');
    await _key(tester, '9');
    _expectCursorVisible(tester);
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    _expectCursorVisible(tester);
    await tester.drag(_display, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await _key(tester, 'C');
    expect(controller.text, isEmpty);
    expect(_field(tester).style!.fontSize, defaultSize);
    expect(_editable(tester).cursorHeight, defaultCursorHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'example wraps at default size and reflows without moving selection',
    (tester) async {
      await _open(tester);
      final controller = _field(tester).controller!;
      final defaultSize = _field(tester).style!.fontSize;
      _setExpression(controller, '16+595');
      await tester.pump();
      expect(_field(tester).style!.fontSize, defaultSize);
      final firstLineTop = _editable(
        tester,
      ).getLocalRectForCaret(controller.selection.extent).top;
      const expression = '91,673-4,692+497+46,294+76,492+679,462+79,462+67,926';
      _setExpression(controller, expression);
      await tester.pump();
      expect(_field(tester).style!.fontSize, defaultSize);
      expect(
        _editable(tester).getLocalRectForCaret(controller.selection.extent).top,
        greaterThan(firstLineTop),
      );
      expect(_field(tester).scrollController!.position.maxScrollExtent, 0);
      await _tapCursor(tester, 17);
      expect(controller.selection.baseOffset, 17);
      final selection = controller.selection;
      await tester.binding.setSurfaceSize(const Size(390, 530));
      await tester.pump();
      expect(_field(tester).style!.fontSize!, lessThan(defaultSize!));
      expect(controller.selection, selection);
      _expectCursorVisible(tester);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pump();
      expect(_field(tester).style!.fontSize, defaultSize);
      expect(controller.selection, selection);
      await _key(tester, '()');
      expect(controller.text, expression.replaceRange(17, 17, '('));
      expect(controller.selection.baseOffset, 18);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel preserves original amount and completion callback', (
    tester,
  ) async {
    var completions = 0;
    final amount = await _open(tester, onCompleted: () => completions++);
    await _key(tester, '9');
    await tester.tap(find.byTooltip('닫기'));
    await tester.pumpAndSettle();
    expect(amount.text, '123');
    expect(completions, 0);
  });
}

void _setExpression(TextEditingController controller, String text) {
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
}

Future<void> _tapCursor(WidgetTester tester, int offset) async {
  // Separate intentional single taps from the platform's double-tap selection.
  await tester.pump(const Duration(milliseconds: 500));
  final editable = _editable(tester);
  final caret = editable.getLocalRectForCaret(TextPosition(offset: offset));
  await tester.tapAt(editable.localToGlobal(caret.center));
  await tester.pump();
  expect(_field(tester).controller!.selection.isCollapsed, isTrue);
}

RenderEditable _editable(WidgetTester tester) => tester
    .state<EditableTextState>(
      find.descendant(of: _display, matching: find.byType(EditableText)),
    )
    .renderEditable;

void _expectCursorVisible(WidgetTester tester) {
  final editable = _editable(tester);
  final caret = editable.getLocalRectForCaret(
    _field(tester).controller!.selection.extent,
  );
  expect(caret.top, greaterThanOrEqualTo(-2));
  expect(caret.bottom, lessThanOrEqualTo(editable.size.height + 2));
}

Future<void> _key(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('mobile-transaction-keypad-$label')));
  await tester.pump();
}

Future<TextEditingController> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  VoidCallback? onCompleted,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final amount = TextEditingController(text: '123');
  addTearDown(amount.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MobileAmountField(controller: amount, onCompleted: onCompleted),
      ),
    ),
  );
  await tester.tap(find.byType(TextField));
  await tester.pumpAndSettle();
  return amount;
}
