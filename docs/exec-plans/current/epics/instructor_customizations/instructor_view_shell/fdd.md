# Instructor View Shell - Functional Design Document

## 1. Executive Summary
`MER-5617` moves only basic-page Instructor View from the legacy controller-rendered page preview into a dedicated LiveView route: `/sections/:section_slug/preview/lesson/:revision_slug`. The design preserves the `MER-5618` activity preview rendering contract, reuses modern lesson-shell concepts where safe, and explicitly avoids the learner `LessonLive` attempt/progress lifecycle. The existing `/preview/page` controller path remains responsible for adaptive/advanced preview and redirects old basic-page links to the new LiveView route.

This design covers `FR-001` through `FR-007` and acceptance criteria `AC-001` through `AC-017`.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001`: provide a dedicated LiveView route for basic-page Instructor View.
  - `FR-002`: route new entry points and in-preview basic-page navigation through `/preview/lesson`.
  - `FR-003`: preserve adaptive, advanced, adaptive screen, and activity bank selection preview behavior on existing controller routes.
  - `FR-004`: render the approved Instructor View shell around basic-page content.
  - `FR-005`: keep basic-page Instructor View side-effect-free for learner attempts, submissions, progress, and learner analytics.
  - `FR-006`: preserve `MER-5618` preview element/fallback rendering inside the new shell.
  - `FR-007`: provide reusable Instructor View header componentry and an explicit preview return-context contract.
- Non-functional requirements:
  - The new route must enforce the same preview authorization posture as current section preview.
  - UI controls must remain accessible, responsive, and compatible with light and dark mode.
  - The setup path must avoid unnecessary per-activity database queries and must keep script selection page-scoped and deduped.
- Assumptions:
  - `MER-5618` lands before or with this work and supplies `preview_element`, `preview_script`, `preview_context`, and mixed preview/fallback rendering.
  - Basic-page Instructor View can render page content without calling learner visit/attempt setup.
  - Old basic-page links may remain temporarily in rendered content, but redirects provide safe compatibility.
  - Return-to-origin context can be carried in query params without new persistence.
  - Existing preview-mode assigns indicate preview shell state but do not encode where the user should return.

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/router.ex` currently defines preview controller routes under `/sections/:section_slug/preview`.
  - `PageDeliveryController.page_preview/2` dispatches both basic pages and adaptive/advanced pages from `/preview/page/:revision_slug`.
  - `PageDeliveryController.render_page_preview/3` currently assembles basic-page preview content, activity summaries, scripts, objectives, previous/next data, and collaboration settings.
  - `OliWeb.Delivery.Student.LearnLive` now uses the preview route helpers for basic-page preview navigation so `preview/learn` returns preserve `selected_view` and `sidebar_expanded` state when an instructor comes back from a page.
  - `PageDeliveryController.render_advanced_page_preview/8` and `adaptive_screen_preview/2` must remain controller-owned.
  - `lib/oli_web/components/layouts/page.html.heex` currently renders legacy Page Discussion when collaboration space is enabled.
  - `lib/oli_web/live/delivery/student/lesson_live.ex` and `student_delivery_lesson.html.heex` contain useful modern shell patterns but are attempt/progress-oriented and should not be reused wholesale.
  - `OliWeb.LiveSessionPlugs.InitPage.previous_next_index/4` and related lesson helpers show how student delivery resolves previous/current/next descriptors, but the preview route requires a different URL builder.
  - `OliWeb.Delivery.Student.Lesson.Components.OutlineComponent` currently builds page links with `Utils.lesson_live_path/3`, which is correct for learner lesson mode but would incorrectly leave Instructor View if reused unchanged.
  - `OliWeb.Delivery.Student.Lesson.Annotations.search_results/1` can build a `Go to Page` link with `/sections/:section_slug/lesson/:resource_slug`; any preview use of that link must also be route-mode-aware.
  - `OliWeb.LiveSessionPlugs.SetPreviewMode` assigns `preview_mode` from `live_action == :preview` for existing preview LiveViews, but it does not carry origin-specific return labels or destinations.
  - `MER-5618` added activity preview infrastructure under `lib/oli/rendering/activity`, `PageDeliveryController`, and `assets/src/components/activities/common/preview`.
