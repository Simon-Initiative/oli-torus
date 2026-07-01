# Phase 3 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell`
Phase: `3 - Instructor View Shell And Toolbar`

## Scope from plan.md
- Implement the reusable Instructor View shell around the new preview LiveView.
- Make outline and notes navigation preview-route-aware.
- Remove the legacy basic-page discussion surface from the preview shell.

## Implementation Blocks
- [x] Core behavior changes
  - Added reusable `instructor_preview_header` componentry in `OliWeb.Components.Delivery.Layouts`.
  - Reworked `OliWeb.Delivery.Instructor.PreviewLessonLive` to use a modern content wrapper plus sticky sidebar shell for outline and notes.
  - Removed the legacy page-level collaboration configuration panel from the basic-page preview shell.
  - Added read-only Class Notes rendering in preview mode so the sidebar can expose notes without pulling learner attempt lifecycle into this LiveView.
- [x] Data or interface changes
  - Extended `PreviewPageContext` with thin hierarchy data and a `notes_enabled?` flag for shell rendering.
  - Extended `OutlineComponent` with optional `route_builder` and `show_progress` inputs so preview mode can reuse it without learner-only path/progress behavior.
  - Extended `Annotations.panel/search_results` with route-builder and read-only options so preview links stay on `/preview/lesson`.
- [x] Access-control or safety checks
  - Preview return behavior remains constrained to validated same-section paths from Phase 2.
  - Notes rendering is read-only in the preview shell; this phase does not introduce new preview-side write paths for collaboration data.
- [x] Observability or operational updates when needed
  - No new telemetry required for Phase 3.

## Test Blocks
- [x] Tests added or updated
  - Updated `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs` for the new shell markup.
  - Added coverage for the reusable preview header and absence of legacy Page Discussion.
  - Added coverage that outline links stay on `/preview/lesson`.
  - Added coverage that the notes sidebar opens in preview and renders class-note content.
- [x] Required verification commands run
  - `mix format lib/oli_web/components/delivery/layouts.ex lib/oli_web/delivery/instructor/preview_page_context.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex lib/oli_web/live/delivery/student/lesson/annotations.ex lib/oli_web/live/delivery/student/lesson/components/outline_component.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix compile`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- [x] Results captured
  - `mix compile` passed.
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs` passed: 7 tests, 0 failures.
  - Combined Phase 2/3 verification passed: 62 tests, 0 failures, 39 excluded.
  - Combined test startup emitted the same non-blocking `Inventory recovery failed` ownership log seen in prior runs; the command still exited successfully.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No work-item doc divergence found.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
- Manual review against the changed shell found two concrete risks before closeout: preview notes were still using task-based DB work that races in LiveView tests and can break under SQL sandbox, and the first notes-sidebar assertion was observing stale async content.
- Round 1 fixes:
- Switched preview notes loading/search/reveal behavior to synchronous helper calls inside `PreviewLessonLive`.
- Kept the route-aware outline and notes components reusable while narrowing preview notes to read-only behavior in this slice.
- Round 2 findings (optional):
- No additional correctness, security, or performance findings remained in the changed code after the synchronous notes fix and full targeted test pass.
- Round 2 fixes (optional):
- None.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
