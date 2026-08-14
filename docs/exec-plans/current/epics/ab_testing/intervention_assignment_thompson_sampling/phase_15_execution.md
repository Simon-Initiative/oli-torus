# Phase 15 Execution Record

Work item: `docs/exec-plans/current/epics/ab_testing/intervention_assignment_thompson_sampling`
Phase: `15 - Simplify Authoring and Reporting UI`

## Completed

- [x] Flattened experiment-details draft state, parsing, mappings, policy fields, and interventions to one experiment-owned configuration.
- [x] Removed point add/remove controls, point titles, point-scoped copy, and point identifiers from the details DOM contract.
- [x] Kept assignment policy creation-only and structural configuration read-only after draft.
- [x] Flattened Thompson reporting to one experiment condition table and one policy snapshot.
- [x] Retained the author-facing `Decision Points` label for the project experiment-controlled group-management surface and kept creation/configuration copy consistent.

## Verification

- `mix test test/oli_web/live/workspaces/course_author/experiments_live_test.exs` — 27 tests, 0 failures.
- `mix compile` — passed after the LiveView refactor.
- Semantic fieldsets, labels, keyboard-focusable help controls, modal semantics, responsive grids, and horizontal table overflow were inspected in the rendered LiveView contract. No feature-level Figma source or prepared authenticated browser session existed for visual comparison.

## Review

The repository UI workflow brief was used as the implementation contract. The surface remains feature-local, reuses existing modal/table/form patterns, and introduces no new token, icon, or shared-component variants.

Gate O is complete.
