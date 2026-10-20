import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../database.dart';
import '../sync_metadata.dart';
import '../tag_category_links.dart';
import '../tables/tags.dart';
import '../tables/transaction_presets.dart';
import '../tables/transactions.dart';

part 'tags_dao.g.dart';

/// SPEC §3.8 / §4.8.3 — 태그 CRUD + 거래-태그 매핑(id 기준).
@DriftAccessor(
  tables: [Tags, TransactionTags, Transactions, TransactionPresets],
)
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  Future<List<Tag>> getTags() {
    return (select(tags)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .get();
  }

  Future<List<Tag>> getRecommendedTags({int? limit}) {
    final query = select(tags)
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPinned),
        (t) => OrderingTerm.desc(t.usageCount),
        (t) => OrderingTerm.desc(t.lastUsedAt),
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Rank actual transaction links, including all tags even if never used.
  /// Explicit category assignments group tags first; both groups use overall
  /// transaction frequency. Merely using a tag in a category does not assign it.
  Future<List<Tag>> getTransactionTagSuggestions({int? categoryId}) async {
    final rows = await customSelect(
      '''
      SELECT tg.* FROM tags tg
      LEFT JOIN transaction_tags tt ON tt.tag_id = tg.id
      LEFT JOIN transactions tx ON tx.id = tt.transaction_id
        AND tx.deleted_at IS NULL
      WHERE tg.deleted_at IS NULL
      GROUP BY tg.id
      ORDER BY
        CASE WHEN EXISTS (
          SELECT 1 FROM json_each(tg.category_ids_json) assigned
          WHERE assigned.value = ?
        ) THEN 0 ELSE 1 END ASC,
        COUNT(tx.id) DESC,
        MAX(tx.occurred_on || ' ' || tx.occurred_time) DESC,
        tg.sort_order ASC, tg.id ASC
    ''',
      variables: [Variable<int>(categoryId)],
      readsFrom: {tags, transactionTags, transactions},
    ).get();
    return rows.map((row) => tags.map(row.data)).toList();
  }

  Stream<List<Tag>> watchTags() {
    return (select(tags)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  Future<int> createTag(
    String name,
    String color, {
    List<int> categoryIds = const [],
  }) async {
    final categoryIdsJson = await _validateCategories(categoryIds);
    final nextOrder = await _nextSortOrder();
    final now = sqlNow();
    return into(tags).insert(
      TagsCompanion.insert(
        name: name,
        color: Value(color),
        categoryIdsJson: Value(categoryIdsJson),
        sortOrder: Value(nextOrder),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> updateTag(
    int id,
    String name,
    String color, {
    List<int>? categoryIds,
  }) async {
    final categoryIdsJson = categoryIds == null
        ? null
        : await _validateCategories(categoryIds);
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        color: Value(color),
        categoryIdsJson: categoryIdsJson == null
            ? const Value.absent()
            : Value(categoryIdsJson),
        updatedAt: Value(sqlNow()),
        syncStatus: const Value(syncStatusPending),
      ),
    );
  }

  Future<String> _validateCategories(List<int> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isNotEmpty) {
      final table = attachedDatabase.categories;
      final categories = await (select(
        table,
      )..where((c) => c.id.isIn(uniqueIds) & c.deletedAt.isNull())).get();
      if (categories.length != uniqueIds.length) {
        throw ArgumentError('존재하지 않는 카테고리가 포함되어 있습니다.');
      }
    }
    return encodeTagCategoryIds(uniqueIds);
  }

  Future<void> setTagPinned(int id, bool pinned) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        isPinned: Value(pinned),
        updatedAt: Value(sqlNow()),
        syncStatus: const Value(syncStatusPending),
      ),
    );
  }

  Future<void> removeCategoryAssignment(int categoryId) async {
    final rows = await getTags();
    for (final tag in rows) {
      final ids = readTagCategoryIds(tag.categoryIdsJson);
      if (!ids.remove(categoryId)) continue;
      await updateTag(tag.id, tag.name, tag.color, categoryIds: ids);
    }
  }

  Future<void> updateTagOrder(List<int> orderedIds) async {
    await transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (update(tags)..where((t) => t.id.equals(orderedIds[i]))).write(
          TagsCompanion(
            sortOrder: Value(i),
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
      }
    });
  }

  Future<void> deleteTag(int id) async {
    await transaction(() async {
      final tag = await (select(
        tags,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      final linkedTransactions =
          await (selectOnly(transactionTags)
                ..addColumns([transactionTags.transactionId])
                ..where(transactionTags.tagId.equals(id)))
              .map((row) => row.read(transactionTags.transactionId)!)
              .get();
      for (final transactionId in linkedTransactions) {
        await (update(
          transactions,
        )..where((t) => t.id.equals(transactionId))).write(
          TransactionsCompanion(
            updatedAt: Value(sqlNow()),
            syncStatus: const Value(syncStatusPending),
          ),
        );
      }
      if (tag != null) {
        await db.transactionPresetsDao.removeTagName(tag.name);
      }
      await (delete(tags)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 거래의 태그를 id 목록으로 재설정. SPEC §4.1 (updateTransactionTags).
  Future<void> setTransactionTags(int transactionId, List<int> tagIds) async {
    await transaction(() async {
      await (delete(
        transactionTags,
      )..where((tt) => tt.transactionId.equals(transactionId))).go();
      for (final tagId in tagIds) {
        await into(transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: transactionId,
            tagId: tagId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      await (update(
        transactions,
      )..where((t) => t.id.equals(transactionId))).write(
        TransactionsCompanion(
          updatedAt: Value(sqlNow()),
          syncStatus: const Value(syncStatusPending),
        ),
      );
    });
  }

  Future<int> _nextSortOrder() async {
    final row = await customSelect(
      'SELECT COALESCE(MAX(sort_order), -1) AS m FROM tags',
      readsFrom: {tags},
    ).getSingle();
    return row.read<int>('m') + 1;
  }
}
