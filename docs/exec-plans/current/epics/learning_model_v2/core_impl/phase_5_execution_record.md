# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/core_impl`
Phase: `5 - Telemetry, Scale, And Operational Hardening`

## Scope from plan.md

- Emit privacy-bounded LKT-AOA batch telemetry for start, stop, and exception outcomes.
- Prove query count is cardinality-independent for representative 500-GUID batches.
- Prove all-duplicate retries short-circuit after the idempotency claim.
- Exercise higher-contention overlapping state/evidence batches.
- Capture representative query plans and local telemetry/AppSignal verification notes.

## Implementation Blocks

- [x] Core behavior changes
  - Added LKT-AOA telemetry events from `Oli.LearningModel.LktAoa.Application`.
  - Event names:
    - `[:oli, :learning_model, :lkt_aoa, :batch, :start]`
    - `[:oli, :learning_model, :lkt_aoa, :batch, :stop]`
    - `[:oli, :learning_model, :lkt_aoa, :batch, :exception]`
  - Stop metadata includes only model, result, bounded failure category, and aggregate counts.
  - Exception telemetry intentionally excludes exception structs and stacktraces to avoid leaking
    learner data, SQL binds, IDs, parameter payloads, or response content.
  - Added bounded failure categories for invalid input, publication lookup, parameter validation,
    claim, state-lock, state-write, evidence, constraint, deadlock, exception, and unknown failures.
- [x] Data or interface changes
  - No schema migrations were added in Phase 5.
  - Existing public return values are unchanged.
  - Telemetry is additive and does not add a feature flag or runtime dashboard.
- [x] Access-control or safety checks
  - No new client input, route, LiveView event, or authorization boundary was introduced.
  - Telemetry tests assert forbidden metadata keys are absent.
- [x] Observability or operational updates when needed
  - Source comments document the telemetry event privacy contract at the emission boundary.
  - AppSignal/local telemetry verification: the events use normal `:telemetry.execute/3`, so the
    existing telemetry/AppSignal integration can consume duration and count metadata without adding
    a bespoke dashboard. Operators should inspect duration percentiles, result/failure-category
    rates, and aggregate fan-out counts from these event names after deploy.

## Test Blocks

- [x] Tests added or updated
  - Added `test/oli/learning_model/lkt_aoa/telemetry_test.exs`.
  - Added `test/oli/learning_model/lkt_aoa/performance_test.exs`.
  - Extended `test/oli/learning_model/lkt_aoa/concurrency_test.exs`.
- [x] Required verification commands run
  - `mix test test/oli/learning_model/lkt_aoa/performance_test.exs test/oli/learning_model/lkt_aoa/telemetry_test.exs test/oli/learning_model/lkt_aoa/concurrency_test.exs`
  - `mix test test/oli/learning_model/lkt_aoa`
  - `mix test test/oli/learning_model`
  - `mix compile --warnings-as-errors`
  - `mix format --check-formatted`
  - `git diff --check`
- [x] Results captured
  - Focused Phase 5 telemetry/performance/concurrency suite passed: 9 tests, 0 failures.
  - Full LKT-AOA suite passed: 41 tests, 0 failures.
  - Full learning-model suite passed: 94 tests, 0 failures.
  - Warning-free compilation, format check, and whitespace check passed.
  - The 500-GUID performance regression proves the same operational query count as a single-GUID
    batch and enforces six or fewer LKT operational statements.
  - The all-duplicate retry regression proves a 500-GUID retry executes only the claim statement and
    returns `:noop` with zero claimed/contribution counts.
  - The higher-contention concurrency regression applies 10 simultaneous overlapping batches to the
    same learner/LO/evidence key and proves exact final counts: 10 claims, one evidence row, one
    learner state with `attempt_count = 10` and `unique_activity_part_count = 1`.
  - Telemetry tests prove start/stop/exception event names, native duration measurement, success,
    duplicate-noop, validation-error, and exception outcomes, bounded failure categories, and absent
    forbidden metadata.

## Manual Query Plans And Operational Notes

- Claim query:
  - Test DB with empty `part_attempts` naturally chose a zero-cost seq scan.
  - Existing index inspection confirmed `attempt_guid_index` exists:
    `CREATE UNIQUE INDEX attempt_guid_index ON public.part_attempts USING btree (attempt_guid)`.
  - With `enable_seqscan = off` to remove the empty-table planner bias, the representative claim
    plan uses `Index Scan using attempt_guid_index on part_attempts pa` and
    `Conflict Arbiter Indexes: learning_model_attempt_applications_pkey`.
- Publication-pinned objective query:
  - Representative plan uses `Index Only Scan using index_published_resources on
    published_resources` with `publication_id` and `resource_id = ANY(...)`.
- State lock query:
  - Representative plan uses `Function Scan on key` from the bounded `unnest(...)` arrays and
    `Index Scan using learning_states_pkey on learning_states state`.
- Lock and growth observations:
  - The implementation retains one neutral insert, one ordered state lock, one evidence insert, and
    one final state write per batch.
  - No task fan-out, query chunking, historical-attempt scan, or per-LO database loop is introduced.
  - In-memory work grows linearly with claimed contributions and affected learner/LO keys.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - Phase 5 plan tasks are marked complete.
  - `AC-014`, `AC-031`, and `AC-032` are now verified.
  - `AC-013`, `AC-019`, and `AC-020` proof paths now include Phase 5 performance/concurrency
    evidence.
- [x] Open questions added to docs when needed
  - No new open questions were introduced.

## Review Loop

- Round 1 findings:
  - Elixir/requirements review found that controlled validation failures were briefly reported in
    stop telemetry with a `:noop` result, which made error/no-op monitoring ambiguous.
- Round 1 fixes:
  - Updated error stop telemetry to override the synthetic no-op result with `:error`, while
    preserving duplicate retry telemetry as `:noop`.
- Round 2 findings (optional):
  - Security review clean: Phase 5 adds no route, authorization boundary, client input, secret, raw
    SQL interpolation, or identifier-bearing telemetry metadata.
  - Performance review clean: query-count tests, duplicate-retry short-circuiting, manual EXPLAIN
    notes, and code inspection show no per-attempt/per-LO database loop or historical-attempt scan.
  - Elixir review clean: telemetry helpers are bounded, explicit, and covered by focused tests.
  - Requirements review clean: `AC-013`, `AC-014`, `AC-019`, `AC-020`, `AC-031`, and `AC-032` have
    implementation and verification proof.
- Round 2 fixes (optional):
  - No further fixes required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
