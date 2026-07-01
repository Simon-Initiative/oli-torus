# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager`
Phase: `2`

## Scope from plan.md
- render the management workspace shell with the reusable preview headers and a local back contract
- load and append candidate rows incrementally while preserving selection state
- surface selection metadata, active-available count, and removed-row styling in the left pane

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (not needed for this shell-and-list slice)

Implementation note:
- Phase 2 extended `list_bank_selection_candidates/4` to return lightweight paging metadata (`offset`, `limit`, `has_more?`, `total_count`, `active_count`) alongside the current candidate rows. The manager uses that response directly so incremental loads can append deterministically without recomputing count state in LiveView.
- Phase 2 now reads `points per question` from the authored selection's `pointsPerActivity` field and renders the selection-criteria summary from the selection logic itself, so the shell reflects the same authored bank-selection metadata shown in authoring instead of placeholder copy.
- Phase 2 intentionally keeps the right pane as a structural preview placeholder. The selected row contract, local back behavior, and candidate paging state are now stable inputs for Phase 3 preview rendering.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification commands:
- `mix compile`
- `mix test test/oli/delivery/instructor_customizations/write_api_test.exs`
- `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed (no new open questions were introduced in phase 2)

## Review Loop
- Round 1 findings:
  - The local back control was regenerating a generic lesson-preview URL instead of preserving the sanitized `request_path` when the manager had an explicit origin-page path.
- Round 1 fixes:
  - Updated the manager LiveView to prefer the sanitized `request_path` for the local back target and tightened the LiveView test to assert the exact link href.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
