# Instructor View Shell - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/instructor_view_shell/fdd.md`

## Scope
Deliver `MER-5617` as the basic-page Instructor View shell migration. The implementation creates `/sections/:section_slug/preview/lesson/:revision_slug`, moves basic-page preview rendering into a dedicated LiveView, redirects old basic-page `/preview/page/:revision_slug` links, preserves adaptive/advanced controller preview routes, updates basic-page Instructor View link producers, and implements the Figma-aligned shell around `MER-5618` activity preview rendering.

Implementation status:
- Phases 1 through 4 are implemented in code and covered by targeted verification.
- The current shell already preserves `preview/learn` return state, including `selected_view` and `sidebar_expanded`, when instructors open a page and return back.
- Phase 5 remains for any final regression, visual QA, and review-readiness polish.

Out of scope:
- adaptive/advanced preview redesign
- adaptive screen preview route migration
- activity bank selection preview route migration
- learner-facing lesson UI changes
- activity question UI changes owned by `MER-5618`
- remove/restore, counters, jump-to-section, and activity bank management behaviors owned by later tickets

## Clarifications & Default Assumptions
- Basic page means a non-advanced page revision where content does not have `"advancedDelivery" => true`.
- Adaptive/advanced preview remains controller-owned even though the old route name contains `/preview/page`.
- Old basic-page links should redirect to the new route, preserving safe query parameters.
- The first implementation may rely on compatibility redirects for some rendered internal content links if migrating them directly would increase risk.
- Return-origin labels default to safe, explicit values when origin context is absent.
- Preview mode and return context are separate: preview mode controls shell rendering, while return context controls the persistent header's return action.
- The Instructor View header should be reusable by later preview surfaces and must not be implemented as markup local only to `PreviewLessonLive`.
- `MER-5618` preview infrastructure is present on this branch and remains the activity rendering foundation.
- The implementation should share pure previous/next descriptor and route-building helpers with the lesson surface where practical, but it must not share learner `InitPage` setup or learner lifecycle calls.
- The current implementation already covers `preview/learn` state preservation and shell-internal back navigation; Phase 4 is only for the remaining external/basic-page link producers.

### Requirements Traceability
- `FR-001`: Phases 1 and 2 cover `AC-001`.
- `FR-002`: Phases 1, 2, 3, and 4 cover `AC-002`, `AC-003`, and `AC-011`.
- `FR-003`: Phase 1 covers `AC-004`, `AC-005`, and `AC-006`.
- `FR-004`: Phases 3 and 5 cover `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-011`, and `AC-012`.
- `FR-005`: Phases 2 and 5 cover `AC-013` and `AC-015`.
- `FR-006`: Phases 2 and 5 cover `AC-014`.
- `FR-007`: Phases 2, 3, and 5 cover `AC-016` and `AC-017`.

## Phase 1: Route Boundary And Compatibility Dispatch
- Goal: add the explicit basic-page preview route and preserve existing adaptive/advanced controller behavior before moving rendering.
- Tasks:
  - [ ] Add `/sections/:section_slug/preview/lesson/:revision_slug` under the existing section preview scope.
  - [ ] Add a route helper for basic-page Instructor View links.
  - [ ] Identify the existing lesson previous/next route-building code and define the minimal shared pure helper needed by both lesson and preview navigation.
  - [ ] Update `PageDeliveryController.page_preview/2` so basic pages redirect to `/preview/lesson/:revision_slug`.
  - [ ] Keep adaptive/advanced page preview on the existing `PageDeliveryController` render path.
  - [ ] Keep adaptive screen preview and activity bank selection preview routes unchanged.
- Testing Tasks:
  - [ ] Add controller/router tests for basic-page old-route redirect (`AC-002`).
  - [ ] Add controller tests proving adaptive/advanced old-route preview still renders (`AC-004`).
  - [ ] Add coverage for adaptive screen preview route preservation (`AC-005`).
  - [ ] Add coverage that activity bank selection preview remains outside the new LiveView (`AC-006`).
  - Command(s): `mix test test/oli_web/controllers/page_delivery_controller_test.exs`