- Unknowns to confirm:
  - Exact return labels for Overview and Assessment Settings beyond the Figma Customize Content example.
  - Whether all rendered internal content links should be migrated immediately or rely on compatibility redirects for the first implementation slice.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- Router:
  - Add a new LiveView route under the existing section preview scope:
    - `/sections/:section_slug/preview/lesson/:revision_slug`
  - Keep existing controller routes for `/preview/page/:revision_slug`, `/preview/page/:page_revision_slug/adaptive_screen/:revision_slug`, and `/preview/page/:revision_slug/selection/:selection_id`.
- Basic-page preview setup:
  - Extract the basic-page assembly currently in `render_page_preview/3` into a reusable module such as `OliWeb.Delivery.Instructor.PreviewPageContext` or a live-session plug such as `InitPreviewPage`.
  - The setup module resolves section, page revision, previous/next index, numbered revisions, section resource, activity summaries, bibliography entries, effective collaboration settings, objectives, and required scripts.
  - The setup module renders the page with `Oli.Rendering.Context{mode: :instructor_preview}` so `MER-5618` preview elements and legacy fallbacks continue to work.
- Shared navigation helpers:
  - Extract or introduce a pure helper that converts `PreviousNextIndex` descriptors into route data for a requested navigation mode.
  - Student lesson navigation should continue producing `/sections/:section_slug/lesson/:revision_slug`.
  - Basic-page Instructor View navigation should produce `/sections/:section_slug/preview/lesson/:revision_slug`.
  - `preview/learn` return-context handling should preserve `selected_view`, `sidebar_expanded`, and the current page target so the user returns to the same preview learn state.
  - Container preview, adaptive preview, adaptive screen preview, and activity bank selection routes should remain explicit rather than inferred from the basic-page helper.
  - The helper should be safe to use from both the learner lesson surface and the new preview LiveView without pulling in `InitPage` or learner attempt setup.
- LiveView:
  - Add a dedicated LiveView such as `OliWeb.Delivery.Instructor.PreviewLessonLive`.
  - The LiveView consumes the preview setup data, renders the Instructor View shell, pushes required activity scripts, and handles toolbar state for outline and notes.
  - The LiveView must not call `PageContext.create_for_visit/4`, `emit_page_viewed_event/1`, learner attempt transition APIs, scoring APIs, or page trigger finalization behavior.
- Controller:
  - Keep `PageDeliveryController.page_preview/2` as the compatibility and adaptive dispatcher.
  - If the resolved revision is adaptive/advanced, continue current controller rendering.
  - If the resolved revision is a basic page, redirect to `/preview/lesson/:revision_slug`, preserving supported query params.
- Shell components:
  - Introduce small Instructor View shell components for:
    - reusable persistent header with Instructor View pill and return action
    - basic-page content wrapper and title area
    - right-side toolbar containing notes and outline triggers
    - bottom previous/next navigation for preview mode
  - The header component should accept explicit preview return context, for example `%{label: label, path: path}`, and should not infer destination from `preview_mode`.
  - The header should validate or receive only safe internal paths. Missing or invalid return context should fall back to a safe internal destination and generic label.
  - Prefer extracting reusable view components rather than embedding a large template directly in the LiveView.
  - Refactor reusable lesson toolbar components so page links are supplied by the owner or by a route resolver rather than being hardcoded to learner lesson paths.

