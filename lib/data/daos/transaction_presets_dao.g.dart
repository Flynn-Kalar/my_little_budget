// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_presets_dao.dart';

// ignore_for_file: type=lint
mixin _$TransactionPresetsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $TransactionPresetsTable get transactionPresets =>
      attachedDatabase.transactionPresets;
  TransactionPresetsDaoManager get managers =>
      TransactionPresetsDaoManager(this);
}

class TransactionPresetsDaoManager {
  final _$TransactionPresetsDaoMixin _db;
  TransactionPresetsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$TransactionPresetsTableTableManager get transactionPresets =>
      $$TransactionPresetsTableTableManager(
        _db.attachedDatabase,
        _db.transactionPresets,
      );
}
