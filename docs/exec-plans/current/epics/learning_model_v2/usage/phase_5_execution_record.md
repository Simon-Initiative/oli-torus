# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/learning_model_v2/usage`
Phase: `5 - Migrate Learner, Instructor, Oracle, Snapshot, and Export Consumers`

## Scope from plan.md

- Route learner and instructor proficiency consumers through the Section-selected provider.
- Replace direct oracle formulas with bulk model-aware reads and version numeric payloads.
- Preserve actual numeric LKT-AOA values through snapshot projection and CSV serialization.
- Retain naive labels and compatibility shapes without formulas outside the Naive provider.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Targeted verification:

- `mix compile --warnings-as-errors` — passed.
- `mix test test/oli/instructor_dashboard test/oli_web/live/delivery test/oli/delivery/learning_objectives` — 2 doctests and 1,309 tests, 0 failures, 9 excluded.
- `mix test test/oli/analytics/summary/metrics_v2_test.exs` — 21 tests, 0 failures.
- Combined final focused suite covering Metrics compatibility, provider contracts/scopes, concrete oracles, and summary projection — 79 tests, 0 failures.
- `mix format --check-formatted` — passed (required an unsandboxed rerun because Mix PubSub could not open its local socket in the sandbox).
- `git diff --check` — passed.
- Direct-formula search found no learner or instructor proficiency calculation outside the provider boundary. Remaining hits are descriptive activity first-attempt displays, Insights directives, the Phase 6 scenario proficiency assertion, and result-field names. Authoring Insights remains an intentional descriptive exclusion documented in source.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

No PRD or FDD divergence was found. Phase 5 task and test checkboxes in `plan.md` were completed.

## Review Loop

- Security review: no actionable findings; provider dispatch remains whitelisted and all new reads are parameterized and Section-scoped.
- Elixir review: corrected a class-container compatibility regression by restoring the historical deterministic mode of per-learner labels; added deterministic LKT-AOA tie ordering and regression coverage.
- Performance review: reused supplied page membership across naive learner discovery and estimation for compatibility container reads. Persisted scope reads still resolve membership independently across identity discovery and estimate calls; consolidating those provider operations remains a bounded optimization opportunity, not a correctness blocker.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
