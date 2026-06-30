# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_filters`
Phase: `2 - Primary Visibility Filters`

## Scope From Lightweight Plan

- Add the primary single-select filter UI above the candidate table.
- Default to Show All.
- Show Available excludes removed rows.
- Show Removed excludes available rows.
- Add empty state messaging for no matching questions.
- Add LiveView tests for all three states and mutual exclusivity.

## Implementation Summary

- Added `visibility` to the candidate filter state with values `:all`, `:available`, and `:removed`.
- Added normalization for atom-keyed and string-keyed visibility filters in `InstructorCustomizations`.
- Applied visibility before paging in the existing candidate query path:
  - Show All leaves the candidate query unscoped by exclusion state.
  - Show Available passes removed candidate ids as a blacklist.
  - Show Removed restricts the query to removed candidate ids.
- Added a scoped `TargetResolver.list_candidates/6` entry point so visibility can reuse existing realizer paging and totals.
- Added a local LiveView primary visibility control with `aria-pressed` state.
- Added a candidate-list empty state when the current filter has no matching rows.
- Preserved the Phase 1 `filter_candidates` bridge while making absent filter params preserve current filter state.

## Scope Boundaries

- No search input was added.
- No Learning Objective or Question Type dropdown was added.
- No Clear All behavior was added.
- No `MER-5623` bulk-action behavior was introduced or assumed.

## Implementation Blocks

- [x] Core behavior changes: visibility filtering added server-side before paging.
- [x] Data or interface changes: `visibility` added to the lightweight candidate filter map; existing callers default to Show All.
- [x] Access-control or safety checks: unchanged; visibility filtering uses the existing authorized LiveView/context boundary.
- [x] Observability or operational updates: not applicable for Phase 2.

## Test Blocks

- [x] Context tests cover visibility filtering before paging.
- [x] Context tests cover invalid visibility rejection.
- [x] LiveView tests cover default Show All state, Available, Removed, and mutual exclusivity.
- [x] LiveView tests cover empty state for no removed candidates.

## Verification

```bash
mix format lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex test/oli/delivery/instructor_customizations/write_api_test.exs test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- Passed.

```bash
mix test test/oli/delivery/instructor_customizations/write_api_test.exs
```

Result:

- `22 tests, 0 failures`

Note:

- The context suite emitted the existing inventory recovery ownership log during test shutdown, but all tests passed.

```bash
mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- `13 tests, 0 failures`

## Work-Item Sync

- [x] Phase 2 implementation result recorded in this execution record.
- [x] Full PRD/FDD/requirements harness docs intentionally not introduced for this lightweight work item.

## Review Loop

- Round 1 findings: LiveView test run exposed an Elixir grouping warning because a helper was placed between `handle_event/3` clauses.
- Round 1 fixes: moved the helper below the grouped event clauses and reran targeted tests.

## Done Definition

- [x] Phase tasks complete.
- [x] Targeted tests pass.
- [x] Review completed when enabled: self-review only; no formal harness review run for this phase.
- [x] Validation passes: not run; this lightweight work item intentionally does not include the full PRD/FDD/requirements harness document set.
