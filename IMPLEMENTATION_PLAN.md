# IMPLEMENTATION PLAN

Scope: analyze and plan the remaining PlaceholderScaffold screens against `SPEC.md`.

Constraints:
- Use `SPEC.md` as the single behavioral source of truth.
- Do not change DB schema or existing DAO contracts unless a later implementation exposes a proven gap.
- Keep work in small UI/provider increments.
- Preserve existing tests; add focused tests only around newly connected UI/provider behavior.

Current routing note:
- `/budget`, `/stats`, and `/investments` still route to placeholder feature pages.
- `/settings` already routes to `lib/ui/desktop/settings/settings_screen.dart` and subpages in `lib/ui/desktop/settings/*`.
- `lib/features/settings/settings_page.dart` is still a PlaceholderScaffold file, but is currently unused by `lib/router/app_router.dart`. Treat it as a stale feature-level placeholder to retire or replace after confirming no imports remain.

## 1. Budget Screen

Target file:
- `lib/features/budget/budget_page.dart`

SPEC sections:
- `§2.1` sidebar budget badge
- `§3.4` budget groups
- `§3.5` monthly income
- `§4.4` `/budget`
- checklist items for budget group constraints and account-linked budget behavior

### Existing Reusable Code

DAO:
- `BudgetDao`
  - `getMonthlyExpectedIncome(month)`
  - `setMonthlyExpectedIncome(month, income)`
  - `listBudgetGroups(month)`
  - `createBudgetGroup(...)`
  - `updateBudgetGroupAmount(groupId, amount)`
  - `updateBudgetGroupAdjustment(groupId, adjustment)`
  - `updateBudgetGroupPercentage(groupId, percentage)`
  - `updateBudgetGroupCarryForward(groupId, carryForward)`
  - `addCategoryToGroup(groupId, categoryId)`
  - `removeCategoryFromGroup(groupId, categoryId)`
  - `deleteBudgetGroup(groupId)`
  - `budgetGroupVsActual(month)`
  - `copyBudgetGroupsWithCarryforward(sourceMonth, targetMonth)`

Logic and validation:
- `features/budget/logic.dart`
  - `effectiveBudget`
  - `percentageBase`
  - `usagePercent`
  - `accountBudgetFlow`
  - `carryForwardAdjustment`
- `features/budget/validation.dart`
  - `validateBudgetGroup`
  - `BudgetGroupDraft`

Cross-screen dependencies:
- `CategoriesDao.getActiveCategories('expense')` for category-based groups.
- `AccountsDao.getActiveAccounts()` for account-linked groups.
- `ui/desktop/shell/badges_providers.dart` already derives the over-budget sidebar badge from `budgetGroupVsActual(currentMonthKey())`.
- `core/date.dart` month helpers.
- `core/money.dart` formatting and parsing.
- Existing transactions month navigation patterns can be copied from `ui/desktop/transactions/widgets/month_nav.dart`, but avoid coupling to transaction providers.

Tests already present:
- `test/features/budget/logic_test.dart`
- `test/features/budget/validation_test.dart`
- `test/data/budget_dao_test.dart`

### New Providers to Add

Suggested location:
- `lib/ui/desktop/budget/providers.dart`

Providers:
- `budgetMonthProvider`: `StateProvider<String>` initialized with `currentMonthKey()`.
- `budgetRowsProvider`: `FutureProvider.autoDispose<List<BudgetVsActual>>`, watches `budgetMonthProvider`.
- `budgetGroupsProvider`: optional `FutureProvider` for raw `BudgetGroupRow` if the create form needs current category/account occupancy separately from computed rows.
- `monthlyExpectedIncomeProvider`: `FutureProvider.autoDispose<int>`, watches month.
- `budgetExpenseCategoriesProvider`: `FutureProvider<List<Category>>`.
- `budgetAccountsProvider`: `FutureProvider<List<Account>>`.
- `availableBudgetCategoriesProvider`: derived provider or helper that excludes categories already assigned to current month category-based groups.
- `availableBudgetAccountsProvider`: derived provider or helper that excludes accounts already linked in current month.

Mutation helper:
- `refreshBudget(ref)` invalidates rows, groups, monthly income, and `overBudgetCountProvider`.

### New Widgets / Dialogs

Suggested location:
- `lib/ui/desktop/budget/budget_screen.dart`
- `lib/ui/desktop/budget/widgets/*`

