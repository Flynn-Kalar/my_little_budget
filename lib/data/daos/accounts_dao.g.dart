// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'accounts_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $InvestmentsTable get investments => attachedDatabase.investments;
  $BudgetGroupsTable get budgetGroups => attachedDatabase.budgetGroups;
  $RecurringTransactionsTable get recurringTransactions =>
      attachedDatabase.recurringTransactions;
  AccountsDaoManager get managers => AccountsDaoManager(this);
}

class AccountsDaoManager {
  final _$AccountsDaoMixin _db;
  AccountsDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db.attachedDatabase, _db.investments);
  $$BudgetGroupsTableTableManager get budgetGroups =>
      $$BudgetGroupsTableTableManager(_db.attachedDatabase, _db.budgetGroups);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.recurringTransactions,
      );
}
