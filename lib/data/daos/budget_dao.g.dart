// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'budget_dao.dart';

// ignore_for_file: type=lint
mixin _$BudgetDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $BudgetGroupsTable get budgetGroups => attachedDatabase.budgetGroups;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BudgetGroupCategoriesTable get budgetGroupCategories =>
      attachedDatabase.budgetGroupCategories;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $MonthlyIncomeTable get monthlyIncome => attachedDatabase.monthlyIncome;
  BudgetDaoManager get managers => BudgetDaoManager(this);
}

class BudgetDaoManager {
  final _$BudgetDaoMixin _db;
  BudgetDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$BudgetGroupsTableTableManager get budgetGroups =>
      $$BudgetGroupsTableTableManager(_db.attachedDatabase, _db.budgetGroups);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BudgetGroupCategoriesTableTableManager get budgetGroupCategories =>
      $$BudgetGroupCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.budgetGroupCategories,
      );
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$MonthlyIncomeTableTableManager get monthlyIncome =>
      $$MonthlyIncomeTableTableManager(_db.attachedDatabase, _db.monthlyIncome);
}
