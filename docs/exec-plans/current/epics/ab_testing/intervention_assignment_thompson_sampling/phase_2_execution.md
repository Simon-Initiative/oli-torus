# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `2 - Establish Canonical Strategy and Persistence Foundations`

## Scope from plan.md

- Add backward-compatible persistence for experiment-scoped conditions, mappings, interventions, assessment bindings, intervention assignments, accepted rewards, and decision-point policy configuration.
- Add canonical Alternatives strategy normalization and reversible ClickHouse evidence columns.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Compatibility Note

The migration retains the legacy decision-point condition columns while adding and seeding the canonical mapping table. Existing runtime queries continue to read immutable historical and legacy rows; Phase 3 can move graph writes and reads to the canonical mapping without requiring a feature conversion, content rewrite, or republication. Before/after policy context remains in xAPI JSON and is intentionally not projected into ClickHouse columns pending a demonstrated OLAP query need.

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

## Review Loop

- Round 1 findings: Preserve indexed/unique legacy assignment lookup during the compatibility period; bound normalized scores in changeset and PostgreSQL; reduce ClickHouse schema operations; and clarify cross-scope integrity ownership, duplicate-code migration behavior, and rollback limits after intervention writes.
- Round 1 fixes: Added a partial legacy sticky assignment index alongside intervention uniqueness, added normalized-score constraints and tests, combined ClickHouse column changes, and documented internal changeset APIs. New A/B Test groups write `experiment_controlled`; existing `upgrade_decision_point` groups remain supported and unchanged by generic editing. Cross-scope graph validation remains owned by the Phase 3 `Oli.Experiments` transaction. Duplicate experiment-scoped codes intentionally fail migration rather than silently merging identities. Rollback was verified before intervention-scoped production writes; deployment remains gated.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
