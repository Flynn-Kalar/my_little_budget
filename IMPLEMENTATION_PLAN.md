# IMPLEMENTATION PLAN

Scope: track the remaining screen implementations against `SPEC.md` and the current Flutter file structure.

Constraints:
- Use `SPEC.md` as the single behavioral source of truth.
- Do not change DB schema or generated Drift files unless a later implementation exposes a proven gap.
- Do not change existing DAO contracts for read-only phases.
- Keep work in small UI/provider increments.
- Preserve existing tests; run `flutter analyze` and `flutter test` after each screen step.

## Current Route Audit

Source of truth:
- `lib/router/app_router.dart`

Active routes:
- `/transactions` -> `lib/ui/desktop/transactions/transactions_screen.dart`
- `/budget` -> `lib/features/budget/budget_page.dart`
  - `BudgetPage` delegates to `lib/ui/desktop/budget/budget_screen.dart`
- `/stats` -> `lib/features/stats/stats_page.dart`
  - `StatsPage` delegates to `lib/ui/desktop/stats/stats_screen.dart`
- `/accounts` -> `lib/ui/desktop/accounts/accounts_screen.dart`
- `/accounts/:id` -> `lib/ui/desktop/accounts/account_detail_screen.dart`
- `/investments` -> `lib/features/investments/investments_page.dart`
  - Still uses `PlaceholderScaffold`
- `/settings` -> `lib/features/settings/settings_page.dart`
- `/settings/categories` -> `lib/ui/desktop/settings/categories_screen.dart`
- `/settings/tags` -> `lib/ui/desktop/settings/tags_screen.dart`
- `/settings/recurring` -> `lib/ui/desktop/settings/recurring_screen.dart`

No active route currently points to `lib/ui/desktop/settings/settings_screen.dart`.

## Completed

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
- Theme settings is represented as a disabled/TODO card.
- Data backup/restore is represented as a disabled/connection-planned card.
- Settings sub-screens remain under `lib/ui/desktop/settings/`.

Remaining settings work:
- Add a real `/settings/theme` route and screen.
- Add data management UI for export/import/reset only after provider invalidation can be handled carefully.

### Budget Read-Only Screen

Active files:
- `lib/features/budget/budget_page.dart`
- `lib/ui/desktop/budget/budget_screen.dart`
- `lib/ui/desktop/budget/providers.dart`

Current status:
- `BudgetPage` delegates to `BudgetScreen`.
- `PlaceholderScaffold` has been removed from `/budget`.
- Read-only screen is implemented with:
  - current-month navigation
  - monthly expected income display
  - total budget
  - total spent
  - remaining amount
  - `budgetGroupVsActual` row list
- Budget providers are implemented:
  - `budgetMonthProvider`
  - `monthlyExpectedIncomeProvider`
  - `budgetRowsProvider`
- `overBudgetCountProvider` has not been changed.
- No budget create/update/delete UI exists yet.

### Stats Read-Only Screen

Active files:
- `lib/features/stats/stats_page.dart`
- `lib/ui/desktop/stats/stats_screen.dart`
- `lib/ui/desktop/stats/providers.dart`

Current status:
- `StatsPage` delegates to `StatsScreen`.
- `PlaceholderScaffold` has been removed from `/stats`.
- Read-only screen is implemented with:
  - current-month navigation
  - current-month expense category breakdown
  - recent 12-month income/expense/net trend table
  - recent 12-month income/expense/net totals
  - `/stats/yearly` TODO card
- Stats providers are implemented:
  - `statsMonthProvider`
  - `statsExpenseBreakdownProvider`
  - `statsMonthlyTrendProvider`
- `fl_chart` is not wired in this first pass; cards, lists, and tables are used.
- `/stats/yearly` route and screen are not implemented yet.

## Remaining Placeholder

### InvestmentsPage

Current file:
- `lib/features/investments/investments_page.dart`

Current status:
- Still uses `PlaceholderScaffold`.
- No `lib/ui/desktop/investments/` implementation exists yet.

SPEC sections:
- investments table
- cost basis and balance impact
- `/investments`

