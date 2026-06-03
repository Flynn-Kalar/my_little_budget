// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categories_dao.dart';

// ignore_for_file: type=lint
mixin _$CategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $AccountsTable get accounts => attachedDatabase.accounts;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $BudgetGroupsTable get budgetGroups => attachedDatabase.budgetGroups;
  $BudgetGroupCategoriesTable get budgetGroupCategories =>
      attachedDatabase.budgetGroupCategories;
  $RecurringTransactionsTable get recurringTransactions =>
      attachedDatabase.recurringTransactions;
  CategoriesDaoManager get managers => CategoriesDaoManager(this);
}

class CategoriesDaoManager {
  final _$CategoriesDaoMixin _db;
  CategoriesDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$BudgetGroupsTableTableManager get budgetGroups =>
      $$BudgetGroupsTableTableManager(_db.attachedDatabase, _db.budgetGroups);
  $$BudgetGroupCategoriesTableTableManager get budgetGroupCategories =>
      $$BudgetGroupCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.budgetGroupCategories,
      );
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.recurringTransactions,
      );
}
