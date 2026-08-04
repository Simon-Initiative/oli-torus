# Phase 4 Execution Record

Work item: `docs/exec-plans/current/features/online-project-fix`
Phase: `4 - Operational Instrumentation and Performance Hardening`

## Scope from plan.md
- Add bounded analysis and repair telemetry/logging without authored content.
- Ensure observability failures cannot change context return values.
- Verify resolver batching/query posture for streamed analysis.
- Keep Phase 4 scoped to backend context instrumentation; do not add route or LiveView behavior.

## Implementation Blocks
- [x] Core behavior changes
  - Added `Oli.Authoring.ProjectRepair.Instrumentation` for bounded public analysis/repair stop telemetry and one completion log per public invocation.
  - Kept instrumentation outside the domain mutation path so analysis and repair return values are computed before best-effort operational recording.
  - Optimized Phase 3 repair cleanup by skipping final full-project analysis when no page update committed; the before-report is reused as the after-report for zero-write lock/stale/fatal failures.
  - Converted acquired locks to a target-keyed map for constant-time refresh lookup and replaced per-target lock acquisition with one conditional batch update using a shared invocation stamp.
- [x] Data or interface changes
  - Added stop telemetry events under `[:oli, :authoring, :project_repair, :analysis, :stop]` and `[:oli, :authoring, :project_repair, :repair, :stop]`.
  - Telemetry measurements include `count` and `duration_ms`; metadata includes bounded project/actor identity after successful preparation, option batch sizes, status, failure category, repair counts, warning/failure counts, and summary counts.
  - Added `:lock_update_failed` as a distinct repair failure reason so database/update errors are not conflated with ordinary lock contention.
- [x] Access-control or safety checks
  - Instrumentation records persisted `prepared.project` and `prepared.actor` only after authorization/project preparation succeeds.
  - Prepare-time failures emit nil project/actor identity so untrusted slugs or hand-built author ids cannot be written to logs or telemetry.
  - The Phase 3 stale-plan hook is now allowed only in `Mix.env() == :test`; it is not documented as a public production option.
- [x] Observability or operational updates when needed
  - Completion logs use the same bounded metadata as telemetry and exclude page content, page titles, activity content, author emails, lock-holder details, and full reports.
  - Telemetry and logging are wrapped in best-effort rescue/catch paths so handler/logger failures cannot alter context results.

## Test Blocks
- [x] Tests added or updated
  - Added operational instrumentation tests for analysis metadata privacy, repair success/stale/lock-conflict/partial/fatal outcomes, and telemetry-handler failure resilience.
  - Existing resolver telemetry test exercises four one-id resolver batches for four unique Basic-page activity ids, proving batching rather than relationship N+1 behavior under `resolution_batch_size: 1`.
  - Existing stream tests run with `stream_max_rows: 1`, exercising multiple cursor fetches without retaining page content in reports.
- [x] Required verification commands run
  - `mix test test/oli/authoring/project_repair_test.exs`
  - `mix format --check-formatted lib/oli/publishing/authoring_resolver.ex lib/oli/authoring/project_repair.ex lib/oli/authoring/project_repair/analysis.ex lib/oli/authoring/project_repair/repair.ex lib/oli/authoring/project_repair/instrumentation.ex lib/oli/authoring/project_repair/repair_failure.ex lib/oli/authoring/project_repair/report.ex lib/oli/authoring/project_repair/repair_result.ex test/oli/authoring/project_repair_test.exs`
  - `mix compile --warnings-as-errors`
- [x] Results captured
  - `project_repair_test.exs`: 30 tests, 0 failures.
  - Format check passed.
  - Compile with warnings as errors passed.
  - AC-007 evidence: the read-only analysis test uses `stream_max_rows: 1` and `resolution_batch_size: 1`; resolver telemetry observes exactly four resolver calls for four unique Basic-page ids, while repeated same-page references and Adaptive-only ids do not create extra resolver calls.
  - AC-025 evidence: telemetry assertions cover required identity, counts, duration, status, failure stage/reason, and privacy exclusions; repair telemetry covers completed, stale, lock conflict, partial, and fatal outcomes; a raising telemetry handler does not change the analysis result.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No PRD/FDD/plan contract change was required for Phase 4. Implementation stayed within Gate D scope.
- [x] Open questions added to docs when needed
  - No new open questions were introduced for Phase 4.

## Review Loop
- Round 1 findings:
  - Requirements: Phase 4 execution record lacked AC-007/AC-025 evidence and Gate D completion details.
  - Security: instrumentation originally used caller-supplied slug/actor values on prepare-time failures.
  - Performance: zero-write failures reran full final analysis; acquired-lock refresh lookup was list-based; lock acquisition was still one update per target.
  - Elixir: a start event was emitted after completion; the stale-plan hook was exposed as a public option; lock update exceptions were normalized as ordinary lock conflicts.
- Round 1 fixes:
  - Completed this Phase 4 execution record with AC-007/AC-025 evidence.
  - Changed instrumentation to use prepared persisted identity only, and nil identity on prepare failures.
  - Skipped final analysis for zero-write outcomes, converted acquired locks to a map, and batched initial lock acquisition with one conditional update.
  - Removed the misleading start event, made the stale-plan hook test-only, and added `:lock_update_failed`.
- Round 2 findings (optional):
  - Not run; Round 1 findings were addressed and verification passed after fixes.
- Round 2 fixes (optional):
  - N/A.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
