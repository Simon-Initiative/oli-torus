# Phase 5 Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell`
Phase: `5 - Regression, Visual QA, And Review Readiness`

## Scope from plan.md
- Verify the complete basic-page shell migration and prepare the branch for review.
- Keep manual QA and final regression focused on preview shell behavior, shell readiness, and no-regression checks.

## Implementation Blocks
- [x] Shared preview shell header placement
  - Rendered the reusable Instructor View header from the shared `student_delivery` layout when `preview_mode` is active.
  - Kept the existing `PreviewLessonLive` header behavior intact for the basic-page preview shell.
  - Added a safe default return context for preview surfaces that do not receive explicit `instructor_preview_return` data.
- [x] Layout spacing adjustments
  - Made the shared delivery sidebar preview-aware so its top offset matches the two-bar preview shell.
  - Increased the preview `LearnLive` and `IndexLive` sticky offsets so their toolbar rows stay below the Instructor View header.
- [x] Preview lesson global header offset
  - Offset the shared delivery header below the Instructor View banner in preview mode and raise it above the sidebar overlay so the Torus logo, course title, and account menu remain visible.
  - Increased the preview sidebar and flash offsets to match the full two-header stack height.
- [x] Preview schedule link routing
  - Updated the full schedule preview surface so basic-page links resolve to `/preview/lesson` instead of the normal lesson route.
  - Kept the preview schedule return path pointed at `/preview/student_schedule` so back navigation remains preview-aware.

## Test Blocks
- [x] Tests added or updated
  - Added preview header assertions to `learn_live_test.exs` for the preview root, preview learn, preview discussions, and preview practice surfaces.
  - Kept the basic-page preview lesson coverage in `preview_lesson_live_test.exs` intact.
- [x] Required verification commands run
  - `mix format lib/oli_web/components/delivery/layouts.ex lib/oli_web/components/layouts/student_delivery.html.heex lib/oli_web/live/delivery/student/index_live.ex lib/oli_web/live/delivery/student/learn_live.ex test/oli_web/live/delivery/student/learn_live_test.exs`
  - `mix test test/oli_web/live/delivery/student/learn_live_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/live/delivery/student/schedule_live_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
  - `mix test test/oli_web/components/delivery/layouts_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- [x] Results captured
  - Targeted preview regression suite passed: `119 tests, 0 failures (3 excluded)`.
  - The known inventory recovery DB ownership log noise still appeared during test startup, but the command completed successfully.
  - Schedule preview regression suite passed: `21 tests, 0 failures`.
  - Header/layout regression suite passed: `35 tests, 0 failures`.

## Work-Item Sync
- [x] PRD, FDD, and plan updated when implementation diverged
  - FDD updated to note that the reusable Instructor View header is consumed by the shared preview delivery layouts as well as `PreviewLessonLive`.
- [x] Open questions added to docs when needed
  - No new open questions.

## Review Loop
- Round 1 findings:
  - The shared preview delivery layout did not yet surface the Instructor View header on `/sections/:section_slug/preview` and its sidebar routes.
- Round 1 fixes:
  - Added the header to the shared preview layout and adjusted the affected sticky offsets.
- Round 2 findings (optional):
  - `IndexLive` expected `preview_mode` in the mobile home tabs component but the assign was not passed through.
- Round 2 fixes (optional):
  - Passed `preview_mode` into the component and kept the preview-specific top offset conditional.

## Done Definition
- [x] Phase tasks complete for this implementation slice
- [x] Tests and verification pass
- [ ] Review completed when enabled
- [x] Validation passes

## Decision Log

### 2026-06-02 - Preview Schedule Links In Phase 5
- Change: Documented that the full schedule preview surface now emits preview lesson links and preserves the preview schedule return path.
- Reason: QA surfaced a regression where schedule links in preview still resolved to the normal lesson route, so the phase 5 execution record needs to reflect the corrected behavior.
- Evidence: `lib/oli_web/components/delivery/schedule.ex`, `lib/oli_web/live/delivery/student/schedule_live.ex`, `test/oli_web/live/delivery/student/schedule_live_test.exs`, targeted `mix test` run.
- Impact: Phase 5 now records the schedule preview routing regression fix alongside the other preview shell QA adjustments.

