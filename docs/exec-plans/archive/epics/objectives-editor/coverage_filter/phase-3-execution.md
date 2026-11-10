# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/objectives-editor/coverage_filter`
Phase: 3 — Compose Filter State with Search, URL, Sort, and Paging

## Scope from plan.md

- Add the Coverage Issues toolbar control and affected-objective count.
- Compose the filter with MER-5797 search, sort, paging, expansion, URL, and CSV state.
- Filter only the loaded in-memory ObjectiveCoverage projection.

## Implementation Blocks

- [x] Added the tokenized `CoverageIssuesControl` with inactive and pressed states.
- [x] Routed activation through the existing `apply_filter` event and `filter[coverage_issues]` URL value.
- [x] Composed search and issue filtering before the existing table sort and slice operations.
- [x] Preserved manual and search-created expansion ownership from MER-5797.
- [x] Reclassified and rebuilt table state after successful coverage loads and threshold updates.
- [x] Normalized internally retained sort parameters before refresh so asynchronous coverage completion cannot reset `sort_order`.

## Test Blocks

- [x] Component tests cover inactive, active, zero, multi-digit, and click-wiring states.
- [x] LiveView tests cover toggle behavior, search composition, empty states, direct URL loading, descendant issue rollup, and CSV parameters.
- [x] A canonical parameter regression preserves query, sort column/direction, expanded objective/child state, and sidebar state while resetting only offset.
- [x] The same regression proves a filter toggle does not restart ObjectiveCoverage loading.

## Review Loop

- Round 1 findings: The closeout regression found `sort_order=desc` changing to `asc` after asynchronous coverage refresh.
- Round 1 fixes: `refresh_table_state/1` now normalizes retained sort atoms to URL-compatible strings before `handle_params/3` reapplies them.
- Round 2 findings: No remaining URL ownership, query, or expansion-state findings.
- Round 2 fixes: None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed
- [x] Final work-item validation passes

## Decision Log

### 2026-09-08 - Normalize retained sort state during coverage refresh

- Change: Internal refresh parameters stringify `sort_by` and `sort_order` before reuse.
- Reason: `SortableTableModel.update_from_params/2` consumes URL-style string values, while retained patch params may contain atoms.
- Evidence: `lib/oli_web/live/workspaces/course_author/objectives_live.ex` and the canonical parameter regression in `test/oli_web/live/workspaces/course_author/objectives_live_test.exs`.
- Impact: Coverage loading and filter activation preserve the complete MER-5797 table-state contract.
