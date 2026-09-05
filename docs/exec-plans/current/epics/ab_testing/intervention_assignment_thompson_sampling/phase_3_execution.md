# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `3 - Draft Configuration, Validation, and Lifecycle Integrity`

## Scope from plan.md

- Replace the single-decision-point authoring graph with experiment-owned conditions and multiple independently configured decision points.
- Add draft validation, activation integrity, lifecycle immutability, current-binding exclusivity, and explicit dependency reconciliation.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

Implementation exposed a Phase 2 normalization gap: `experiment_conditions.decision_point_id`
and `option_id` remained mandatory even though stable conditions now belong to the experiment and
point-specific option identity belongs in `experiment_decision_point_conditions`. The generated
Phase 3 migration makes those legacy columns nullable without rewriting existing rows and restores
representative mapping values during rollback.

## Review Loop

- Round 1 findings: Missing author authorization on dependency APIs; non-draft graph rewrites; experiment-level policy leakage into per-point assignment/reward; malformed weights; per-resource lock queries; repeated activation queries; incomplete-draft UI incompatibility.
- Round 1 fixes: Centralized collaborator/admin checks, draft-only graph mutation, per-point algorithm/config/counts, structured weight validation, batch sorted locks/conflict reads, batch activation condition/intervention reads, and intentionally incomplete draft saves with strict activation validation.
- Round 2 findings: Dependency reads still used the weaker scope-only check; guardrail counts and snapshot config remained experiment-scoped; mapping weights needed boundary validation; remaining authoring resolver/persistence calls are row-oriented.
- Round 2 fixes: Dependency reads now require author access, guardrail counts and snapshots use decision-point scope, and mapping weights return structured errors. Remaining row-oriented resolver/persistence work is confined to authoring and activation rather than learner delivery hot paths and is recorded as residual risk.

## Verification Evidence

- `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling --check all` - passed before implementation.
- `mix test test/oli/experiments/configuration_test.exs test/oli/experiments/persistence_test.exs` - 12 tests, 0 failures.
- `mix test test/oli/experiments/context_test.exs` - 32 tests, 0 failures.
- `mix ecto.migrate` - forward migration passed.
- `mix ecto.rollback --step 1` - explicit Phase 3 rollback passed.
- `mix ecto.migrate` - Phase 3 migration reapplied successfully.
- `mix format <touched Elixir, test, and migration files>` - passed.
- `mix compile` - passed.
- `git diff --check` - passed.
- `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling --check all` - passed after implementation.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
