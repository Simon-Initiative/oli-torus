# Template Preview — PRD

## 1. Overview
Feature Name: Template Preview

Summary: Enable template authors and admins to launch a preview for a template by reusing existing section delivery behavior. When a delivery `current_user` is present, the preview flow ensures that user has a student enrollment in the template-backed section and opens the standard student delivery home in a new browser window. When preview is initiated from an author/admin session without a logged-in user account, the flow falls back to the section's singleton hidden instructor account, following the existing admin section-access model.

Links: `docs/exec-plans/current/epics/product_overhaul/overview.md`, `docs/exec-plans/current/epics/product_overhaul/prd.md`, `docs/exec-plans/current/epics/product_overhaul/template_preview/informal.md`, ticket `MER-4053`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Template overview lacks a direct way to verify student delivery experience from authoring/admin context.
  - Manual preview workarounds are slow and can diverge from real delivery behavior.
- Affected users/roles:
  - Authors and institution admins managing templates.
  - Students are indirectly affected by preview quality because template changes depend on correct verification.
- Why now:
  - Epic `MER-4032` requires template workflow modernization and parity with real section behavior while minimizing implementation risk.

## 3. Goals & Non-Goals
- Goals:
  - Add a preview action on Template Overview that launches the real student delivery experience for the template-backed section.
  - Reuse canonical section/delivery routing and rendering so preview fidelity matches production student experience.
  - Ensure enrollment creation is idempotent so repeated preview actions do not create duplicate enrollment rows.
  - Ensure preview remains available for authorized authors/admins who do not have a logged-in delivery user session by reusing the existing hidden-instructor access pattern.
- Non-Goals:
  - Building a separate preview rendering stack.
  - Changing core delivery UI, grading, or learner progression behavior.
  - Introducing new enrollment role types or new launch destinations beyond section student home.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Author with template edit/manage permissions in the owning institution.
  - Institution admin with template management permissions.
- Use Cases:
  - An author clicks Preview from Template Overview for the first time and is auto-enrolled as a student in the template-backed section before delivery opens.
  - The same author clicks Preview again and delivery opens without creating a second enrollment.
  - An admin verifies that preview content matches what a real student sees for the same section.
  - An authorized author without a logged-in user account clicks Preview and the system creates or reuses the section's singleton hidden instructor account so preview can launch without asking the author to choose a learner login.
  - A user clicks Exit Preview from template preview delivery and the system clears preview-session state; if preview was using a hidden instructor account, that hidden user is also removed from the browser session.
  - An authorized author or admin who is left in a hidden instructor session after preview can open Instructor Workspace, inspect the active hidden delivery account, and sign it out before moving to a different section/template preview.

## 5. UX / UI Requirements
- Key Screens/States:
  - Template Overview displays a Preview action for authorized users.
  - Preview click shows loading/disabled state until launch URL resolution completes.
  - Template preview delivery shows a `Preview Mode` header strip with an `Exit Preview` action; exiting clears preview state and logs out the hidden delivery account when one is in use.
  - Error state shows actionable message if enrollment upsert or launch resolution fails.
  - Instructor Workspace exposes the active hidden delivery account and a logout control whenever a hidden instructor session is present, so users can manually clear sticky preview/admin hidden-user state before opening a different section.
- Navigation & Entry Points:
  - Entry point is Template Overview page action area.
  - Destination is the section student home/delivery entrypoint in a new browser window/tab.
- Accessibility:
  - Preview action is keyboard accessible and has a descriptive accessible name.
  - Loading and failure states are announced to assistive technologies.
  - Focus remains predictable on originating page after launch or failure.
- Internationalization:
  - All new labels/messages are localizable via existing i18n pipeline; no hard-coded user-visible strings.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
Requirements are found in requirements.yml
## 7. Acceptance Criteria
Requirements are found in requirements.yml
## 8. Non-Functional Requirements
- Performance & Scale: Preview launch preparation (authorization + enrollment check/upsert + launch URL generation) p95 <= 700ms under normal authoring load; duplicate-click handling remains consistent under concurrent requests.
- Reliability: Enrollment upsert operation is atomic/idempotent and maintains zero duplicate enrollments for `(user_id, section_id, role=student)` across retries; preview launch failure rate <= 1% excluding external browser-popup blocking.
- Security & Privacy: Server-side authorization required for every preview action; tenant and section scoping enforced before enrollment operations; logs avoid PII payloads.
- Compliance: WCAG 2.1 AA for preview action and status messaging; auditability of enrollment creation/reuse and preview launch events.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No new schema or migration required.
  - Reuse existing enrollment schema/constraints and section-template association.
- Context Boundaries:
  - Template Overview LiveView/controller handles preview action dispatch.
  - Delivery/sections context resolves launch route and section scoping.
  - Enrollment context performs student-enrollment check/upsert.