Reusable code:
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
- `features/investments/cost_basis.dart`
- `features/investments/validation.dart`

Providers to add:
- `lib/ui/desktop/investments/providers.dart`
- `investmentViewProvider`
- `investmentMonthProvider`
- `investmentRowsProvider`
- `investmentMonthlySummaryProvider`
- `investmentAccountProvider`
- `heldTickersProvider`
- `currentHoldingsProvider`
- `pnlDateRangeProvider`
- `realizedPnlProvider`

Widgets/screens to add:
- `lib/ui/desktop/investments/investments_screen.dart`
- `lib/ui/desktop/investments/widgets/*` as needed
- `InvestmentsScreen`
- `InvestmentViewTabs`
- `InvestmentAccountBanner`
- `InvestmentMonthNav`
- `InvestmentSummaryBar`
- `HoldingsList`
- `InvestmentList`
- `InvestmentQuickRow`
- `TickerField`
- `PnLDateRange`
- `InvestmentPnL`

Implementation order:
1. Replace `InvestmentsPage` with a thin wrapper to `InvestmentsScreen`.
2. Add `lib/ui/desktop/investments/providers.dart`.
3. Implement read-only investments list:
   - investment account banner
   - month nav
   - monthly summary
   - monthly rows
4. Add current holdings snapshot.
5. Add create/edit/delete investment rows:
   - buy first
   - sell and dividend with `checkTradableTicker`
6. Add PnL tab:
   - date range
   - realized PnL rows
   - summary
7. Confirm account-related providers refresh after investment mutations.
8. Add focused widget tests.
9. Run `flutter analyze` and full `flutter test`.

Risks/gaps:
- `saveInvestment` can save with `accountId = null` when no active investment account exists; UI should make that state visible.
- Sell/dividend validation must happen before DAO calls.
- Investment mutations affect account balances and account detail virtual rows.

## Stats Remaining Work

Current monthly read-only base is complete.

Next steps:
1. Add selected category state and category transaction detail panel.
2. Add `/stats/yearly` route.
3. Implement yearly stats screen:
   - available years
   - expense pivot
   - income pivot
   - net table
4. Consider replacing list/table visuals with `fl_chart` after the read-only data surface is stable.
5. Add focused widget tests for `/stats` and `/stats/yearly`.

## Budget Remaining Work

Current read-only base is complete. Continue only after preserving the existing provider shape.

Next steps:
1. Add monthly expected income editing with `BudgetDao.setMonthlyExpectedIncome`.
2. Add previous-month copy with `BudgetDao.copyBudgetGroupsWithCarryforward`.
3. Add create budget group flow:
   - fixed category-based group
   - percentage mode
   - account-linked mode
4. Add row-level editing:
   - amount
   - adjustment
   - percentage
   - carry-forward
   - delete
5. Add category add/remove for category-based groups.
6. Invalidate budget rows, expected income, and `overBudgetCountProvider` only after mutations are implemented.
7. Add focused widget tests for create/copy/edit flows.

## Settings Remaining Work

Current main page is complete as a navigation/status surface.

Next steps:
1. Add `/settings/theme` route.
2. Implement `ThemeScreen` using existing theme notifier/code.
3. Add backup/export/import/reset UI only after deciding provider invalidation scope.
4. Keep existing `/settings/categories`, `/settings/tags`, and `/settings/recurring` routes intact.

## Next Implementation Order

Recommended order from the current code state:

1. Investments read-only screen
2. Investments holdings snapshot
3. Investments mutations and PnL tab
4. Budget monthly income editing
5. Budget previous-month copy
6. Budget create/edit/delete flows
7. Stats category detail panel
8. Stats yearly screen
9. Settings theme screen
10. Settings data management

Rationale:
- Investments is now the only top-level remaining placeholder and already has strong DAO/logic/test coverage.
- Budget and stats both have read-only bases, so their next steps are incremental enhancements.
- Settings data management has broad invalidation impact and should remain late.

## Verification Strategy

After each small step:
- Run `flutter analyze`.
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
- Refactor transactions/accounts UI while implementing the remaining placeholder.
