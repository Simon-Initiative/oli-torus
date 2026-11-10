# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Phase: `5 - Existing Attempts And Visits Warning Flow`

## Scope from plan.md

- Warn instructors that remove/restore changes apply only to future attempts when the current Course Section page already has scored attempts or practice visits.
- Render the warning banner at the top of Instructor Preview and make it dismissable.
- Require confirmation in a warning modal before applying remove/restore for affected preview customization actions.
- Keep Phase 6 template verification out of this phase.

## Implementation Blocks

- [x] Core behavior changes
  - Added aggregate, privacy-preserving attempt/access existence helpers in `Oli.Delivery.Attempts.Core`.
  - Added scored/practice warning state to `PreviewLessonLive` during Instructor Preview mount.
  - Added dismissable page-level warning banner using the scored/practice copy from `informal.md`.
  - Added warning modal state that stores a pending preview customization action and applies it only after instructor confirmation.
  - Routed confirmed actions back to React/fallback preview components through the existing preview customization reply event shape.
- [x] Data or interface changes
  - Added a LiveView-pushed `preview_customization_reply` browser event for confirmed modal actions.
  - Kept existing remove/restore payloads and success replies unchanged after confirmation.
- [x] Access-control or safety checks
  - Warning eligibility uses only section/page existence queries and does not expose learner identity, attempt IDs, user IDs, or counts.
  - Confirmed actions revalidate the current page and target before writing.
- [x] Observability or operational updates when needed
  - No new telemetry or logging required for this phase.

## Test Blocks

- [x] Tests added or updated
  - Added scored warning banner copy and dismiss coverage.
  - Added practice warning banner copy coverage.
  - Added bank-selection modal gating coverage proving remove does not persist until confirmation.
  - Added cancel coverage proving pending actions are cleared without persistence.
  - Added embedded activity modal-gating regression coverage.
  - Added coverage for action-specific modal copy: remove/restore and question/selection labels.
  - Added coverage for the narrowed warning banner width treatment.
- [x] Required verification commands run
  - `mix format lib/oli/delivery/attempts/core.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
  - `cd assets && ./node_modules/.bin/eslint src/hooks/instructor_preview_customization.ts`
  - `cd assets && ./node_modules/.bin/prettier src/hooks/instructor_preview_customization.ts --check`
  - `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/ui_core --check all`
- [x] Results captured
  - Targeted LiveView test passed: 28 tests, 0 failures.
  - Phase contract test set passed: 39 tests, 0 failures.
  - Targeted TypeScript lint passed.
  - Targeted TypeScript Prettier check passed.
  - Work item validation passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - `plan.md` updated to mark Phase 5 complete and record the Phase 5 decision.
- [x] Open questions added to docs when needed
  - No new open questions; template behavior remains pending for Phase 6.

## Review Loop

- Round 1 findings: Local review across security, performance, Elixir, TypeScript, and UI found one accessibility issue: the custom warning modal needed dialog keyboard/focus behavior instead of only a static fixed overlay.
- Round 1 fixes: Added `focus_wrap`, Escape handling, and click-away cancellation to the warning modal while preserving the Figma-aligned visual treatment.
- Round 2 findings (optional): Refinement review found no blocking issues in the narrower banner width or action-specific modal copy changes.
- Round 2 fixes (optional): None required.

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