### 4.2 State & Data Flow
1. A user opens `/sections/:section_slug/preview/lesson/:revision_slug`.
2. Existing preview pipeline plugs load and authorize the section.
3. The preview setup module resolves the revision from the section publication.
4. If the revision is adaptive/advanced, the LiveView should not be used; direct navigation should redirect or render a clear unsupported route behavior, while normal adaptive routes remain on `/preview/page`.
5. For basic pages, setup builds activity summaries using the `MER-5618` preview metadata and renders page HTML through `Oli.Rendering.Page.Html`.
6. The LiveView renders shell HTML around `raw(@html)` with `phx-update="ignore"` for page content when appropriate.
7. Required activity scripts are loaded once for the page from deduped preview/fallback scripts.
8. The preview live-session setup assigns an `instructor_preview_return` value derived from a validated `return_to` query param or a safe fallback before preview LiveViews render.
9. The reusable header renders when preview shell state is active and receives `instructor_preview_return` for its return action.
10. Toolbar state lives in LiveView assigns, following the lesson shell pattern for `:outline`, `:notes`, or no active panel.
11. Outline item links are generated through a route resolver supplied to the outline component; learner lesson mode emits `/lesson`, while preview mode emits `/preview/lesson`.
12. Notes panel page links, including `Go to Page` search-result links if enabled, use the same route-mode-aware resolver.
13. Previous/next descriptors are converted through a shared pure navigation helper configured for preview mode, emitting `/preview/lesson` for basic pages and leaving containers/adaptive decisions explicit.
14. Bottom navigation receives resolved URLs or a route-builder function from the owning LiveView rather than hardcoding `Utils.lesson_live_path/3`.

### 4.3 Lifecycle & Ownership
- The LiveView owns basic-page Instructor View shell rendering and sidebar/toolbar UI state.
- The extracted preview setup module owns basic-page preview data assembly and should be callable from LiveView tests without a controller connection.
- Shared navigation helpers own descriptor-to-URL decisions that are genuinely common between student lesson and Instructor View; they must not own learner lifecycle state.
- `PageDeliveryController` owns adaptive/advanced preview and compatibility redirects only.
- Activity preview rendering remains owned by `Oli.Rendering.Activity.Html` and the `MER-5618` preview components.
- Return-to-origin labeling and destination mapping should be isolated in a small helper so entry-point-specific labels do not spread through templates.
- Later preview workflows, including bank-selection management views, should reuse the same global header and return context while owning their local back-to-page navigation separately.

### 4.4 Alternatives Considered
- Reuse `Delivery.Student.LessonLive` directly:
  - rejected because it is built around learner page context, attempts, progress, survey scripts, page-view events, and assessment lifecycle.
- Reuse the same LiveView strategy used by preview home/learn/schedule/assignments:
  - rejected for this work item because those shared surfaces differ mostly in shell state, routing, offsets, and preview-aware links, while lesson preview also needs a different operational context.
  - basic-page Instructor View must render activities in preview mode and remain free of learner `resource_access`, attempt, progress, submission, and analytics side effects, which makes `LessonLive` a riskier place to thread preview conditionals through.
  - `LessonLive` is also structurally more coupled to learner delivery than the shared preview-shell surfaces: it already splits setup across multiple `mount/3` clauses keyed off `socket.assigns.view`, with distinct initialization paths for practice, graded, adaptive, and related lesson modes.
  - threading Instructor View through that module would therefore not have been a simple shell variation; it would have introduced preview-specific branching into several existing lesson lifecycle entry points that already own script loading, attempts, scoring, review state, collaboration, and other learner-delivery concerns.
  - tactical advantage: a dedicated `PreviewLessonLive` isolates preview-only behavior from the learner lesson lifecycle and reduces the chance of regressions in student delivery while the new shell lands.
  - tactical cost: lesson UI parity is not automatic; when the learner lesson shell changes, preview lesson can drift and may require follow-up updates in a second render path.
  - future option if lesson UI churn remains high: keep separate setup/context owners, but move more of the lesson markup into shared components or a shared HEEx surface so preview and learner modes can diverge on side effects without duplicating as much DOM structure.
- Keep styling the controller template:
  - rejected because Jira comments explicitly chose the LiveView path and the old layout keeps diverging from modern lesson-shell behavior.
- Replace `/preview/page` entirely:
  - rejected because adaptive/advanced preview, adaptive screen preview, and activity bank selection preview still depend on the existing route family.