Widgets:
- `BudgetScreen`: page shell, month nav, actions, income input, progress, group list.
- `BudgetMonthNav`: independent month navigation using `budgetMonthProvider`.
- `MonthlyIncomeInput`: integer input, saves with `setMonthlyExpectedIncome`.
- `CopyPreviousBudgetButton`: calls `copyBudgetGroupsWithCarryforward(shiftMonth(month, -1), month)`.
- `BudgetProgress`: totals all `BudgetVsActual` rows.
- `BudgetGroupList`: renders empty state and rows.
- `BudgetGroupRowCard`: row display for category-based and account-linked groups.
- `BudgetInlineEditor` or `BudgetGroupEditDialog`: edit amount/adjustment/percentage/carryForward/delete.
- `CreateBudgetGroupForm` or `CreateBudgetGroupDialog`: creates fixed amount, percentage mode, or account-linked group.
- `BudgetCategoryChip`: mapped category display and remove button.
- `AddCategoryToBudgetGroupMenu`: add only unassigned categories.

### Implementation Order

1. Replace only `budget_page.dart` with a thin wrapper to a new `BudgetScreen`.
2. Add budget providers and read-only page:
   - month nav
   - expected income display
   - progress summary
   - group list from `budgetGroupVsActual`
3. Add monthly income editing.
4. Add “previous month copy” button.
5. Add create group flow:
   - fixed category-based group first
   - percentage mode second
   - account-linked mode third
6. Add row-level editing:
   - amount
   - adjustment
   - percentage toggle/value
   - carry-forward toggle
   - delete
7. Add category add/remove inside existing category-based groups.
8. Confirm `overBudgetCountProvider` invalidation after all budget mutations.
9. Add focused widget test for:
   - `/budget` renders seeded empty state or created group
   - create fixed group
   - copy previous month button invokes DAO behavior via an in-memory DB
10. Run `flutter analyze` and full `flutter test`.

### Risks / Gaps

- `BudgetDao.createBudgetGroup` enforces some constraints by convention, not DB CHECK. Keep validation in UI before DAO calls.
- Need to avoid assigning archived categories/accounts. Use active DAO queries only.
- Existing badge provider must refresh after mutations; otherwise sidebar badge may lag.

## 2. Stats Screen

Target file:
- `lib/features/stats/stats_page.dart`

SPEC sections:
- `§4.5` `/stats`
- `§4.6` `/stats/yearly`

### Existing Reusable Code

DAO:
- `TransactionsDao.expenseByCategory(month)`
- `TransactionsDao.monthlyTrend(n, anchorMonth)`
- `TransactionsDao.yearlyCategoryPivot(year, type)`
- `TransactionsDao.availableTransactionYears()`
- `TransactionsDao.monthlySummary(month)` for income/expense/net composition if needed.
- `TransactionsDao.listTransactionsByMonth(month, filter: ...)` can be reused for the category detail panel by passing category/date filters, but confirm range semantics align with SPEC.

Data rows:
- `CategoryBreakdownRow`
- `MonthlyTrendRow`
- `YearlyPivotRow`

Existing dependency:
- `fl_chart` is already in `pubspec.yaml`.

Tests already present:
- `test/data/stats_dao_test.dart`

### New Providers to Add

Suggested location:
- `lib/ui/desktop/stats/providers.dart`

Providers:
- `statsMonthProvider`: `StateProvider<String>` initialized with `currentMonthKey()`.
- `expenseBreakdownProvider`: `FutureProvider.autoDispose<List<CategoryBreakdownRow>>`.
- `statsMonthlySummaryProvider`: `FutureProvider.autoDispose<MonthlySummary>`.
- `monthlyTrendProvider`: `FutureProvider.autoDispose<List<MonthlyTrendRow>>`.
- `selectedStatsCategoryProvider`: `StateProvider<int?>` for detail panel.
- `statsCategoryTransactionsProvider`: `FutureProvider.autoDispose<List<TransactionRow>>`, optional for the detail panel.
- `statsYearProvider`: `StateProvider<int>` initialized with current year or latest available year.
- `availableTransactionYearsProvider`: `FutureProvider<List<int>>`.
- `yearlyExpensePivotProvider`: `FutureProvider<List<YearlyPivotRow>>`.
- `yearlyIncomePivotProvider`: `FutureProvider<List<YearlyPivotRow>>`.
- `yearlyNetRowsProvider`: derived from income/expense pivot or a small helper over `monthlySummary`/trend data.

