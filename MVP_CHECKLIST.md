# MVP CHECKLIST

Last audit: 2026-06-06

Scope:
- transactions
- accounts
- budget
- stats
- investments
- settings

Classification:
- `DONE`: usable MVP surface with the expected primary create/read/update/delete flow or completed scope.
- `PARTIAL`: route renders and core workflow works, but a deliberate MVP follow-up remains.
- `TODO`: deferred work that is not required for the current MVP stabilization pass.
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
- `/settings/theme`
- `/settings/backup`

Result:
- All active routes point to concrete screens.
- A permanent route smoke widget test covers the MVP route set.
- `PlaceholderScaffold` has been removed.
- No active import or route currently uses `PlaceholderScaffold`.
- `/settings/data` remains only as a compatibility redirect to `/settings/backup`.

Not routed yet:
- None in the current MVP route set.

## Screen Status

| Area | Route(s) | Status | Input? | Notes |
| --- | --- | --- | --- | --- |
| transactions | `/transactions` | DONE | Yes | Inline entry, edit dialog, duplicate, delete, debounced title/memo search, filters, month nav. |
| accounts | `/accounts`, `/accounts/:id` | DONE | Yes | Account create/edit/archive/restore/delete, reorder, detail transaction list with date/category/tag filters, adjustment edit. |
| budget | `/budget` | DONE | Yes | Expected income editing, previous-month copy, fixed/percentage/account-linked group creation/editing, category add/remove, account-linked account editing, and row delete are implemented. |
| stats | `/stats`, `/stats/yearly` | READ_ONLY | No | Monthly category breakdown with selectable category detail, 12-month trend table, and yearly income/expense/net plus category annual expense totals. |
| investments | `/investments` | PARTIAL | Yes | Monthly rows with side/account/ticker/date filters, summary, account banner, holdings inline SELL/DIVIDEND entry, realized PnL read-only section, BUY creation, edit/delete. Follow-up is UX hardening. |
| settings | `/settings`, `/settings/theme`, `/settings/backup` | PARTIAL | Yes | Main settings cards exist. Categories/tags/recurring have CRUD; theme settings and data backup/restore have first-pass screens. |

## Detailed Status

### transactions

Status:
- `DONE`

Currently input-capable:
- Create transaction from inline entry.
- Edit transaction from list row.
- Duplicate transaction.
- Delete transaction.
- Filter transaction list.
- Debounced search across displayed title context and memo.
- Show search/filter status and separate empty states for no data, no search result, and no filter result.

FOLLOW-UP:
- Add broader widget coverage around transfer/adjustment/tag edge cases.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers debounced transaction search, search status display, and search clearing.

### accounts

Status:
- `DONE`

Currently input-capable:
- Create/edit/archive account.
- Restore/delete archived account.
- Reorder accounts.
- Open account detail.
- Edit/delete adjustment rows from account detail.
- Filter account detail transactions by date, category, and tag.

FOLLOW-UP:
- Confirm investment virtual rows in account detail remain clear as account-detail filters get broader coverage.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers account detail category and tag filtering.
- `test/ui/mvp_stabilization_test.dart` covers account archive confirmation, archived restore, archived delete guard, and investment virtual-row filtering in account detail.

### budget

Status:
- `DONE`

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

TECH_DEBT:
- Keep budget mutation tests focused on provider refresh for `budgetRowsProvider`, `monthlyExpectedIncomeProvider`, and `overBudgetCountProvider`.
- Add deeper widget tests for budget create/copy/edit/delete edge cases when UI flows need more regression coverage.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers budget group list rendering, expected income display, fixed/percentage/account-linked group display, and expected-income mutation refresh.

### stats

Status:
- `READ_ONLY`

Currently input-capable:
- None, except month/year navigation and read-only category selection.

FOLLOW-UP:
- Consider `fl_chart` visuals after table/list data surface is stable.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers monthly category selection, category transaction detail rendering, tag display, and selection clearing.
- `test/ui/mvp_stabilization_test.dart` covers `/stats/yearly` entry rendering, year selector rendering, monthly income/expense/net table, annual category expense totals, and no-data empty states.

### investments

Status:
- `PARTIAL`

Currently input-capable:
- Create BUY investment transaction.
- Create SELL investment transaction from an expanded holding row with automatic ticker and held quantity validation.
- Create DIVIDEND investment transaction from an expanded holding row with automatic ticker selection.
- Edit BUY/SELL/DIVIDEND investment transactions from monthly rows.
- Delete investment transactions from monthly rows after confirmation.
- Filter monthly investment transactions by side, account, ticker, and date range.
- Quantity precision policy is active for BUY/SELL:
  - quantity is rounded to 4 decimal places before storage/calculation
  - holdings, average cost, realized PnL, and account virtual rows display quantity with 4 decimal places
- Month navigation.

FOLLOW-UP:
- Consider a dedicated PnL tab only if the read-only monthly section becomes too dense.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers BUY/SELL/DIVIDEND row rendering, holdings inline expansion, 4-decimal quantity display, realized PnL rendering, and first-pass ticker filter empty state.
- `test/ui/mvp_stabilization_test.dart` covers BUY/SELL/DIVIDEND edit dialog prefills, edit save refresh, delete confirmation, and delete refresh across list/summary/PnL.

### settings

Status:
- `PARTIAL`

Currently input-capable:
- Categories CRUD/reorder/archive/delete/restore.
- Tags CRUD/delete.
- Recurring transactions CRUD/toggle/delete.
- Change theme mode between system/light/dark.
- Change persisted theme color tokens.
- Export all app data to a JSON backup file.
- Import a validated JSON backup file with full replacement after confirmation.

FOLLOW-UP:
- Add reset UI only if the destructive flow gets separate UX and tests.
- Add full export/import integration coverage with file picker abstraction or platform integration harness.
- Keep settings subroutes stable while extending main settings.

Test coverage:
- `test/ui/mvp_stabilization_test.dart` covers `/settings/theme` mode controls, `/settings/backup` export/import buttons, and the destructive import confirmation message.

## Technical Debt

Status:
- `TECH_DEBT`

Items:
- Cross-screen provider invalidation was tightened for transaction, settings, account metadata, and account adjustment mutations.
- Permanent MVP route smoke coverage remains in `test/widget_test.dart`.
- Core MVP screen widget coverage is added in `test/ui/mvp_stabilization_test.dart`.
- Mojibake audit completed for Dart/Markdown files; the previously known UI-facing artifact was corrected.
- Core MVP edge case widget tests now cover account archive/restore/delete guards, investment edit/delete refresh, and `/stats/yearly`.
- Keep DB schema unchanged until a specific DAO/schema gap is proven.

## MVP Recommendation

Shortest path to a usable MVP:
1. Add optional settings reset UI only after invalidation is explicit and tested.
