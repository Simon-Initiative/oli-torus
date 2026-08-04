# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_filters`
Phase: `3 - Search`

## Scope From Lightweight Plan

- Add the search input matching the Figma toolbar.
- Search should debounce and update without manual submit.
- Search title and question content where practical from the available data/query layer.
- Preserve search through preview selection, remove/restore, and checkbox interactions.
- Add tests for title/content matching and no manual submit requirement.

## Pre-Work Correction

- A `ui_workflow` run was started by mistake before this phase.
- The partial runtime state created outside the repo under `~/.codex/memories/oli-torus-ng/ui-work/MER-5624/` was removed.
- The partial code patch from that aborted run was reverted before implementing this phase through `harness-work`.

## Implementation Summary

- Added `text_search` to the bank candidate filter contract.
- Normalized search text in `InstructorCustomizations`.
- Composed search into the existing activity-bank realizer logic using the `:text` fact.
- Sanitized free-text search into a simple `to_tsquery` conjunction so ordinary input with spaces/punctuation does not become raw query syntax.
- Added a Figma-aligned search input to the local filter toolbar with:
  - existing `Icons.search`
  - `phx-change="filter_candidates"`
  - `phx-debounce="300"`
  - token-aligned input fill, border, typography, and focus behavior
- Preserved current filter state when search events omit visibility, objective, or activity type params.
- Kept search server-side and before paging so totals and `Load more` stay correct.
- Updated the realizer SQL builder to use the correct parameter index for multiple text expressions in a single logic tree.

## Scope Boundaries

- No Learning Objective dropdown was added.
- No Question Type dropdown was added.
- No Clear All behavior was added.
- No `MER-5623` bulk-action behavior was introduced or assumed.

## Implementation Blocks

- [x] Core behavior changes: dynamic text search added server-side before paging.
- [x] Data or interface changes: `text_search` added to the lightweight candidate filter map.
- [x] Access-control or safety checks: unchanged; search uses the existing authorized LiveView/context boundary.
- [x] Observability or operational updates: not applicable for Phase 3.

## Test Blocks

- [x] Context tests cover text search before paging.
- [x] Context tests cover search combined with visibility filters.
- [x] Context tests cover invalid search filter input.
- [x] LiveView tests cover dynamic `phx-change` search without manual submit.
- [x] LiveView tests cover search preservation after remove.
- [x] Realizer tests cover multiple text expressions using distinct SQL params.

## Verification

```bash
mix format lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex lib/oli/activities/realizer/query/builder.ex lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex test/oli/delivery/instructor_customizations/write_api_test.exs test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs test/oli/activities/realizer/query_execution_test.exs
```

Result:

- Passed.

```bash
mix test test/oli/delivery/instructor_customizations/write_api_test.exs
```

Result:

- `24 tests, 0 failures`

```bash
mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- `14 tests, 0 failures`

```bash
mix test test/oli/activities/realizer/query_execution_test.exs
```

Result:

- `9 tests, 0 failures`

Note:

- The context and LiveView suites emitted the existing inventory recovery ownership log during test shutdown, but all tests passed.

## Work-Item Sync

- [x] Phase 3 implementation result recorded in this execution record.
- [x] Full PRD/FDD/requirements harness docs intentionally not introduced for this lightweight work item.

## Review Loop

- Round 1 findings: the first realizer test used a Postgres full-text stopword and did not exercise the intended query path.
- Round 1 fixes: updated the fixture text to use searchable terms and reran the targeted suite.

## Done Definition

- [x] Phase tasks complete.
- [x] Targeted tests pass.
- [x] Review completed when enabled: self-review only; no formal harness review run for this phase.
- [x] Validation passes: not run; this lightweight work item intentionally does not include the full PRD/FDD/requirements harness document set.
