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
- `/stats/yearly`
- `/settings/theme`
- Settings data management route, if a separate route is later desired.

## Screen Status

| Area | Route(s) | Status | Input? | Notes |
| --- | --- | --- | --- | --- |
| transactions | `/transactions` | DONE | Yes | Inline entry, edit dialog, duplicate, delete, filters, month nav. |
| accounts | `/accounts`, `/accounts/:id` | DONE | Yes | Account create/edit/archive/restore/delete, reorder, detail transaction list, adjustment edit. |
| budget | `/budget` | CRUD_INCOMPLETE | Partial | Expected income editing, previous-month copy, and existing group amount/adjustment/carry-forward editing. No create/delete yet. |
| stats | `/stats` | READ_ONLY | No | Monthly category breakdown and 12-month trend table. Yearly stats deferred. |
| investments | `/investments` | CRUD_INCOMPLETE | Partial | Monthly rows, summary, account banner, holdings snapshot, BUY creation. SELL/DIVIDEND and PnL deferred. |
| settings | `/settings` | CRUD_INCOMPLETE | Partial | Main settings cards exist. Categories/tags/recurring have CRUD; theme and backup/data management are TODO. |

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
- Edit existing fixed budget group amount.
- Edit existing category-based group adjustment.
- Edit existing category-based group carry-forward.
- Copy previous month budget groups into the selected month.
- Month navigation.

TODO:
- Add create budget group flow:
  - fixed category-based group
  - percentage mode
  - account-linked mode
- Add percentage group editing.
- Add account-linked group editing behavior only where it affects DAO calculations.
- Add row-level delete.
- Add category add/remove for category-based groups.
- Keep invalidating `budgetRowsProvider`, `monthlyExpectedIncomeProvider`, and `overBudgetCountProvider` after budget mutations.
- Add focused widget tests for budget rendering and mutations.

### stats

Status:
- `READ_ONLY`

Currently input-capable:
- None, except month navigation.

TODO:
- Add selected category detail panel.
- Add `/stats/yearly` route.
- Implement yearly stats:
  - available years
  - expense pivot
  - income pivot
  - net table
- Consider `fl_chart` visuals after table/list data surface is stable.
- Add focused widget tests for `/stats` and `/stats/yearly`.

### investments

Status:
- `CRUD_INCOMPLETE`

Currently input-capable:
- Create BUY investment transaction.
- Month navigation.

TODO:
- Add SELL/DIVIDEND creation.
- Add investment edit/delete flow.
- Validate sell/dividend with `checkTradableTicker`.
- Add PnL tab:
  - date range
  - realized PnL rows
  - summary
- Confirm account balance/account detail providers refresh after investment mutations.
- Add focused widget tests for read-only rendering, mutations, and PnL.

### settings

Status:
- `CRUD_INCOMPLETE`

Currently input-capable:
- Categories CRUD/reorder/archive/delete/restore.
- Tags CRUD/delete.
- Recurring transactions CRUD/toggle/delete.

TODO:
- Add `/settings/theme` route and `ThemeScreen`.
- Wire theme UI to existing theme notifier.
- Add data backup/export/import/reset UI.
- Define provider invalidation for import/reset.
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
1. Complete investments SELL/DIVIDEND, edit/delete, and PnL.
2. Complete remaining budget create/delete flows.
3. Add stats yearly route/screen.
4. Add settings theme.
5. Add settings data management only after invalidation is explicit and tested.
