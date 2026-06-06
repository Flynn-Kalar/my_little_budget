# IMPLEMENTATION PLAN

Scope: track the remaining screen implementations against `SPEC.md` and the current Flutter file structure.

Constraints:
- Use `SPEC.md` as the single behavioral source of truth.
- Do not change DB schema or generated Drift files unless a later implementation exposes a proven gap.
- Do not change existing DAO contracts for read-only phases.
- Keep work in small UI/provider increments.
- Preserve existing tests; run `flutter analyze` and `flutter test` after each screen step.

Current phase:
- MVP stabilization pass.
- `MVP_CHECKLIST.md` is the current status board for `DONE`, `PARTIAL`, `TODO`, `READ_ONLY`, `NOT_IMPLEMENTED`, and `TECH_DEBT`.
- Keep this plan aligned with `MVP_CHECKLIST.md` after each MVP step.

## Current Route Audit

Source of truth:
- `lib/router/app_router.dart`

Active routes:
- `/transactions` -> `lib/ui/desktop/transactions/transactions_screen.dart`
- `/budget` -> `lib/features/budget/budget_page.dart`
  - `BudgetPage` delegates to `lib/ui/desktop/budget/budget_screen.dart`
- `/stats` -> `lib/features/stats/stats_page.dart`
  - `StatsPage` delegates to `lib/ui/desktop/stats/stats_screen.dart`
- `/stats/yearly` -> `lib/ui/desktop/stats/yearly_stats_screen.dart`
- `/accounts` -> `lib/ui/desktop/accounts/accounts_screen.dart`
- `/accounts/:id` -> `lib/ui/desktop/accounts/account_detail_screen.dart`
- `/investments` -> `lib/features/investments/investments_page.dart`
  - `InvestmentsPage` delegates to `lib/ui/desktop/investments/investments_screen.dart`
- `/settings` -> `lib/features/settings/settings_page.dart`
- `/settings/categories` -> `lib/ui/desktop/settings/categories_screen.dart`
- `/settings/tags` -> `lib/ui/desktop/settings/tags_screen.dart`
- `/settings/recurring` -> `lib/ui/desktop/settings/recurring_screen.dart`
- `/settings/theme` -> `lib/ui/desktop/settings/theme_screen.dart`
- `/settings/backup` -> `lib/ui/desktop/settings/data_management_screen.dart`
- `/settings/data` -> compatibility redirect to `/settings/backup`

No active route currently points to `lib/ui/desktop/settings/settings_screen.dart`.

Placeholder audit:
- `PlaceholderScaffold` has been removed.
- No active route or feature page imports `PlaceholderScaffold`.
- A permanent route smoke widget test covers:
  - `/transactions`
  - `/accounts`
  - `/budget`
  - `/stats`
  - `/stats/yearly`
  - `/investments`
  - `/settings`
  - `/settings/theme`
  - `/settings/backup`
- Focused MVP widget coverage is added in `test/ui/mvp_stabilization_test.dart` for:
  - Budget group rendering, expected income display, group mode display, and expected-income mutation refresh
  - Investment BUY/SELL/DIVIDEND rendering, holdings inline expansion, quantity precision display, and realized PnL rendering
  - Transaction debounced search, investment ticker filter empty state, and account detail category/tag filtering
  - Settings theme controls, backup/export import entry buttons, and destructive import confirmation copy

## Completed

### Search And Filter UX Step 1

Active files:
- `lib/ui/desktop/transactions/widgets/filter_panel.dart`
- `lib/ui/desktop/transactions/widgets/transaction_list.dart`
- `lib/ui/desktop/transactions/providers.dart`
- `lib/ui/desktop/accounts/widgets/account_tx_list.dart`
- `lib/ui/desktop/accounts/providers.dart`
- `lib/ui/desktop/investments/investments_screen.dart`
- `lib/ui/desktop/investments/providers.dart`

Current status:
- `/transactions` search now debounces text input and keeps the existing detailed filter panel flow.
- Transaction search state is visible in the filter panel, and search can be cleared directly.
- Transaction empty states distinguish no monthly data, no search result, and no filter result.
- `/investments` monthly transaction rows can be filtered by:
  - BUY/SELL/DIVIDEND side
  - account
  - ticker
  - date range
