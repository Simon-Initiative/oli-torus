# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/bank_selection_bulk_actions`
Phase: `4`

## Scope from plan.md
- Wire the bulk action CTA to the atomic backend API.
- Reuse the invalid-removal modal with plural-aware copy, refresh the active query after success, and normalize the checked ids against the refreshed rows.

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
  - The bulk CTA was still stubbed, and the invalid-removal modal only handled the single-question wording from the preview action path.
- Round 1 fixes:
  - Connected the CTA to `set_bank_candidates_enabled/6`, refreshed the current query after success, preserved normalized checked ids, and generalized the warning modal copy for singular and plural bulk removals.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
