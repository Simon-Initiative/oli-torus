# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_filters`
Phase: `1 - Filter Contract And Server-Side Listing`

## Scope From Lightweight Plan

- Add a filter state shape to `BankSelectionManagerLive`.
- Thread filters through candidate load, refresh, and pagination.
- Reset offset when filters change.
- Keep the current `Showing X of Y questions` behavior, updated for filtered totals.
- Preserve selected candidate when still visible; otherwise select the first visible filtered candidate.
- Add focused tests for filter state transitions and pagination reset.

## Implementation Summary

- Added a server-side candidate filter contract under `InstructorCustomizations.list_bank_selection_candidates/4`.
- Normalized `objective_ids` and `activity_type_ids` from atom-keyed or string-keyed filter maps.
- Composed validated filters into the existing activity-bank realizer logic in `TargetResolver`.
- Kept candidate filtering in the existing query path so totals and paging apply to the full candidate set, not only loaded rows.
- Preserved the unfiltered active-count calculation used by `disable_allowed?` safety checks.
- Added LiveView filter state and a `filter_candidates` event.
- Preserved active filters during load-more and refresh paths.
- Relied on the existing page replacement flow to reset pagination and select the first visible candidate when the prior selection is filtered out.

## Scope Boundaries

- No final toolbar UI was added in this phase.
- No visibility filter, text search, option generation, dropdown UI, or Clear All behavior was added.
- No `MER-5623` bulk-action behavior was introduced or assumed.

## Implementation Blocks

- [x] Core behavior changes: filter contract added for objective and activity type ids.
- [x] Data or interface changes: `list_candidates/5` added under `TargetResolver`; existing `list_candidates/4` remains as the compatibility path.
- [x] Access-control or safety checks: existing LiveView route and event authorization boundaries unchanged.
- [x] Observability or operational updates: not applicable for Phase 1.

## Test Blocks

- [x] Context tests cover activity type filtering before paging.
- [x] Context tests cover invalid filter rejection.
- [x] LiveView tests cover filter event pagination reset and selected preview replacement.
- [x] Existing targeted suites rerun.

## Verification

```bash
mix format lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex test/oli/delivery/instructor_customizations/write_api_test.exs test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- Passed.

```bash
mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- `11 tests, 0 failures`

```bash
mix test test/oli/delivery/instructor_customizations/write_api_test.exs
```

Result:

- `21 tests, 0 failures`

Note:

- A parallel test attempt hit test database setup contention with `duplicate key value violates unique constraint "pg_database_datname_index"` for `oli_test`. The affected context suite passed when rerun by itself.

## Work-Item Sync

- [x] Phase 1 implementation result recorded in this execution record.
- [x] Full PRD/FDD/requirements harness docs intentionally not introduced for this lightweight work item.

## Review Loop

- Round 1 findings: self-review found one defensive struct-update improvement in `TargetResolver.apply_candidate_filters/2`.
- Round 1 fixes: changed filter composition to preserve the parsed `Logic` struct while replacing `conditions`.

## Done Definition

- [x] Phase tasks complete.
- [x] Targeted tests pass.
- [x] Review completed when enabled: self-review only; no formal harness review run for this phase.
- [x] Validation passes: not run; this lightweight work item intentionally does not include the full PRD/FDD/requirements harness document set.
