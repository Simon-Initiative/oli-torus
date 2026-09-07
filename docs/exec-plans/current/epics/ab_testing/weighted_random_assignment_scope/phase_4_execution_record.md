# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/weighted_random_assignment_scope`
Phase: `4 - Authoring And Experiment Details UX`

## Scope from plan.md

- Expose weighted-random assignment scope in experiment creation and draft editing.
- Keep Thompson Sampling intervention-scoped and show saved scope across lifecycle states.
- Provide accessible controls, help, validation feedback, and focused LiveView proof.

## Implementation Blocks

- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (not applicable to this UI phase)

## Test Blocks

- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Focused verification:

- `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs` - 30 tests, 0 failures.
- `mix format lib/oli_web/live/workspaces/course_author/experiments_live.ex lib/oli_web/live/workspaces/course_author/experiment_details_live.ex test/oli_web/live/workspaces/course_author/experiments_live_test.exs` - passed.
- `mix compile` - passed.
- `git diff --check` - passed.

Test startup emitted the pre-existing asynchronous inventory-recovery sandbox log recorded by prior phases; it did not fail the suite and this phase did not modify that subsystem.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged (no product or design divergence; Phase 4 completion state synchronized)
- [x] Open questions added to docs when needed (none)

## Review Loop

- Round 1 findings: UI review found missing inline error association and duplicate announcement, insufficient dark-mode error contrast, and small radio touch targets. Elixir review found that local binary scope validation errors did not update or clear field-level error state. Security and performance reviews reported no findings.
- Round 1 fixes: associated help and error IDs with the fieldset, added `aria-invalid`, removed duplicate alert behavior, added an accessible dark-mode error color, expanded label hit areas, and classified both domain and local scope errors consistently. Added focused invalid-scope accessibility coverage.
- Round 2 findings: UI and Elixir re-reviews reported no remaining concrete findings.
- Round 2 fixes: none required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
