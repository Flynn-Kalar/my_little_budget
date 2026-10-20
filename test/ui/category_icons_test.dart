import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_budget/core/category_icons.dart';
import 'package:my_little_budget/data/database.dart';
import 'package:my_little_budget/data/providers.dart';
import 'package:my_little_budget/ui/desktop/settings/widgets/category_form.dart';
import 'package:my_little_budget/ui/mobile/settings/mobile_categories_screen.dart';
import 'package:my_little_budget/ui/shared/category_icon_picker.dart';

void main() {
  test(
    'default categories resolve distinctly; explicit selection overrides names',
    () {
      expect(resolveCategoryIcon(name: '식비'), Icons.restaurant_rounded);
      expect(resolveCategoryIcon(name: '교통'), Icons.directions_bus_rounded);
      expect(
        resolveCategoryIcon(name: '급여', type: 'income'),
        Icons.payments_rounded,
      );
      expect(resolveCategoryIcon(name: '식비', id: 'pets'), Icons.pets_rounded);
      expect(
        resolveCategoryIcon(name: '교통', id: 'old-unknown'),
        Icons.directions_bus_rounded,
      );
      expect(resolveCategoryIcon(name: '직접 만든 분류'), Icons.category_rounded);
      expect(
        categoryIconOptions.map((o) => o.id).toSet().length,
        categoryIconOptions.length,
      );
    },
  );

  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'PC'} searches, saves, and reopens a custom category icon',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(mobile ? 390 : 900, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        Future<void> show(Category? category) => tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              home: mobile
                  ? const MobileCategoriesScreen()
                  : Scaffold(
                      body: SingleChildScrollView(
                        child: CategoryForm(
                          key: ValueKey(category?.id),
                          category: category,
                          type: 'expense',
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
          await tester.tap(find.byTooltip('카테고리 추가'));
          await tester.pumpAndSettle();
        }
        await tester.enterText(find.byType(TextField).last, '우리 고양이');
        await tester.tap(find.byType(CategoryIconPicker));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, '반려');
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('category-icon-pets')));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, '저장');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final category = (await db.categoriesDao.getAllCategories())
            .singleWhere((c) => c.name == '우리 고양이');
        expect(category.icon, 'pets');
        final originalColor = category.color;
        if (mobile) {
          await tester.ensureVisible(find.text(category.name));
          await tester.pumpAndSettle();
          await tester.tap(find.text(category.name));
        } else {
          await show(category);
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CategoryIconPicker>(find.byType(CategoryIconPicker))
              .value,
          'pets',
        );
        await tester.tap(find.byType(CategoryIconPicker));
        await tester.pumpAndSettle();
        await tester.tap(find.text('자동 선택 (카테고리 이름 기준)'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, '저장'));
        await tester.pumpAndSettle();
        final updated = (await db.categoriesDao.getAllCategories()).singleWhere(
          (c) => c.id == category.id,
        );
        expect(updated.icon, isNull);
        expect(updated.color, originalColor);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
