# Phase 6 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Phase: `6 - Template Verification And Scope Hardening`

## Scope from plan.md
- Verify template-level behavior and lock down page/section scoping guarantees.
- Confirm Product/Template Customize Content reaches the existing instructor-style preview route.
- Verify or implement propagation of template blueprint activity exclusions to future course sections.

## Implementation Blocks
- [x] Core behavior changes
  - Verified that `Oli.Delivery.Sections.Blueprint.duplicate/3` uses the existing core `InstructorCustomizations.duplicate_section_exclusions/2` path, so future course sections created from a customized template inherit template-level activity exclusions without duplicate MER-5620 copy logic.
  - Updated instructor preview return sanitization to preserve product remix return paths from Product/Template Customize Content page Edit links, including `/workspaces/course_author/:project_slug/products/:product_slug/remix`.
- [x] Data or interface changes
  - Reused the existing `section_page_activity_exclusions` table and `ActivityExclusion` schema; no migration or new interface was required.
- [x] Access-control or safety checks
  - Kept template UI on the existing `PreviewLessonLive` route and relied on the existing blueprint duplication boundary for future-section exclusion inheritance, preserving existing authorization and avoiding retroactive updates to already-created sections.
- [x] Observability or operational updates when needed
  - No new telemetry or logging was needed.

## Test Blocks
- [x] Tests added or updated
  - Confirmed existing blueprint duplication coverage for inherited embedded activity, bank selection, and bank candidate exclusions.
  - Added LiveView smoke coverage for Product/Template Customize Content `return_to` preservation.
- [x] Required verification commands run
  - `mix format lib/oli_web/delivery/instructor/preview_return.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs lib/oli/delivery/sections/blueprint.ex test/oli/delivery/sections/blueprint_test.exs`
  - `mix test test/oli/delivery/sections/blueprint_test.exs`
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli/delivery/sections/blueprint_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- [x] Results captured
  - `test/oli/delivery/sections/blueprint_test.exs`: 22 tests, 0 failures.
  - `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`: 29 tests, 0 failures.
  - Combined targeted run: 51 tests, 0 failures.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - Updated template-level assumptions, risks, Phase 6 status, and decision log to reflect the Customize Content route and future-section propagation behavior.
- [x] Open questions added to docs when needed
  - No new open questions were needed.

## Review Loop
- Round 1 findings:
  - Preserve query params for product remix `return_to` paths without allowing unsafe prefix matches such as `remixevil`.
  - Do not carry duplicate blueprint exclusion-copying helpers in MER-5620 now that the core duplication path owns this behavior.
- Round 1 fixes:
  - Added `safe_path_prefix?/2` to allow exact, child, and query-suffixed safe paths.
  - Removed the duplicate MER-5620 blueprint exclusion-copying helper and kept the call to `InstructorCustomizations.duplicate_section_exclusions/2` as the source of truth.
- Round 2 findings (optional):
- Round 2 fixes (optional):

## Done Definition
- [x] Phase tasks complete
- [x] Tests and verification pass
- [x] Review completed when enabled
- [x] Validation passes
