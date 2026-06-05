# MVP CHECKLIST

Last audit: 2026-06-03

Scope:
- transactions
- accounts
- budget
- stats
- investments
- settings

Classification:
- `DONE`: usable MVP surface with the expected primary create/read/update/delete flow or completed scope.
- `READ_ONLY`: route renders real data but intentionally has no mutation UI yet.
- `CRUD_INCOMPLETE`: route has some mutation UI, but important MVP CRUD or connected workflows are missing.
- `NOT_IMPLEMENTED`: no real routed screen yet.
- `TECH_DEBT`: cleanup, tests, UX hardening, or deferred integration work.

## Route Audit

Source of truth:
- `lib/router/app_router.dart`

Active routes checked:
- `/transactions`
- `/budget`
- `/stats`
- `/accounts`
- `/accounts/:id`
- `/investments`
- `/settings`
- `/settings/categories`
- `/settings/tags`
- `/settings/recurring`

Result:
- All active routes point to concrete screens.
- A temporary route smoke widget test was run and all active routes rendered without exceptions.
- `PlaceholderScaffold` remains as an unused file at `lib/shell/placeholder_scaffold.dart`.
- No active import or route currently uses `PlaceholderScaffold`.

Not routed yet:
- None in the current MVP route set.

## Screen Status

| Area | Route(s) | Status | Input? | Notes |
| --- | --- | --- | --- | --- |
| transactions | `/transactions` | DONE | Yes | Inline entry, edit dialog, duplicate, delete, filters, month nav. |
| accounts | `/accounts`, `/accounts/:id` | DONE | Yes | Account create/edit/archive/restore/delete, reorder, detail transaction list, adjustment edit. |
| budget | `/budget` | CRUD_INCOMPLETE | Partial | Expected income editing, previous-month copy, fixed/percentage/account-linked group creation, fixed/percentage editing with category add/remove, account-linked account editing, and row delete. |
| stats | `/stats`, `/stats/yearly` | READ_ONLY | No | Monthly category breakdown, 12-month trend table, and yearly income/expense/net plus category annual expense totals. |
| investments | `/investments` | CRUD_INCOMPLETE | Partial | Monthly rows, summary, account banner, holdings snapshot with inline SELL/DIVIDEND entry, realized PnL read-only section, BUY creation, edit/delete. |
| settings | `/settings`, `/settings/theme`, `/settings/data` | CRUD_INCOMPLETE | Partial | Main settings cards exist. Categories/tags/recurring have CRUD; theme settings and data backup/restore have first-pass screens. |

## Detailed TODO

### transactions

Status:
- `DONE`

Currently input-capable:
- Create transaction from inline entry.
- Edit transaction from list row.
- Duplicate transaction.
- Delete transaction.
- Filter/search transaction list.

TODO:
- Add broader widget coverage around transfer/adjustment/tag edge cases.
- Review text encoding artifacts in labels/comments as `TECH_DEBT`.

### accounts

Status:
- `DONE`

Currently input-capable:
- Create/edit/archive account.
- Restore/delete archived account.
- Reorder accounts.
- Open account detail.
- Edit/delete adjustment rows from account detail.

TODO:
- Add widget coverage for archive/restore/delete guard behavior.
- Confirm investment virtual rows in account detail remain clear after investments mutations are added.
- Review text encoding artifacts in labels/comments as `TECH_DEBT`.

### budget

Status:
- `CRUD_INCOMPLETE`

Currently input-capable:
- Edit monthly expected income.
- Create fixed category-based budget groups.
- Create percentage category-based budget groups.
- Create account-linked budget groups within the existing DAO/schema.
- Edit existing fixed budget group amount.
- Edit existing percentage budget group percentage.
- Edit existing category-based group adjustment.
- Edit existing category-based group carry-forward.
- Edit linked expense categories for existing fixed/percentage category-based groups.
- Edit linked account for existing account-linked budget groups with calculation preview.
- Delete existing budget groups.
- Copy previous month budget groups into the selected month.
- Month navigation.

TODO:
- Keep invalidating `budgetRowsProvider`, `monthlyExpectedIncomeProvider`, and `overBudgetCountProvider` after budget mutations.
- Add focused widget tests for budget rendering and mutations.

### stats

Status:
- `READ_ONLY`

Currently input-capable:
- None, except month/year navigation.

TODO:
- Add selected category detail panel.
- Consider `fl_chart` visuals after table/list data surface is stable.
- Add focused widget tests for `/stats` and `/stats/yearly`.

### investments

Status:
- `CRUD_INCOMPLETE`

Currently input-capable:
- Create BUY investment transaction.
- Create SELL investment transaction from an expanded holding row with automatic ticker and held quantity validation.
- Create DIVIDEND investment transaction from an expanded holding row with automatic ticker selection.
- Edit BUY/SELL/DIVIDEND investment transactions from monthly rows.
- Delete investment transactions from monthly rows after confirmation.
- Quantity precision policy is active for BUY/SELL:
  - quantity is rounded to 4 decimal places before storage/calculation
  - holdings, average cost, realized PnL, and account virtual rows display quantity with 4 decimal places
- Month navigation.

TODO:
- Consider a dedicated PnL tab only if the read-only monthly section becomes too dense.
- Confirm account balance/account detail providers refresh after investment mutations.
- Add focused widget tests for read-only rendering, mutations, and realized PnL.

### settings

Status:
- `CRUD_INCOMPLETE`

Currently input-capable:
- Categories CRUD/reorder/archive/delete/restore.
- Tags CRUD/delete.
- Recurring transactions CRUD/toggle/delete.
- Change theme mode between system/light/dark.
- Change persisted theme color tokens.
- Export all app data to a JSON backup file.
- Import a validated JSON backup file with full replacement after confirmation.

TODO:
- Add reset UI only if the destructive flow gets separate UX and tests.
- Add focused widget coverage for theme settings.
- Add focused widget/integration coverage for data export/import UI.
- Keep settings subroutes stable while extending main settings.
- Add settings smoke/widget tests.

## Technical Debt

Status:
- `TECH_DEBT`

Items:
- `lib/shell/placeholder_scaffold.dart` is unused and can be deleted after one more route/import audit.
- Several existing Korean strings/comments appear mojibake-encoded in source files; fix as a separate text cleanup pass to avoid mixing with feature work.
- Add permanent route smoke tests for all active routes.
- Expand widget tests for the new read-only budget/stats/investments screens.
- Keep DB schema unchanged until a specific DAO/schema gap is proven.

## MVP Recommendation

Shortest path to a usable MVP:
1. Add optional settings reset UI only after invalidation is explicit and tested.
