// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_dao.dart';

// ignore_for_file: type=lint
mixin _$BackupDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountsTable get accounts => attachedDatabase.accounts;
  $CategoriesTable get categories => attachedDatabase.categories;
  $BudgetGroupsTable get budgetGroups => attachedDatabase.budgetGroups;
  $BudgetGroupCategoriesTable get budgetGroupCategories =>
      attachedDatabase.budgetGroupCategories;
  $MonthlyIncomeTable get monthlyIncome => attachedDatabase.monthlyIncome;
  $TransactionsTable get transactions => attachedDatabase.transactions;
  $InvestmentsTable get investments => attachedDatabase.investments;
  $RecurringTransactionsTable get recurringTransactions =>
      attachedDatabase.recurringTransactions;
  $TagsTable get tags => attachedDatabase.tags;
  $TransactionTagsTable get transactionTags => attachedDatabase.transactionTags;
  $NotesTable get notes => attachedDatabase.notes;
  $NoteChecklistItemsTable get noteChecklistItems =>
      attachedDatabase.noteChecklistItems;
  BackupDaoManager get managers => BackupDaoManager(this);
}

class BackupDaoManager {
  final _$BackupDaoMixin _db;
  BackupDaoManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db.attachedDatabase, _db.accounts);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$BudgetGroupsTableTableManager get budgetGroups =>
      $$BudgetGroupsTableTableManager(_db.attachedDatabase, _db.budgetGroups);
  $$BudgetGroupCategoriesTableTableManager get budgetGroupCategories =>
      $$BudgetGroupCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.budgetGroupCategories,
      );
  $$MonthlyIncomeTableTableManager get monthlyIncome =>
      $$MonthlyIncomeTableTableManager(_db.attachedDatabase, _db.monthlyIncome);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db.attachedDatabase, _db.transactions);
  $$InvestmentsTableTableManager get investments =>
      $$InvestmentsTableTableManager(_db.attachedDatabase, _db.investments);
  $$RecurringTransactionsTableTableManager get recurringTransactions =>
      $$RecurringTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.recurringTransactions,
      );
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$TransactionTagsTableTableManager get transactionTags =>
      $$TransactionTagsTableTableManager(
        _db.attachedDatabase,
        _db.transactionTags,
      );
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db.attachedDatabase, _db.notes);
  $$NoteChecklistItemsTableTableManager get noteChecklistItems =>
      $$NoteChecklistItemsTableTableManager(
        _db.attachedDatabase,
        _db.noteChecklistItems,
      );
}