- APIs / Contracts:
  - Add preview handler contract from Template Overview to backend action with inputs: `template_section_id`, `current_user`, `current_author`.
  - Enrollment helper contract returns one of: `{:ok, :created}`, `{:ok, :reused}`, `{:error, reason}` for the current-user learner path.
  - Hidden-instructor helper contract returns one of: `{:ok, :created}`, `{:ok, :reused}`, `{:error, reason}` for the section-scoped singleton hidden instructor fallback.
  - Launch resolver establishes the correct preview session for the chosen identity and redirects to the canonical section delivery destination.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Institution Admin | View/click Preview, create/reuse own student enrollment, launch student home | Must be authorized for template section institution |
| Author with template manage rights | View/click Preview, create/reuse own student enrollment when `current_user` exists, otherwise create/reuse section hidden instructor fallback, launch preview destination | Scoped to template permissions |
| Instructor without template-manage rights | Not allowed | Delivery role alone does not grant template preview action |
| Student | Not allowed from Template Overview | Student access remains through standard delivery entrypoints |

## 10. Integrations & Platform Considerations
- LTI 1.3: No launch protocol changes; preview uses existing authenticated Torus flow and section delivery routes, including hidden-instructor fallback when no delivery user session exists.
- GenAI (if applicable): Not applicable.
- External services: No new external service integration.
- Caching/Perf: Reuse existing section/delivery path; avoid introducing alternate preview caches that could drift from runtime.
- Multi-tenancy: Section resolution and enrollment upsert must remain institution-scoped and must not allow cross-tenant enrollment creation or launch.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Success Metrics
- KPIs:
  - >= 95% preview launch success for authorized users (excluding browser popup blocks).
  - 0 duplicate student enrollments attributable to preview flow.
  - >= 90% of preview launches complete within NFR p95 latency target.

## 13. Risks & Mitigations
- Popup blockers may prevent window launch -> Open window/tab in direct user-click context and provide fallback link on failure.
- Enrollment race conditions under rapid repeated clicks -> Use idempotent upsert with DB constraint-backed uniqueness and retry-safe logic.
- Authorization edge cases across template vs delivery roles -> Enforce server-side permission checks before enrollment changes and add regression tests for unauthorized roles.
- Hidden-instructor fallback could create ambiguous preview identity if not section-scoped -> Reuse the existing singleton-per-section hidden instructor model and cover create vs reuse paths with regression tests.
- Hidden-instructor sessions persist in browser state and can be wrong for a later section/template -> Surface the active hidden delivery account in Instructor Workspace with a logout affordance so users can manually reset the session before bouncing to another section.

## 14. Open Questions & Assumptions
- Assumptions:
  - Template/product is represented by an existing section entity and can be launched through standard student home route.
  - Existing enrollment uniqueness constraints and context helpers can support idempotent preview upsert without schema change.
  - Existing hidden-instructor section access pattern can be reused for author/admin preview launches that do not have a logged-in delivery user session.
  - Template Overview has a stable action area for adding Preview without broader layout redesign.
- Open Questions:
  - Should preview open in a new tab (`_blank`) or configurable same-tab behavior for accessibility preferences?
  - Should preview support deep-linking to last visited student page, or always open section home for v1?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Confirm Template Overview entrypoint and permission boundaries.
- Milestone 2: Implement enrollment idempotent upsert + launch URL resolution.
- Milestone 3: Wire frontend launch behavior and failure UX.
- Milestone 4: Add regression coverage and release readiness checks.

## 16. QA Plan
- Automated:
  - Authorization tests for Preview visibility and backend access denial.
  - Enrollment upsert tests for create vs reuse paths and duplicate-prevention under repeated requests.
  - Hidden instructor fallback tests for no-`current_user` author/admin launches, including singleton create vs reuse behavior.
  - Integration/LiveView tests validating preview launches to canonical student home URL.
- Manual:
  - Verify first preview click creates enrollment and launches student home.
  - Verify repeated clicks do not create duplicate enrollments.
  - Verify no-`current_user` author/admin preview creates or reuses the hidden instructor fallback and launches without asking for a separate learner login.
  - Verify `Exit Preview` clears template preview session state and logs out the hidden instructor account when preview was launched through hidden-instructor fallback.
  - Verify a hidden instructor session created via preview can be identified and signed out from Instructor Workspace before opening a different section/template.
  - Verify unauthorized users cannot view or invoke Preview.
  - Verify keyboard access, focus behavior, and status/error messaging accessibility.
- Performance Verification:
  - Measure end-to-end launch-prep latency in staging across representative templates and concurrent author actions; confirm p95 target compliance.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)

## Decision Log
- 2026-03-18: Added an explicit no-`current_user` preview requirement. Authorized authors/admins now fall back to the section-scoped singleton hidden instructor model instead of failing for missing delivery identity.
- 2026-03-24: Clarified that hidden-instructor fallback uses persistent browser session state and that the supported workaround for cross-section/template bouncing is the hidden delivery-account logout affordance in Instructor Workspace. Evidence: `lib/oli_web/live/workspaces/instructor/index_live.ex`, `test/oli_web/live/workspaces/instructor_test.exs`.
- 2026-03-24: Clarified that `Exit Preview` also clears the hidden delivery account when template preview is running under the hidden-instructor fallback. Evidence: `lib/oli_web/controllers/products_controller.ex`, `test/oli_web/controllers/products_controller_test.exs`.
