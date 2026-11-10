# Phase 4 Execution Record

Work item: `docs/exec-plans/current/features/preview-environment-tooling`
Phase: `4 - Move Bulk Users and Progress Simulation into Oli.Scenarios`

## Scope from plan.md

- Add deterministic `bulk_create_enroll_users` and `simulate_progress` directives to the normal scenario DSL.
- Move reusable enrollment and progress behavior under `Oli.Scenarios` and retire Stagehand.
- Bound validation, concurrency, timeouts, result data, and unsupported-content warnings.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification results:

- Focused parser/schema/directive integration suite — 44 tests, 0 failures after review fixes.
- Progress-simulation and data-generation directive suite — 15 tests, 0 failures, including response generation for multiple choice, ordering, check all that apply, single response, and multi input.
- End-to-end progress-simulation scenario — 1 test, 0 failures, covering bulk enrollment, an ungraded page, a graded page, and evaluated correct attempts for all five supported native activity types.
- `mix test test/scenarios` — 376 tests, 0 failures, 2 excluded.
- `mix compile` — passed.
- `mix format` and `git diff --check` — passed.
- Remaining verification gap: real graded-attempt, unsupported-content, and timeout/failure integration coverage requires a runner outside the existing Ecto sandbox transaction; the corresponding plan item remains unchecked.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no contract divergence; phase tasks marked complete)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: Correctness selection weighted individual answers instead of correct/incorrect buckets; warning variants could grow in the result; schema and parser disagreed on explicit zero role counts.
- Round 1 fixes: Selection now chooses a correctness bucket first and keys deterministic choices by learner; warnings aggregate into bounded categories; schema and parser now share zero-count semantics. Added probability, seed-variation, parity, retry, and collision coverage.
- Round 2 findings (optional): Direct bulk inserts bypassed account invariants, prefixes were unbounded, and evaluation failures were discarded.
- Round 2 fixes (optional): Added a changeset-backed batched account boundary, a shared 40-character prefix limit, set-based enrollment, and evaluation-failure propagation. Final review found no remaining code-path security or batching defects; it retained the explicit integration-test gap above.

## Done Definition

- [ ] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
