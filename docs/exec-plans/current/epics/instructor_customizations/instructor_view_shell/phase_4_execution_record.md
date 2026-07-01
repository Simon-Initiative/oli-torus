# Phase 4 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell`
Phase: `4 - Link Producer Migration`

## Scope from plan.md
- Update new basic-page Instructor View links to use `/preview/lesson`.
- Keep adaptive, adaptive screen, and activity bank selection links on their existing routes.

## Implementation Blocks
- [x] Core behavior changes
  - Updated course-content page opening to use `PreviewRoutes.resource_path/3`, which routes basic pages to `/preview/lesson` and preserves controller-owned container preview behavior.
  - Updated latest-visited-page instructor preview links to open basic pages at `/preview/lesson`.
  - Updated deliberate-practice, exploration, assignment, and discussion-related page links to use the new basic-page preview route when preview mode is enabled.
  - Updated student explorations preview links so page openings stay on `/preview/lesson`.
- [x] Data or interface changes
  - Reused the existing `PreviewRoutes` helper contract instead of introducing new persisted state or new route parameters.
  - Kept adaptive/controller-owned route helpers intact for container and non-basic-page preview paths.
- [x] Access-control or safety checks
  - Adaptive and controller-owned preview routes remain on their existing paths.
  - Basic-page preview links continue to flow through the same LiveView route and same-section constraints already enforced in earlier phases.
- [x] Observability or operational updates when needed
  - No new telemetry required for Phase 4.

## Test Blocks
- [x] Tests added or updated
  - Updated component tests to assert `/preview/lesson` for assignment and exploration preview links.
  - Added coverage for latest-visited-page instructor preview links.
  - Added coverage for deliberate-practice preview links.
  - Updated the course-content live test to assert page opens in preview mode redirect to `/preview/lesson`.
  - Re-ran the controller and preview LiveView regression suites after the producer migration.
- [x] Required verification commands run
  - `mix format lib/oli_web/components/delivery/course_content.ex lib/oli_web/components/delivery/deliberate_practice_card.ex lib/oli_web/components/delivery/exploration_card.ex lib/oli_web/components/delivery/assignments/assignment_card.ex lib/oli_web/components/delivery/discussion_activity/discussion_table_model.ex lib/oli_web/live/delivery/student/explorations_live.ex test/oli_web/components/delivery/deliberate_practice_card_test.exs test/oli_web/components/delivery/assignments/assignment_card_test.exs test/oli_web/components/delivery/exploration_card_test.exs test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
  - `mix test test/oli_web/components/delivery/deliberate_practice_card_test.exs test/oli_web/components/delivery/assignments/assignment_card_test.exs test/oli_web/components/delivery/exploration_card_test.exs test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/live/delivery/student/explorations_live_test.exs test/oli_web/live/delivery/student/practice_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
  - `mix test test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/live/delivery/student/learn_live_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- [x] Results captured
  - Targeted producer tests passed: `103 tests, 0 failures (39 excluded)`.
  - Broader delivery and preview regression suite passed: `191 tests, 0 failures (42 excluded)`.
  - Test startup emitted the known non-blocking inventory recovery DB ownership log noise in some runs; the commands still exited successfully.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Plan updated to reflect the completed phase 4 producer migration and the preserved `preview/learn` return-state behavior.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
  - The first pass left several page-oriented preview producers still hardcoded to `/preview/page`.
- Round 1 fixes:
  - Migrated the remaining basic-page producers to `/preview/lesson` and added route assertions for the changed surfaces.
- Round 2 findings (optional):
  - No new correctness, security, or performance findings remained after the broader regression pass.
- Round 2 fixes (optional):
  - None.

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
