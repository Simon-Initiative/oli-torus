# ClickHouse Bulk Backfill Improvements - Product Requirements Document

## 1. Overview

Improve the ClickHouse bulk backfill admin experience so administrators can operate backfills and ClickHouse maintenance tasks with accurate state, safe controls, resilient batch execution, and near-real-time progress visibility. This epic covers admin-facing workflow fixes for run lifecycle controls, per-batch retry behavior, status and metric correctness, an up-front design audit of the backfill architecture and job orchestration, a namespace cleanup for ClickHouse task modules, and a constrained ClickHouse analytics dashboard for safe database operations.

## 2. Background & Problem Statement

The current backfill admin surface has several reliability and UX gaps that make operational work harder than it should be. Run-level controls can present invalid actions after cancellation, pause and cancel actions do not clearly reflect in-progress state, batch retries can redo already completed work inside a batch, and one failed batch can interrupt unrelated work. The UI can also show stale or misleading batch states, such as `Queued` while progress is visibly advancing, which reduces operator trust. Metrics for in-progress runs are not sufficiently current to support active monitoring. The broader bulk backfill design and job orchestration also need an explicit reliability audit so the feature can become repeatable, observable, and tunable without growing into an overly complex admin surface. Separately, the ClickHouse analytics dashboard needs a safer operational boundary: initialization should be available only when the instance is reachable but the database has not yet been set up, while more dangerous create, drop, and reset operations should remain available only through IEx shell and Mix tasks. The current `Oli.ClickHouse.Tasks` naming is also inconsistent with the desired module namespace, which forces avoidable ambiguity in code and docs.

## 3. Goals & Non-Goals

### Goals

- Make backfill run actions reflect the true lifecycle rules for paused, cancelled, completed, and in-progress runs.
- Ensure pause and cancel actions resolve to the correct next available settled controls after each request completes.
- Make batch retries resume from the failed chunk rather than replaying already completed chunk work.
- Prevent one failed batch from blocking unrelated current or future batch processing within the same run.
- Keep batch and run statuses accurate enough that the UI always reflects the real execution state operators need to act on.
- Improve in-progress metric freshness so operators can monitor row accumulation and partial completion before a run finishes.
- Perform an up-front design audit of bulk backfill execution and orchestration and capture concrete recommendations for reliability, repeatability, observability, and admin-tunable controls.
- Keep the admin dashboard minimal while still exposing the tunable controls operators need to manage backfill execution safely.
- Add guarded ClickHouse database task controls to the analytics dashboard for initialization and migration workflows, while keeping dangerous create, drop, and reset operations out of the UI.
- Surface detailed operation logs and error messages in the UI for backfill-control and ClickHouse task execution.
- Rename `Oli.ClickHouse.Tasks` to `Oli.Clickhouse.Tasks` and update relevant documentation to match the canonical module name.

### Non-Goals

- Redesign the full analytics or admin information architecture outside the affected backfill and ClickHouse operations surfaces.
- Introduce self-service ClickHouse operations for non-admin roles.
- Change the underlying ClickHouse schema design beyond what is required to support accurate status and metric reporting.
- Replace existing operational tooling that remains necessary for infrastructure-level tasks outside the scope of the exposed dashboard actions.
- Expand the admin surface into a broad operational console beyond the minimal controls justified by the design audit.
- Expose create, drop, or reset database actions in the admin UI.

## 4. Users & Use Cases

- System administrators: need to pause, cancel, inspect, retry, delete, and clean up backfill runs without ambiguous or unsafe UI states.
- Platform operators: need accurate live batch and run status so they can distinguish queued, active, paused, cancelled, failed, and completed work.
- Engineers supporting analytics operations: need batch failure isolation and chunk-level retry semantics so partial work is not needlessly repeated.
- Administrators managing ClickHouse: need to initialize an uninitialized ClickHouse database and run supported migrations from the admin UI with clear execution feedback, while retaining create, drop, and reset workflows in shell and Mix tooling.

## 5. UX / UI Requirements

