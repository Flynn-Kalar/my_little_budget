import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_little_budget/ui/desktop/transactions/widgets/form_fields.dart';

void main() {
  testWidgets(
    'MemoAutocompleteField keeps focus after selecting a suggestion',
    (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      var submitCount = 0;

      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: MemoAutocompleteField(
                  controller: controller,
                  focusNode: focusNode,
                  suggestions: const ['Coffee beans', 'Lunch'],
                  onSubmitted: (committedSuggestion) {
                    if (!committedSuggestion) submitCount++;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee beans'));
      await tester.pumpAndSettle();

      expect(controller.text, 'Coffee beans');
      expect(focusNode.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(submitCount, 1);
    },
  );
}
