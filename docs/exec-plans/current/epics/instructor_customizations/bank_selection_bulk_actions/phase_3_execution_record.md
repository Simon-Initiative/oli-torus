# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_bulk_actions`
Phase: `3`

## Scope from plan.md
- Implement one atomic backend path for bulk remove and restore within a bank selection.
- Validate remove requests against the hypothetical post-removal active count before any writes and persist the selected rows with set-based operations.

## Implementation Blocks
- [x] Core behavior changes
- [x] Data or interface changes
- [x] Access-control or safety checks
- [ ] Observability or operational updates when needed

## Test Blocks
- [x] Tests added or updated
- [x] Required verification commands run
- [x] Results captured

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
- [x] Open questions added to docs when needed

## Review Loop
- Round 1 findings:
  - The initial bulk-restore validation broke the existing stale-exclusion restore contract by requiring every restored candidate to still match the current selection query.
- Round 1 fixes:
  - Bulk restore now accepts already-persisted excluded ids even when they are stale, while still validating non-stale ids against the current selection target.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
