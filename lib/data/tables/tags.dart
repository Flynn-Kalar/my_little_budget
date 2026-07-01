import 'package:drift/drift.dart';

import 'transactions.dart';
import '../sync_metadata.dart';

/// SPEC §3.8
/// 카테고리와 독립적인 자유 라벨. 한 거래에 여러 태그 가능.
/// transfer/adjustment 거래에는 UI 가 노출하지 않음 (income/expense 만).
@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text().withLength(min: 1, max: 20).unique()();
  TextColumn get color => text().withDefault(const Constant('#64748b'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get usageCount => integer().withDefault(const Constant(0))();
  TextColumn get lastUsedAt => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();
}

/// SPEC §3.8
/// 거래 ↔ 태그 N:M.
@DataClassName('TransactionTagLink')
@TableIndex(name: 'idx_txtags_tag', columns: {#tagId})
class TransactionTags extends Table {
  IntColumn get transactionId =>
      integer().references(Transactions, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
