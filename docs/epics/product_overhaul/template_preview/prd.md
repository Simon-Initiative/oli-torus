# Template Preview — PRD

## 1. Overview
Feature Name: Template Preview

Summary: Enable template authors and admins to launch a true student-view preview for a template by reusing existing section delivery behavior. The preview flow ensures the current user has a student enrollment in the template-backed section, then opens the standard student delivery home in a new browser window.

Links: `docs/epics/product_overhaul/overview.md`, `docs/epics/product_overhaul/prd.md`, `docs/epics/product_overhaul/template_preview/informal.md`, ticket `MER-4053`

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

## 5. UX / UI Requirements
- Key Screens/States:
  - Template Overview displays a Preview action for authorized users.
  - Preview click shows loading/disabled state until launch URL resolution completes.
  - Error state shows actionable message if enrollment upsert or launch resolution fails.
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
- Security & Privacy: Server-side authorization required for every preview action; tenant and section scoping enforced before enrollment operations; logs and telemetry avoid PII payloads.
- Compliance: WCAG 2.1 AA for preview action and status messaging; auditability of enrollment creation/reuse and preview launch events.
- Observability: Telemetry and AppSignal instrumentation for preview request count, upsert outcome (`created`/`reused`), launch success/failure, and latency distributions.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No new schema or migration required.
  - Reuse existing enrollment schema/constraints and section-template association.
- Context Boundaries:
  - Template Overview LiveView/controller handles preview action dispatch.
  - Delivery/sections context resolves launch route and section scoping.
  - Enrollment context performs student-enrollment check/upsert.
- APIs / Contracts:
  - Add preview handler contract from Template Overview to backend action with inputs: `template_section_id`, `current_user`.
  - Enrollment helper contract returns one of: `{:ok, :created}`, `{:ok, :reused}`, `{:error, reason}`.
  - Launch resolver returns canonical student-home URL for the scoped section.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Institution Admin | View/click Preview, create/reuse own student enrollment, launch student home | Must be authorized for template section institution |
| Author with template manage rights | View/click Preview, create/reuse own student enrollment, launch student home | Scoped to template permissions |
| Instructor without template-manage rights | Not allowed | Delivery role alone does not grant template preview action |
| Student | Not allowed from Template Overview | Student access remains through standard delivery entrypoints |

## 10. Integrations & Platform Considerations
- LTI 1.3: No launch protocol changes; preview uses existing authenticated Torus flow and section delivery routes.
- GenAI (if applicable): Not applicable.
- External services: No new external service integration.
- Caching/Perf: Reuse existing section/delivery path; avoid introducing alternate preview caches that could drift from runtime.
- Multi-tenancy: Section resolution and enrollment upsert must remain institution-scoped and must not allow cross-tenant enrollment creation or launch.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - >= 95% preview launch success for authorized users (excluding browser popup blocks).
  - 0 duplicate student enrollments attributable to preview flow.
  - >= 90% of preview launches complete within NFR p95 latency target.
- Events:
  - `template_preview_requested`
  - `template_preview_enrollment_upserted` (outcome: `created` or `reused`)
  - `template_preview_launch_succeeded`
  - `template_preview_launch_failed` (error_category)

## 13. Risks & Mitigations
- Popup blockers may prevent window launch -> Open window/tab in direct user-click context and provide fallback link on failure.
- Enrollment race conditions under rapid repeated clicks -> Use idempotent upsert with DB constraint-backed uniqueness and retry-safe logic.
- Authorization edge cases across template vs delivery roles -> Enforce server-side permission checks before enrollment changes and add regression tests for unauthorized roles.

## 14. Open Questions & Assumptions
- Assumptions:
  - Template/product is represented by an existing section entity and can be launched through standard student home route.
  - Existing enrollment uniqueness constraints and context helpers can support idempotent preview upsert without schema change.
  - Template Overview has a stable action area for adding Preview without broader layout redesign.
- Open Questions:
  - Should preview open in a new tab (`_blank`) or configurable same-tab behavior for accessibility preferences?
  - Should preview support deep-linking to last visited student page, or always open section home for v1?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Confirm Template Overview entrypoint and permission boundaries.
- Milestone 2: Implement enrollment idempotent upsert + launch URL resolution.
- Milestone 3: Wire frontend launch behavior and failure UX.
- Milestone 4: Add telemetry, regression coverage, and release readiness checks.

## 16. QA Plan
- Automated:
  - Authorization tests for Preview visibility and backend access denial.
  - Enrollment upsert tests for create vs reuse paths and duplicate-prevention under repeated requests.
  - Integration/LiveView tests validating preview launches to canonical student home URL.
  - Telemetry tests for request/success/failure/outcome payloads.
- Manual:
  - Verify first preview click creates enrollment and launches student home.
  - Verify repeated clicks do not create duplicate enrollments.
  - Verify unauthorized users cannot view or invoke Preview.
  - Verify keyboard access, focus behavior, and status/error messaging accessibility.
- Performance Verification:
  - Measure end-to-end launch-prep latency in staging across representative templates and concurrent author actions; confirm p95 target compliance.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
