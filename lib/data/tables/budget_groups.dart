import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import '../sync_metadata.dart';

/// SPEC §3.4
/// 월별 예산 그룹. (name, month) UNIQUE.
/// 한 그룹은 카테고리 묶음(account_id NULL) 또는 자산 연동(account_id NOT NULL) 둘 중 하나.
///   percentage 있으면 base = (월 예상 소득 × percentage / 100). 자산 연동과 동시 금지 — application 레이어에서 강제.
///   carry_forward: 다음 달 복사 시 잔금 자동 이월. 자산 연동은 강제 false.
@DataClassName('BudgetGroup')
@TableIndex(
  name: 'uq_budget_groups_name_month',
  columns: {#name, #month},
  unique: true,
)
@TableIndex(name: 'idx_budget_groups_month', columns: {#month})
class BudgetGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text()();
  TextColumn get month => text().customConstraint(
    "NOT NULL CHECK (month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]')",
  )();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount >= 0)')();
  IntColumn get adjustment => integer().withDefault(const Constant(0))();
  BoolColumn get carryForward => boolean().withDefault(const Constant(false))();
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.cascade,
  )();
  // 1~1000 정수. 검증은 application 레이어. NULL 이면 고정 금액 모드.
  IntColumn get percentage => integer().nullable()();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();
}

/// SPEC §3.4
/// 예산 그룹 ↔ 카테고리 N:M 매핑. 자산 연동 그룹은 매핑 추가 안 함.
@DataClassName('BudgetGroupCategoryLink')
class BudgetGroupCategories extends Table {
  IntColumn get groupId =>
      integer().references(BudgetGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {groupId, categoryId};
}