- Introduce a feature flag:
  - rejected for the PRD because the route migration can be compatibility-preserving and this work item is not scoped as a staged rollout.

## 5. Interfaces
- New route:
  - `GET /sections/:section_slug/preview/lesson/:revision_slug`
  - route owner: `OliWeb.Delivery.Instructor.PreviewLessonLive`
  - satisfies `AC-001`
- Compatibility route:
  - `GET /sections/:section_slug/preview/page/:revision_slug`
  - basic page: redirect to `/sections/:section_slug/preview/lesson/:revision_slug`
  - adaptive/advanced page: existing controller render path
  - satisfies `AC-002` and `AC-004`
- Preserved adaptive screen route:
  - `GET /sections/:section_slug/preview/page/:page_revision_slug/adaptive_screen/:revision_slug`
  - owner remains `PageDeliveryController.adaptive_screen_preview/2`
  - satisfies `AC-005`
- Preserved activity bank route:
  - `GET /sections/:section_slug/preview/page/:revision_slug/selection/:selection_id`
  - owner remains `ActivityBankController.preview/2`
  - satisfies `AC-006`
- Route helper:
  - Add a helper for basic-page Instructor View URLs, for example `InstructorPreviewRoutes.lesson_path/3` or a verified-routes helper local to delivery preview modules.
  - Consumers include Overview, Customize Content, Assessment Settings, previous/next navigation, course content preview opening, assignment/exploration cards, and discussion links.
  - Course Content entry points should route container resources through `learn`/`preview/learn` with `target_resource_id` instead of the deprecated controller container preview surface so both Instructor View and student-facing navigation stay aligned with the NG23 LiveView delivery UI.
  - supports `AC-003` and `AC-011`
- Previous/next navigation helper:
  - Input: section slug, previous/current/next descriptors from `PreviousNextIndex.retrieve/2`, selected mode, and optional return context.
  - Output: display metadata plus resolved previous and next URLs suitable for bottom navigation.
  - Supported modes for this work item: learner lesson and basic-page instructor preview.
  - Non-goal: resolving adaptive screen or activity bank selection URLs through this helper.
  - supports `AC-011` and protects `AC-015`
- Outline and notes route resolver:
  - Input: section slug, page/resource slug, selected mode, selected course view if relevant, and optional return context.
  - Output: a safe internal path for page navigation from right-side panels.
  - In learner lesson mode, output should remain `/sections/:section_slug/lesson/:revision_slug` with existing request-path behavior where needed.
  - In Instructor View preview mode, output should be `/sections/:section_slug/preview/lesson/:revision_slug` and preserve preview return context where needed.
  - The resolver should be passed into `OutlineComponent` and any notes component path that can navigate to another page.
  - supports `AC-003`, `AC-009`, `AC-011`, and protects `AC-015`
- Return context:
  - Query params should support a `return_to` URL whose path is validated as internal and then matched server-side to a supported origin label while preserving the original query params in the rendered link.
  - The header must render a safe internal link and never trust arbitrary external destinations.
  - The return context should be represented separately from `preview_mode`, for example as `instructor_preview_return`.
  - Preview shell navigation must preserve `return_to` across page-to-page transitions so the header does not fall back accidentally after internal navigation.
  - supports `AC-008` and `AC-017`
- Reusable Instructor View header:
  - Input: preview-active state from the owning LiveView/layout, explicit return context, and optional style mode.
  - Output: persistent Instructor View label/pill, accent rule, and safe return action.
  - Consumers in this work item: preview-aware delivery layouts for `/sections/:section_slug/preview` plus basic-page `PreviewLessonLive`.
  - Expected later consumers: entry-point-expanded preview surfaces from `MER-5619` and secondary preview workflows such as bank-selection management from `MER-5622`.
  - supports `AC-016`
- Rendered content contract:
  - Continue passing page HTML rendered from `Oli.Rendering.Context{mode: :instructor_preview}`.
  - Continue loading the page's union of preview and fallback activity scripts.
  - supports `AC-012` and `AC-014`

