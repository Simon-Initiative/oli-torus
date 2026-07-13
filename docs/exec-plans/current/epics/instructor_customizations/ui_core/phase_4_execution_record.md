# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Phase: `4 - Whole-Selection Remove/Restore Wiring`

## Scope from plan.md

- Route Activity Bank Selection remove/restore through the shared preview customization contract into the core instructor customization implementation.
- Close hardening and coverage gaps for restore, stale/error cases, and LiveView reply contract assertions.
- Keep Phase 5 warning banner/modal behavior out of this phase.

## Implementation Blocks

- [x] Core behavior changes
  - Kept the existing `bank_selection` remove/restore dispatcher in `PreviewLessonLive`.
  - Added reasoned `ok: false` replies for invalid page targets, invalid selection targets, invalid actions, malformed targets, unauthorized writes, and unexpected domain errors.
  - Preserved short success flash copy: `Activity bank selection removed` and `Activity bank selection restored`.
- [x] Data or interface changes
  - Added `originalAvailableCount` to the server-built Activity Bank Selection preview payload so restore replies can return the original available count even when the selection initially rendered as removed.
  - Stored the original available count in `preview_metadata.bank_selection_available_counts_by_id`.
- [x] Access-control or safety checks
  - Preserved existing page-resource-id and selection-id validation before domain writes.
  - Preserved `Oli.Delivery.InstructorCustomizations` as the final authorization and persistence boundary.
- [x] Observability or operational updates when needed
  - No new telemetry or logging required for this phase.

## Test Blocks

- [x] Tests added or updated
  - Updated bank-selection remove test to assert the `{:reply, reply, socket}` contract with `assert_reply/2`.
  - Added bank-selection restore coverage.
  - Added stale page id, missing/unknown selection id, malformed target, and invalid action coverage.
  - Kept unauthorized and unexpected domain-error replies reasoned at the LiveView boundary; direct LiveView coverage remains focused on reachable stale, malformed, missing-selection, and invalid-action requests.
  - Kept embedded activity remove/restore tests in the same LiveView module passing.
- [x] Required verification commands run
  - `mix format lib/oli_web/delivery/instructor/activity_bank_selection_preview.ex lib/oli_web/delivery/instructor/preview_page_context.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
  - `python3 /Users/gastonabella/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/instructor_customizations/ui_core --check all`
- [x] Results captured
  - Targeted LiveView test passed: 22 tests, 0 failures.
  - Phase contract test set passed: 33 tests, 0 failures.
  - Work item validation passed.

## Work-Item Sync

- [x] PRD, FDD, and plan updated when implementation diverged
  - `plan.md` updated to mark Phase 4 complete and record the Phase 4 decision.
- [x] Open questions added to docs when needed
  - No new open questions; Phase 5 warning behavior remains explicitly pending.

## Review Loop

- Round 1 findings: Local fallback review completed for security, performance, and Elixir concerns because the available multi-agent tool policy requires explicit user approval before spawning subagents. No blocking findings found. Scope remains limited to Phase 4 remove/restore contract hardening.
- Round 1 fixes: None required after review.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition

- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
