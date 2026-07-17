import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/ui/mobile/mobile_widgets.dart';

void main() {
  testWidgets('월 선택 시트는 시스템 내비게이션 영역 위에 배치된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          const systemNavigation = EdgeInsets.only(bottom: 48);
          return MediaQuery(
            data: mediaQuery.copyWith(
              padding: systemNavigation,
              viewPadding: systemNavigation,
            ),
            child: child!,
          );
        },
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () =>
                    showMobileMonthPicker(context, initialMonth: '2026-07'),
                child: const Text('월 선택 열기'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('월 선택 열기'));
    await tester.pumpAndSettle();

    final cancelButton = find.widgetWithText(TextButton, '취소');
    expect(cancelButton, findsOneWidget);
    expect(tester.getRect(cancelButton).bottom, lessThanOrEqualTo(844 - 48));
  });
}
