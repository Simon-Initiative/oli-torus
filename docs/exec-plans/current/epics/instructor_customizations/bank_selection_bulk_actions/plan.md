# Bank Selection Bulk Actions - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_bulk_actions/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_bulk_actions/fdd.md`

## Scope
Deliver `MER-5623` as an extension of the existing bank selection manager LiveView. The work covers same-state checkbox selection, shown-row-only master selection, contextual bulk remove/restore actions, disabled competing preview actions, an atomic bulk backend operation, plural invalid-removal modal behavior, and checked-row normalization after refresh. It explicitly does not implement the filter toolbar from `MER-5624`, but it must preserve a state model that makes future URL-param-backed query filters straightforward.

## Clarifications & Default Assumptions
- The active list in the manager represents the currently shown result set for the active query.
- Future filters from `MER-5624` should live in URL params and reload the active query from the server.
- `checked_candidate_ids` remains LiveView state only in this work item and does not need URL persistence.
- If future query params change, the default behavior should be to clear checked rows unless later product guidance requires cross-query persistence.
- The master checkbox acts only on the currently shown rows for the active query and never on hidden, unloaded, or future filtered rows.

### Requirements Traceability
- `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`:
  - covered by Phases 1 and 2 through the LiveView state model, helper logic, and preview-action disable behavior
- `AC-007`, `AC-008`, `AC-009`:
  - covered by Phase 3 through the atomic bulk backend operation and modal handling
- `AC-010`, `AC-011`:
  - covered by Phase 4 through refresh normalization and query-state boundary hardening

## Phase 1: State Model And LiveView Helper Refactor
- Goal: establish the active-query versus checked-row state model without changing external behavior yet.
- Tasks:
  - [ ] Refactor the manager helpers so checkbox behavior derives from `candidates` plus `checked_candidate_ids` rather than ad hoc row-state assumptions.
  - [ ] Add helper functions for `selection_mode`, selectable shown rows, and checked-id normalization.
  - [ ] Add a brief comment in the LiveView documenting the roles of the active query rows, checked ids, and future URL-param-backed query state.
- Testing Tasks:
  - [ ] Add or update LiveView tests for helper-driven same-state selection behavior.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`
- Definition of Done:
  - same-state selection semantics are explicit in the code and tests
  - the state model is documented for future filter work
- Gate:
  - helper and LiveView tests pass for the refactored checkbox behavior
- Dependencies:
  - existing `MER-5622` manager route and tests
- Parallelizable Work:
  - the code comment and helper extraction can proceed alongside test updates once the state model is agreed

## Phase 2: Bulk Selection UI And Preview Disable Behavior
- Goal: expose the manager-side bulk selection UX without yet finalizing backend persistence.
- Tasks:
  - [ ] Render the contextual `Remove Selected (n)` / `Restore Selected (n)` action above the table.
  - [ ] Implement shown-row-only master checkbox behavior.
  - [ ] Disable the single-question preview action while a bulk selection is active.
  - [ ] Apply muted/disabled treatment to opposite-state shown rows during selection.
- Testing Tasks:
  - [ ] Add LiveView tests for `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, and `AC-006`.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`
- Definition of Done:
  - the manager reflects the intended same-state bulk-selection UX
  - the preview no longer offers competing single-row actions during bulk selection
- Gate:
  - LiveView tests prove the shown-row-only bulk-selection behavior and preview disable state
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - preview disable wiring can be developed in parallel with the toolbar markup once helper contracts stabilize

## Phase 3: Atomic Bulk Backend Operation
- Goal: implement one backend path for validating and persisting a whole bulk remove or restore action.
- Tasks:
  - [ ] Add a bulk candidate toggle API under `Oli.Delivery.InstructorCustomizations`.
  - [ ] Resolve the selection target, authorize the actor, and lock the page once per bulk request.
  - [ ] Validate remove requests against the hypothetical post-removal active count for the full selected set before any writes.
  - [ ] Persist the selected candidate rows atomically using set-based writes where appropriate.
- Testing Tasks:
  - [ ] Add targeted ExUnit coverage for `AC-007`, `AC-008`, and `AC-009`.
  - Command(s): `mix test test/oli/delivery/instructor_customizations_test.exs`
- Definition of Done:
  - bulk remove and restore no longer depend on repeated single-row mutation loops
  - blocked bulk removals persist nothing
- Gate:
  - backend tests pass for atomic success and failure cases
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - backend API shape and transaction logic can proceed independently of the final LiveView event wiring

## Phase 4: LiveView Bulk Mutation Wiring And Refresh Normalization
- Goal: connect the manager UI to the bulk backend path and normalize state after refreshes.
- Tasks:
  - [ ] Wire the bulk action button to the new backend API.
  - [ ] Reuse the invalid-removal modal with plural-aware copy for blocked bulk removals.
  - [ ] Refresh the active query result after successful bulk actions.
  - [ ] Normalize checked ids against the refreshed shown rows and preserve only still-valid state.
- Testing Tasks:
  - [ ] Add LiveView coverage for `AC-007`, `AC-008`, `AC-009`, and `AC-010`.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`
- Definition of Done:
  - successful bulk actions refresh the manager consistently
  - blocked bulk removes show the modal and leave state untouched
- Gate:
  - mutation, modal, and normalization tests pass
- Dependencies:
  - Phases 2 and 3
- Parallelizable Work:
  - plural-copy modal handling can be developed alongside refresh normalization once the backend result shape is fixed

## Phase 5: Hardening For Future Query Params And Final Verification
- Goal: close the slice with explicit compatibility for future URL-param-backed filters and final validation.
- Tasks:
  - [ ] Verify that the implementation keeps query state separate from checked-row state.
  - [ ] Reconcile any doc drift back into the PRD/FDD/plan if implementation details require it.
  - [ ] Remove the temporary requirements seed file once the work-item docs are stable.
  - [ ] Run formatting and targeted test suites.
- Testing Tasks:
  - [ ] Run final targeted LiveView and backend tests.
  - [ ] Run formatting on touched Elixir files.
  - Command(s): `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs test/oli/delivery/instructor_customizations_test.exs`, `mix format`
- Definition of Done:
  - the docs and code both preserve the future URL-param filter model cleanly
  - validation and formatting gates pass
- Gate:
  - final targeted tests pass and docs stay aligned with the implemented behavior
- Dependencies:
  - Phases 1 through 4
- Parallelizable Work:
  - doc reconciliation and final verification can run while low-risk test adjustments land

## Parallelization Notes
- Backend bulk API work can start before the final LiveView event wiring is complete.
- Preview disable treatment can proceed in parallel with the bulk-action toolbar once the selection-mode helpers exist.
- The future URL-param filter compatibility is mostly a state-model concern; it should be verified continuously rather than deferred to a separate implementation spike.

## Phase Gate Summary
- Gate A: helper-driven same-state selection model is explicit and tested.
- Gate B: bulk-selection UI and preview disable behavior are stable.
- Gate C: atomic bulk backend mutation behavior is validated.
- Gate D: LiveView wiring, modal behavior, and normalization are correct.
- Gate E: final verification confirms clean compatibility with future URL-param-backed filters.
