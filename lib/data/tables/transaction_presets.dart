import 'package:drift/drift.dart';

import '../sync_metadata.dart';
import 'accounts.dart';
import 'categories.dart';

@DataClassName('TransactionPreset')
class TransactionPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get uuid => text().clientDefault(newSyncUuid).unique()();
  TextColumn get name => text().nullable()();
  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK (type IN ('income','expense','transfer'))",
  )();
  IntColumn get amount =>
      integer().customConstraint('NOT NULL CHECK (amount > 0)')();
  TextColumn get memo => text().nullable()();
  @ReferenceName('presetAccount')
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
  @ReferenceName('presetFromAccount')
  IntColumn get fromAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  @ReferenceName('presetToAccount')
  IntColumn get toAccountId => integer().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get tagNames => text().nullable()();
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
          (type IN ('income','expense')
            AND from_account_id IS NULL
            AND to_account_id IS NULL)
          OR
          (type = 'transfer'
            AND account_id IS NULL
            AND category_id IS NULL
            AND (from_account_id IS NULL
              OR to_account_id IS NULL
              OR from_account_id <> to_account_id))
        )''',
  ];
}
