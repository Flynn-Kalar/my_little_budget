import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import '../sync_metadata.dart';

/// SPEC §3.7
/// 반복 거래 템플릿. type ∈ {income, expense, transfer} (adjustment 없음).
///   monthly: day_of_month 1~31 (그 달에 없으면 마지막 날로 폴백)
///   weekly:  day_of_week 0(일) ~ 6(토)
/// last_generated_on 이후 ~ horizon 까지 자동 backfill. /transactions 진입 시 매번 호출. 멱등.
/// 자산/카테고리 삭제 시 set null → 실질 비활성.
@DataClassName('RecurringTransaction')
@TableIndex(name: 'idx_rec_active', columns: {#active})
class RecurringTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text()();
  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK (type IN ('income','expense','transfer'))",
  )();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();
  TextColumn get memo => text().nullable()();
  @ReferenceName('recAccount')
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  @ReferenceName('recFromAccount')
  IntColumn get fromAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  @ReferenceName('recToAccount')
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get frequency => text().customConstraint(
    "NOT NULL CHECK (frequency IN ('monthly','weekly'))",
  )();
  IntColumn get dayOfMonth => integer().nullable()();
  IntColumn get dayOfWeek => integer().nullable()();
  TextColumn get occurredTime => text().withDefault(const Constant('00:00'))();
  TextColumn get startDate => text()();
  TextColumn get endDate => text().nullable()();
  TextColumn get lastGeneratedOn => text().nullable()();
  // 자동 생성된 거래에 적용할 태그 이름 배열 (JSON 문자열, 예: '["여행","고정"]')
  TextColumn get tagNames => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();

  @override
  List<String> get customConstraints => [
    // 형상: transactions 와 동일하지만 adjustment 가 없다.
    '''CHECK (
          (type IN ('income','expense')
            AND account_id IS NOT NULL
            AND category_id IS NOT NULL
            AND from_account_id IS NULL
            AND to_account_id IS NULL)
          OR
          (type = 'transfer'
            AND account_id IS NULL
            AND category_id IS NULL
            AND from_account_id IS NOT NULL
            AND to_account_id IS NOT NULL
            AND from_account_id <> to_account_id)
        )''',
    // cadence: monthly 면 day_of_month 만, weekly 면 day_of_week 만.
    '''CHECK (
          (frequency = 'monthly' AND day_of_month BETWEEN 1 AND 31 AND day_of_week IS NULL)
          OR
          (frequency = 'weekly'  AND day_of_week  BETWEEN 0 AND 6  AND day_of_month IS NULL)
        )''',
  ];
}
