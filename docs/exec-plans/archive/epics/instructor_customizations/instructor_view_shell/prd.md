# Instructor View Shell - Product Requirements Document

## 1. Overview
`MER-5617` updates the basic-page Instructor View shell so instructors, authors, and administrators can review course pages in a modern instructor-facing experience that aligns with the current lesson UI and approved Figma designs. The work introduces a dedicated basic-page Instructor View LiveView route, keeps adaptive preview behavior on the existing controller path, preserves `preview/learn` return-state continuity for the basic-page shell, and limits scope to the page shell around rendered content: header, return action, outline and notes toolbar, legacy discussion removal, and bottom navigation.

## 2. Background & Problem Statement
Instructor View currently renders basic pages through the older controller preview route, `/sections/:section_slug/preview/page/:revision_slug`, and the legacy delivery page layout. That path predates the modern LiveView lesson shell and now diverges from the current course experience. It also displays legacy page discussion UI and lacks the approved Instructor View header and return-to-origin affordance required for instructor customization workflows.

`MER-5618` introduces first-class activity preview components for supported activities but still mounts them inside the controller-based basic-page preview. `MER-5617` should move only the basic-page shell to a LiveView surface while preserving `MER-5618` activity preview rendering and leaving adaptive/advanced page preview routes handled by the existing controller.

## 3. Goals & Non-Goals
### Goals
- Provide a dedicated LiveView route for basic-page Instructor View at `/sections/:section_slug/preview/lesson/:revision_slug`.
- Make all new basic-page Instructor View entry points and in-preview navigation use the new route.
- Preserve `preview/learn` state when an instructor opens a page and returns back to preview learn, including selected view and sidebar expansion.
- Preserve compatibility for old basic-page `/preview/page/:revision_slug` links by redirecting them to the new route when the target is not an adaptive/advanced page.
- Keep adaptive and advanced page preview behavior on the current controller routes.
- Render a persistent Instructor View header that matches the approved Figma direction and includes a dynamic return action.
- Provide the Instructor View header as a reusable shell primitive that later preview surfaces can consume.
- Display the modern outline and notes toolbar behavior for basic-page Instructor View and remove legacy Page Discussion from the shell.
- Keep the existing `MER-5618` activity preview/fallback rendering contract intact.

### Non-Goals
- Redesign adaptive or advanced page preview.
- Move adaptive screen preview routes out of `PageDeliveryController`.
- Change the learner-facing student lesson UI.
- Implement new entry-point surfaces beyond routing existing entry points to the new basic-page Instructor View route.
- Implement remove/restore, activity bank management, jump-to-section, learning-objective counters, or question UI changes owned by adjacent Jira tickets.
- Change activity preview component behavior delivered by `MER-5618`, except where shell integration requires route or script loading adjustments.

## 4. Users & Use Cases
- Instructor: opens a course page from Overview, Customize Content, Assessment Settings, or in-preview navigation to inspect the basic-page experience and instructor-facing resources without creating learner activity.
- Author or admin: reviews a template-level basic page with the same updated Instructor View shell and can return to the originating workflow.
- Product and design reviewer: compares the basic-page Instructor View shell against the approved Figma design for header, toolbar, and bottom navigation.
- Engineering and QA: verifies that basic-page preview moved to LiveView while adaptive preview remains controller-owned and unchanged.

## 5. UX / UI Requirements
- The top Instructor View header must be persistent, visually distinct from the normal delivery header, and support light and dark mode according to Figma.
- The header must show an Instructor View pill/label and a text return action whose label and destination reflect the originating workflow when that context is available.
- The header must be implemented as reusable delivery shell componentry rather than as markup local to `PreviewLessonLive`.
- Preview mode and return context must be represented separately: preview mode controls whether Instructor View shell affordances render, and return context controls the header return action label and destination.
- When return context is missing or invalid, the header must fall back to a safe internal destination and generic return label without disabling the preview shell.
- Basic-page content should align with the modern lesson page layout and preserve instructor-facing resources rendered in page content.
- The right-side toolbar must expose Course Outline and Class Notes when notes are enabled for the course/page.
- Legacy Page Discussion must not be rendered in the basic-page Instructor View shell.
- Bottom previous/next navigation must match the modern Figma direction and link to the new basic-page Instructor View route for basic pages.
- When the origin is `preview/learn`, the return action must preserve the same `selected_view` and `sidebar_expanded` state on the way back.
- The route and shell must be responsive and usable across supported desktop and mobile breakpoints.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: header actions, toolbar buttons, notes and outline toggles, and bottom navigation must be keyboard accessible, expose clear labels, and preserve visible focus.
- Reliability: basic-page Instructor View must not create learner attempts, learner submissions, learner progress, or learner analytics side effects.
- Security: existing Instructor View authorization and section/template access constraints must remain enforced by the route and LiveView setup.
- Performance: the LiveView preview setup should reuse already-required section, revision, activity summary, and script data without adding avoidable per-activity queries.
- Compatibility: existing adaptive preview, adaptive screen preview, activity bank selection preview, and legacy basic-page links must not break during migration.

