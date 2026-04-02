# ClickHouse Bulk Backfill Improvements - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements/prd.md`
- FDD: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements/fdd.md`

## Scope

Deliver the FDD-selected reconciliation-first backfill architecture and the constrained ClickHouse admin operations surface:

- add authoritative run lifecycle reconciliation with explicit `:pausing` and `:cancelling` transitional states
- preserve per-batch progress and chunk logs across retry so retries resume from the failed chunk boundary
- prevent one failed batch from halting unrelated current or future eligible work in the same run
- drive batch status and in-progress metrics from chunk and reconciliation updates so the admin UI reflects authoritative progress
- expose only safe ClickHouse admin operations in the analytics dashboard with durable progress and error feedback
- rename `Oli.ClickHouse.Tasks` to `Oli.Clickhouse.Tasks` across code, Mix entrypoints, tests, and docs
- keep telemetry, performance posture, documentation, and rollout notes aligned with the operational scope defined in the PRD/FDD

## Scope Guardrails

- Backend contexts remain the source of truth for lifecycle, retry, scheduling, metrics, authorization, and capability rules; LiveView only renders and invokes those rules.
- Dangerous ClickHouse operations (`create`, `drop`, `reset`) remain shell-only through Mix or IEx and must not appear in the admin UI.
- The admin surface stays intentionally minimal; new tunables are only introduced where the FDD gives an operational justification.
- PubSub and notifier updates are transport only; Postgres-backed state remains authoritative.
- Feature flags are out of scope unless implementation proves rollout risk materially exceeds the current work-item assumptions.
- Telemetry and AppSignal coverage are required because `harness.yml` marks telemetry adoption as included.

## Clarifications & Default Assumptions

- This FDD is the required design-audit artifact for `FR-008`; no separate audit document is needed before implementation starts.
- `clickhouse_inventory_runs`, `clickhouse_inventory_batches`, and `clickhouse_inventory_chunk_logs` remain the primary orchestration state store.
- Existing admin authz protections for ClickHouse and backfill pages remain the enforcement boundary for UI-exposed operations.
- Capability checks for `setup` may require a dedicated health/capability query if the current health view cannot distinguish reachable-but-uninitialized from initialized.
- Run-scoped operation history persists until explicit cleanup via `Delete Run`; no automatic retention subsystem is added in this work item.
- Jira remains the system of record for execution tracking; implementation should keep the issue updated as each phase gate is completed.

## Requirements Traceability

- Source of truth: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements/requirements.yml`
- Plan verification command:
  - `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action verify_plan`
- Stage gate command:
  - `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action master_validate --stage plan_present`

## Phase 1: Reconciliation Contract and Lifecycle Safety Net

- Goal: Lock the authoritative run-state model and establish regression coverage for lifecycle, retry, and failure-isolation behavior before implementation broadens the admin surface.
- Tasks:
  - [x] Audit current backfill orchestration entrypoints in `Oli.Analytics.Backfill.Inventory` and `Inventory.BatchWorker` to confirm all places where run status, batch status, metrics, and retry state are mutated.
  - [x] Define the canonical run-state transition contract for `:running`, `:pausing`, `:paused`, `:cancelling`, `:cancelled`, `:failed`, and `:completed`, including the exact criteria for settled `Delete Run` availability.
  - [x] Identify all current optimistic or UI-derived lifecycle assumptions in `OliWeb.Admin.ClickhouseBackfillLive` that must be replaced by authoritative state reads.
  - [x] Add or extend baseline ExUnit coverage for pause, resume, cancel, retry, batch failure, and aggregate recomputation behavior so current regressions are explicit before the refactor.
  - [x] Add or extend baseline LiveView coverage for button visibility, disabled-state behavior, warning styling, and stale-status rendering gaps called out in the PRD.
- Testing Tasks:
  - [x] Add targeted tests covering current lifecycle edge cases for `AC-001` through `AC-006`, `AC-009`, `AC-010`, and `AC-015`.
  - [x] Add baseline tests that expose the current incorrect retry-reset behavior and stale metric/status behavior for `AC-007` through `AC-013`.
  - [x] Command(s): `mix test test/oli/analytics/backfill`
  - [x] Command(s): `mix test test/oli_web/live/admin`
- Definition of Done:
  - The authoritative lifecycle contract is explicit and reflected in tests.
  - Regression coverage exists for the known failure modes the remaining phases will fix.
  - Hidden coupling between Inventory, workers, and LiveView action rules is documented by the work item or captured in tests.
- Gate:
  - Gate A: lifecycle and orchestration expectations are explicit and covered before state-model changes begin.
- Dependencies:
  - PRD, FDD, and requirements baseline complete.
- Parallelizable Work:
  - Domain-test expansion and LiveView-test expansion can proceed in parallel once the lifecycle matrix is agreed.

## Phase 2: Backfill Reconciliation, Retry Cursor Preservation, and Failure Isolation