## 6. Data Model & Storage
- No new database tables or columns are required.
- No new persisted return-to-origin state is required.
- Existing section, revision, activity registration, publication, settings, objective, and collaboration data remain the sources of truth.

## 7. Consistency & Transactions
- Preview setup is read-only request-time assembly and should not introduce transactions.
- Shared navigation helpers must be pure and side-effect-free.
- The redirect from old basic-page routes must be deterministic based on the resolved revision's `advancedDelivery` flag.
- No learner attempt, resource access, progress, or analytics writes are part of this flow.

## 8. Caching Strategy
- No new cache is required.
- Existing section resource depot, activity registration, and resolver behavior should be reused.
- Script selection should be computed from in-memory activity summaries rather than by adding extra queries.

## 9. Performance & Scalability Posture
- The setup module should preserve or improve the current controller query shape by extracting logic without adding per-activity fetches.
- Navigation URL generation should reuse already-resolved previous/current/next descriptors and must not query per navigation item.
- Activity objective title lookup should remain batched.
- LiveView assigns should be kept narrow enough to avoid retaining unnecessary full hierarchy or activity data for the lifetime of the process.
- Large rendered page content should use existing raw HTML and script-loading patterns, not re-render activity components through LiveView diffs.

## 10. Failure Modes & Resilience
- Basic-page old route does not redirect:
  - tests should assert redirect behavior for `AC-002`.
- Adaptive page is accidentally redirected:
  - tests should assert controller render behavior for `AC-004` and `AC-005`.
- New route receives adaptive/advanced revision:
  - prefer redirecting back to the controller adaptive route or returning a controlled unsupported state; do not attempt to render it through the basic-page shell.
- Missing preview metadata for a supported activity:
  - preserve `MER-5618` warning/fallback behavior and keep the page renderable.
- Missing or invalid return context:
  - fall back to a safe section/course-content destination and a generic return label.
- Notes or outline data unavailable:
  - hide or disable the affected toolbar panel rather than failing the page render.

## 11. Observability
- Reuse existing AppSignal and Logger behavior for render-time failures.
- Preserve `MER-5618` warnings for supported activity preview fallback.
- Add narrowly scoped logs only if redirect or setup failures would otherwise be silent.
- Do not emit learner analytics events from the basic-page Instructor View LiveView, supporting `AC-013`.

## 12. Security & Privacy
- The route must run through existing browser, section requirement, section preview authorization, delivery protection, and layout-related plugs equivalent to the current preview scope.
- Return URLs must be validated as internal `return_to` paths and mapped server-side to supported origin labels to prevent open redirects.
- `preview_mode` must not be treated as authorization or as a trusted return destination; it is only a rendering-mode signal.
- The preview setup must not include student attempt data, learner response data, or private learner analytics in the rendered preview context.
- Template-level access must continue using existing author/admin/preview authorization checks.

## 13. Testing Strategy
- Controller tests:
  - basic `/preview/page/:revision_slug` redirects to `/preview/lesson/:revision_slug` for `AC-002`.
  - adaptive/advanced `/preview/page/:revision_slug` remains controller-rendered for `AC-004`.
  - adaptive screen preview remains available for `AC-005`.
  - activity bank selection preview remains controller-owned for `AC-006`.
- LiveView tests:
  - `/preview/lesson/:revision_slug` renders for basic pages for `AC-001`.
  - header, return action, outline/notes toolbar, absence of Page Discussion, page content, instructor resources, and bottom navigation are present for `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-011`, and `AC-012`.
  - reusable header component or helper renders from explicit return context and falls back safely when context is absent or invalid for `AC-016` and `AC-017`.
  - outline item links and notes `Go to Page` links, when rendered, stay in `/preview/lesson` while preview mode is active for `AC-003`, `AC-009`, and `AC-011`.
  - basic-page preview does not create learner attempts, submissions, progress, or learner analytics side effects for `AC-013`.
  - supported and unsupported activities render through preview/fallback behavior for `AC-014`.