- `/accounts/:id` detail transactions can be filtered by:
  - date range
  - category
  - tag
- Filter state is held in Riverpod state providers and survives screen rebuilds within the running app session.
- No DB schema, backup format, route, or search-index changes were introduced.

### Settings Main Page

Active file:
- `lib/features/settings/settings_page.dart`

Current status:
- `PlaceholderScaffold` has been removed.
- The active `/settings` implementation is `SettingsPage`.
- Settings cards are implemented for:
  - `/settings/categories`
  - `/settings/tags`
  - `/settings/recurring`
  - `/settings/theme`
  - `/settings/backup`
- Theme settings is connected to a first-pass theme screen.
- Data backup/restore is connected to a first-pass data management screen.
- Settings sub-screens remain under `lib/ui/desktop/settings/`.
- The theme screen supports:
  - system/light/dark mode selection
  - persisted theme mode through SharedPreferences
  - persisted color token changes through the existing `themeProvider`
  - immediate `MaterialApp` theme updates through `themeProvider` and `themeModeProvider`
- The data management screen supports:
  - export to a single JSON backup file
  - filename format `my_little_budget-backup-yyyyMMdd-HHmmss.json`
  - JSON backup file selection
  - parse/structure validation with the existing backup parser
  - required destructive import confirmation
  - full replacement import through `BackupDao.importBackup`
  - broad provider invalidation after import so visible data refreshes without app restart

Remaining settings work:
- Add optional reset UI only after provider invalidation and destructive UX are tested carefully.

### Budget Editing Step 1

Active files:
- `lib/features/budget/budget_page.dart`
- `lib/ui/desktop/budget/budget_screen.dart`
- `lib/ui/desktop/budget/providers.dart`

Current status:
- `BudgetPage` delegates to `BudgetScreen`.
- `PlaceholderScaffold` has been removed from `/budget`.
- Screen is implemented with:
  - current-month navigation
  - monthly expected income display
  - total budget
  - total spent
  - remaining amount
  - `budgetGroupVsActual` row list
  - monthly expected income editing
  - previous-month budget copy with carry-forward
  - fixed category-based budget group creation
  - percentage category-based budget group creation with expected-income preview
  - account-linked budget group creation within the existing DAO/schema
  - existing fixed-group amount editing
  - existing percentage-group percentage editing with expected-income preview
  - existing category-based group adjustment editing
  - existing category-based group carry-forward editing
  - existing fixed/percentage category-based group category add/remove editing
  - account-linked group linked-account editing with calculation preview
  - budget group delete with confirmation
- Budget providers are implemented:
  - `budgetMonthProvider`
  - `monthlyExpectedIncomeProvider`
  - `budgetRowsProvider`
  - `budgetExpenseCategoriesProvider`
  - `budgetActiveAccountsProvider`
- `refreshBudget(ref)` invalidates `monthlyExpectedIncomeProvider`, `budgetRowsProvider`, and `overBudgetCountProvider`.
- Budget group creation currently supports:
  - fixed category-based groups:
    - group name
    - monthly budget amount
    - linked expense categories
    - carry-forward flag
  - percentage category-based groups:
    - group name
    - expected-income percentage
    - calculated budget preview from monthly expected income
    - linked expense categories
    - carry-forward flag
  - account-linked groups:
    - group name
    - linked active account
    - no carry-forward or category mapping
- Percentage editing currently supports:
  - percentage value update
  - adjustment update
  - carry-forward update
- Category-based editing currently supports:
  - selected-state display for currently linked expense categories
  - adding/removing expense category mappings through existing `BudgetDao` methods
  - validation that at least one category remains linked
- Account-linked editing currently supports:
  - selected-state display for the currently linked account
  - linked account change through `BudgetDao.updateBudgetGroupAccount`
  - calculation preview through `BudgetDao.accountLinkedBudgetPreview`
  - validation that a valid account remains selected

### Stats Read-Only Screen

Active files:
- `lib/features/stats/stats_page.dart`
- `lib/ui/desktop/stats/stats_screen.dart`
- `lib/ui/desktop/stats/yearly_stats_screen.dart`
- `lib/ui/desktop/stats/providers.dart`

