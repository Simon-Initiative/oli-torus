# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/lo_analytics/linked_activities`
Phase: `2 - Extract the Shared Activity Detail Lifecycle`

## Scope
- Repointed the Learning Objective linked-activities route to the Phase 1 resolver.
- Added a shared activity insight state projection for initialization, reset, cache, lazy-load checks, expanded rows, and table data.
- Added default and linked column modes to `ActivitiesTableModel`, including accessible expansion attributes.
- Retired the duplicate shallow related-activities renderer behind a compatibility adapter.
- Derived LTI activity state from registered LTI activity types.

## Tests
- Added state, linked/default model, normalization, objective-scope, missing-context, and zero-ratio tests.
- Updated linked route assertions for the expansion-control column and stable row IDs.
- `mix test test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs`: passed, 10 tests.
- Focused component/domain/state suite: passed, 30 tests.
- `mix format` and `git diff --check`: passed.

## Review
The required security, performance, Elixir/Phoenix, UI/accessibility, and requirements review lenses were applied to the changed boundaries. No actionable findings remain. Queries remain parameterized and section-scoped; the known full page-revision load and grouped summary integration are explicitly deferred to Phase 3.

The test environment emits an existing background inventory-recovery sandbox ownership error during startup; it does not fail the suites.

## Done Definition
- [x] Phase tasks complete.
- [x] Default and linked table contracts covered.
- [x] Existing linked route suite passes.
- [x] Formatting and diff checks pass.
- [x] Review completed when enabled.
- [ ] Full work-item implementation is not complete; Phases 3-5 remain.
