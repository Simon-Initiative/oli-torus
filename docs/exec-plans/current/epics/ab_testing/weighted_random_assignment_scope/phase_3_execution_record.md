# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope`
Phase: `3 - Placement-Specific Exposure, xAPI, And ClickHouse Contracts`

## Scope from plan.md

- Preserve intervention-specific observation evidence when several placements reuse one canonical assignment.
- Enrich exposure requests with server-resolved placement identity and validate that identity against the assignment's experiment.
- Carry explicit assignment scope through xAPI and ClickHouse without inventing intervention ownership for canonical assignments.
- Prove participant and exposure analytics semantics for AC-007 and AC-012.

## Implementation Blocks

- [x] Core behavior changes
  - Exposure requests and idempotency keys now carry assignment plus page/content-element placement identity.
  - Single and batch evidence paths resolve the encountered intervention from the assignment experiment and placement before attribution.
  - Canonical assignment evidence omits intervention ownership while every exposure carries its resolved intervention ID/key.
- [x] Data or interface changes
  - `RecordExposureRequest` requires `page_resource_id` and `content_element_id`.
  - xAPI schema, Elixir/Python ClickHouse uploaders, backfill SQL, query filters, and fixtures carry `assignment_scope`.
  - `priv/clickhouse/migrations/20260814120000_add_experiment_assignment_scope.sql` adds a reversible low-cardinality scope column with an `intervention` default for older evidence.
- [x] Access-control or safety checks
  - Assignment scope validation remains project/section/enrollment/user scoped before placement lookup.
  - Missing, forged, cross-project, and cross-experiment placements fail closed in single and batch APIs.
  - ClickHouse assignment-scope filters use a closed enum predicate and fail closed for invalid input.
- [x] Observability or operational updates when needed
  - Exposure telemetry includes bounded `assignment_scope` and resolved `intervention_id` metadata.
  - Runtime exposure event maps retain the enriched placement fields used by evidence construction.

## Test Blocks

- [x] Tests added or updated
  - Runtime coverage proves one canonical participant assignment and two placement-specific exposure records with distinct keys and intervention IDs.
  - Single/batch rejection coverage includes missing, forged, cross-project, and cross-experiment placements.
  - xAPI, schema validation, ClickHouse uploader/query/backfill, ETL, and migration contract fixtures cover scope and nullable assignment intervention ownership.
  - Mixed-experiment query-shape coverage proves exact tuple predicates without Cartesian `IN` expansion.
- [x] Required verification commands run
  - `mix test test/oli/experiments test/oli/analytics test/oli/resources/alternatives`
  - `mix format`
  - `mix compile`
  - `git diff --check`
  - Python 3.11 `py_compile` for the ETL source and tests.
  - Isolated local ClickHouse forward/default/rollback exercise.
- [x] Results captured
  - Complete Phase 3 suite: 277 tests, 0 failures, 1 pre-existing exclusion.
  - ClickHouse exercise returned `old-evidence intervention` after the forward migration and zero scope columns after rollback.
  - The full Python test suite could not run because local `pytest`/`pyarrow` dependencies are not installed; source compilation passed and Elixir uploader/backfill contract tests cover the persisted shape.
  - Test startup emitted the pre-existing asynchronous inventory-recovery sandbox log; it did not fail the suite and this phase did not modify that subsystem.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - No product or functional-design semantics changed; `plan.md` completion state and this proof record were synchronized.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop

- Round 1 findings:
  - Security: the new ClickHouse scope filter reached a generic string SQL helper without enforcing the closed enum.
  - Performance: independent intervention identity `IN` lists admitted a Cartesian result superset.
  - Elixir/Ecto: no additional finding.
- Round 1 fixes:
  - Added constant enum clauses with an impossible predicate for invalid scope values and an injection-shaped regression test.
  - Replaced independent `IN` lists with exact indexed tuple predicates, projected four required fields, and added mixed-experiment SQL-shape coverage.
- Round 2 findings (optional):
  - Security, performance, and Elixir/Ecto re-reviews reported no remaining concrete findings.
- Round 2 fixes (optional):
  - None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
