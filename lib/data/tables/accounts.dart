import 'package:drift/drift.dart';

import '../sync_metadata.dart';

/// SPEC §3.1
/// 자산(계좌). 보관(archive) 은 archived_at 으로 소프트 삭제.
/// initial_balance 는 편집 시 절대 변경하지 않음 — 잔액 차이는 adjustment 거래로.
@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text().withLength(min: 1, max: 40).unique()();
  TextColumn get kind => text().customConstraint(
    "NOT NULL CHECK (kind IN ('cash','bank','card','other'))",
  )();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get cardLimit => integer().nullable()();
  TextColumn get color => text().withDefault(const Constant('#94a3b8'))();
  BoolColumn get excludeFromTotal =>
      boolean().withDefault(const Constant(false))();
  // 전 앱에서 1개만 true 가 되도록 application 레이어에서 강제.
  BoolColumn get isInvestment => boolean().withDefault(const Constant(false))();
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
