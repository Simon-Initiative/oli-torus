# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope`
Phase: `2 - Scope-Aware Assignment Identity And Runtime Concurrency`

## Scope from plan.md

- Implement one assignment-identity contract across single, read-only, and page-batch delivery paths.
- Preserve intervention-scoped behavior while adding canonical section-and-enrollment assignment reuse.
- Prove concurrency convergence, participation isolation, and bounded batch behavior.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Focused verification:

- `mix test test/oli/experiments/runtime_test.exs` - 50 tests, 0 failures.
- `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/context_test.exs test/oli/resources/alternatives` - 88 tests, 0 failures.
- `mix format` - passed.
- `mix compile` - passed.
- `git diff --check` - passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no design divergence)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: batch sticky reuse skipped full option-set validation; single/read reuse could return inactive conditions and added a redundant condition query; conflict and creation telemetry needed explicit assignment-scope evidence.
- Round 1 fixes: applied the same active-condition and mapping validation across all paths, reused already-loaded conditions on hot paths, and added bounded scope metadata plus conflict telemetry.
- Round 2 findings: single-path conflict reload needed the same condition-availability check; the reviewer requested explicit batch conflict signaling.
- Round 2 fixes: validated conflict-reloaded assignments against active/available conditions. Confirmed batch conflicts already carry a non-null selection in the deferred event and emit `[:oli, :experiments, :assignment, :conflict]` after commit.
- Round 3 findings: batch conflict recovery needed current-placement condition validation; simplified lookup EXPLAINs did not prove the actual OR batch join used the partial sticky indexes.
- Round 3 fixes: validated conflict winners against current active conditions; split the OR join into scope-specific partial-index-compatible joins; added EXPLAIN proof for the actual generated batch SQL. Final security, performance, and Elixir reviews reported no remaining findings.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
