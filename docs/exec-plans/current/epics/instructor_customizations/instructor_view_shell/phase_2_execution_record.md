# Phase 2 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell`
Phase: `2 - Basic Preview Context Extraction And LiveView Skeleton`

## Scope from plan.md
- Move basic-page preview data assembly out of `PageDeliveryController`.
- Render basic pages through `/sections/:section_slug/preview/lesson/:revision_slug`.
- Preserve adaptive/advanced preview handling in the controller path.
- Keep instructor preview free of learner delivery side effects.

## Implementation Blocks
- [x] Core behavior changes
  - Added `OliWeb.Delivery.Instructor.PreviewPageContext` to build basic-page preview assigns for LiveView.
  - Expanded `OliWeb.Delivery.Instructor.PreviewLessonLive` from a route stub into the basic-page preview renderer.
  - Kept adaptive/advanced requests to `/preview/lesson/:revision_slug` controlled by redirecting back to `/preview/page/:revision_slug`.
  - Loaded the page-level union of preview and fallback activity scripts from the extracted activity summaries.
  - Added preview-specific route resolution so top and bottom in-preview navigation uses `/preview/lesson` for basic pages while preserving adaptive/controller-owned routes.
  - Restored bottom page navigation and collaboration surface rendering in the LiveView shell.
- [x] Data or interface changes
  - No data model changes.
  - Added `PreviewRoutes.page_path/2`, `PreviewRoutes.container_path/3`, and `PreviewRoutes.resource_path/3` for preview route generation.
  - Added `instructor_preview_return` assign shape with `label` and `path`.
  - Added explicit navigation URL and preserved-query-param support to `Components.Delivery.PageNavigator` and `Components.Delivery.PageDelivery.header`.
- [x] Access-control or safety checks
  - The LiveView stays under the existing authenticated section preview live session.
  - `return_to` accepts only same-section internal destinations; unsafe or missing values fall back to `/sections/:section_slug/remix`.
  - The preview header label is inferred server-side from the validated `return_to` path, with `Return to Customize Content` as the fallback label.
- [x] Observability or operational updates when needed
  - No new telemetry required for Phase 2.
  - Existing warnings for supported activity preview fallback remain in the extracted context builder.

## Test Blocks
- [x] Tests added or updated
  - Added `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
  - Covered basic-page rendering at `/preview/lesson/:revision_slug`.
  - Covered supported preview scripts and unsupported authoring-script fallback in the new LiveView.
  - Covered adaptive request fallback back to the controller-owned `/preview/page/:revision_slug` path.
  - Covered safe and unsafe return context behavior.
  - Covered no creation of resource accesses, resource attempts, activity attempts, part attempts, or resource summaries as the persisted proxies for learner attempts, submissions, progress, and analytics writes in this path.
  - Covered in-preview navigation links targeting `/preview/lesson` and preserving safe return context across page-to-page navigation.
- [x] Required verification commands run
  - `mix format lib/oli_web/delivery/instructor/preview_page_context.ex lib/oli_web/delivery/instructor/preview_routes.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex lib/oli_web/router.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix compile`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
- [x] Results captured
  - `mix compile` passed.
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs` passed: 6 tests, 0 failures.
  - Combined Phase 2 verification passed: 61 tests, 0 failures, 39 excluded.
  - Combined test startup emitted a non-blocking `Inventory recovery failed` DB ownership log from application startup; the test command exited successfully.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No plan divergence found.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
- UI and Elixir review found the first LiveView shell still delegated previous/next navigation through the legacy `/preview/page` route and omitted the bottom navigator.
- Security review found `return_to` still accepted arbitrary internal paths outside the current section.
- Performance review flagged the move from request assigns to LiveView assigns and suggested trimming large socket state.
- Requirements review called out the need to make Phase 2 test evidence explicit for navigation and persisted side-effect proxies.
- Round 1 fixes:
- Added preview-specific route helpers and explicit URL injection into the shared page navigator/header so basic-page preview navigation stays on `/preview/lesson`.
- Restored bottom navigation and collaboration surface rendering in the new shell.
- Restricted `return_to` to same-section internal destinations and preserved only sanitized navigation query params.
- Removed full `section` and `revision` structs from the preview LiveView assign payload, keeping only the fields the shell renders.
- Expanded tests and execution notes to cover `/preview/lesson` navigation links and clarify the persisted no-side-effect proxy assertions.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