- The run detail UI shall only show `Resume` when the run is in a paused state.
- The run detail UI shall never show `Resume` for a cancelled run; cancellation is terminal.
- A paused run shall show `Resume` and `Cancel` after the pause action completes.
- A completed run shall show `Delete Run` as the terminal cleanup action.
- A cancelled run shall show `Delete Run` after the cancellation request completes.
- When both `Pause` and `Cancel` are visible, `Pause` shall use a neutral gray treatment and `Cancel` shall use the warning treatment.
- Batch status labels, badges, and progress indicators shall update from authoritative run state and must not show stale values that conflict with visible progress.
- The ClickHouse analytics dashboard shall expose available ClickHouse database tasks with clear labeling for migrate up, migrate down, and initialize database.
- The initialize database action shall only be enabled when the ClickHouse instance is reachable and the database has not yet been set up or initialized.
- The admin UI shall show detailed progress, success, and error messaging for supported ClickHouse database tasks while the operation is running and after it completes.
- The admin experience shall reflect a minimal control model, where tunable settings exposed to administrators are limited to those justified by the design audit and necessary for safe backfill operation.

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: Run and batch state transitions must be durable and deterministic so refreshes, polling, or reconnects do not surface contradictory action availability.
- Correctness: Retry behavior must avoid reprocessing already completed chunks within a batch unless an operator explicitly restarts the batch from scratch through a separate workflow.
- Observability: The system must expose enough status and metric detail to explain active progress, stalled work, partial completion, and terminal outcomes.
- Performance: Status and metrics refresh behavior must remain responsive for active runs without introducing excessive polling load or blocking the processing pipeline, with chunk-level and LiveView-based UI updates as the preferred freshness model.
- Security: ClickHouse database task controls must remain limited to authorized admin users, and dangerous create, drop, and reset operations must remain outside the admin UI.
- Accessibility: Disabled states, warning actions, status changes, and destructive confirmation flows must remain keyboard accessible and screen-reader understandable.
- Maintainability: The canonical task-module namespace and all affected documentation must be internally consistent so future implementation and operations work does not rely on mixed `ClickHouse` and `Clickhouse` naming.

## 9. Data, Interfaces & Dependencies

- Backfill run and batch persistence must store enough execution state to distinguish paused, cancelled, completed, failed, active, queued, and per-chunk retry positions where applicable.
- Batch processing interfaces must preserve chunk-level progress markers so retries can resume at the failed chunk boundary instead of replaying earlier chunks.
- Run metrics data must support incremental updates for in-progress runs, including rows inserted and batch counts, even when the full run has not yet completed.
- The admin UI depends on a status propagation path that keeps LiveView and any backing jobs synchronized from the authoritative backfill execution state.
- ClickHouse task controls depend on existing backend operations for migration and initialization, or on new admin-safe wrappers around those operations.
- Dangerous create, drop, and reset operations depend on shell and Mix task entrypoints rather than admin UI exposure.
- The admin UI depends on an operation-status and message stream that can deliver detailed log and error output to LiveView while long-running tasks execute.
- The design audit depends on current backfill orchestration, state persistence, retry, batching, and observability paths being documented or inspectable enough to support concrete recommendations.
- Module and documentation updates depend on identifying all references to `Oli.ClickHouse.Tasks` across code, docs, and operational guidance.

## 10. Repository & Platform Considerations

- This work spans Phoenix backend state management under `lib/oli/analytics` and admin UI behavior in `lib/oli_web/` and any associated frontend components.
- Domain rules for run lifecycle, retry semantics, and metrics calculation should live in backend analytics contexts rather than only in UI rendering logic.
- Admin UI orchestration should use LiveView tests for action availability, disabled states, status rendering, and destructive confirmation workflows.
- Batch execution resilience and metrics correctness should be covered with targeted ExUnit tests around analytics job orchestration and persistence updates.
- ClickHouse operational controls should align with existing runtime and deployment practices documented in `docs/OPERATIONS.md` and avoid bypassing authorization boundaries.
- The initial design audit should result in a durable design artifact or equivalent captured guidance before implementation broadens the admin control surface further.
- Namespace cleanup for the tasks module should be reflected consistently in product, engineering, and operations documentation.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Emit telemetry or structured logs for run-level actions requested, action completion, and action failure for pause, resume, cancel, delete, initialize, and migrate operations.
- Emit telemetry or structured logs for batch chunk retry resume position, batch failures, and batch completion so operators can understand whether retries resume from the correct point.
- Emit telemetry or structured logs for initialize and migrate task progress and terminal outcomes so the UI can present detailed operator-facing messages.
- The design audit should produce a concrete recommendation set for which controls are tunable, what observability is required, and how orchestration failures are surfaced.
- Success signals:
  - cancelled runs no longer surface `Resume`
  - paused runs consistently surface `Resume` and `Cancel` after pause completion
  - pause and cancel requests resolve to the correct next settled control set
  - failed batches no longer prevent unrelated batches from continuing
  - batch status labels remain aligned with observable progress
  - in-progress run metrics reflect accumulating inserted-row counts closely enough for active operational monitoring
  - ClickHouse administration tasks exposed in the dashboard remain intentionally limited to safe operations
  - operators can see detailed progress, success, and failure messages for long-running backfill and ClickHouse operations in the UI
  - a design audit is completed before implementation decisions are finalized for orchestration and admin controls
  - the canonical task module name is consistent across code and documentation