### 2026-06-02 - Preview Lesson Global Header Offset
- Change: Documented that the shared delivery header is offset below the Instructor View banner in preview mode and stacked above the sidebar overlay so the standard Torus header remains visible.
- Reason: Browser QA showed the second header was still visually hidden in lesson preview, so the shared layout needed explicit preview offsets and stacking priority.
- Evidence: `lib/oli_web/components/delivery/layouts.ex`, `lib/oli_web/components/layouts/student_delivery.html.heex`, `test/oli_web/components/delivery/layouts_test.exs`.
- Impact: Phase 5 now captures the final preview-shell stacking correction for lesson pages without changing the existing local preview header contract.

### 2026-06-03 - Instructor Preview Header On Adaptive Pages

- Change: Added the Instructor View header to adaptive page preview, keeping adaptive pages controller-rendered (not migrated to LiveView).
- Reason: QA showed that adaptive pages opened from preview surfaces (Practice, Learn, etc.) lost the Instructor View header because the header was only wired into the LiveView-based shell. The PRD lists adaptive preview migration as a non-goal, but adding the header to the existing controller path was a small, self-contained change.
- Evidence: `lib/oli_web/controllers/page_delivery_controller.ex` (new `resolve_preview_return/1` helper, `instructor_preview_return` added to `render_advanced_page_preview` and the nil-user branch of `page_preview`), `lib/oli_web/templates/resource/advanced_page_preview.html.eex` converted to `.html.heex` with the header at the top, `lib/oli_web/templates/page_delivery/instructor_page_preview.html.heex` header added at the top.
- Impact: Adaptive pages now show the Instructor View header with the correct return context (or fallback) in preview mode, on par with basic pages. Adaptive pages remain controller-owned.

### 2026-06-03 - Remove Dead Latest-Visited Preview Card
- Change: Removed the unused `CourseLatestVisitedPage` component, its dedicated component test, and the dead `latest_visited_page` assigns from `PageDeliveryController`.
- Reason: Static usage review found no runtime consumer of the component in delivery templates, layouts, or LiveViews. The only remaining references were the component file itself, a branch-local component test, branch-local controller expectations, and the controller assigns that no template consumed.
- Evidence: `lib/oli_web/controllers/page_delivery_controller.ex`, `test/oli_web/controllers/page_delivery_controller_test.exs`, removal of `lib/oli_web/components/delivery/course_lastest_visited_page.ex`, removal of `test/oli_web/components/delivery/course_lastest_visited_page_test.exs`.
- Impact: Phase 5 now records a small cleanup of dead preview-related UI code so the PR can call out that the stale latest-visited preview card surface was removed rather than migrated.

### 2026-06-04 - Route Course Content Open Actions Through Learn/Lesson LiveViews
- Change: Updated Course Content so container `Open as instructor` and `Open as student` actions open `preview/learn` or `learn` with `target_resource_id`, while page actions continue through `preview/lesson` or `lesson`. Extended `LearnLive` target scrolling so nested section containers resolve to the containing module/unit and pulse the section target instead of falling back to the old controller preview surface.
- Reason: This is not only a preview-shell cleanup. The old controller-backed container/page delivery routes are deprecated for student-facing navigation after the NG23 LiveView delivery rollout, so `Open as student` was pointing to the wrong UI. Unifying both actions on the LiveView delivery surfaces keeps Instructor View and learner navigation on the same maintained path and removes another dependency on the legacy controller shell.
- Evidence: `lib/oli_web/components/delivery/course_content.ex`, `lib/oli_web/live/delivery/student/learn_live.ex`, `assets/src/hooks/scroller.ts`, `test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs`, `test/oli_web/live/delivery/student/learn_live_test.exs`, `test/oli_web/live/delivery/instructor_dashboard/overview/content_tab_test.exs`.
- Impact: Course Content no longer sends containers through `/preview/container` or normal controller delivery pages. Instructor/admin preview opens the new preview shell, student opens the NG23 lesson/learn LiveViews, and nested section containers can be highlighted correctly from Course Content entry points.

