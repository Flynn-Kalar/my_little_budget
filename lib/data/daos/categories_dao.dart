import 'package:drift/drift.dart';

import '../../features/categories/validation.dart';
import '../database.dart';
import '../tables/budget_groups.dart';
import '../tables/categories.dart';
import '../tables/recurring_transactions.dart';
import '../tables/transactions.dart';

part 'categories_dao.g.dart';

/// SPEC §3.2 / §4.8.1 — 카테고리 조회·CRUD.
@DriftAccessor(tables: [
  Categories,
  Transactions,
  BudgetGroupCategories,
  RecurringTransactions,
])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// 활성 카테고리 (보관 제외). type 지정 시 필터. sortOrder, id 순.
  Future<List<Category>> getActiveCategories([String? type]) {
    final q = select(categories)
      ..where((c) => type == null
          ? c.archivedAt.isNull()
          : c.archivedAt.isNull() & c.type.equals(type))
      ..orderBy([
        (c) => OrderingTerm(expression: c.sortOrder),
        (c) => OrderingTerm(expression: c.id),
      ]);
    return q.get();
  }

  Stream<List<Category>> watchActiveCategories([String? type]) {
    final q = select(categories)
      ..where((c) => type == null
          ? c.archivedAt.isNull()
          : c.archivedAt.isNull() & c.type.equals(type))
      ..orderBy([
        (c) => OrderingTerm(expression: c.sortOrder),
        (c) => OrderingTerm(expression: c.id),
      ]);
    return q.watch();
  }

  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..orderBy([
            (c) => OrderingTerm(expression: c.sortOrder),
            (c) => OrderingTerm(expression: c.id),
          ]))
        .get();
  }

  /// 거래·예산매핑·반복거래에서 참조되는 횟수. 0 이면 hard delete 가능. SPEC §4.8.1.
  Future<int> getCategoryUsageCount(int id) async {
    final row = await customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM transactions WHERE category_id = ?)
        + (SELECT COUNT(*) FROM budget_group_categories WHERE category_id = ?)
        + (SELECT COUNT(*) FROM recurring_transactions WHERE category_id = ?)
        AS n
      ''',
      variables: List.filled(3, Variable<int>(id)),
      readsFrom: {transactions, budgetGroupCategories, recurringTransactions},
    ).getSingle();
    return row.read<int>('n');
  }

  /// 카테고리 저장. SPEC §4.8.1.
  ///   신규: sortOrder = 해당 type 의 max+1.
  ///   편집: name·color 만 변경 (type·sortOrder 불변).
  Future<void> saveCategory({int? id, required CategoryDraft draft}) async {
    if (id != null) {
      await (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(
          name: Value(draft.name),
          color: Value(draft.color),
        ),
      );
    } else {
      final maxRow = await customSelect(
        'SELECT COALESCE(MAX(sort_order), -1) AS m FROM categories WHERE type = ?',
        variables: [Variable<String>(draft.type)],
        readsFrom: {categories},
      ).getSingle();
      final nextOrder = maxRow.read<int>('m') + 1;
      await into(categories).insert(
        CategoriesCompanion.insert(
          name: draft.name,
          type: draft.type,
          color: Value(draft.color),
          sortOrder: Value(nextOrder),
        ),
      );
    }
  }

  Future<void> updateCategoryOrder(String type, List<int> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(categories)
              ..where((c) => c.id.equals(orderedIds[i]) & c.type.equals(type)))
            .write(CategoriesCompanion(sortOrder: Value(i)));
      }
    });
  }

  Future<void> archiveCategory(int id) async {
    await customUpdate(
      "UPDATE categories SET archived_at = datetime('now') WHERE id = ?",
      variables: [Variable<int>(id)],
      updates: {categories},
    );
  }

  Future<void> restoreCategory(int id) async {
    await (update(categories)..where((c) => c.id.equals(id)))
        .write(const CategoriesCompanion(archivedAt: Value(null)));
  }

  /// 참조 0건일 때만 영구 삭제. 사용 중이면 메시지 반환, 성공 시 null. SPEC §4.8.1.
  Future<String?> deleteCategory(int id) async {
    final usage = await getCategoryUsageCount(id);
    if (usage > 0) {
      return '이 카테고리는 $usage건의 기록에 사용 중이라 삭제할 수 없습니다. '
          '먼저 해당 기록을 정리해주세요.';
    }
    await (delete(categories)..where((c) => c.id.equals(id))).go();
    return null;
  }
}
