# Phase 14 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `14 - Simplify Domain and Runtime Contracts`

## Completed

- [x] Production PostgreSQL and ClickHouse callers use singular experiment ownership.
- [x] Public create/update, assignment, authoring-view, telemetry, xAPI, and analytics contracts are flattened.
- [x] Runtime assignment, policy state, guardrails, rewards, and repeated interventions are experiment-scoped.
- [x] Single and batched assignment paths serialize by experiment; assignment placement identity is required.
- [x] Every experiment update requires authoring authorization.
- [x] Assignment count aggregation has an experiment/condition index.

## Verification

- `mix format` — passed.
- `mix compile` — passed.
- `mix test test/oli/experiments test/oli/delivery/experiments test/oli/analytics/xapi` — 152 tests, 0 failures, 1 excluded.
- `git diff --check` — passed.
- Work-item validation — passed.

## Review

Security and Elixir review blockers were resolved by requiring authoring access for all updates, serializing single assignments with the experiment advisory lock, and rejecting missing placement identity. Performance review resulted in an experiment/condition count index. Additional transaction-query optimizations are non-blocking follow-up opportunities.

## Deferred to Phase 16

Phase 16 already owns obsolete schema/helper/fixture removal and integrated scenario reconciliation. It now also owns representative-data `EXPLAIN (ANALYZE, BUFFERS)` checks, after Phase 15 stabilizes the final authoring/reporting caller set.

Gate N is complete for production domain, runtime, worker, and analytics callers. Remaining decision-point terminology and obsolete fixtures are confined to the Phase 15 UI migration and Phase 16 integrated cleanup; they are not production persistence reads or writes.