Current status:
- `StatsPage` delegates to `StatsScreen`.
- `PlaceholderScaffold` has been removed from `/stats`.
- Read-only screen is implemented with:
  - current-month navigation
  - current-month expense category breakdown
  - selectable category breakdown rows
  - selected category transaction detail panel
  - recent 12-month income/expense/net trend table
  - recent 12-month income/expense/net totals
  - `/stats/yearly` entry button
- `/stats/yearly` is implemented with:
  - year selector
  - monthly income/expense/net table
  - yearly income/expense/net totals
  - category annual expense totals
  - empty states for years with no transaction data
- Stats providers are implemented:
  - `statsMonthProvider`
  - `statsYearProvider`
  - `statsSelectedCategoryProvider`
  - `statsExpenseBreakdownProvider`
  - `statsMonthlyTrendProvider`
  - `statsCategoryTransactionsProvider`
  - `availableStatsYearsProvider`
  - `yearlyMonthlyTrendProvider`
  - `yearlyExpenseByCategoryProvider`
- `fl_chart` is not wired in this first pass; cards, lists, and tables are used.

### Investments Creation And Realized PnL Step

Active files:
- `lib/features/investments/investments_page.dart`
- `lib/ui/desktop/investments/investments_screen.dart`
- `lib/ui/desktop/investments/providers.dart`

Current status:
- `InvestmentsPage` delegates to `InvestmentsScreen`.
- `PlaceholderScaffold` has been removed from `/investments`.
- Read-only screen is implemented with:
  - current-month navigation
  - investment account status banner
  - monthly buy/sell/dividend/net summary
  - current holdings snapshot
  - current-month investment transaction list with side/account/ticker/date filters
  - current-month realized PnL read-only section
- Investment transaction creation is implemented for BUY, SELL, and DIVIDEND.
- BUY fields:
  - occurred date
  - ticker
  - display name captured into memo because the DB has no separate name column
  - quantity
  - unit price
  - fee
  - linked investment account display
  - memo
- SELL fields:
  - occurred date
  - ticker from the expanded holding row
  - quantity
  - total sell amount
  - fee
  - memo
- DIVIDEND fields:
  - occurred date
  - ticker from the expanded holding row
  - dividend total amount
  - memo
- BUY creation remains in the top action button.
- SELL/DIVIDEND creation is implemented as inline expansion under current holding rows:
  - no top fixed SELL/DIVIDEND form
  - clicking a holding row toggles its inline forms
  - only one holding row can be expanded at a time
  - clicking another row closes the previous expansion
  - clicking the same row again collapses it
  - save closes the inline area and refreshes investment/account providers
- SELL/DIVIDEND reuse existing `validateInvestment`; inline creation uses the expanded holding ticker directly.
- SELL additionally uses `checkSellQuantity` to reject selling more than current holdings.
- Investment quantity precision policy is implemented:
  - quantity only supports 4 decimal places
  - values with 5+ decimals are rounded at the 5th decimal place before storage
  - amounts, unit prices, and fees remain integer KRW values
  - holdings, average-cost, realized PnL, validation, investment rows, PnL rows, and account virtual rows use the same 4-decimal quantity policy
  - internal holdings/PnL calculations use fixed 1/10000 units to avoid direct floating-point quantity comparisons
- Investment row edit/delete is implemented:
  - monthly list rows expose edit/delete actions
  - edit reuses the investment dialog with existing row values
  - BUY, SELL, and DIVIDEND can be updated through `InvestmentsDao.saveInvestment(id: draft:)`
  - delete uses a confirmation dialog and `InvestmentsDao.deleteInvestment(id)`
  - save/delete refresh investment rows, monthly summary, current holdings, realized PnL, investment account, account balances, and account detail providers when possible
- Investment providers are implemented:
  - `investmentMonthProvider`
  - `investmentRowsProvider`
  - `investmentMonthlySummaryProvider`
  - `investmentAccountProvider`
  - `currentHoldingsProvider`
  - `realizedPnlProvider`
