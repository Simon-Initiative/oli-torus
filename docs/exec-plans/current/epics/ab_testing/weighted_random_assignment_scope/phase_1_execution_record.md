# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope`
Phase: `1 - Persisted Scope And Domain Configuration Contract`

## Scope from plan.md

- Establish typed assignment-scope persistence and public experiment contracts.
- Enforce weighted-random-only section-and-enrollment scope and safe lifecycle changes.
- Add reversible PostgreSQL constraints and identity indexes for both assignment shapes.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (not applicable until runtime phases)

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Focused verification:

- `mix test test/oli/experiments/persistence_test.exs test/oli/experiments/context_test.exs test/oli/experiments/configuration_test.exs` - 56 tests, 0 failures.
- `MIX_ENV=test mix ecto.rollback --step 1` - passed for an empty canonical-assignment set.
- `MIX_ENV=test mix ecto.migrate` - passed.
- `mix compile` - passed.
- `mix format` - passed.

Rollback posture: `down/0` deliberately raises when any `section_enrollment` assignment exists. Operators must remove pre-release canonical assignment data or roll forward; rollback never fabricates intervention ownership.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no design divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: assignment-scope update races, assignment/experiment scope mismatch, hot intervention lookup index regression, incomplete context-boundary and AC-013 proof.
- Round 1 fixes: coordinated configuration updates with assignment advisory locks and locked-state revalidation; added a composite experiment/scope foreign key; retained the hot lookup index; expanded authorization, lifecycle, algorithm, assignment-existence, concurrency, and guarded-rollback tests.
- Round 2 findings: locked draft state needed revalidation after acquiring the transaction lock.
- Round 2 fixes: added locked-state validation before either configuration update path writes. Final security, performance, and Elixir re-reviews reported no findings.

Post-review product decision: new weighted-random requests that omit `assignment_scope` now resolve to `section_enrollment`; Thompson Sampling and existing persisted rows remain intervention-scoped.

Default-change review: security, performance, Elixir, and requirements lenses were rerun. An invalid falsey scope fallback was found and fixed by defaulting only when the request value is `nil`; regression coverage now verifies invalid non-nil values are rejected.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