- Definition of Done:
  - New route exists and can be addressed in tests.
  - Old basic-page preview route redirects.
  - Adaptive/advanced controller preview remains green.
- Gate:
  - `AC-002`, `AC-004`, `AC-005`, and `AC-006` have passing automated coverage before basic rendering moves.
- Dependencies:
  - `MER-5618` branch/base is available.
- Parallelizable Work:
  - Route helper naming and redirect tests can be implemented while LiveView setup design is being prepared.
  - Shared navigation helper extraction can be designed in parallel with redirect behavior, as long as it does not pull in learner `InitPage` state.

## Phase 2: Basic Preview Context Extraction And LiveView Skeleton
- Goal: move basic-page preview data assembly out of the controller and into a LiveView-safe setup path.
- Tasks:
  - [ ] Extract the basic-page assembly from `render_page_preview/3` into a module or live-session plug dedicated to preview setup.
  - [ ] Build `OliWeb.Delivery.Instructor.PreviewLessonLive`.
  - [ ] Define a small return-context assign contract, such as `instructor_preview_return`, with safe fallback behavior.
  - [ ] Use `PreviousNextIndex.retrieve/2` directly or through a shared pure helper, not through learner `InitPage`.
  - [ ] Render basic-page content through `Oli.Rendering.Context{mode: :instructor_preview}` using the extracted setup.
  - [ ] Load the page-level union of preview/fallback activity scripts from `MER-5618`.
  - [ ] Avoid `PageContext.create_for_visit/4`, page viewed events, attempt lifecycle calls, submissions, scoring, and learner progress writes.
  - [ ] Add a controlled behavior if an adaptive/advanced page is requested through `/preview/lesson`.
- Testing Tasks:
  - [ ] Add LiveView tests proving basic pages render at `/preview/lesson/:revision_slug` (`AC-001`).
  - [ ] Add tests proving supported activities use preview elements and unsupported activities use legacy fallback inside the new shell (`AC-014`).
  - [ ] Add no-side-effect tests for attempts, submissions, progress, and learner analytics (`AC-013`).
  - [ ] Add return-context fallback tests proving missing or invalid context does not disable preview shell rendering (`AC-017`).
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli_web/controllers/page_delivery_controller_test.exs`
- Definition of Done:
  - Basic pages render in the new LiveView with activity preview/fallback behavior intact.
  - The controller no longer owns basic-page HTML rendering except redirect compatibility.
- Gate:
  - `AC-001`, `AC-013`, and `AC-014` have passing automated coverage.
- Dependencies:
  - Phase 1 route boundary.
- Parallelizable Work:
  - Activity script loading tests can proceed in parallel with the LiveView skeleton once the setup module returns summaries and scripts.
  - Previous/next descriptor tests can be written against the pure helper before the full shell is styled.

## Phase 3: Instructor View Shell And Toolbar
- Goal: implement the Figma-aligned shell around rendered basic-page content.
- Tasks:
  - [ ] Implement the persistent Instructor View header as reusable delivery shell componentry with pill/label, accent rule, and dark-mode-compatible token usage.
  - [ ] Implement return action rendering from validated origin context.
  - [ ] Add basic-page title/content wrapper aligned with modern lesson layout.
  - [ ] Refactor `OutlineComponent` or wrap it so page links are generated by a supplied route resolver rather than hardcoded learner lesson paths.
  - [ ] Add outline toolbar trigger and panel behavior using preview-mode page links.
  - [ ] Refactor notes page navigation paths, including search-result `Go to Page` links if rendered, to use the same route resolver.
  - [ ] Add Class Notes toolbar trigger and panel behavior when notes are enabled.
  - [ ] Adapt or reuse bottom navigation components by passing resolved preview URLs or a route-builder callback rather than hardcoding learner lesson paths.
  - [ ] Remove legacy Page Discussion from the basic-page Instructor View shell.
  - [ ] Preserve instructor-facing resources embedded in page content.
  - [ ] Run the repo-local `ui_workflow` plan/implement loop for Figma-backed shell fidelity.
- Testing Tasks:
  - [ ] Add LiveView/component assertions for header and return action (`AC-007`, `AC-008`).
  - [ ] Add component or helper assertions proving the header accepts explicit return context and is reusable outside `PreviewLessonLive` (`AC-016`).
  - [ ] Add LiveView assertions for outline and Class Notes availability (`AC-009`).
  - [ ] Add assertions that outline item links stay in `/preview/lesson` in preview mode and remain `/lesson` in student lesson mode (`AC-003`, `AC-009`, `AC-015`).
  - [ ] Add assertions for notes `Go to Page` links if that state is rendered in the preview shell (`AC-009`, `AC-015`).
  - [ ] Add automated assertion that Page Discussion is absent (`AC-010`).
  - [ ] Add bottom navigation assertions that verify preview URL generation while preserving student lesson behavior (`AC-011`, `AC-015`).
  - [ ] Add content assertion for instructor-facing resources (`AC-012`).
  - Command(s): `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- Definition of Done:
  - Basic-page Instructor View shell matches approved design intent closely enough for implementation QA.
  - Header markup and return-action behavior are reusable by later preview LiveViews.
  - Page Discussion is removed only from the new basic-page shell.