- Route producer tests:
  - Overview, Customize Content, Assessment Settings, assignment/exploration cards, course content open-resource behavior, and previous/next links generate `/preview/lesson` for `AC-003`.
  - Preview learn return-state tests verify that `selected_view` and `sidebar_expanded` survive a page open/back cycle.
- Regression tests:
  - student `/sections/:section_slug/lesson/:revision_slug` route and layout remain unchanged for `AC-015`.
- Manual/Figma validation:
  - light and dark header, toolbar, content width, and bottom navigation are compared with Jira Figma nodes.

## 14. Backwards Compatibility
- Existing basic-page `/preview/page/:revision_slug` links remain valid through redirect.
- Adaptive/advanced page preview remains on existing controller routes.
- Adaptive screen and activity bank selection preview routes are unchanged.
- Existing `MER-5618` preview component rendering and fallback behavior remain in place.
- Student-facing lesson routes and content rendering remain unchanged.

## 15. Risks & Mitigations
- Reintroducing learner lifecycle side effects:
  - keep the new LiveView separate from `LessonLive` and verify no attempts/progress writes in tests.
- Incomplete route migration:
  - centralize new route generation and audit producers that currently call `:page_preview`.
- Navigation drift between lesson and preview:
  - share pure descriptor-to-route helpers and test both learner and preview modes.
- Open redirect via return context:
  - validate `return_to` URLs as internal paths only and derive labels from a centralized allowlist of supported origins.
- Visual drift from Figma:
  - run the repo-local `ui_workflow` before implementation and verify with browser review.
- Adaptive regression:
  - preserve controller code paths and add explicit tests before removing any basic-page controller logic.

## 16. Open Questions & Follow-ups
- Confirm exact return labels for Overview and Assessment Settings.
- Decide whether internal content link rewriting should move immediately to `/preview/lesson` or rely on old-route redirects initially.
- Decide whether a future ticket should add `/preview/adaptive_lesson/:revision_slug` for naming symmetry without changing adaptive behavior in `MER-5617`.
- Decide final module placement for the reusable header after inspecting existing delivery layout/component boundaries during implementation.

## 17. References
- `MER-5617`
- `MER-5618`
- `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/requirements.yml`
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/fdd.md`
- `lib/oli_web/router.ex`
- `lib/oli_web/controllers/page_delivery_controller.ex`
- `lib/oli_web/live/delivery/student/lesson_live.ex`
- `lib/oli_web/components/layouts/student_delivery_lesson.html.heex`
- `lib/oli_web/components/layouts/page.html.heex`

## Decision Log

### 2026-06-01 - Preview Learn Return-State Preservation
- Change: Documented the `preview/learn` return-state contract in the route-helper and testing sections.
- Reason: The implementation now preserves the `preview/learn` sidebar and view state when navigating into a page and back, so the FDD should describe that behavior explicitly instead of treating it as incidental preview routing.
- Evidence: `lib/oli_web/live/delivery/student/learn_live.ex`, `lib/oli_web/components/delivery/layouts.ex`, `lib/oli_web/delivery/instructor/preview_routes.ex`, `test/oli_web/live/delivery/student/learn_live_test.exs`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: Route-helper responsibilities are now slightly broader than the original basic-page route redirection work, while still keeping the broader link-producer migration separate.

### 2026-05-29 - Header Component And Return Contract
- Change: Added `FR-007`, `AC-016`, `AC-017`, and interface details for reusable Instructor View header componentry and explicit return context.
- Reason: Epic review showed that entry-point work and secondary bank-selection workflows must share the same persistent Instructor View header while keeping local back navigation separate.
- Evidence: `MER-5619` origin-specific return requirements, `MER-5622` local back requirements, and `OliWeb.LiveSessionPlugs.SetPreviewMode` preview-mode behavior.
- Impact: Implementation must not infer return destination from `preview_mode`; it must pass a validated `instructor_preview_return`-style contract into reusable header componentry.
