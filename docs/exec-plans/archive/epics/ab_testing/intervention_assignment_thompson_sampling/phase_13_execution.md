# Phase 13 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `13 - Replace Experiment Persistence with the Singular Schema`

## Scope from plan.md

- Replace the QA-only decision-point PostgreSQL hierarchy with experiment-owned persistence.
- Remove decision-point attribution from the ClickHouse experiment evidence schema.
- Verify forward and rollback schema shape without preserving pre-release experiment rows.
- Keep Alternatives content, revisions, and publications outside the destructive boundary.

## Implementation Blocks

- [x] Core behavior changes (schema-level ownership and changesets)
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (ClickHouse attribution schema)

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Results:

- `mix test test/oli/experiments/persistence_test.exs test/oli/utils/schema_resolver_test.exs test/oli/publishing_test.exs` — 59 tests, 0 failures.
- `MIX_ENV=test mix ecto.rollback --to 20260813175154 --no-compile --no-deps-check` followed by `MIX_ENV=test mix ecto.migrate --no-compile --no-deps-check` — passed; prior constraint names and schema shape restored before successful re-apply.
- ClickHouse Up/Down/Up statements applied against local `oli_analytics_dev.experiment_attributions` — passed; decision-point columns were removed, restored with the prior nullable types, then removed again.
- `mix compile` — passed.
- `git diff --check` — passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Security found missing changeset translation for composite cross-experiment foreign keys; Elixir identified the expected Phase 14 work to migrate PostgreSQL and ClickHouse callers that still reference removed persistence; performance found no actionable issues.
- Round 1 fixes: Registered both composite foreign keys with safe changeset errors and added regression coverage. Moved atomic deployment and complete caller migration explicitly into Phase 14 and Gate N.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes

Gate M is complete. The schema contract, destructive boundary, rollback, analytical schema, and existing Alternatives compatibility are verified. Independent deployment was not a Phase 13 deliverable: Phase 14 now explicitly owns migrating every PostgreSQL and ClickHouse caller and proving that the Phase 13 migrations ship atomically with singular callers at Gate N.
