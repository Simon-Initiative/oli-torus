# Phase 1 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell`
Phase: `1 - Route Boundary And Compatibility Dispatch`

## Scope from plan.md
- Add the explicit basic-page Instructor View preview route.
- Redirect old basic-page `/preview/page/:revision_slug` requests to `/preview/lesson/:revision_slug`.
- Preserve adaptive/advanced preview, adaptive screen preview, and activity bank selection preview routes.

## Implementation Blocks
- [x] Core behavior changes
  - Added `OliWeb.Delivery.Instructor.PreviewRoutes.lesson_path/3`.
  - Added `/sections/:section_slug/preview/lesson/:revision_slug` as a LiveView route boundary.
  - Added a minimal `OliWeb.Delivery.Instructor.PreviewLessonLive` route target for Phase 1.
  - Updated `PageDeliveryController.page_preview/2` so basic pages redirect to the new route.
  - Removed the now-unused controller-owned basic-page preview render path and kept adaptive/advanced controller rendering intact.
- [x] Data or interface changes
  - No data model changes.
  - Introduced the preview lesson route helper as the public route-generation interface for later phases.
- [x] Access-control or safety checks
  - New route is under the existing section preview scope and uses section preview authorization plus delivery protected routing.
  - Redirect preserves an allowlisted subset of query params and the legacy `/page/:page` path segment as safe internal query params.
  - Unsafe `return_to` values are dropped unless they are internal paths.
- [x] Observability or operational updates when needed
  - No new telemetry or logs required for Phase 1.

## Test Blocks
- [x] Tests added or updated
  - Updated basic-page `/preview/page` tests to assert redirect behavior.
  - Added route-boundary assertions and a `live/2` mount assertion for the new preview lesson LiveView route.
  - Added route-preservation assertion for activity bank selection preview.
  - Added redirect query-param allowlist coverage.
  - Existing adaptive preview and adaptive screen preview tests continue to cover controller-owned behavior.
- [x] Required verification commands run
  - `mix format lib/oli_web/delivery/instructor/preview_routes.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex lib/oli_web/router.ex lib/oli_web/controllers/page_delivery_controller.ex test/oli_web/controllers/page_delivery_controller_test.exs`
  - `mix compile`
  - `mix test test/oli_web/controllers/page_delivery_controller_test.exs`
- [x] Results captured
  - `mix compile` passed.
  - `mix test test/oli_web/controllers/page_delivery_controller_test.exs` passed: 55 tests, 0 failures, 39 excluded.
  - Test startup emitted the known inventory recovery DB ownership log noise in one run; the final successful run did not repeat that specific log.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - No plan divergence found.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
  - UI and Elixir review found the initial Phase 1 LiveView route used the full lesson layout without the assigns that layout requires.
  - Requirements review found the route was only checked through `route_info/4`, not by a real `live/2` mount.
  - Requirements/security review noted that forwarding all query params would create an overly broad future return-context surface.
  - Performance and security review reported no current blocking findings.
- Round 1 fixes:
  - Removed the full lesson layout from the Phase 1 LiveView boundary.
  - Added a `live/2` mount assertion for `/preview/lesson/:revision_slug`.
  - Replaced unrestricted query forwarding with an allowlist and internal-path validation for `return_to`.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