- `realizedPnlProvider` calculates the selected month range with `monthRange(month)` and calls `InvestmentsDao.getRealizedPnL(from, to)`.
- The realized PnL section shows:
  - monthly total realized PnL
  - total sell amount
  - total dividend amount
  - SELL/DIVIDEND rows with date, ticker, quantity, sell/dividend amount, cost basis, PnL, and return rate
  - empty state when the selected month has no realized PnL rows
- `refreshInvestments(ref, accountId: ...)` invalidates investment providers, `realizedPnlProvider`, and account balance/detail providers when possible.

## Remaining Placeholder

There are no remaining top-level `PlaceholderScaffold` screens in the current route set.

The legacy placeholder scaffold file has been deleted.

Note:
- Investments PnL is represented by a read-only monthly realized PnL section; a separate tab is still deferred.

## Investments Remaining Work

Current read-only base, BUY/SELL/DIVIDEND creation, monthly realized PnL section, and investment edit/delete are complete.

Next steps:
1. Consider a dedicated PnL tab only if the monthly read-only section needs more filtering or historical range controls.
2. Add focused widget tests for investment mutations and realized PnL rendering.
3. Revisit account detail virtual investment rows after more manual QA.

## Stats Remaining Work

Current monthly read-only base, selected category detail panel, and yearly read-only screen are complete.

Next steps:
1. Consider replacing list/table visuals with `fl_chart` after the read-only data surface is stable.
2. Add focused widget tests for `/stats/yearly`.

## Budget Remaining Work

Current read-only base, first edit step, previous-month copy, fixed/percentage/account-linked creation, fixed/percentage editing, category add/remove editing, account-linked account editing, and row delete are complete. Continue only after preserving the existing provider shape and refresh behavior.

Next steps:
1. Keep invalidating budget rows, expected income, and `overBudgetCountProvider` after mutations.
2. Add focused widget tests for create/copy/edit/delete flows.

## Settings Remaining Work

Current main page is complete as a navigation/status surface.

Next steps:
1. Add optional reset UI only after deciding provider invalidation scope and destructive confirmation UX.
2. Add focused widget/integration coverage for `/settings/theme` and `/settings/backup`.
3. Keep existing `/settings/categories`, `/settings/tags`, `/settings/recurring`, `/settings/theme`, and `/settings/backup` routes intact.

## Stabilization Notes

Current pass:
- `/settings/backup` is the canonical backup/restore route.
- `/settings/data` redirects to `/settings/backup` for compatibility.
- Cross-screen provider invalidation was tightened for:
  - transaction save/delete/duplicate flows
  - category/tag/recurring settings mutations
  - account metadata changes
  - account adjustment transaction mutations
- DB schema and backup JSON format were not changed.
- Widget tests now cover the highest-risk MVP surfaces called out in `MVP_CHECKLIST.md`, including monthly stats category detail.

## Next Implementation Order

Recommended order from the current code state:

1. Optional settings reset UI

Rationale:
- The top-level placeholder pass is complete.
- Investments now has create/edit/delete coverage at the UI layer, plus read-only realized PnL.
- Budget CRUD is now mostly covered; remaining budget work is focused widget coverage and manual UX QA.
- Stats monthly and yearly read-only surfaces are complete; remaining stats work is optional visualization/test depth.
- Settings theme and data export/import are now implemented; optional reset UI still has broad invalidation/destructive UX impact and should remain late.

## Verification Strategy

After each small step:
- Run `flutter analyze`.
- Run focused MVP widget tests:
  - `flutter test test/ui/mvp_stabilization_test.dart`
- Run focused tests first:
  - Budget: `test/features/budget`, `test/data/budget_dao_test.dart`
  - Investments: `test/features/investments`, `test/data/investments_dao_test.dart`, `test/data/investments_yearly_test.dart`
  - Stats: `test/data/stats_dao_test.dart`
  - Settings data: `test/data/backup_dao_test.dart`, `test/core/theme`
- Run full `flutter test` before considering a screen complete.

Do not:
- Change DB schema for these screen steps.
- Touch settings sub-screens while implementing unrelated screens.
- Combine unrelated screen implementations in one pass.
- Refactor transactions/accounts UI while implementing these remaining enhancements.
