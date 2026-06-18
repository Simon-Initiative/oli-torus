# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_manager`
Phase: `3`

## Scope from plan.md
- preview the currently selected candidate through the shared preview activity pipeline
- keep row selection and right-panel rendering on the same instructor-preview contract already used elsewhere

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [x] Observability or operational updates when needed (not needed for this preview-render slice)

Implementation note:
- Phase 3 adds `PreviewPageContext.build_bank_candidate_preview/4` as the bank-selection manager's server-side entry point for rendering one candidate through the existing instructor-preview stack. The helper reuses the same `ActivitySummary` / `Html.activity` contract already used by page preview instead of introducing a separate preview renderer for bank candidates.
- The manager LiveView now keeps only the selected candidate preview HTML and the union of required preview scripts in assigns. Candidate selection updates the right panel directly, while the left list remains the source of selection state.

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

Verification commands:
- `mix compile`
- `mix test test/oli_web/live/delivery/instructor/bank_selection_manager_live_test.exs`

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged (plan only; no PRD/FDD divergence in this slice)
- [x] Open questions added to docs when needed (no new open questions were introduced in phase 3)

## Review Loop
- Round 1 findings:
  - The initial row-selection tests assumed preview titles would be present in server HTML, but preview-capable activities still render their titles inside hydrated custom elements.
- Round 1 fixes:
  - Updated the tests to assert the selected preview container itself, while keeping a direct helper test that proves preview HTML and scripts are returned for the candidate.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
