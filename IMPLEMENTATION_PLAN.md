# IMPLEMENTATION PLAN

Scope: track the remaining screen implementations against `SPEC.md` and the current Flutter file structure.

Constraints:
- Use `SPEC.md` as the single behavioral source of truth.
- Do not change DB schema or generated Drift files unless a later implementation exposes a proven gap.
- Do not change existing DAO contracts for read-only phases.
- Keep work in small UI/provider increments.
- Preserve existing tests; run `flutter analyze` and `flutter test` after each screen step.

Current phase:
- MVP audit and completion pass.
- `MVP_CHECKLIST.md` is the current status board for `DONE`, `READ_ONLY`, `CRUD_INCOMPLETE`, `NOT_IMPLEMENTED`, and `TECH_DEBT`.
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
- `/accounts` -> `lib/ui/desktop/accounts/accounts_screen.dart`
- `/accounts/:id` -> `lib/ui/desktop/accounts/account_detail_screen.dart`
- `/investments` -> `lib/features/investments/investments_page.dart`
  - `InvestmentsPage` delegates to `lib/ui/desktop/investments/investments_screen.dart`
- `/settings` -> `lib/features/settings/settings_page.dart`
- `/settings/categories` -> `lib/ui/desktop/settings/categories_screen.dart`
- `/settings/tags` -> `lib/ui/desktop/settings/tags_screen.dart`
- `/settings/recurring` -> `lib/ui/desktop/settings/recurring_screen.dart`

No active route currently points to `lib/ui/desktop/settings/settings_screen.dart`.

Placeholder audit:
- `PlaceholderScaffold` is still present as `lib/shell/placeholder_scaffold.dart`.
- No active route or feature page imports `PlaceholderScaffold`.
- A temporary route smoke widget test was run for all active routes and passed, then removed.

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
  - existing fixed-group amount editing
  - existing category-based group adjustment editing
  - existing category-based group carry-forward editing
- Budget providers are implemented:
  - `budgetMonthProvider`
  - `monthlyExpectedIncomeProvider`
  - `budgetRowsProvider`
- `refreshBudget(ref)` invalidates `monthlyExpectedIncomeProvider`, `budgetRowsProvider`, and `overBudgetCountProvider`.
- Budget group delete UI is intentionally left as TODO.
- Budget group create UI is not implemented yet.

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

### Investments Read-Only Screen

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
  - current-month investment transaction list
  - PnL TODO card
- Investment providers are implemented:
  - `investmentMonthProvider`
  - `investmentRowsProvider`
  - `investmentMonthlySummaryProvider`
  - `investmentAccountProvider`
  - `currentHoldingsProvider`
- Buy/sell/dividend input UI is not implemented yet.
- PnL tab is not implemented yet.

## Remaining Placeholder

There are no remaining top-level `PlaceholderScaffold` screens in the current route set.

Note:
- `/stats/yearly` is still not routed or implemented; `/stats` shows a TODO card for it.
- Investments PnL is still represented by a TODO card.

## Investments Remaining Work

Current read-only base is complete.

Next steps:
1. Add create/edit/delete investment rows:
   - buy first
   - sell and dividend with `checkTradableTicker`
2. Add PnL tab:
   - date range
   - realized PnL rows
   - summary
3. Confirm account-related providers refresh after investment mutations.
4. Add focused widget tests.

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

Current read-only base, first edit step, and previous-month copy are complete. Continue only after preserving the existing provider shape and refresh behavior.

Next steps:
1. Add create budget group flow:
   - fixed category-based group
   - percentage mode
   - account-linked mode
2. Add percentage group editing.
3. Add account-linked group editing only where it affects DAO calculations.
4. Add row-level delete.
5. Add category add/remove for category-based groups.
6. Keep invalidating budget rows, expected income, and `overBudgetCountProvider` after mutations.
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

1. Investments mutations and PnL tab
2. Budget create/delete flows
3. Budget percentage/account-linked follow-up editing
5. Stats category detail panel
6. Stats yearly screen
7. Settings theme screen
8. Settings data management

Rationale:
- The top-level placeholder pass is complete.
- Investments, budget, and stats all have read-only bases, so their next steps are incremental enhancements.
- Investments has strong DAO/logic/test coverage and is the most natural next mutation surface.
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
- Refactor transactions/accounts UI while implementing these remaining enhancements.
