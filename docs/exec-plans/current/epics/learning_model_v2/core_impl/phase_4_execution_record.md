# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/core_impl`
Phase: `4 - Snapshot Worker And Summary/XAPI Integration`

## Scope from plan.md

- Insert semantic learning-model application into the established evaluated-attempt workflow without
  changing job arguments, summaries, xAPI statements, or naive behavior.
- Add a Summary pipeline overload for a prebuilt `%AttemptGroup{}` or `nil`.
- Refactor `Oli.Delivery.Snapshots.Worker` to load the Section once, build the AttemptGroup once,
  apply the learning model, then run existing summary upserts and xAPI emission.
- Preserve retry safety: an LKT commit followed by downstream summary/xAPI failure must retry as an
  LKT no-op rather than double-applying learner state.
- Audit existing evaluated-attempt producers and avoid producer-specific learning-model loops.

## Implementation Blocks

- [x] Core behavior changes
  - Added `Oli.Analytics.Summary.execute_analytics_pipeline/1` for prebuilt `%AttemptGroup{}` and
    `nil` inputs while retaining the existing three-argument API.
  - Refactored `Oli.Delivery.Snapshots.Worker.perform_now/3` to load the Section once, assemble one
    AttemptGroup, apply `Oli.LearningModel.apply_evaluated_attempts/2`, then run summary upserts and
    xAPI emission from that same AttemptGroup.
  - Preserved empty/no-evaluated behavior: no summary or xAPI bundle is emitted and the job returns
    `:ok`.
  - Added a controlled `{:error, {:section_not_found, section_slug}}` result when the requested
    Section slug cannot be loaded before model dispatch.
  - Added manual-grading snapshot queueing after successful manual scoring so the producer converges
    on the same Snapshot Worker path as server/client evaluation, graded finalization, and
    auto-submit.
  - Extended `test/support/learning_model_lkt_aoa_fixtures.ex` so Worker tests use real
    SectionResource project mapping and xAPI-compatible page/activity attempt scores.
- [x] Data or interface changes
  - No schema migrations were added in Phase 4.
  - Existing Snapshot job arguments, Oban queue, max attempts, bundle ID construction, xAPI category,
    and summary tables remain unchanged.
  - The new Summary overload is additive and delegates to the same resource/response summary upsert
    functions used by the existing API.
- [x] Access-control or safety checks
  - No new route, controller action, client parameter, or user-selectable learning-model setting was
    introduced.
  - Snapshot dispatch uses the loaded persisted Section `learning_model_version`.
  - LKT errors propagate as Worker errors; there is no fallback to the naive path for `:lkt_aoa`
    Sections.
- [x] Observability or operational updates when needed
  - Phase 4 adds no new custom telemetry; Phase 5 owns telemetry/scale hardening.
  - Source comments document why LKT runs before summary writes, why the AttemptGroup is built once,
    and why claim idempotency makes downstream retries safe.

## Test Blocks

- [x] Tests added or updated
  - Extended `test/oli/delivery/snapshots/worker_test.exs` for naive dispatch, LKT-AOA dispatch,
    empty/no-evaluated inputs, one-part and bulk/multi-objective inputs, controlled LKT failure, and
    downstream summary retry idempotency.
  - Updated `test/support/learning_model_lkt_aoa_fixtures.ex` to support Worker/Summary/XAPI
    integration tests.
- [x] Required verification commands run
  - `mix test test/oli/delivery/snapshots/worker_test.exs`
  - `mix test test/oli/delivery/snapshots/worker_test.exs test/oli/analytics/summary test/oli/delivery/attempts`
  - `mix test test/oli_web/live/manual_grading`
  - `mix test test/oli/learning_model`
  - `mix compile --warnings-as-errors`
- [x] Results captured
  - Worker test passed: 8 tests, 0 failures.
  - Requested Phase 4 focused suite passed: 179 tests, 0 failures.
  - Manual-grading focused suite passed: 28 tests, 0 failures.
  - Broader learning-model suite passed after shared fixture updates: 87 tests, 0 failures.
  - `mix compile --warnings-as-errors` passed.
  - One sandboxed `mix test test/oli_web/live/manual_grading` invocation failed before startup
    because Mix could not open its local PubSub TCP socket (`:eperm`); the exact command passed with
    approved escalation.
  - The broader learning-model suite emitted an unrelated existing Inventory recovery sandbox
    ownership log during application startup, but the suite passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - Phase 4 plan tasks are marked complete.
  - `AC-022` now verifies actual Snapshot Worker dispatch, replacing the Phase 3 public-boundary-only
    wording.
  - `AC-023` and `AC-024` proof paths now include Worker and producer artifacts.
  - `AC-024` is marked hybrid because the manual-grading producer convergence is proven by code
    audit plus focused tests, not a direct LiveView event assertion.
  - The plan wording was narrowed from asserting an intercepted xAPI upload bundle to asserting that
    existing xAPI construction/emission path is preserved; test configuration suppresses actual
    upload emission.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop

- Round 1 findings:
  - Security review: clean. Phase 4 adds no new client-controlled model-selection surface, no raw
    SQL with interpolated values, no secret/logging changes, and no learner attempt payload logging.
  - Performance review: clean. The Worker still performs one evaluated-attempt query, one
    AttemptGroup construction, one LKT application call, and existing set-based summary writes; no
    producer-specific loops or per-LO DB loops were introduced.
  - Elixir review: clean after local inspection. The Summary overload is additive, the Worker keeps
    the workflow boundary cohesive, and manual grading delegates snapshot creation to the existing
    `Snapshots` context.
  - Requirements review: one proof-classification issue found. `AC-024` was marked automated even
    though manual-grading convergence is code-audit proof plus focused tests rather than a direct
    LiveView event assertion.
- Round 1 fixes:
  - Changed `AC-024` verification method to hybrid and documented the proof boundary.
- Round 2 findings (optional):
  - Clean after proof-classification fix.
- Round 2 fixes (optional):
  - None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