- Goal: Implement the backend orchestration changes that make run state authoritative, preserve retry progress, and keep unrelated work moving after a single batch failure.
- Tasks:
  - [ ] Extend the run status model to include `:pausing` and `:cancelling`, with any required schema, enum, and changeset updates.
  - [ ] Implement `Inventory.reconcile_run/1` and the new `Inventory.ReconcileWorker` so settled run state is derived from batch state plus control intent rather than optimistic mutation.
  - [ ] Update `Inventory.pause_run/1` and `Inventory.cancel_run/1` to enter transitional states, stamp request metadata, apply immediate queued/pending batch state changes, and schedule reconciliation.
  - [ ] Update `BatchWorker` to check pause/cancel intent at chunk boundaries and to stop forcing the parent run directly to `:failed` on single-batch failure.
  - [ ] Change `Inventory.retry_batch/1` so it preserves `processed_objects`, `rows_ingested`, `bytes_ingested`, `chunk_count`, `chunk_sequence`, and prior chunk logs while clearing only retry-safe terminal/error state.
  - [ ] Ensure aggregate recomputation and scheduling continue while eligible work remains after a failed batch.
  - [ ] Emit lifecycle and retry telemetry/logging for transitional states, retry cursor metadata, batch failures, and settled terminal outcomes.
- Testing Tasks:
  - [ ] Add ExUnit coverage for reconciliation-driven state transitions, settled cancellation, delayed `Delete Run`, preserved retry cursors, chunk-log retention, and continued scheduling after single-batch failure.
  - [ ] Add worker-level tests proving pause/cancel intent is respected at chunk boundaries and failed batches do not poison the run while eligible work remains.
  - [ ] Command(s): `mix test test/oli/analytics/backfill`
  - [ ] Command(s): `mix test test/oli/analytics`
- Definition of Done:
  - Run state is derived authoritatively in the backend and includes transitional settlement.
  - Retry no longer replays already successful chunk work.
  - Single-batch failure no longer blocks unrelated current or future eligible batches.
  - Telemetry and structured logs exist for the main orchestration state changes.
- Gate:
  - Gate B: backend reconciliation, retry semantics, and failure isolation are green in targeted domain tests before UI wiring depends on them.
- Dependencies:
  - Phase 1 Gate A.
- Parallelizable Work:
  - Retry-cursor preservation and reconcile-worker implementation can proceed in parallel after the state contract and persistence changes are agreed.

## Phase 3: Live Backfill UI State, Metrics Freshness, and Operator Controls

- Goal: Rewire the admin backfill LiveView to the authoritative lifecycle and progress streams so controls, statuses, and metrics stay consistent during active runs.
- Tasks:
  - [ ] Update `OliWeb.Admin.ClickhouseBackfillLive` to render action availability from settled and transitional run states rather than inferred metadata-only rules.
  - [ ] Keep `Pause` and `Cancel` visible but disabled while pause/cancel is in progress, with the required neutral vs warning styling.
  - [ ] Update run and batch rendering to use authoritative persisted counters and granular notifier/PubSub updates emitted after chunk success and reconciliation.
  - [ ] Ensure batch status labels and progress indicators cannot remain stale as `Queued` or otherwise contradict visible progress.
  - [ ] Gate `Delete Run` on fully settled cancellation or completion semantics defined in the backend.
  - [ ] Surface operator-visible failure/progress messages for run-control actions where the user needs to distinguish requested, in-progress, completed, and failed outcomes.
- Testing Tasks:
  - [ ] Add LiveView tests for cancelled, cancelling, paused, pausing, completed, and active states covering `AC-001` through `AC-006` and `AC-015`.
  - [ ] Add LiveView tests for chunk-driven status and metric updates covering `AC-011`, `AC-012`, and `AC-013`, plus a manual validation note for the partial/freshness representation in `AC-014`.
  - [ ] Command(s): `mix test test/oli_web/live/admin`
- Definition of Done:
  - The admin UI reflects authoritative lifecycle state with no invalid `Resume` or premature `Delete Run` actions.
  - In-progress controls remain visible but disabled while transitions settle.
  - Batch and run progress stays aligned with backend state and emitted progress updates.
- Gate:
  - Gate C: admin backfill UI behavior is aligned with backend lifecycle semantics and targeted LiveView tests are green.
- Dependencies:
  - Phase 2 Gate B.
- Parallelizable Work:
  - Control-state rendering and progress-stream rendering can proceed in parallel once the backend event contract is stable.

## Phase 4: ClickHouse Task Service Rename and Safe Admin Operations Surface

- Goal: Rename the canonical task namespace and add the minimal UI-safe ClickHouse operation service with durable progress history and capability gating.
- Tasks:
  - [ ] Rename `Oli.ClickHouse.Tasks` to `Oli.Clickhouse.Tasks` across runtime code, Mix tasks, tests, and internal references.
  - [ ] Refactor the canonical task service so task functions accept structured event sinks suitable for shell and LiveView consumers.
  - [ ] Implement `Oli.Clickhouse.AdminOperations` for the safe operation subset: `:setup`, `:migrate_up`, and `:migrate_down`.
  - [ ] Add the persisted `clickhouse_admin_operations` model, migration, schema, and bounded event-log persistence needed to survive refreshes and show terminal outcomes.
  - [ ] Implement or finalize the admin capability snapshot that distinguishes reachable, database-exists, initialized, and `setup_enabled` states.
  - [ ] Expand `OliWeb.Admin.ClickHouseAnalyticsView` to render the safe operations, current capability state, durable operation logs, and running-task updates.
  - [ ] Explicitly exclude `create`, `drop`, and `reset` from the admin UI while preserving Mix/IEx workflows for those operations.
  - [ ] Update telemetry/AppSignal instrumentation for admin operation starts, progress events, completions, and failures.