## 13. Risks & Mitigations

- Lifecycle rules may already be encoded in multiple layers, which can create divergent UI behavior: centralize action availability around authoritative backend states and test each settled state transition.
- Chunk-level retry may expose hidden assumptions about idempotency or chunk ordering: require explicit persisted retry checkpoints and targeted failure-path coverage.
- More frequent metric updates can increase load on the admin surface or job coordination paths: define bounded refresh behavior and update only the metrics needed for operator decisions.
- Exposing overly powerful ClickHouse operations in-product increases operator risk: keep create, drop, and reset out of the UI and rely on shell and Mix entrypoints for those workflows.
- Batch isolation changes may affect current scheduling assumptions: verify that failed-batch handling does not leak resources or starve queued work.
- Detailed operator logs could become noisy or expose low-signal internal failures: define a UI-safe message contract that is informative, bounded, and mapped to terminal outcomes.
- A design audit that stays too abstract will not improve implementation quality: require concrete recommendations tied to orchestration behavior, observability gaps, and justified admin controls.
- Namespace renames can leave partial references behind: require a comprehensive reference sweep across code and documentation.

## 14. Open Questions & Assumptions

### Open Questions

- N/A

### Assumptions

- Cancellation is a permanent terminal state and must not support resume.
- Pause is a reversible operator action and remains the only state that should surface `Resume`.
- The system can persist or derive chunk-level batch progress markers needed for retry-at-failure semantics.
- It is desirable, not merely acceptable, for unrelated batches to continue processing when another batch fails.
- Near-real-time metric and status updates should use chunk-level progress propagation and LiveView-based UI updates rather than coarse polling alone.
- ClickHouse database tasks exposed in the UI will be limited to authorized administrative contexts already present in Torus.
- The UI should show detailed log and error messages for supported database tasks so operators can see what is happening and whether the operation succeeded or failed.
- The admin UI should expose only initialize and migration tasks, while create, drop, and reset remain available through IEx shell and Mix tooling.
- `Delete Run` should appear after the cancellation request completes and the run is authoritatively `:cancelled`.
- Batch retry does not need an operator-visible chunk index or offset indicator in the UI.
- The design audit should recommend a minimal set of admin-tunable controls rather than maximizing surface area.
- `Oli.Clickhouse.Tasks` is the desired canonical module namespace and all relevant documentation should align to that spelling.

## 15. QA Plan

- Automated validation:
  - ExUnit tests for run lifecycle transitions, terminal action availability, and correct post-request control availability after pause and cancel.
  - ExUnit tests for chunk-level retry resumption, failed-batch isolation, incremental metric accumulation during active runs, and `Delete Run` availability after cancellation completes.
  - LiveView tests for rendered button availability, disabled states, warning styling, status synchronization, operation-message rendering, and destructive confirmation requirements.
  - Targeted tests for ClickHouse admin task authorization, initialize availability when the instance is reachable but uninitialized, and migration task visibility and outcomes.
  - Coverage that verifies the renamed `Oli.Clickhouse.Tasks` namespace and any affected documentation or developer-facing references are updated consistently.
- Manual validation:
  - Exercise active, paused, cancelled, failed, and completed runs in the admin UI and confirm the action set stays correct after refreshes.
  - Trigger a mid-batch chunk failure and confirm retry resumes at the failed chunk rather than replaying earlier chunks.
  - Confirm a failed batch does not block other batches that are already running or later become eligible to run.
  - Observe an active backfill and confirm status labels and metrics update consistently with actual progress.
  - Exercise ClickHouse initialize and migrate flows and confirm initialize is enabled only when the instance is reachable but uninitialized, and confirm supported tasks provide detailed UI feedback during execution.
  - Review the design audit output and confirm it identifies reliability, repeatability, observability, and admin-control recommendations with enough specificity to guide implementation.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