- Gate:
  - `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-012`, `AC-016`, and `AC-017` are covered by automated checks plus UI workflow evidence.
- Dependencies:
  - Phase 2 LiveView setup.
- Parallelizable Work:
  - Header and bottom navigation component styling can proceed in parallel after route/context assigns are stable.

## Phase 4: Link Producer Migration
- Goal: update new basic-page Instructor View links to use `/preview/lesson`.
- Note: the shell-internal `preview/learn` return flow and preview-shell bottom navigation are already covered by earlier phases; this phase focuses on the remaining producer surfaces outside the shell.
- Tasks:
  - [x] Update Overview entry points, including latest visited page and course content surfaces.
  - [x] Update Customize Content entry points where preview opens a basic page.
  - [x] Update Assessment Settings entry points where preview opens a basic page.
  - [x] Update assignment, exploration, deliberate practice, discussion, and previous/next basic-page preview links.
  - [x] Decide whether to migrate rendered internal content link rewriting now or rely on old-route redirects for the first slice.
  - [x] Keep adaptive, adaptive screen, and activity bank selection links on their existing routes.
- Testing Tasks:
  - [x] Update affected component and LiveView tests to assert `/preview/lesson` for basic-page Instructor View links (`AC-003`).
  - [x] Add or update previous/next navigation tests for `/preview/lesson` links (`AC-011`).
  - [x] Re-run tests that previously asserted `/preview/page` for basic-page UI links.
  - Command(s): `mix test test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs test/oli_web/components/delivery/assignments/assignment_card_test.exs test/oli_web/components/delivery/exploration_card_test.exs test/oli_web/live/collaboration_live_test.exs`
- Definition of Done:
  - New UI-generated basic-page Instructor View links use `/preview/lesson`.
  - Preserved routes are not accidentally migrated.
- Gate:
  - `AC-003` and `AC-011` have passing automated or hybrid coverage.
- Dependencies:
  - Phase 1 route helper and Phase 2 LiveView route.
- Parallelizable Work:
  - Individual link producer updates can be split by surface after the route helper exists.

## Phase 5: Regression, Visual QA, And Review Readiness
- Goal: verify the complete basic-page shell migration and prepare the branch for review.
- Tasks:
  - [ ] Run targeted backend and LiveView suites from prior phases.
  - [ ] Run targeted frontend tests if any TypeScript source changed.
  - [ ] Run formatting for touched Elixir and frontend files.
  - [ ] Verify student-facing lesson route behavior remains unchanged.
  - [ ] Perform manual browser QA for light and dark Figma states, toolbar behavior, return action, and bottom navigation.
  - [ ] Document any deferred internal-link migration or return-label follow-up.
  - [ ] Document any deferred origin-token additions that belong to `MER-5619`.
- Testing Tasks:
  - [ ] Run targeted LiveView/controller/component tests for `AC-001` through `AC-017`.
  - [ ] Run regression coverage for student lesson behavior (`AC-015`).
  - [ ] Run `mix format`.
  - [ ] Run `yarn --cwd assets test <targeted-tests>` only if frontend files changed.
  - Command(s): `mix test test/oli_web/controllers/page_delivery_controller_test.exs test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`