### 2026-06-04 - Final Preview Learn Return And Nested Highlight Polish
- Change: Adjusted `PreviewLessonLive` so the local back action treats a preview-learn origin as the local return surface instead of re-threading it as global `return_to`, which keeps the header reserved for the originating workflow while sending the page-level back action to `preview/learn` centered on the current page. Simplified nested gallery focus so deep page/section targets no longer perform a separate unit scroll before expanding the module; instead the flow centers the module card, then performs a single `contain` scroll to the nested target and applies the stronger list-item highlight through `Scroller`.
- Reason: QA showed two UX gaps in the final shell polish: external entry points such as `Overview > Course Content` made the local back action redundant with the header exit, and nested targets inside long module indices could pulse off-screen or too subtly after the module expanded.
- Evidence: `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`, `lib/oli_web/live/delivery/student/learn_live.ex`, `assets/src/hooks/scroller.ts`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`, `test/oli_web/live/delivery/student/learn_live_test.exs`.
- Verification:
  - `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs:73`
  - `mix test test/oli_web/live/delivery/student/learn_live_test.exs:1987 test/oli_web/live/delivery/student/learn_live_test.exs:2022 test/oli_web/live/delivery/student/learn_live_test.exs:2126 test/oli_web/live/delivery/student/learn_live_test.exs:2149 test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/live/delivery/instructor_dashboard/overview/content_tab_test.exs`
- Impact: Preview pages entered from external workflows now preserve a clear split between the global header return and the local back affordance, while deep nested Course Content targets land in viewport with a visible highlight instead of relying on the legacy controller flow or off-screen pulse timing.

### 2026-06-04 - Keep Preview Lesson Separate From Learner Lesson
- Change: Recorded the implementation rationale for keeping `PreviewLessonLive` separate even though other preview delivery surfaces reuse the same LiveView modules as their non-preview routes.
- Reason: preview home/learn/schedule/assignments differ mostly in shell chrome, preview-aware routing, and UI state, so sharing those LiveViews is low-risk. Lesson preview is different: it must render the same family of UI while also swapping the operational context so activities run in preview mode and no learner attempts, resource accesses, progress, submissions, or analytics side effects are created. That made a dedicated preview LiveView the safer tactical boundary for `MER-5617`.
- Additional context: `LessonLive` already fans out through multiple `mount/3` clauses keyed by lesson `view`, with separate initialization branches for practice, graded, adaptive, and related lesson modes. Adding Instructor View there would not have been just another shell flag; it would have threaded preview-specific conditions through several pre-existing learner-delivery setup paths that already own attempts, scoring, review, collaboration, and script-loading concerns.
- Tradeoff:
  - Advantage: isolates preview-only behavior from the learner lesson lifecycle and lowers the risk of student delivery regressions.
  - Disadvantage: lesson shell changes can drift between `LessonLive` and `PreviewLessonLive`, so preview may need follow-up parity work when the learner lesson UI evolves.
- Future option: if lesson-shell churn stays high, keep separate setup/context owners but extract more shared lesson markup into shared components or a shared HEEx surface so the side-effect boundary stays isolated without maintaining two independent renders.
- Evidence: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/fdd.md`, `lib/oli_web/live/delivery/instructor/preview_lesson_live.ex`, `lib/oli_web/live/delivery/student/lesson_live.ex`.

### 2026-06-04 - Bottom Navigation Shell Alignment
- Change: Tightened the bottom navigation shell layout so the hover-revealed previous/next bar lines up cleanly with its rounded top corners instead of carrying extra vertical padding that pushed the bar away from the curved edge.
- Reason: Browser QA showed the floating bottom navigation looked visually detached from its own rounded corners after the preview-shell adjustments, so the nav shell needed a small spacing correction.
- Evidence: `lib/oli_web/components/delivery/layouts.ex`.
- Impact: The bottom navigation reads as a single, coherent floating surface again instead of a padded box sitting inside the rounded chrome.

### 2026-06-04 - Stabilize Dev Icons Surface
- Change: Added a default `:class` attr for `thumbs_up_ai/1` and switched `progress_arrow/1` to assign its generated `clip_path_id` without relying on a missing required attr path.
- Reason: The development icons surface could crash when rendering icons that were invoked without an explicit `class` assign, so the icon helpers needed safer defaults.
- Evidence: `lib/oli_web/icons.ex`.
- Impact: `/dev/icons` can render the icon set without crashing on helper calls that omit optional styling assigns.
