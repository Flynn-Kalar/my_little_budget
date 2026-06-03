// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investments_dao.dart';

// ignore_for_file: type=lint
mixin _$InvestmentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $InvestmentsTable get investments => attachedDatabase.investments;
  InvestmentsDaoManager get managers => InvestmentsDaoManager(this);
}

class InvestmentsDaoManager {
  final _$InvestmentsDaoMixin _db;
  InvestmentsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db.attachedDatabase, _db.investments);
}
