import 'package:drift/drift.dart';

import '../sync_metadata.dart';

/// SPEC §3.2
/// 수입/지출 카테고리. UNIQUE(name, type).
/// 사용 중인 카테고리는 hard delete 금지 → archived_at 으로 보관.
@DataClassName('Category')
@TableIndex(
  name: 'uq_categories_name_type',
  columns: {#name, #type},
  unique: true,
)
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text().withLength(min: 1, max: 20)();
  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK (type IN ('income','expense'))",
  )();
  TextColumn get color => text().withDefault(const Constant('#64748b'))();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get archivedAt => text().nullable()();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();
}