## 9. Data, Interfaces & Dependencies
- Jira issue: `MER-5617`.
- Depends on `MER-5618` activity preview infrastructure being available on this branch or merged before implementation lands.
- Figma source of truth:
  - updated basic-page view: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=343-2826`
  - header: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=375-6492`
  - dark mode assessment context: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-8433`
- New basic-page route: `/sections/:section_slug/preview/lesson/:revision_slug`.
- Existing controller routes preserved for adaptive/advanced behavior:
  - `/sections/:section_slug/preview/page/:revision_slug`
  - `/sections/:section_slug/preview/page/:page_revision_slug/adaptive_screen/:revision_slug`
  - `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id`
- The LiveView setup should own basic-page preview context assembly or call an extracted shared module rather than depending on controller-private functions.
- The route should accept a `return_to` parameter sufficient to navigate back to the origin workflow.
- The reusable header contract should receive an explicit value such as `instructor_preview_return` containing a safe internal path and an inferred label derived from the validated `return_to` path.
- Existing `preview_mode` assigns remain useful for conditional preview shell rendering, but they are not sufficient to determine the return label or destination.

## 10. Repository & Platform Considerations
- The implementation belongs primarily in `lib/oli_web` routing, LiveView, live-session plugs or setup modules, and delivery layout/components.
- Domain-sensitive behavior such as section authorization and revision resolution must continue to use existing delivery, publishing, and authorization contexts.
- Activity rendering should continue through the `MER-5618` rendering contract in `Oli.Rendering.Context`, `Oli.Rendering.Page.Html`, and activity summaries.
- Basic-page preview must avoid `Oli.Delivery.Page.PageContext.create_for_visit/4` because that learner visit path can create or inspect attempt/progress state inappropriate for Instructor View.
- The new LiveView may share pure navigation helpers and visual components with the modern lesson surface, but it must not reuse the learner `InitPage` setup or any learner lifecycle behavior directly.
- Instructor View header componentry should live at a reusable delivery shell boundary so `MER-5619` entry points and future preview LiveViews can consume it without duplicating markup or return mapping.
- UI implementation must use the repo-local Figma-backed `ui_workflow` before coding visual changes.
- Review should include security and performance by default, plus Elixir, UI, TypeScript, and requirements review where touched files warrant them.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The migration should be route-compatible: old basic-page `/preview/page/:revision_slug` links redirect to `/preview/lesson/:revision_slug`, while adaptive and advanced page preview requests continue to render through the existing controller path.

## 12. Telemetry & Success Metrics
- No new product analytics events are required for Instructor View interactions in this work item.
- Existing logs and AppSignal should continue to surface render failures.
- Success is measured by:
  - basic-page Instructor View entry points and navigation use the new route
  - adaptive/advanced preview still works through the old controller routes
  - no learner-side attempts, submissions, progress, or analytics side effects are introduced
  - visual review confirms the shell matches Figma closely enough to ship

## 13. Risks & Mitigations
- Risk: accidentally migrating adaptive preview into the new basic-page LiveView. Mitigation: keep controller branches and tests explicit for `advancedDelivery` and adaptive screen routes.
- Risk: reusing student `LessonLive` directly could trigger attempt/progress behavior. Mitigation: create a dedicated Instructor View LiveView and setup path that renders preview content without learner lifecycle calls.
- Risk: duplicating lesson navigation logic could create drift between student lesson and Instructor View previous/next behavior. Mitigation: extract or reuse pure descriptor-to-route helpers while keeping learner and preview init paths separate.
- Risk: stale `/preview/page` links remain in rendered content or UI. Mitigation: centralize basic-page preview route generation and redirect old basic-page links.
- Risk: shell work expands into activity question UI or customization actions. Mitigation: keep `MER-5618`, `MER-5620`, `MER-5625`, and `MER-5626` out of scope except for integration compatibility.
- Risk: dynamic return labels and destinations become inconsistent across entry points. Mitigation: define a small `return_to` contract with centralized path-to-label matching and cover each supported origin in tests.
- Risk: future preview surfaces copy the `MER-5617` header instead of reusing it. Mitigation: make reusable header componentry and explicit return context part of this work item's acceptance criteria.

## 14. Open Questions & Assumptions
### Open Questions
- What exact return labels should be used for each origin beyond the Figma examples, especially Assessment Settings and Overview?
- Should old basic-page `/preview/page/:revision_slug` redirects preserve all query parameters, including return context?
- Should rendered internal content links immediately migrate to `/preview/lesson`, or should compatibility redirects handle those links for the first iteration?
- Which concrete module should own the reusable Instructor View header: a general delivery layout component module or a narrower instructor-preview shell component module?

### Assumptions
- `MER-5618` will land substantially as represented by the current branch and can be treated as the activity preview foundation for `MER-5617`.
- `MER-5617` applies only to basic pages; adaptive/advanced page preview remains controller-based.
- Template-level Instructor View uses the same basic-page shell behavior when the target page is not adaptive/advanced.
- Existing authorization plugs for section preview remain the starting point for the new route.
- Return-to-origin can be represented by a `return_to` query parameter or session assigns without introducing new persistence.
- The return context is derived from constrained internal origins or validated internal paths; arbitrary external return URLs are not trusted.

## 15. QA Plan
- Automated validation:
  - LiveView tests for `/preview/lesson/:revision_slug` rendering basic-page Instructor View with header, content, toolbar availability, and bottom navigation.
  - Controller tests proving basic-page `/preview/page/:revision_slug` redirects to `/preview/lesson/:revision_slug`.
  - Controller tests proving adaptive/advanced `/preview/page/:revision_slug` and adaptive screen preview still render through `PageDeliveryController`.
  - Tests proving basic-page preview does not create learner attempts, learner submissions, learner progress, or learner analytics side effects.
  - Tests proving new in-preview previous/next links for basic pages use `/preview/lesson`.
  - Tests proving the Instructor View header component renders from explicit return context and falls back safely when return context is absent or invalid.
  - Targeted Jest or component tests only if new TypeScript behavior is introduced.
- Manual validation:
  - Open Instructor View from Overview, Customize Content, and Assessment Settings for basic pages and confirm return labels/destinations.
  - Compare light and dark shell states against Figma nodes for header, toolbar, content width, and bottom navigation.
  - Confirm Class Notes appears when notes are enabled and legacy Page Discussion is absent.
  - Confirm `preview/learn` back navigation returns to the same selected view and sidebar state.
  - Confirm adaptive preview pages still render through the old route and are not redirected to the basic-page LiveView.

### 2026-06-01 - Preview Learn Return-State Preservation
- Change: Documented the `preview/learn -> preview/lesson -> back` flow as part of the basic-page shell contract, including preservation of `selected_view` and `sidebar_expanded`.
- Reason: The implementation now preserves preview learn state through the reusable return-context and route-builder helpers instead of treating the back path as a generic link.
- Evidence: `lib/oli_web/live/delivery/student/learn_live.ex`, `lib/oli_web/components/delivery/layouts.ex`, `lib/oli_web/delivery/instructor/preview_routes.ex`, `test/oli_web/live/delivery/student/learn_live_test.exs`, `test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs`.
- Impact: The PRD now reflects the actual instructor return flow used by the new preview shell, and the broader link-producer migration remains a separate phase.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## Decision Log

### 2026-05-29 - Reusable Header And Return Context
- Change: Added reusable Instructor View header requirements and separated preview mode from return context.
- Reason: Adjacent epic tickets add entry points and secondary preview workflows that need the same persistent header without redefining exit behavior.
- Evidence: Jira `MER-5619` requires origin-specific return actions; Jira `MER-5622` requires a local back action inside a secondary bank-selection management view.
- Impact: `MER-5617` must implement the header as reusable shell componentry and expose a safe return-context contract for later tickets.