### New Widgets / Dialogs

Suggested location:
- `lib/ui/desktop/stats/stats_screen.dart`
- `lib/ui/desktop/stats/yearly_stats_screen.dart`
- `lib/ui/desktop/stats/widgets/*`

Widgets:
- `StatsScreen`: page shell, month nav, two donut panels, trend chart, yearly link.
- `StatsMonthNav`: equivalent month control, independent provider.
- `ExpenseCategoryDonut`: `fl_chart` pie chart using `expenseByCategory`.
- `IncomeExpenseDonut`: income slice + expense category slices.
- `CategoryLegend`: legend rows and click handling.
- `CategoryDetailPanel`: list of transactions for selected category.
- `TrendChart`: 12-month income/expense/net chart.
- `YearlyStatsScreen`: `/stats/yearly` page.
- `YearNav`: previous/next year and available-year chips.
- `PivotTable`: category x 12 months table.
- `NetIncomeTable`: monthly income-expense rows.

Router additions:
- Add nested route under `/stats`:
  - `path: 'yearly'`
  - optional query `year=YYYY`; if omitted, use provider default.

### Implementation Order

1. Replace `stats_page.dart` with a thin wrapper to `StatsScreen`.
2. Add `/stats/yearly` route and a placeholder `YearlyStatsScreen` shell without data.
3. Add stats providers.
4. Implement read-only monthly stats:
   - month nav
   - expense donut
   - income vs expense donut
   - trend chart
5. Add `CategoryLegend` and selected category state.
6. Add `CategoryDetailPanel`.
7. Implement yearly stats:
   - available years
   - year navigation
   - expense pivot
   - income pivot
   - net income table
8. Add widget tests:
   - `/stats` renders seeded/fixture chart labels
   - `/stats/yearly` renders 12 month headers
9. Run `flutter analyze` and full `flutter test`.

### Risks / Gaps

- Chart rendering can be visually correct but hard to assert in tests. Keep tests on labels, totals, and table text.
- `CategoryDetailPanel` should not alter `TransactionsScreen` provider state.
- SPEC says stats currently have no category/account filters beyond category detail; do not add extra filtering now.

## 3. Investments Screen

Target file:
- `lib/features/investments/investments_page.dart`

SPEC sections:
- `§3.6` investments table
- `§3.10` cost basis and balance impact
- `§4.7` `/investments`

### Existing Reusable Code

DAO:
- `InvestmentsDao.listInvestmentsByMonth(month)`
- `InvestmentsDao.investmentMonthlySummary(month)`
- `InvestmentsDao.listInvestmentsByYear(year)`
- `InvestmentsDao.investmentYearlySummary(year)`
- `InvestmentsDao.availableInvestmentYears()`
- `InvestmentsDao.listCurrentHoldings()`
- `InvestmentsDao.getInvestmentAccount()`
- `InvestmentsDao.getInvestmentById(id)`
- `InvestmentsDao.listHeldTickers()`
- `InvestmentsDao.getRealizedPnL(from, to)`
- `InvestmentsDao.saveInvestment(id?, draft)`
- `InvestmentsDao.deleteInvestment(id)`

Logic and validation:
- `features/investments/cost_basis.dart`
  - `computeInvestmentEvents`
  - `realizedPnL`
  - `heldTickers`
  - `currentHoldings`
- `features/investments/validation.dart`
  - `validateInvestment`
  - `checkTradableTicker`

Cross-screen dependencies:
- `AccountsDao` indirectly through `getInvestmentAccount`.
- `core/date.dart` for month/date range.
- `core/money.dart` for KRW.

Tests already present:
- `test/features/investments/*`
- `test/data/investments_dao_test.dart`
- `test/data/investments_yearly_test.dart`
- `test/data/account_transactions_test.dart` confirms investment virtual rows in account detail.

### New Providers to Add

Suggested location:
- `lib/ui/desktop/investments/providers.dart`

