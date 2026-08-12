# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/experiment_scoped_arms`
Phase: `1 - Confirm Runtime Contracts and Detailed Slice Boundaries`

## Scope from plan.md

- Audit current persistence, attempt lifecycle, content identity, delivery queries, analytics evidence, and compatibility boundaries.
- Produce implementation-ready slice designs and record baseline characterization targets without changing migrations or runtime behavior.

## Implementation Blocks

- [x] Core behavior changes — no runtime behavior change belongs to Phase 1; current contracts and discrepancies are recorded.
- [x] Data or interface changes — later-phase data/API boundaries, indexes, transactions, and rollback order are specified in slice designs.
- [x] Access-control or safety checks — `Scope`, server-derived identity, non-cascading foreign keys, lifecycle locks, and privacy boundaries are specified.
- [x] Observability or operational updates when needed — query budgets, telemetry, durable evidence, and ClickHouse migration placement are specified.

## Confirmed Implementation Facts

- Resource-attempt canonical order is `attempt_number ASC` with defensive `id ASC`; authoritative successful final state is `:evaluated`. Active/submitted earlier attempts block later evaluated attempts.
- Automatic reward handoff is currently activity-attempt based and inside activity rollup transactions; manual grading has no equivalent reward hook. The future seam is one resource-attempt handoff after successful commit.
- Fresh Alternatives insertion creates new nested IDs; reorder and whole-page movement retain them. Basic page duplication retains element IDs but creates a new page resource, which is sufficient to create new compound intervention identities. Only same-page element copy/reinsertion must regenerate the placement ID; blanket content-tree regeneration is neither required nor safe.
- Delivery has no section-level active-experiment relevance gate. Group revisions and render context are batched, but experiment resolution is per distinct group and repeated placements collapse by `alternatives_id`.
- Detailed evidence is attached to host xAPI statements; current assignment runtime JSON is not a durable outbox. The ClickHouse target is the existing `experiment_attributions` table through an additive migration.
- No feature-level Figma exists or is required. Phase 6 will implement a minimal best-effort Torus-native UI, default to LiveView/LiveComponents and Tailwind light/dark patterns, and refine the UX against the running application.

## Test Blocks

- [x] Tests added or updated — Phase 1 identifies the existing characterization suite and exact missing query/identity/attempt cases in the slice designs; it intentionally changes no runtime contract.
- [x] Required verification commands run
- [x] Results captured

Command: `mix test test/oli/experiments/context_test.exs test/oli/experiments/runtime_test.exs test/oli/experiments/persistence_test.exs test/oli/resources/alternatives_test.exs test/oli/delivery/experiments/page_decisions_test.exs test/oli/delivery/experiments/reward_handoff_test.exs test/oli/delivery/attempts/page_lifecycle_test.exs test/oli/editing/container_editor_test.exs test/oli_web/live/workspaces/course_author/experiments_live_test.exs`

Result: 126 tests, 0 failures. A new repeated-placement query characterization was then added and passed separately, bringing the targeted suite to 127 tests on final rerun.

Recorded core baseline for both two and ten repeated placements of one group: 5 SELECTs for inactive/no-match resolution and 14 SELECTs for a first active assignment at either cardinality. The constant count exposes the current incorrect collapse by group ID rather than proving intervention batching.

Existing characterization coverage is anchored in:

- `test/oli/experiments/context_test.exs`
- `test/oli/experiments/runtime_test.exs`
- `test/oli/experiments/persistence_test.exs`
- `test/oli/resources/alternatives_test.exs`
- `test/oli/delivery/experiments/page_decisions_test.exs`
- `test/oli/delivery/experiments/reward_handoff_test.exs`
- `test/oli/delivery/attempts/page_lifecycle_test.exs`
- `test/oli/editing/container_editor_test.exs`
- `test/oli_web/live/workspaces/course_author/experiments_live_test.exs`

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged — product requirements did not change; confirmed discrepancies are captured in detailed designs.
- [x] Open questions added to docs when needed — the UI brief records implementation-time choices and runtime refinement expectations without a Figma dependency.

## Review Loop

- Round 1 findings: Security review required scoped, deny-by-default read authorization and negative tenant/project tests. Performance review required an exact negative relevance-query shape, concrete index order, and a query-growth comparison across placement cardinalities.
- Round 1 fixes: Updated persistence/configuration read authorization and test targets; specified the `experiment_sections`/active-definition `EXISTS` query, composite/partial indexes, positive binding index, and representative-data `EXPLAIN` gate; characterized both two and ten repeated placements.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
