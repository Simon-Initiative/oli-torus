# ClickHouse PR Review Follow-up Plan

Date: 2026-04-03
Work item: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements`

## Scope

This follow-up addresses concrete PR review findings on the ClickHouse ETL and bulk backfill enhancements branch. The goal is to close correctness, security, performance, accessibility, and compatibility gaps without broadening the feature scope beyond the reviewed diff.

## Review Findings To Resolve

1. `lib/oli/clickhouse/admin_operations.ex`
   - Add a server-side admin authorization check in `start/2`.
   - Add a single-flight guard so destructive/admin operations cannot run concurrently.
   - Replace repeated event list append behavior that causes quadratic growth.

2. `lib/oli_web/live/admin/clickhouse_analytics_view.ex`
   - Stop appending events with `++` on every progress update.
   - Cap retained event history in assigns to bound socket growth.
   - Localize new user-facing copy with gettext helpers.

3. `lib/oli/analytics/backfill/inventory/batch_worker.ex`
   - Remove the extra `Repo.get!` roundtrip from the chunk success hot path.

4. `lib/oli_web/live/admin/clickhouse_backfill_live.ex`
   - Add `aria-expanded` and `aria-controls` for the inline Edit Settings disclosure.

5. `lib/oli/analytics/backfill/worker.ex`
   - Validate and sanitize `target_table` before interpolating it into `OPTIMIZE TABLE`.

6. `lib/oli/analytics/xapi/clickhouse_uploader.ex`
   - Accept both legacy and current verb identifiers during transition.
   - Read both `http://oli.cmu.edu/...` and `https://oli.cmu.edu/...` extension keys.

## Implementation Order

### 1. Admin operation hardening

- Add an explicit `Accounts.is_admin?/1` gate inside `AdminOperations.start/2`.
- Introduce a single-flight guard keyed to ClickHouse admin operations so only one operation runs at a time.
- Switch operation event accumulation to prepend-plus-reverse semantics and cap retained events.
- Add tests for unauthorized access, in-flight rejection, and event ordering.

Why first:
These are the highest-risk findings because they affect privileged behavior and runtime safety.

### 2. LiveView event/state fixes

- Store current-operation events in reverse chronological form internally.
- Cap the in-memory event list before assigning back to the socket.
- Render events in chronological order by reversing only at render time.
- Convert newly introduced dashboard copy to gettext-backed strings.
- Add or update LiveView assertions for user-visible localized strings and event rendering.

Why second:
This closes the paired performance/UI comments against the same feature area and keeps the UI aligned with the admin operation state model.

### 3. Backfill runtime cleanup

- Reuse the loaded `InventoryBatch` struct in `apply_chunk_success/4` instead of re-fetching it.
- Reuse the same target-table validation rule for optimization dispatch and fail safely on invalid values.
- Add targeted tests covering the optimize path and invalid table rejection.

Why third:
These are isolated backend fixes with clear test seams and low merge risk once the admin work is stable.

### 4. Accessibility and xAPI compatibility

- Add disclosure ARIA state and panel wiring for the inline Edit Settings UI.
- Accept both old and new xAPI verb IDs where the branch changed event classification.
- Add fallback reads for both `http` and `https` OLI extension namespaces.
- Expand uploader tests to prove both legacy and canonical payloads still ingest correctly.

Why fourth:
These are localized changes with straightforward tests and no architectural dependencies on earlier steps.

## Verification Plan

- Run `mix format` on all touched Elixir files and tests.
- Run targeted backend tests:
  - `test/oli/clickhouse/admin_operations_test.exs`
  - `test/oli/analytics/backfill/worker_test.exs`
  - `test/oli/analytics/backfill/inventory/batch_worker_test.exs`
  - `test/oli/analytics/xapi/clickhouse_uploader_test.exs`
- Run targeted LiveView tests:
  - `test/oli_web/live/admin/clickhouse_analytics_view_test.exs`
  - `test/oli_web/live/admin/clickhouse_backfill_live_test.exs`

## Non-goals

- No redesign of the ClickHouse admin UI beyond the requested accessibility and localization fixes.
- No expansion of raw event schema beyond compatibility handling already implied by the review comments.
- No broader distributed job orchestration rewrite for admin operations in this follow-up.
