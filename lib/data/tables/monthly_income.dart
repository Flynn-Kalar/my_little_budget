import 'package:drift/drift.dart';

import '../sync_metadata.dart';

/// SPEC §3.5
/// 월별 사용자 입력 예상 소득. % 기반 예산의 base 산정용.
@DataClassName('MonthlyIncomeRow')
class MonthlyIncome extends Table {
  TextColumn get month => text().customConstraint(
    "NOT NULL CHECK (month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]')",
  )();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  IntColumn get expectedIncome => integer()
      .withDefault(const Constant(0))
      .check(const CustomExpression('expected_income >= 0'))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();

  @override
  Set<Column> get primaryKey => {month};
}
