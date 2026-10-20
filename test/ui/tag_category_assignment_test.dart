import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/data/tag_category_links.dart';
import 'package:my_little_budget/ui/desktop/settings/widgets/tag_form.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_tags_screen.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} saves multiple categories and restores editor selection',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(mobile ? 390 : 900, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final categories = await db.categoriesDao.getAllCategories();
        final ids = categories.take(2).map((c) => c.id).toList()..sort();
        Future<void> show(Tag? tag) => tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: mobile
                  ? const MobileTagsScreen()
                  : Scaffold(
                      body: SingleChildScrollView(
                        child: TagForm(
                          key: ValueKey(tag?.id),
                          tag: tag,
                          onDone: () {},
                        ),
                      ),
                    ),
            ),
          ),
        );
        await show(null);
        await tester.pumpAndSettle();
        if (mobile) {
          await tester.tap(find.byTooltip('태그 추가'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField).last, '여행');
        for (final id in ids) {
          final chip = find.byKey(ValueKey('tag-category-$id'));
          await tester.ensureVisible(chip);
          await tester.tap(chip);
          await tester.pumpAndSettle();
        }
        final save = find.widgetWithText(FilledButton, '저장');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final tag = (await db.tagsDao.getTags()).single;
        expect(readTagCategoryIds(tag.categoryIdsJson), ids);
        if (mobile) {
          await tester.tap(find.text('#여행'));
        } else {
          await show(tag);
        }
        await tester.pumpAndSettle();
        for (final id in ids) {
          expect(
            tester
                .widget<FilterChip>(find.byKey(ValueKey('tag-category-$id')))
                .selected,
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