Providers:
- `investmentViewProvider`: `StateProvider<InvestmentView>` for list vs PnL.
- `investmentMonthProvider`: `StateProvider<String>`.
- `investmentRowsProvider`: `FutureProvider.autoDispose<List<Investment>>`.
- `investmentMonthlySummaryProvider`: `FutureProvider.autoDispose<InvestmentSummary>`.
- `investmentAccountProvider`: `FutureProvider<Account?>`.
- `heldTickersProvider`: `FutureProvider<List<String>>`.
- `currentHoldingsProvider`: `FutureProvider<List<CurrentHolding>>`.
- `pnlDateRangeProvider`: `StateProvider<({String from, String to})>`.
- `realizedPnlProvider`: `FutureProvider.autoDispose<List<RealizedPnL>>`.

Mutation helper:
- `refreshInvestments(ref)` invalidates rows, summary, held tickers, holdings, PnL, investment account, and account balance providers if imported carefully.

### New Widgets / Dialogs

Suggested location:
- `lib/ui/desktop/investments/investments_screen.dart`
- `lib/ui/desktop/investments/widgets/*`

Widgets:
- `InvestmentsScreen`: page shell and tab switch.
- `InvestmentViewTabs`: list / PnL.
- `InvestmentAccountBanner`: shows linked investment asset or missing asset guidance.
- `InvestmentMonthNav`: list tab month navigation.
- `InvestmentSummaryBar`: buy/sell/dividend/net cash.
- `HoldingsList`: current holdings snapshot.
- `InvestmentList`: rows by month.
- `InvestmentQuickRow`: add/edit row with side/date/time/ticker/quantity/amount/memo.
- `TickerField` or `TickerSearch`: simple text field with held ticker suggestions.
- `InvestmentDeleteButton` or row action.
- `PnLDateRange`: from/to date controls.
- `InvestmentPnL`: realized PnL summary and row list.

### Implementation Order

1. Replace `investments_page.dart` with a thin wrapper to `InvestmentsScreen`.
2. Add providers and read-only list tab:
   - account banner
   - month nav
   - summary bar
   - list rows
3. Add holdings snapshot.
4. Add create/edit row:
   - buy first
   - sell/dividend with `checkTradableTicker`
   - delete
5. Add PnL tab:
   - date range
   - summary
   - realized rows
6. Confirm account balances refresh after investment mutations because investments affect account balance.
7. Add widget tests:
   - `/investments` renders monthly summary
   - adding sell for non-held ticker is rejected
   - PnL tab renders dividend/sell rows from fixture data
8. Run `flutter analyze` and full `flutter test`.

### Risks / Gaps

- `saveInvestment` always maps to the current active investment account. If no investment account exists, it saves with `accountId=null`; UI should make that explicit.
- Sell/dividend validation must be in UI/provider before DAO call, as DAO intentionally does not enforce held-ticker rules.
- Investment mutations affect `AccountsScreen` balances and account detail virtual rows. Invalidate those providers if they are in scope.

## 4. Settings Placeholder File

Target file:
- `lib/features/settings/settings_page.dart`

SPEC sections:
- `§4.8` `/settings`
- `§4.8.1` categories
- `§4.8.2` recurring
- `§4.8.3` tags
- `§4.8.4` theme
- `§4.8.5` data management
- `§5.2` backup schema

### Current Status

Router currently uses:
- `lib/ui/desktop/settings/settings_screen.dart`
- `lib/ui/desktop/settings/categories_screen.dart`
- `lib/ui/desktop/settings/tags_screen.dart`
- `lib/ui/desktop/settings/recurring_screen.dart`

Therefore `lib/features/settings/settings_page.dart` is not the active `/settings` implementation. It is still a PlaceholderScaffold file and should be handled deliberately:
- Option A: delete it after confirming no imports.
- Option B: replace it with a compatibility export/wrapper to `SettingsScreen`.
- Option C: leave it temporarily but track it as stale placeholder debt.

Recommended: Option B first, then delete only in a cleanup PR if no imports remain.

### Existing Reusable Code

Already implemented settings subareas:
- Categories UI and providers in `lib/ui/desktop/settings/categories_screen.dart` and widgets.
- Tags UI and providers in `lib/ui/desktop/settings/tags_screen.dart` and widgets.
- Recurring UI and providers in `lib/ui/desktop/settings/recurring_screen.dart` and widgets.

DAO:
- `CategoriesDao`
- `TagsDao`
- `RecurringDao`
- `BackupDao`
  - `exportBackup`
  - `importBackup`
  - `resetAllData`

Theme:
- `core/theme/theme_notifier.dart`
  - `themeProvider`
  - `ThemeNotifier.setColor`
  - `ThemeNotifier.reset`
