# Phase 0 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_filters`
Phase: `0 - Preparation And Branch Reality Check`

## Scope From Lightweight Plan

- Confirm `MER-5623` is not present on this branch.
- Inspect existing manager LiveView tests.
- Identify the current candidate row view model fields available for title, content, objective data, question type, and enabled/removed state.
- Decide whether candidate filtering can be added to the existing `list_bank_selection_candidates/4` path or needs a companion query/view model helper.

## Findings

### `MER-5623` Branch State

`MER-5623` should not be assumed available in this branch.

Observed current branch state:

- `BankSelectionManagerLive` has checkbox UI and events:
  - `toggle_candidate_checkbox`
  - `toggle_all_candidate_checkboxes`
  - `checked_candidate_ids`
- The LiveView comment explicitly says `MER-5623` adds the bulk action side effect later.
- No same-state bulk remove/restore actions for bank-selection candidates were found in this branch.

Implementation implication:

- `MER-5624` should preserve current checkbox state where practical.
- Do not introduce bulk mutation behavior in this ticket.
- Preserve compatibility for future `MER-5623`, but do not depend on unpublished branch behavior.

### Existing Tests

Primary LiveView coverage exists in:

- `test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`

Current coverage includes:

- preview route/helper behavior
- authorized manager render
- removed candidate row styling
- selected preview preservation across load-more
- candidate checkbox/header checkbox behavior
- remove/restore via preview customization bridge
- invalid remove warning modal
- invalid selection redirect
- learner redirect out of preview mode

Relevant context coverage exists in:

- `test/oli/delivery/instructor_customizations/write_api_test.exs`

Current coverage includes:

- `list_bank_selection_candidates/4`
- paging validation
- active count and disable-allowed computation
- resolved section/page/selection target overload
- candidate activity type id listing

Baseline command run:

```bash
mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs
```

Result:

- `10 tests, 0 failures`

### Current Candidate View Model

`Oli.Delivery.InstructorCustomizations.list_bank_selection_candidates/4` currently returns candidate rows shaped as:

- `activity_resource_id`
- `revision_slug`
- `title`
- `enabled?`
- `disable_allowed?`

The underlying query result rows have access to revision fields such as:

- `resource_id`
- `slug`
- `title`
- `content`
- `objectives`
- `activity_type_id`

Implementation implication:

- The current LiveView row model is enough for primary visibility filters.
- Search by title/content, Learning Objective filters, and Question Type filters need either:
  - an expanded row/view model, or
  - companion option/filter helpers in `InstructorCustomizations` / `TargetResolver`.

### Query Boundary

The safest boundary for server-side filtering is the existing candidate query path:

- `Oli.Delivery.InstructorCustomizations.list_bank_selection_candidates/4`
- `Oli.Delivery.InstructorCustomizations.TargetResolver.list_candidates/4`
- `Oli.Activities.Realizer.Query.execute/3`

Reason:

- The realizer already supports bank logic facts for:
  - `text`
  - `objectives`
  - `type`
- The existing query path already handles:
  - selection logic
  - publication/section source
  - paging
  - blacklist/exclusions
  - total counts
- Filtering only the currently loaded LiveView rows would be incorrect for paged banks.

Recommendation for Phase 1:

- Add a small filter contract to `InstructorCustomizations.list_bank_selection_candidates/4` opts.
- Keep paging in the existing query path.
- Compose `MER-5624` filters into the resolved selection logic before executing the realizer query.
- Use query-level filtering for search, objectives, and activity type whenever possible.
- Keep primary visibility filtering coordinated with exclusion state so Show Available and Show Removed compute accurate totals.

### Option Generation

Learning Objective and Question Type options must come from the full current selection candidate set, including both available and removed rows.

Recommended Phase 1/4 support:

- Add a compact helper that returns filter option data for a resolved bank selection.
- Do not derive options from currently loaded rows.
- For question types, reuse activity registration metadata for labels where possible.
- For learning objectives, resolve objective resource ids to titles through the section/publication resolver path used elsewhere in delivery.

## Implementation Blocks

- [x] Core behavior changes: no functional behavior changed in Phase 0.
- [x] Data or interface changes: no runtime interface changed in Phase 0.
- [x] Access-control or safety checks: confirmed existing LiveView route coverage remains the relevant safety baseline.
- [x] Observability or operational updates: not applicable for Phase 0.

## Test Blocks

- [x] Existing targeted LiveView tests run.
- [x] Results captured.

## Work-Item Sync

- [x] Phase 0 findings recorded in this execution record.
- [x] No PRD/FDD updates required for this lightweight work item.

## Review Loop

- Round 1 findings: not run; Phase 0 changed documentation only.
- Round 1 fixes: not applicable.

## Done Definition

- [x] Phase tasks complete.
- [x] Baseline targeted test passes.
- [x] Review completed when enabled: not applicable for documentation-only Phase 0.
- [x] Validation passes: not run; this lightweight work item intentionally does not include the full PRD/FDD/requirements harness document set.

