import 'package:drift/drift.dart';

import 'accounts.dart';
import 'categories.dart';
import '../sync_metadata.dart';

/// SPEC §3.3
/// 거래 메인 테이블. type 에 따라 컬럼 필요/금지가 다름 — CHECK 로 강제.
///   income/expense:  account_id + category_id 필수, amount > 0
///   transfer:        from_account_id + to_account_id 필수 (서로 다름), amount > 0
///   adjustment:      account_id 필수, amount != 0 (signed)
@DataClassName('Transaction')
@TableIndex(name: 'idx_tx_occurred_on', columns: {#occurredOn})
@TableIndex(name: 'idx_tx_type', columns: {#type})
@TableIndex(name: 'idx_tx_category', columns: {#categoryId})
@TableIndex(name: 'idx_tx_account', columns: {#accountId})
@TableIndex(name: 'idx_tx_from_account', columns: {#fromAccountId})
@TableIndex(name: 'idx_tx_to_account', columns: {#toAccountId})
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK (type IN ('income','expense','transfer','adjustment'))",
  )();
  TextColumn get occurredOn => text()();
  TextColumn get occurredTime => text().withDefault(const Constant('00:00'))();
  IntColumn get amount => integer()();
  TextColumn get memo => text().nullable()();
  @ReferenceName('txAccount')
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  @ReferenceName('txFromAccount')
  IntColumn get fromAccountId =>
      integer().nullable().references(Accounts, #id)();
  @ReferenceName('txToAccount')
  IntColumn get toAccountId => integer().nullable().references(Accounts, #id)();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();

  @override
  List<String> get customConstraints => [
    // amount 부호: adjustment 는 0만 아니면 signed 허용, 그 외엔 양수.
    '''CHECK (
          (type = 'adjustment' AND amount <> 0)
          OR (type IN ('income','expense','transfer') AND amount > 0)
        )''',
    // 형상: type 별로 어떤 컬럼이 채워져야 하는지.
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
          OR
          (type = 'adjustment'
            AND account_id IS NOT NULL
            AND category_id IS NULL
            AND from_account_id IS NULL
            AND to_account_id IS NULL)
        )''',
  ];
}