- Definition of Done:
  - All automated coverage for `AC-001` through `AC-017` passes or has explicit manual verification where marked hybrid.
  - UI workflow evidence exists for Figma-backed shell changes.
  - Security, performance, Elixir, UI, and requirements review scopes are clear for PR review.
- Gate:
  - No known adaptive preview regression, no known learner-side preview side effects, and no known student lesson regression remain.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Manual Figma/browser QA can run while final low-risk link-producer tests are being adjusted.

## Parallelization Notes
- Phase 1 must establish the route boundary before broad implementation starts.
- Phase 2 setup extraction and Phase 3 shell component design can overlap after the setup return shape is stable.
- Shared previous/next route helper work should be done before broad link producer migration so both bottom navigation and entry points use the same route contract.
- Phase 4 link migration can be split by UI surface once a central helper exists.
- Phase 5 visual QA and targeted regression runs can happen in parallel with documentation reconciliation.

## Phase Gate Summary
- Gate A: route boundary is explicit and adaptive/controller compatibility is protected.
- Gate B: basic-page LiveView renders without learner lifecycle side effects.
- Gate C: Instructor View shell matches Figma intent and removes Page Discussion from basic pages.
- Gate D: basic-page link producers use `/preview/lesson` while preserved preview routes remain intact.
- Gate E: targeted automated and hybrid verification covers `AC-001` through `AC-017`.
- Gate F: reusable header and return-context behavior are documented and covered before later entry-point and bank-manager work consumes them.

## Decision Log

### 2026-06-01 - Phase 4 Link Producer Migration
- Change: Marked the phase 4 basic-page link producers as implemented and updated the plan status to reflect the completed `/preview/lesson` migration for page-oriented entry points.
- Reason: The code now routes basic-page preview entry points through the new LiveView route while preserving controller/adaptive routes, and the targeted verification passed for the updated surfaces.
- Evidence: `lib/oli_web/components/delivery/course_content.ex`, `lib/oli_web/components/delivery/deliberate_practice_card.ex`, `lib/oli_web/components/delivery/exploration_card.ex`, `lib/oli_web/components/delivery/assignments/assignment_card.ex`, `lib/oli_web/components/delivery/discussion_activity/discussion_table_model.ex`, `lib/oli_web/live/delivery/student/explorations_live.ex`, `test/oli_web/components/delivery/deliberate_practice_card_test.exs`, `test/oli_web/components/delivery/assignments/assignment_card_test.exs`, `test/oli_web/components/delivery/exploration_card_test.exs`, `test/oli_web/live/delivery/student_dashboard/course_content_live_test.exs`, `test/oli_web/controllers/page_delivery_controller_test.exs`.
- Impact: Phase 4 is now treated as closed for basic-page link producer migration, leaving only final regression/visual QA polish in phase 5.

### 2026-06-01 - Preview Learn Return-State Preservation
- Change: Documented that the implementation already preserves `preview/learn` state through back navigation and narrowed Phase 4 to the remaining non-shell producers.
- Reason: The code now keeps `selected_view` and `sidebar_expanded` stable across the preview learn back path, so the plan should not imply that this shell-internal behavior is still pending.
- Evidence: `lib/oli_web/live/delivery/student/learn_live.ex`, `lib/oli_web/components/delivery/layouts.ex`, `lib/oli_web/delivery/instructor/preview_routes.ex`, `test/oli_web/live/delivery/student/learn_live_test.exs`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: Phase 4 is now scoped to the remaining external/basic-page link producers only, while phases 1 through 3 remain the completed shell migration slice.

### 2026-05-29 - Plan For Reusable Header Contract
- Change: Added phase tasks, tests, gates, and traceability for reusable Instructor View header componentry and explicit return context.
- Reason: The implementation plan must produce shell behavior that `MER-5619` and `MER-5622` can consume without reworking `MER-5617`.
- Evidence: Epic ticket review across `MER-5619` and `MER-5622`; PRD/FDD updates in this work item.
- Impact: Phases 2 and 3 now include return-context setup and reusable header testing before broad link-producer migration.