- Testing Tasks:
  - [ ] Add ExUnit tests for task-service rename coverage, admin-operation service allowlist enforcement, operation-log persistence, and capability evaluation.
  - [ ] Add LiveView tests for operation visibility, `setup` enablement rules, durable progress/error rendering, and dangerous-operation absence covering `AC-016` through `AC-021`.
  - [ ] Command(s): `mix test test/oli/clickhouse`
  - [ ] Command(s): `mix test test/oli_web/live/admin`
- Definition of Done:
  - `Oli.Clickhouse.Tasks` is the only canonical namespace in code paths touched by this work.
  - The admin dashboard exposes only the intended safe operations with durable progress and error feedback.
  - `setup` enablement is driven by an explicit capability snapshot, not page-local assumptions.
- Gate:
  - Gate D: safe ClickHouse operations and namespace consistency are verified before documentation and release close-out.
- Dependencies:
  - Phase 1 Gate A for test baseline.
  - Phase 2 Gate B where shared telemetry or PubSub contracts overlap.
- Parallelizable Work:
  - Namespace sweep and admin-operation persistence/service work can proceed in parallel if file ownership stays separated.

## Phase 5: Documentation, Validation, and Release Readiness

- Goal: Close the work item with validated traceability, updated operator/developer docs, and targeted regression coverage across all touched boundaries.
- Tasks:
  - [ ] Update product, engineering, and operations documentation to use `Oli.Clickhouse.Tasks` consistently, including ClickHouse runbooks and any impacted work-item artifacts.
  - [ ] Capture rollout and operator notes for the final control surface, transitional run behavior, metric freshness expectations, and shell-only dangerous operations.
  - [ ] Confirm telemetry and AppSignal coverage are documented where operators or future maintainers need to inspect lifecycle and admin-task behavior.
  - [ ] Update Jira execution notes with phase completion, validation status, and any follow-up items intentionally deferred beyond this work item.
  - [ ] Reconcile the PRD/FDD/plan if implementation detail drift is discovered during execution.
- Testing Tasks:
  - [ ] Run the narrowest impacted backend and LiveView suites across all changed boundaries, broadening only as failures or coupling warrant.
  - [ ] Run the required work-item trace and validation commands for plan presence and plan correctness.
  - [ ] Command(s): `mix test test/oli/analytics/backfill test/oli/analytics test/oli/clickhouse test/oli_web/live/admin`
  - [ ] Command(s): `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action verify_plan`
  - [ ] Command(s): `python3 <skills_root>/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --action master_validate --stage plan_present`
  - [ ] Command(s): `python3 <skills_root>/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements --check plan`
- Definition of Done:
  - Requirements trace and work-item validation pass.
  - Operator and developer docs match the canonical namespace and final UI/shell boundaries.
  - Targeted regression suites covering lifecycle, retry, failure isolation, LiveView controls, and admin operations are green.
- Gate:
  - Gate E: no implementation close-out until validation passes, docs are aligned, and targeted regression coverage is green.
- Dependencies:
  - Phases 2 through 4 complete.
- Parallelizable Work:
  - Documentation updates and validation-command execution can run in parallel with final targeted test stabilization.

## Parallelization Notes

- Phase 1 should stay small and front-loaded; it defines the test and contract safety net the rest of the work depends on.
- Once the lifecycle contract is stable, Phase 2 backend reconciliation work and Phase 4 namespace-sweep groundwork can proceed in parallel because they are largely disjoint.
- Phase 3 should start only after the Phase 2 event and state contracts stabilize; otherwise the LiveView work risks recoding the same lifecycle assumptions twice.
- Phase 4 service and persistence work can be split between task-service/namespace ownership and admin-UI/capability ownership if those write sets remain separate.
- Documentation and Jira tracking should be updated continuously, but final sign-off waits for the Phase 5 validation gate.

## Phase Gate Summary

- Gate A: lifecycle, retry, and UI-control safety-net tests exist and the authoritative state contract is explicit.
- Gate B: backend reconciliation, retry-cursor preservation, and failure isolation are implemented and proven in targeted domain tests.
- Gate C: admin backfill UI reflects authoritative state and near-real-time progress with targeted LiveView coverage.
- Gate D: `Oli.Clickhouse.Tasks` is canonical and the ClickHouse admin page exposes only the safe, capability-gated operations with durable feedback.
- Gate E: trace validation, work-item validation, targeted regression suites, and documentation updates are all complete.
