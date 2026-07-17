import 'package:drift/drift.dart';

import '../../core/date.dart';
import '../database.dart';
import '../sync_metadata.dart';
import '../tables/tags.dart';
import '../tables/transactions.dart';

part 'tags_dao.g.dart';

/// SPEC §3.8 / §4.8.3 — 태그 CRUD + 거래-태그 매핑(id 기준).
@DriftAccessor(tables: [Tags, TransactionTags, Transactions])
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

  Stream<List<Tag>> watchTags() {
    return (select(tags)..orderBy([
          (t) => OrderingTerm(expression: t.sortOrder),
          (t) => OrderingTerm(expression: t.id),
        ]))
        .watch();
  }

  Future<int> createTag(String name, String color) async {
    final nextOrder = await _nextSortOrder();
    return into(tags).insert(
      TagsCompanion.insert(
        name: name,
        color: Value(color),
        sortOrder: Value(nextOrder),
      ),
    );
  }

  Future<void> updateTag(int id, String name, String color) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: Value(name),
        color: Value(color),
        updatedAt: Value(sqlNow()),
        syncStatus: const Value(syncStatusPending),
      ),
    );
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
