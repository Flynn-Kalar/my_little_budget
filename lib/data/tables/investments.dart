import 'package:drift/drift.dart';

import 'accounts.dart';
import '../sync_metadata.dart';

/// SPEC §3.6
/// 투자 거래. side ∈ {buy, sell, dividend}.
///   buy/sell: quantity > 0
///   dividend: quantity == 0 (배당금만)
/// account_id 는 isInvestment=true 인 자산을 자동으로 박는다.
/// 자산이 archive/삭제되어도 투자 기록은 유지 → ON DELETE SET NULL.
@DataClassName('Investment')
@TableIndex(name: 'idx_inv_occurred_on', columns: {#occurredOn})
@TableIndex(name: 'idx_inv_side', columns: {#side})
@TableIndex(name: 'idx_inv_ticker', columns: {#ticker})
@TableIndex(name: 'idx_inv_account', columns: {#accountId})
class Investments extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get side => text().customConstraint(
    "NOT NULL CHECK (side IN ('buy','sell','dividend'))",
  )();
  TextColumn get occurredOn => text()();
  TextColumn get occurredTime => text().withDefault(const Constant('00:00'))();
  TextColumn get ticker => text().withLength(min: 1, max: 40)();
  // 마이그 0015: 소수점 주식 수량 허용 (REAL).
  RealColumn get quantity => real().withDefault(const Constant(0))();
  IntColumn get totalAmount =>
      integer().customConstraint('NOT NULL CHECK (total_amount > 0)')();
  IntColumn get accountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get memo => text().nullable()();
  TextColumn get createdAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get updatedAt =>
      text().withDefault(const CustomExpression("datetime('now')"))();
  TextColumn get deletedAt => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant(syncStatusPending))();

  @override
  List<String> get customConstraints => [
    '''CHECK (
          (side IN ('buy','sell') AND quantity > 0)
          OR (side = 'dividend' AND quantity = 0)
        )''',
  ];
}
