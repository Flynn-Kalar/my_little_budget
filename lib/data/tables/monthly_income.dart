import 'package:drift/drift.dart';

/// SPEC §3.5
/// 월별 사용자 입력 예상 소득. % 기반 예산의 base 산정용.
@DataClassName('MonthlyIncomeRow')
class MonthlyIncome extends Table {
  TextColumn get month => text().customConstraint(
        "NOT NULL CHECK (month GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]')",
      )();
  IntColumn get expectedIncome => integer()
      .withDefault(const Constant(0))
      .check(const CustomExpression('expected_income >= 0'))();
  TextColumn get updatedAt => text()
      .withDefault(const CustomExpression("datetime('now')"))();

  @override
  Set<Column> get primaryKey => {month};
}
