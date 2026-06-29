# Phase 7 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Phase: `7 - Final Verification, Review Prep, And Cleanup`

## Scope from plan.md
- Finish with targeted automated coverage, formatting, manual QA notes, and review-ready scope.
- Decide whether any legacy Activity Bank preview or selection rendering code should be removed.
- Prepare final PR notes for Course Section behavior, template behavior, warning behavior, and scope/safety evidence.

## Implementation Blocks
- [x] Core behavior changes
  - No runtime behavior changes were needed for Phase 7.
  - Reviewed the cleanup candidates and retained the legacy Activity Bank candidate-listing route/template because it is explicitly out of scope for this ticket.
  - Retained `Oli.Rendering.Content.Selection` because instructor preview now bypasses it for inline Activity Bank Selection previews, but non-instructor-preview rendering still needs the legacy renderer.
- [x] Data or interface changes
  - Confirmed no new feature flag, database table, migration, or transport contract was needed.
- [x] Access-control or safety checks
  - Confirmed mutation behavior remains page-scoped and section/template-scoped through `Oli.Delivery.InstructorCustomizations`.
  - Confirmed warning checks render only aggregate scored/practice warning messages and do not expose learner identity, attempt ids, or learner-specific details.
- [x] Observability or operational updates when needed
  - No new telemetry or logging was needed; existing LiveView/domain error paths remain the operational surface.

## Test Blocks
- [x] Tests added or updated
  - No new tests were required in Phase 7; prior phases already added targeted coverage for bank-selection preview rendering, remove/restore, warning confirmation, template propagation, and embedded activity regression behavior.
- [x] Required verification commands run
  - `mix test test/oli/delivery/instructor_customizations/write_api_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli/delivery/sections/blueprint_test.exs`
  - `mix format --check-formatted lib/oli/activities/realizer/query.ex lib/oli/delivery/instructor_customizations.ex lib/oli/delivery/instructor_customizations/target_resolver.ex lib/oli/delivery/sections/blueprint.ex lib/oli_web/delivery/instructor/activity_bank_selection_preview.ex lib/oli_web/delivery/instructor/preview_return.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex test/oli/delivery/instructor_customizations/write_api_test.exs test/oli/delivery/sections/blueprint_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `cd assets && ./node_modules/.bin/eslint src/apps/InstructorPreviewComponents.tsx src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx src/components/instructor_preview/activity_bank_selection_preview/preview-entry.tsx src/hooks/instructor_preview_customization.ts`
  - `cd assets && ./node_modules/.bin/prettier --check src/apps/InstructorPreviewComponents.tsx src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx src/components/instructor_preview/activity_bank_selection_preview/preview-entry.tsx src/hooks/instructor_preview_customization.ts`
  - `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/ui_core --check all`
- [x] Results captured
  - `test/oli/delivery/instructor_customizations/write_api_test.exs`: 12 tests, 0 failures.
  - `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`: 32 tests, 0 failures.
  - `test/oli/delivery/sections/blueprint_test.exs`: 22 tests, 0 failures.
  - Targeted Elixir format, TypeScript lint, and TypeScript prettier checks passed.
  - Prettier emitted warnings about ignored import-order options from the local config, but all matched files passed style checks.
  - Work item validation passed.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Updated Phase 7 status and cleanup decisions in `plan.md`.
- [x] Open questions added to docs when needed
  - No new open questions were needed.

## Review Loop
- Round 1 findings:
  - Legacy Activity Bank controller/template and `Oli.Rendering.Content.Selection` should not be deleted in this ticket because they still cover out-of-scope candidate-listing and non-instructor-preview rendering paths.
  - No learner-specific data was found in warning copy or browser-facing warning state.
  - No new feature flag or migration is warranted because the implementation reuses the existing preview customization transport and `section_page_activity_exclusions` storage.
- Round 1 fixes:
  - Documented the retention decisions and final verification evidence.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
