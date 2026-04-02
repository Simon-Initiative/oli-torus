# ClickHouse Bulk Backfill Improvements - Functional Design Document

## 1. Executive Summary

This design keeps the current repository boundaries centered on `Oli.Analytics.Backfill.Inventory`, `Oli.Analytics.Backfill.Inventory.BatchWorker`, `OliWeb.Admin.ClickhouseBackfillLive`, and `OliWeb.Admin.ClickHouseAnalyticsView`, but replaces optimistic run-state updates with a simpler authoritative settled-state model. The selected approach keeps only settled run states for pause and cancel, preserves per-batch progress on retry instead of resetting it, prevents a single batch failure from forcing the entire run into `:failed` while other work is still eligible, and pushes chunk-driven aggregate updates back through the existing notifier and chunk-log channels so the admin UI reflects authoritative progress in near real time.

The design also separates safe UI-exposed ClickHouse operations from dangerous shell-only tasks. `Oli.ClickHouse.Tasks` is renamed to `Oli.Clickhouse.Tasks`, refactored into a structured task service with event callbacks, and used in two ways: Mix or IEx continues to expose the full task set including create, drop, and reset, while the admin UI is limited to migrate up, migrate down, and `setup`. To keep operator feedback durable instead of page-local, the design adds a small persisted operation-log model for safe UI-triggered tasks. Run-scoped operation history is retained until `Delete Run` is invoked, making run deletion the explicit cleanup path rather than adding a separate automatic retention mechanism. The up-front audit requirement is satisfied by making this FDD the phase-0 design audit artifact and requiring implementation planning to follow its recommendations rather than expanding the admin surface speculatively.

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001` / `AC-001` / `AC-004`: cancelled runs must not show `Resume`, and `Delete Run` must appear only after cancellation cleanup has fully settled.
  - `FR-001` / `AC-002` / `AC-003`: paused and completed runs must expose only the valid terminal actions for their settled lifecycle state.
  - `FR-002` / `AC-005` / `AC-006`: pause and cancel requests must remain visible but disabled while the underlying transition is still in progress.
  - `FR-003` / `AC-007` / `AC-008`: batch retry must resume from preserved progress and must not duplicate already successful chunks.
  - `FR-004` / `AC-009` / `AC-010`: a failed batch must not block other active or future eligible batches.
  - `FR-005` / `AC-011` / `AC-012` / `AC-013` / `AC-014`: batch status and in-progress metrics must come from authoritative progress updates, with partial values represented honestly.
  - `FR-006` / `AC-015` / `AC-016`: run controls must use the intended warning styling, and supported ClickHouse operations must surface detailed progress and error feedback.
  - `FR-007` / `AC-017` / `AC-018` / `AC-019` / `AC-020` / `AC-021`: the ClickHouse admin page exposes only migrate up, migrate down, and `setup`; `setup` is enabled only when the instance is reachable and uninitialized; create, drop, and reset remain absent from the UI.
  - `FR-008` / `AC-022` / `AC-023`: implementation must begin from an explicit orchestration audit and keep the admin control surface minimal and justified.
  - `FR-009` / `AC-024` / `AC-025`: the canonical module namespace is `Oli.Clickhouse.Tasks`, and code plus docs must be updated consistently.
- Non-functional requirements:
  - Reliability requires settled state ownership in the backend, not inferred button rules in LiveView.
  - Observability requires chunk-level progress, run-level aggregates, operation logs, and clear terminal outcomes.
  - Performance requires event-driven UI refresh from chunk and lifecycle updates, avoiding heavy polling loops.
  - Security requires that dangerous ClickHouse operations stay in Mix or IEx workflows rather than admin UI exposure.
  - Maintainability requires one canonical ClickHouse task namespace and one safe task execution contract.
- Assumptions:
  - Existing `clickhouse_inventory_runs`, `clickhouse_inventory_batches`, and `clickhouse_inventory_chunk_logs` remain the main backfill state store.
  - Existing notifier and PubSub infrastructure is sufficient for live UI updates if aggregate broadcasts become more granular.
  - Ecto enum values are application-managed and can be extended safely for transitional states.
  - Shell and Mix workflows for dangerous operations remain valid operationally after the namespace rename.

## 3. Repository Context Summary

- What we know:
  - `lib/oli/analytics/backfill/inventory.ex` already owns run scheduling, batch scheduling, pause, resume, cancel, retry, aggregate recomputation, and chunk-log broadcast.
  - `lib/oli/analytics/backfill/inventory/batch_worker.ex` already persists `processed_objects`, `rows_ingested`, `bytes_ingested`, `chunk_count`, and `chunk_sequence`, which is enough to resume from prior successful progress if retry stops resetting those fields.
  - The current retry path in `Inventory.retry_batch/1` resets `processed_objects`, `rows_ingested`, `bytes_ingested`, `chunk_count`, and `chunk_sequence` to zero, which forces batch replay and directly conflicts with `AC-007` and `AC-008`.
  - The current batch failure path in `BatchWorker.handle_failure/3` transitions both the batch and the run to `:failed`, which directly conflicts with `AC-009` and `AC-010`.
  - The current pause path transitions a run to `:paused` immediately, even though running batches may still be draining, which explains the stale control-state problem behind `AC-005`, `AC-006`, and `AC-011`.
  - The current ClickHouse analytics admin page is health-only and does not yet include task execution, capability gating, or durable operation logs.
  - `lib/oli/clickhouse/tasks.ex` and `lib/mix/tasks/clickhouse_migrate.ex` already centralize the ClickHouse migration and database tasks, but the module naming is still `Oli.ClickHouse.Tasks`.
  - `docs/runbooks/clickhouse/operations.md` already documents Mix-based schema lifecycle commands and admin pages, so the rename and UI-scope restriction both need documentation updates there.
- Unknowns to confirm:
  - Whether the current health query set already exposes enough information to distinguish “reachable but uninitialized” from “reachable and initialized,” or whether a dedicated admin capability query is needed.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `Oli.Analytics.Backfill.Inventory`:
  - Remains the domain owner for inventory-run orchestration.
  - Keeps aggregate recomputation and lifecycle derivation centralized in the domain context.
  - Owns the rules for when a run is `:running`, `:paused`, `:cancelled`, `:failed`, or `:completed`.
- `Oli.Analytics.Backfill.Inventory.BatchWorker`:
  - Remains the per-batch executor.
  - Stops forcing the parent run to `:failed` on single-batch failure.
  - Emits aggregate progress after every successful chunk and checks direct paused or cancelled batch state at chunk boundaries.
- `OliWeb.Admin.ClickhouseBackfillLive`:
  - Continues to own admin rendering and user actions.
  - Reads action availability from authoritative settled run state, not from `pause_requested` metadata alone.
  - Subscribes to more granular run and batch progress broadcasts so metrics and status labels move with chunk completion.
- `Oli.Clickhouse.Tasks`:
  - Renamed canonical task service replacing `Oli.ClickHouse.Tasks`.
  - Keeps the full operational task set for Mix and IEx workflows.
  - Exposes structured progress events so shell wrappers and the safe admin UI runner can render the same underlying task lifecycle without parsing ad hoc stdout.
- `Oli.Clickhouse.AdminOperations`:
  - New service responsible for safe UI-exposed operations only: `:setup`, `:migrate_up`, and `:migrate_down`.
  - Persists operation status and bounded event logs, publishes updates over PubSub, and delegates execution to `Oli.Clickhouse.Tasks`.
- `OliWeb.Admin.ClickHouseAnalyticsView`:
  - Expands from health-only to health plus safe task execution.
  - Uses a capability snapshot to decide whether `setup` is visible and enabled.
  - Renders recent persisted admin operations and subscribes for live updates while a task is running.

### 4.2 State & Data Flow

- Phase 0 audit lane:
  - This FDD is the audit artifact required by `AC-022` and `AC-023`.
  - Implementation must begin by codifying the selected recommendations here, not by widening the UI control set.
- Pause flow:
  - User clicks pause.
  - LiveView calls `Inventory.pause_run/1`.
  - Run status becomes `:paused`.
  - Pending, queued, and running batches are moved to `:paused` immediately.
  - `Resume` becomes visible after the pause request completes.
- Cancel flow:
  - User clicks cancel.
  - LiveView calls `Inventory.cancel_run/1`.
  - Run status becomes `:cancelled`.
  - Pending, queued, paused, and running batches become `:cancelled` immediately with best-effort Oban cancellation.
  - `Delete Run` becomes available after the cancellation request completes, satisfying `AC-001` and `AC-004`.
- Chunk success flow:
  - `BatchWorker` completes a chunk.
  - Batch counters, `processed_objects`, `rows_ingested`, `bytes_ingested`, `chunk_count`, and `chunk_sequence` are updated in the same persistence step as the chunk log upsert.
  - `Inventory.recompute_run_aggregates/1` recalculates run counters and emits run or batch updates through the notifier.
  - LiveView receives the new aggregate snapshot; the chunk-log channel continues to stream per-chunk details.
- Retry flow:
  - User retries a failed batch.
  - `Inventory.retry_batch/1` clears error state and terminal timestamps but preserves counters and chunk progress.
  - Existing chunk logs are preserved.
  - The batch returns to `:pending`, then is re-enqueued from the preserved `processed_objects` offset.
  - This satisfies `AC-007` and `AC-008` without introducing a separate retry cursor store.
- Batch failure flow:
  - `BatchWorker.handle_failure/3` transitions only the batch to `:failed`.
  - Run aggregates are recomputed.
  - If other pending, queued, or running batches remain, the run stays active and scheduling continues.
  - Only when no more work is eligible and failures remain unresolved does aggregate derivation mark the run `:failed`.
- ClickHouse safe task flow:
  - Admin page loads health plus capability snapshot.
  - User starts migrate up, migrate down, or `setup`.
  - `Oli.Clickhouse.AdminOperations` creates an operation record, streams bounded step events, runs the renamed task service in a supervised async process, and persists completion or failure.
  - LiveView renders live progress and recent operation history from persisted state.
  - Run-scoped operation history is removed when `Delete Run` deletes the associated run.

### 4.3 Lifecycle & Ownership

- Run status ownership:
  - `Inventory` owns all lifecycle transitions.
  - UI never infers action availability from metadata flags alone.
- Batch status ownership:
  - `BatchWorker` owns `:running`, `:completed`, and `:failed` transitions.
  - `Inventory` owns queued, pending, paused, cancelled, and retry transitions.
  - No new batch status is required.
- Progress ownership:
  - Batch counters remain the source of truth for run aggregates.
  - Run aggregates are derived and persisted after each chunk success and each terminal batch transition.
- Operation-log ownership:
  - `Oli.Clickhouse.AdminOperations` owns persisted UI task history.
  - `Oli.Clickhouse.Tasks` owns the task execution semantics and step emission contract.
- Documentation ownership:
  - Product and planning docs update the canonical module name.
  - Runbooks and Mix-task docs update operational references and reinforce that create, drop, and reset remain shell-only.

### 4.4 Alternatives Considered

- Alternative A: Keep current statuses and derive disabled buttons only from metadata flags.
  - Rejected because the current bug pattern comes from optimistic metadata-driven state. It would leave `AC-005`, `AC-006`, `AC-011`, and `AC-012` fragile.
- Alternative B: Introduce new batch statuses like `:pausing`, `:retrying`, and `:cancelling`.
  - Rejected because batch metadata and current status values already capture the needed batch behavior. The true inconsistency is at run-level lifecycle derivation.
- Alternative C: Reset batch progress on retry but add chunk dedupe in ClickHouse.
  - Rejected because it preserves unnecessary work and makes correctness depend on downstream dedupe rather than explicit orchestration.
- Alternative D: Expose create, drop, and reset in the admin UI behind confirmations.
  - Rejected by product scope and security posture. Shell and Mix remain the appropriate boundary for those dangerous operations.
- Selected approach:
  - Keep only settled run statuses and derive them directly from authoritative batch state.
  - Preserve batch progress on retry.
  - Persist safe UI task operations separately from shell-only dangerous operations.
  - Rename and refactor the task module once, then reuse it across UI and Mix wrappers.

## 5. Interfaces

- `Inventory.pause_run/1`:
  - Transition runs directly to `:paused` and pause eligible batches immediately.
- `Inventory.cancel_run/1`:
  - Transition runs directly to `:cancelled` and cancel eligible batches immediately.
- `Inventory.retry_batch/1`:
  - Change contract to preserve `processed_objects`, `rows_ingested`, `bytes_ingested`, `chunk_count`, and `chunk_sequence`.
  - Clear only retryable error and terminal timestamps.
- `Oli.Clickhouse.Tasks`:
  - Canonical task API:
    - `up/1`
    - `down/1`
    - `status/1`
    - `setup/1`
    - `create/2`
    - `drop/1`
    - `reset/1`
  - All functions accept an optional event sink callback so progress can be rendered both in shell and admin UI.
- `Oli.Clickhouse.AdminOperations.start/2`:
  - New safe operation API: accepts `kind` in `[:setup, :migrate_up, :migrate_down]` and the initiating author.
  - Rejects unsupported kinds at the service layer.
- `ClickhouseAnalytics.admin_capabilities/0`:
  - New capability snapshot for the admin page:
    - `reachable`
    - `database_exists`
    - `initialized`
    - `setup_enabled`
    - `allowed_operations`
- PubSub:
  - Existing backfill notifier remains.
  - New topic for admin operation updates keyed by operation id plus a list topic for recent operations.

## 6. Data Model & Storage

- Existing tables updated semantically:
  - `clickhouse_inventory_runs`
    - Continue to persist aggregate counts and timestamps.
    - Metadata continues to store operator timestamps and optional tuning settings already present for run execution.
  - `clickhouse_inventory_batches`
    - No new status required.
    - Metadata stores direct lifecycle timestamps and optional retry metadata like `last_retry_at`.
    - Existing `processed_objects`, `chunk_count`, and `chunk_sequence` become the preserved retry cursor.
  - `clickhouse_inventory_chunk_logs`
    - Preserve logs across retries.
    - Add retry-attempt context in `metrics` rather than deleting historical logs.
- New table:
  - `clickhouse_admin_operations`
    - Fields:
      - `kind` as enum-like string: `setup`, `migrate_up`, `migrate_down`
      - `status`: `running`, `completed`, `failed`
      - `events` as JSON list of bounded `{ts, level, message}` entries
      - `error` as summary string
      - `metadata` for capability snapshot or environment details safe for admins
      - `started_at`, `finished_at`
      - `initiated_by_id`
    - Purpose:
      - survive page refreshes
      - support “while running and after completion” feedback for `AC-016`
      - provide a durable operator trail without turning the page into a full operations console
      - remain eligible for explicit cleanup when `Delete Run` removes the associated run-scoped history
- No caching layer is added for orchestration state; the database remains the source of truth and PubSub is only a transport.

## 7. Consistency & Transactions

- Chunk success transaction:
  - Persist batch progress update.
  - Upsert chunk log.
  - Recompute and persist run aggregates.
  - Emit notifier and PubSub updates after commit.
- Batch failure transaction:
  - Persist batch `:failed`.
  - Recompute run aggregates.
  - Do not mark the run `:failed` unless aggregate derivation determines no more eligible work remains.
- Pause and cancel request transaction:
  - Persist the run’s direct settled status and action timestamp metadata.
  - Apply immediate state changes to eligible batches.
- Retry transaction:
  - Reset only retry-safe fields.
  - Preserve progress counters and logs.
  - Re-enqueue through normal scheduling.
- Admin task operation transaction:
  - Create operation row first.
  - Persist progress-event batches as the task runs.
  - Persist terminal result exactly once.

## 8. Caching Strategy

- N/A.
- The selected design intentionally avoids a cache for run or operation state because correctness and observability matter more than shaving a database read off an admin-only operational surface.

## 9. Performance & Scalability Posture

- Backfill UI updates:
  - Prefer event-driven LiveView updates off chunk completion and lifecycle recomputation instead of coarse polling.
  - Bound chunk-log history loaded initially and paginate older logs through the existing channel.
- Aggregate recomputation:
  - Continue using database-backed aggregate recalculation, but only trigger it at meaningful boundaries: chunk success, batch terminal transition, and run control transition.
  - If recomputation becomes too heavy at scale, the fallback optimization is an incremental aggregate updater inside `Inventory`, not a caching layer.
- Admin task operations:
  - Expected volume is low.
  - Persisted operation logs are bounded to a small recent window and bounded event count per operation.

## 10. Failure Modes & Resilience

- `AC-005` / `AC-006`: pause or cancel requested while a batch is mid-chunk.
  - Mitigation: control actions persist direct batch state changes, and the worker checks authoritative paused or cancelled batch state at chunk boundaries so it stops before starting the next chunk.
- `AC-007` / `AC-008`: retry accidentally replays successful work.
  - Mitigation: preserve `processed_objects` and chunk counters; do not delete prior chunk logs.
- `AC-009` / `AC-010`: one failed batch halts the run.
  - Mitigation: remove run-failure side effect from `BatchWorker.handle_failure/3`; keep scheduling pending work until no eligible batches remain.
- `AC-011` / `AC-012` / `AC-013`: UI shows stale status or metrics.
  - Mitigation: publish aggregate updates after each chunk success and each lifecycle recomputation; use persisted run counters as the UI source of truth.
- `AC-019` / `AC-020`: `setup` button is enabled in the wrong state.
  - Mitigation: capability snapshot computes enablement from an explicit reachability plus initialization check, not from page-local assumptions.
- `AC-016`: long-running task output is lost on refresh.
  - Mitigation: persist safe operation logs in Postgres and stream updates over PubSub.
- `AC-024` / `AC-025`: namespace rename leaves stale references.
  - Mitigation: one explicit code and doc sweep across Mix tasks, tests, PRD/FDD docs, and runbooks.

## 11. Observability

- Backfill telemetry and logs:
  - Emit run lifecycle transitions including `paused`, `cancelled`, `failed`, and `completed`.
  - Emit batch retry events with preserved cursor metadata, not just “retried”.
  - Emit chunk-success updates with rows, bytes, processed object count, chunk ordinal, and retry-attempt number.
- UI transport:
  - Continue using `Inventory.Notifier` for run and batch updates.
  - Continue using `OliWeb.ClickhouseChunkLogsChannel` for per-batch detail.
  - Add PubSub topics for safe ClickHouse admin operation progress.
- AppSignal:
  - Instrument lifecycle recomputation and admin task runner duration and failure counts.
- Audit output:
  - This FDD records the concrete recommendations required by `AC-022` and `AC-023`, so no separate throwaway audit document is needed.

## 12. Security & Privacy

- Dangerous ClickHouse operations remain shell-only:
  - `create`, `drop`, and `reset` stay callable from Mix or IEx through `Oli.Clickhouse.Tasks`, satisfying `AC-021` by omission from the UI.
- Admin authorization:
  - Existing authenticated admin LiveView protections remain in place for backfill and ClickHouse admin pages.
- Log content:
  - Admin task logs must stay operational and configuration-oriented.
  - Do not persist secrets, raw credentials, or full connection strings into operation events.

## 13. Testing Strategy

- ExUnit:
  - `Inventory` tests for direct settled run transitions covering `AC-001` through `AC-006`, `AC-009`, and `AC-010`.
  - Retry tests ensuring preserved `processed_objects`, `chunk_count`, and chunk logs for `AC-007` and `AC-008`.
  - Batch-worker tests ensuring single-batch failure no longer marks the entire run failed while pending work remains for `AC-009` and `AC-010`.
  - Task-module rename and Mix-task tests for `AC-024`.
- LiveView:
  - `clickhouse_backfill_live` tests for terminal and active button states, correct post-request control rendering, and warning styling for `AC-001` through `AC-006` and `AC-015`.
  - `clickhouse_analytics_view` tests for safe operation visibility, `setup` enablement rules, operation-log rendering, and dangerous-operation absence for `AC-016` through `AC-021`.
- Manual:
  - Verify partial metric freshness and honest partial-state rendering for `AC-014`.
  - Verify the audit recommendations in this FDD remain reflected in the implementation plan for `AC-022` and `AC-023`.
  - Verify runbooks and planning docs use `Oli.Clickhouse.Tasks` consistently for `AC-025`.

## 14. Backwards Compatibility

- Existing backfill runs:
  - Existing settled statuses remain valid.
- Existing retry behavior:
  - Behavior changes intentionally from replay-on-retry to resume-on-retry.
  - This is a correctness fix, not a compatibility break.
- Existing shell and Mix workflows:
  - Continue to work after the namespace rename via updated call sites and docs, with `setup` as the canonical operation name in code and UI.
- No new feature flags:
  - This work item keeps rollout straightforward and aligned with the PRD.

## 15. Risks & Mitigations

- Lifecycle derivation could still drift across layers.
  - Mitigation: keep lifecycle derivation centralized in `Inventory.recompute_run_aggregates/1` and remove competing optimistic transitions.
- Persisted admin operation logs grow without bound.
  - Mitigation: bound event count per operation, limit the number of recent operations shown by default, and use `Delete Run` as the explicit cleanup mechanism for run-scoped history.
- Initialize capability detection is ambiguous across environments.
  - Mitigation: implement one explicit capability query contract and test it against reachable initialized, reachable uninitialized, and unreachable states.
- Namespace rename misses indirect references.
  - Mitigation: update code, tests, PRD/FDD docs, and runbooks in the same change set.

## 16. Open Questions & Follow-ups

- `setup` is the canonical safe operation name in code and UI.
- The namespace rename assumes there are no external direct call sites that require a compatibility shim.
- `Delete Run` is the explicit cleanup path for run-scoped admin-visible operation history; this work item does not introduce a separate automatic retention policy for that history.
  Delete Run the explicit cleanup path.

## 17. References

- `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements/prd.md`
- `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements/requirements.yml`
- `lib/oli/analytics/backfill/inventory.ex`
- `lib/oli/analytics/backfill/inventory/batch_worker.ex`
- `lib/oli/analytics/backfill/inventory/orchestrator_worker.ex`
- `lib/oli_web/live/admin/clickhouse_backfill_live.ex`
- `lib/oli_web/live/admin/clickhouse_analytics_view.ex`
- `lib/oli/clickhouse/tasks.ex`
- `lib/mix/tasks/clickhouse_migrate.ex`
- `docs/runbooks/clickhouse/operations.md`
