# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements`
Phase: `4`

## Scope from plan.md
- Rename the canonical ClickHouse task namespace to `Oli.Clickhouse.Tasks`.
- Add the safe admin operation service, initiation audit trail, capability snapshot, and analytics dashboard controls for migrate up, migrate down, and setup.

## Implementation Blocks
- [x] Core behavior changes
  Renamed the task module to `Oli.Clickhouse.Tasks`, added structured event sinks for shell/UI consumers,
  introduced `Oli.Clickhouse.AdminOperations`, and expanded the admin analytics LiveView to run only the
  safe ClickHouse operations with initiation audit history and page-local progress.
- [x] Data or interface changes
  Reused `Oli.Auditing.LogEvent` for a single ClickHouse admin-operation initiation record and added
  the `:clickhouse_admin_operation_initiated` audit event type plus description. Added `ClickhouseAnalytics.admin_capabilities/0`
  as the explicit capability snapshot for the dashboard.
- [x] Access-control or safety checks
  Kept dangerous `create`, `drop`, and `reset` operations out of the admin UI. The dashboard only starts
  `:setup`, `:migrate_up`, and `:migrate_down`, with `setup` gated by explicit capability checks.
- [x] Observability or operational updates when needed
  Added telemetry events for admin operation start, progress, completion, and failure. Failures are also
  surfaced through `Oli.Utils.Appsignal.capture_error/2`, and task progress is broadcast to the LiveView
  without separate DB-backed operation storage; only the initiation event is persisted for audit purposes.

## Test Blocks
- [x] Tests added or updated
  Updated task-module tests for the canonical namespace, added `AdminOperations` initiation-audit and allowlist
  tests, and expanded the analytics LiveView tests for setup visibility, dangerous-operation absence, and
  page-local progress rendering.
- [x] Required verification commands run
- [x] Results captured
  `mix format lib/oli/clickhouse/admin_operations.ex lib/oli/clickhouse/tasks.ex lib/oli/auditing/log_event.ex lib/oli/analytics/clickhouse_analytics.ex lib/oli_web/live/admin/clickhouse_analytics_view.ex lib/mix/tasks/clickhouse_migrate.ex test/oli/clickhouse/tasks_test.exs test/oli/clickhouse/admin_operations_test.exs test/oli_web/live/admin/clickhouse_analytics_view_test.exs`
  `mix test test/oli/analytics/clickhouse_analytics_test.exs test/oli/clickhouse test/oli_web/live/admin/clickhouse_analytics_view_test.exs`
  `mix test test/oli/clickhouse/tasks_test.exs test/oli/clickhouse/admin_operations_test.exs test/oli_web/live/admin/clickhouse_analytics_view_test.exs`
  `mix test test/oli_web/live/admin`
  `mix test test/oli/analytics/backfill test/oli/analytics test/oli/clickhouse test/oli_web/live/admin`
  `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action verify_plan`
  `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action master_validate --stage plan_present`
  `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --check all`
  All commands passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed
  Updated the Phase 4 checklist in `plan.md` to reflect completion. Added runbook notes that the admin
  ClickHouse surface exposes only migrate up, migrate down, and initialize database, while dangerous
  operations remain shell-only and only initiation is persisted in the audit log. No new open questions were introduced.

## Review Loop
- Round 1 findings:
  `lib/oli/clickhouse/tasks.ex`: the initial refactor dropped `Application.ensure_all_started(:httpoison)`
  from `load_app/0`, which could break release-task execution paths that depend on HTTPoison outside the
  normal app boot flow.
- Round 1 fixes:
  Restored `Application.ensure_all_started(:httpoison)` in `load_app/0` and reran the targeted ClickHouse
  and LiveView suites.
- Round 2 findings (optional):
  No additional findings after restoring the HTTPoison startup guard.
- Round 2 fixes (optional):
  N/A

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
