import 'package:drift/drift.dart';

import 'database.dart';
import 'defaults.dart';

/// SPEC §5.3 — 카테고리·자산이 비어 있을 때만 기본값 삽입 (멱등).
Future<void> seedDefaults(AppDatabase db) async {
  final existingCategories = await db.select(db.categories).get();
  if (existingCategories.isEmpty) {
    await db.batch((b) {
      var i = 0;
      for (final c in defaultExpenseCategories) {
        b.insert(
          db.categories,
          CategoriesCompanion.insert(
            name: c.name,
            type: 'expense',
            color: Value(c.color),
            sortOrder: Value(i++),
          ),
        );
      }
      i = 0;
      for (final c in defaultIncomeCategories) {
        b.insert(
          db.categories,
          CategoriesCompanion.insert(
            name: c.name,
            type: 'income',
            color: Value(c.color),
            sortOrder: Value(i++),
          ),
        );
      }
    });
  }

  final existingAccounts = await db.select(db.accounts).get();
  if (existingAccounts.isEmpty) {
    await db.batch((b) {
      var i = 0;
      for (final a in defaultAccounts) {
        b.insert(
          db.accounts,
          AccountsCompanion.insert(
            name: a.name,
            kind: a.kind,
            color: Value(a.color),
            isInvestment: Value(a.isInvestment),
            sortOrder: Value(i++),
          ),
        );
      }
    });
  }
}