- `core/theme/theme_colors.dart`
  - `ThemeColors`
  - `ThemeToken`
  - `defaultTheme`

Backup parsing:
- `data/backup.dart`
  - `parseBackup`
  - `buildBackupFilename`
  - `Backup`

Dependencies available:
- `file_picker`
- `shared_preferences`
- `path_provider`

### New Providers to Add

Suggested location:
- Extend `lib/ui/desktop/settings/providers.dart` or split into focused files if it grows too much.

Providers:
- `backupExportProvider`: not necessarily a provider; direct action is fine.
- `themeReadyProvider`: optional Future wrapper around `ThemeNotifier.whenReady` if UI needs loading state.

Mutation helpers:
- `refreshAfterImportOrReset(ref)`:
  - invalidate accounts
  - transactions
  - categories
  - tags
  - recurring
  - budget
  - investments
  - stats-related providers once they exist

### New Widgets / Dialogs

Settings main:
- `DataManagementPanel`
- `ExportBackupButton`
- `ImportBackupButton`
- `ResetAllDataDialog`

Theme:
- `ThemeScreen` under `/settings/theme`
- `ThemeColorRow`
- `ThemeColorPickerDialog` or inline swatch picker
- `ResetThemeButton`

Compatibility:
- Replace `features/settings/settings_page.dart` with a wrapper or remove from project after route audit.

Router additions:
- Add `/settings/theme`.
- Optional future route `/settings/data` only if the settings main becomes too dense. SPEC places data management on settings main, so keep it there first.

### Implementation Order

1. Decide how to retire `features/settings/settings_page.dart`:
   - replace with wrapper to `SettingsScreen` for now.
2. Add `/settings/theme` route and `ThemeScreen`.
3. Connect theme UI to `themeProvider`.
4. Update `app.dart` if needed so `MaterialApp.router.theme` uses `themeProvider` instead of static `buildAppTheme`.
   - Keep this small and avoid rewriting global tokens in the same step.
5. Add `DataManagementPanel` to `SettingsScreen`.
6. Implement export:
   - call `backupDao.exportBackup`
   - serialize using existing `Backup` support or add a minimal serializer if missing
   - write via file picker / save location
7. Implement import:
   - pick file
   - read JSON
   - `parseBackup`
   - `backupDao.importBackup`
   - invalidate relevant providers
8. Implement reset:
   - confirmation dialog requiring exact text `삭제`
   - call `backupDao.resetAllData`
   - invalidate relevant providers
9. Add tests:
   - theme notifier tests already exist; add UI smoke if route is added.
   - backup DAO tests already exist; add one settings widget smoke test if practical.
10. Run `flutter analyze` and full `flutter test`.

### Risks / Gaps

- Export/import file system behavior needs platform handling. Keep serialization and DAO tested separately from picker UI.
- Import/reset invalidation touches almost every page. Centralize it in one helper to prevent stale screens.
- `app_theme.dart` still has static token comments. Theme UI should either update actual `ThemeData` or be clearly delayed; SPEC requires persistence and restoration.

## Cross-Cutting Order Recommendation

Recommended implementation sequence:

1. Budget read-only screen.
2. Budget mutations.
3. Investments read-only list.
4. Investments mutations and PnL tab.
5. Stats monthly screen.
6. Stats yearly screen.
7. Settings theme.
8. Settings data management.
9. Cleanup stale `features/settings/settings_page.dart`.

Rationale:
- Budget and investments already have strong DAO coverage and affect daily use.
- Stats is mostly read-only but chart-heavy, so it is safer after data views are stable.
- Settings data management has broad blast radius; do it after main data screens have providers that can be invalidated consistently.

## Verification Strategy

After each small step:
- Run `flutter analyze`.
- Run the narrow relevant tests first:
  - Budget: `test/features/budget`, `test/data/budget_dao_test.dart`
  - Stats: `test/data/stats_dao_test.dart`
  - Investments: `test/features/investments`, `test/data/investments_dao_test.dart`, `test/data/investments_yearly_test.dart`
  - Settings data: `test/data/backup_dao_test.dart`, `test/core/theme`
- Run full `flutter test` before considering a screen complete.

Do not:
- Change schema or generated Drift files unless a DAO/schema gap is explicitly identified.
- Combine unrelated screen implementations in one pass.
- Refactor existing transactions/accounts UI while implementing these screens.
