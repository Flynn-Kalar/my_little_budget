import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/tags.dart';

part 'tags_dao.g.dart';

/// SPEC §3.8 / §4.8.3 — 태그 CRUD + 거래-태그 매핑(id 기준).
@DriftAccessor(tables: [Tags, TransactionTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  Future<List<Tag>> getTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  Stream<List<Tag>> watchTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  Future<int> createTag(String name, String color) {
    return into(tags).insert(TagsCompanion.insert(name: name, color: Value(color)));
  }

  Future<void> updateTag(int id, String name, String color) async {
    await (update(tags)..where((t) => t.id.equals(id)))
        .write(TagsCompanion(name: Value(name), color: Value(color)));
  }

  Future<void> deleteTag(int id) async {
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  /// 거래의 태그를 id 목록으로 재설정. SPEC §4.1 (updateTransactionTags).
  Future<void> setTransactionTags(int transactionId, List<int> tagIds) async {
    await transaction(() async {
      await (delete(transactionTags)
            ..where((tt) => tt.transactionId.equals(transactionId)))
          .go();
      for (final tagId in tagIds) {
        await into(transactionTags).insert(
          TransactionTagsCompanion.insert(
            transactionId: transactionId,
            tagId: tagId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}
