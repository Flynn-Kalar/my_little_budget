import 'package:drift/drift.dart';
import 'database.dart';
import 'tag_category_links.dart';

enum BulkEntity {
  categories('categories', '카테고리'),
  tags('tags', '태그'),
  accounts('accounts', '자산'),
  notes('notes', '메모'),
  calendar('calendar_events', '일정'),
  recurring('recurring_transactions', '반복 거래'),
  presets('transaction_presets', '프리셋'),
  budgets('budget_groups', '예산 그룹'),
  investments('investments', '투자 내역');

  const BulkEntity(this.table, this.label);
  final String table, label;
}

enum BulkOperation { delete, archive, enable, disable, pin, unpin }

enum BulkTagCategoryMode { add, replace, remove }

/// Every batch validates its entire selection and commits or rolls back together.
class BulkManagement {
  BulkManagement(this.db);
  final AppDatabase db;

  Future<List<QueryRow>> _requireRows(BulkEntity entity, Set<int> ids) async {
    if (ids.isEmpty || ids.any((id) => id <= 0)) {
      throw ArgumentError('처리할 항목을 선택하세요.');
    }
    final selected = ids.toList();
    final result = <QueryRow>[];
    for (var start = 0; start < selected.length; start += 400) {
      final chunk = selected.skip(start).take(400).toList();
      result.addAll(
        await db
            .customSelect(
              'SELECT * FROM ${entity.table} WHERE ${entity == BulkEntity.notes ? '' : 'deleted_at IS NULL AND '}id IN (${List.filled(chunk.length, '?').join(',')})',
              variables: chunk.map((id) => Variable<int>(id)).toList(),
            )
            .get(),
      );
    }
    if (result.length != ids.length) {
      throw StateError('목록이 변경되었습니다. 닫고 다시 선택해주세요. 변경한 항목은 없습니다.');
    }
    return result;
  }

  Future<void> apply(
    BulkEntity entity,
    Set<int> ids,
    BulkOperation operation,
  ) => db.transaction(() async {
    final rows = await _requireRows(entity, ids);
    for (final id in ids) {
      switch ((entity, operation)) {
        case (BulkEntity.categories, BulkOperation.delete):
          final error = await db.categoriesDao.deleteCategory(id);
          if (error != null) {
            final name = rows
                .firstWhere((row) => row.read<int>('id') == id)
                .read<String>('name');
            throw StateError('$name: $error\n선택한 항목은 모두 유지했습니다.');
          }
        case (BulkEntity.tags, BulkOperation.delete):
          await db.tagsDao.deleteTag(id);
        case (BulkEntity.accounts, BulkOperation.archive):
          await db.accountsDao.archiveAccount(id);
        case (BulkEntity.notes, BulkOperation.delete):
          await db.notesDao.deleteNote(id);
        case (BulkEntity.notes, BulkOperation.pin):
          await db.notesDao.setPinned(id, true);
        case (BulkEntity.notes, BulkOperation.unpin):
          await db.notesDao.setPinned(id, false);
        case (BulkEntity.calendar, BulkOperation.delete):
          await db.calendarEventsDao.deleteEvent(id);
        case (BulkEntity.recurring, BulkOperation.delete):
          await db.recurringDao.deleteRecurring(id);
        case (BulkEntity.recurring, BulkOperation.enable):
          await db.recurringDao.toggleRecurringActive(id, true);
        case (BulkEntity.recurring, BulkOperation.disable):
          await db.recurringDao.toggleRecurringActive(id, false);
        case (BulkEntity.presets, BulkOperation.delete):
          await db.transactionPresetsDao.deletePreset(id);
        case (BulkEntity.budgets, BulkOperation.delete):
          await db.budgetDao.deleteBudgetGroup(id);
        case (BulkEntity.investments, BulkOperation.delete):
          await db.investmentsDao.deleteInvestment(id);
        default:
          throw ArgumentError('지원하지 않는 일괄 작업입니다.');
      }
    }
  });

  Future<void> assignTagCategories(
    Set<int> tagIds,
    Set<int> categoryIds,
    BulkTagCategoryMode mode,
  ) => db.transaction(() async {
    final tags = await _requireRows(BulkEntity.tags, tagIds);
    if (categoryIds.isNotEmpty) {
      await _requireRows(BulkEntity.categories, categoryIds);
    }
    if (categoryIds.isEmpty && mode != BulkTagCategoryMode.replace) {
      throw ArgumentError('추가하거나 해제할 카테고리를 선택하세요.');
    }
    for (final tag in tags) {
      final before = readTagCategoryIds(
        tag.read<String>('category_ids_json'),
      ).toSet();
      final next = switch (mode) {
        BulkTagCategoryMode.add => before.union(categoryIds),
        BulkTagCategoryMode.replace => categoryIds,
        BulkTagCategoryMode.remove => before.difference(categoryIds),
      };
      await db.tagsDao.updateTag(
        tag.read<int>('id'),
        tag.read<String>('name'),
        tag.read<String>('color'),
        categoryIds: next.toList(),
      );
    }
  });
}
