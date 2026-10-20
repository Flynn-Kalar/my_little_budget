import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/features/transactions/validation.dart';
import 'package:my_little_budget/ui/desktop/transactions/widgets/form_fields.dart';
import 'package:my_little_budget/ui/mobile/transactions/sheets/mobile_transaction_sheet.dart';

void main() {
  testWidgets(
    'PC Enter preserves preceding tags with suggestions and exact names',
    (tester) async {
      var tags = <String>[];
      final tagFocus = FocusNode();
      addTearDown(tagFocus.dispose);
      var advanced = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagAutocompleteField(
                value: tags,
                suggestions: const ['게임아이템', '게임', '스팀'],
                focusNode: tagFocus,
                onChanged: (value) => setState(() => tags = value),
                onSubmitted: (result) {
                  if (result == TagSubmitResult.empty) advanced++;
                },
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      await tester.enterText(field, '게임');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tags, ['게임']);
      expect(tester.widget<TextField>(field).controller!.text, '게임, ');
      expect(tagFocus.hasFocus, isTrue);
      expect(advanced, 0);

      await tester.enterText(field, '게임, 스');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tags, ['게임', '스팀']);
      expect(tester.widget<TextField>(field).controller!.text, '게임, 스팀, ');
      expect(tagFocus.hasFocus, isTrue);
      expect(advanced, 0);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(tags, ['게임', '스팀']);
      expect(advanced, 1);
    },
  );

  testWidgets(
    'PC tag chips keep their positions while selecting and deselecting',
    (tester) async {
      var selected = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TagInput(
                value: selected,
                suggestions: const ['게임', '스팀', '교통'],
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      );
      final steam = find.widgetWithText(FilterChip, '#스팀');
      final before = tester.getTopLeft(steam);
      await tester.tap(steam);
      await tester.pumpAndSettle();
      expect(selected, ['스팀']);
      expect(tester.getTopLeft(steam), before);
      await tester.tap(steam);
      await tester.pumpAndSettle();
      expect(selected, isEmpty);
      expect(tester.getTopLeft(steam), before);
    },
  );

  testWidgets(
    'mobile shows all tags in category order without promoting selected chips',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = (await db.accountsDao.getActiveAccounts()).first;
      final categories = await db.categoriesDao.getActiveCategories('expense');
      Future<int> save(int category, List<String> names) =>
          db.transactionsDao.saveTransaction(
            draft: TransactionDraft(
              type: 'expense',
              amount: 100,
              occurredOn: '2026-10-01',
              occurredTime: '12:00',
              categoryId: category,
              accountId: account.id,
            ),
            tagNames: names,
          );
      final id = await save(categories[0].id, ['게임']);
      for (var i = 0; i < 3; i++) {
        await save(categories[1].id, ['스팀']);
      }
      for (final tag in await db.tagsDao.getTags()) {
        await db.tagsDao.updateTag(
          tag.id,
          tag.name,
          tag.color,
          categoryIds: [categories[tag.name == '게임' ? 0 : 1].id],
        );
      }
      for (var i = 0; i < 23; i++) {
        await db.tagsDao.createTag('추가$i', '#64748b');
      }
      final row = (await db.transactionsDao.getTransactionById(id))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(body: MobileTransactionSheet(row: row)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNWidgets(25));
      final game = find.widgetWithText(FilterChip, '#게임');
      final steam = find.widgetWithText(FilterChip, '#스팀');
      final positions = [
        for (final chip in find.byType(FilterChip).evaluate())
          tester.getTopLeft(find.byWidget(chip.widget)),
      ];
      expect(
        tester.getTopLeft(game).dy,
        lessThanOrEqualTo(tester.getTopLeft(steam).dy),
      );
      await tester.ensureVisible(steam);
      final beforeTap = [
        for (final chip in find.byType(FilterChip).evaluate())
          tester.getTopLeft(find.byWidget(chip.widget)),
      ];
      await tester.tap(steam);
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(steam).selected, isTrue);
      expect([
        for (final chip in find.byType(FilterChip).evaluate())
          tester.getTopLeft(find.byWidget(chip.widget)),
      ], beforeTap);
      expect(positions.length, 25);
      final category = find.byType(DropdownButtonFormField<int>).last;
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text(categories[1].name).last);
      await tester.pumpAndSettle();
      expect(
        find.byType(FilterChip).evaluate().first.widget,
        isA<FilterChip>().having(
          (c) => (c.label as Text).data,
          'first tag',
          '#스팀',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
