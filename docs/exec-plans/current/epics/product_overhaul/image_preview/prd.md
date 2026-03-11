# Image Preview — PRD

## 1. Overview
Feature Name: Image Preview

Summary: Add a template authoring/admin capability that previews cover images exactly as they appear in three production student-facing contexts: My Course, Course Picker, and Welcome page. The implementation must reuse canonical rendering templates/components from runtime surfaces so preview output stays in lockstep with production UI changes.

Links: `docs/epics/product_overhaul/prd.md`, `docs/epics/product_overhaul/overview.md`, `docs/epics/product_overhaul/image_preview/informal.md`, ticket `MER-4052`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Cover image preview behavior is inconsistent and can drift from production student-facing surfaces.
  - Existing approaches that mimic rendering (rather than reusing the same rendering units) are brittle and create maintenance overhead.
- Affected users/roles:
  - Template authors and admins configuring template cover assets.
  - Students indirectly consuming cover image output across entry points.
- Why now:
  - Epic `MER-4032` requires template workflow modernization and consistency as "Product" moves to "Template" semantics.

## 3. Goals & Non-Goals
- Goals:
  - Provide reliable preview rendering for My Course, Course Picker, and Welcome contexts.
  - Ensure preview and runtime fidelity by sharing canonical markup/component boundaries.
  - Prevent future UI drift by construction when destination UIs evolve.
- Non-Goals:
  - Building a screenshot/image compositing pipeline.
  - Redesigning non-cover-image areas of the three destination screens.
  - Changing unrelated publication, enrollment, or course launch behavior.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Institution admin or author managing template cover image settings in Torus authoring/admin surfaces.
  - Student roles in LMS/Torus delivery contexts consuming rendered cards/welcome content.
- Use Cases:
  - An author uploads/edits a cover image and previews how it will appear in My Course before saving.
  - An admin validates appearance across Course Picker and Welcome contexts at desktop/mobile breakpoints.
  - A maintainer updates destination UI markup and preview automatically reflects the update without duplicate changes.

## 5. UX / UI Requirements
- Key Screens/States:
  - Template settings/overview screen with preview mode selector (My Course, Course Picker, Welcome).
  - Empty/fallback image state consistent with destination runtime surfaces.
  - Error state for unavailable/malformed image assets with parity messaging where applicable.
- Navigation & Entry Points:
  - Entry from template management/edit workflow in authoring/admin area.
  - No direct student navigation changes; student views remain destination of shared render components.
- Accessibility:
  - Preview controls keyboard reachable with visible focus indicators.
  - Preview image and related labels use accessible names/alt behavior aligned with destination UI.
  - WCAG 2.1 AA contrast and semantic structure inherited from shared runtime components.
- Internationalization:
  - All new preview labels/help text externalized for localization; no hard-coded user-facing strings.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
Requirements are found in requirements.yml
## 7. Acceptance Criteria
Requirements are found in requirements.yml
## 8. Non-Functional Requirements
- Performance & Scale: Preview context switch p95 <= 400ms after initial data load; initial preview render p95 <= 700ms for standard template payloads; no additional N+1 queries introduced.
- Reliability: Preview failures degrade gracefully with fallback state and actionable logging; no uncaught LiveView crashes from missing assets.
- Security & Privacy: Authorization enforced server-side using existing template permissions; no exposure of cross-institution template data; no sensitive user data logged in preview events.
- Compliance: WCAG 2.1 AA for controls/states; auditability of role-gated access through existing request logs.
- Observability: Telemetry for preview context viewed, preview render duration, and render failure count; AppSignal tagging for feature area `image_preview`.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None expected; reuse existing template cover image fields and associations.
- Context Boundaries:
  - Authoring/admin LiveView(s) for template settings consume shared view-layer rendering units.
  - Shared rendering modules/components reside in UI layer boundaries reusable by both runtime and preview surfaces.
- APIs / Contracts:
  - Internal view/component contract defines required assigns for each context (image URL, title/subtitle metadata, fallback data).
  - Contract must remain backward compatible for current destination surface call sites.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Institution Admin | View/use all preview contexts in template management | Subject to institution scoping |
| Author with template edit rights | View/use preview contexts for authorized templates | Server-side auth required |
| Instructor | No preview authoring access | Student-facing runtime unaffected |
| Student | No preview authoring access | Consumes runtime rendering only |

## 10. Integrations & Platform Considerations
- LTI 1.3: No direct launch-flow contract change; role resolution continues to drive access to authoring/admin surfaces.
- GenAI (if applicable): Not applicable.
- External services: No new external integration.
- Caching/Perf: Reuse existing image delivery/caching posture; avoid duplicate rendering pipelines.
- Multi-tenancy: Preview data strictly scoped by institution/template authorization; shared rendering units must not query outside scoped template context.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - >= 95% successful preview render rate per context after release.
  - < 1% preview-related support issues relative to templates edited.
  - Zero known parity defects between preview and destination surfaces for cover image rendering.
- Events:
  - `template_image_preview_context_selected` with context type.
  - `template_image_preview_rendered` with duration bucket and success.
  - `template_image_preview_render_failed` with error class/category (no PII).

## 13. Risks & Mitigations
- Shared extraction introduces regressions in destination UI -> Add regression tests for each destination surface before/with extraction.
- Hidden coupling in existing templates/components -> Stage refactor by context and verify parity before moving to next context.
- Responsive parity drifts at uncommon breakpoints -> Add explicit breakpoint test matrix and manual QA checklist.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing cover image metadata and URLs are sufficient for all three contexts.
  - No database schema updates are required.
  - Existing authorization primitives for template edit/view can gate preview access.
- Open Questions:
  - Which exact template-management screen should host the preview controls first (overview vs settings pane)?
  - Do we require side-by-side multi-context comparison, or single-context switcher is sufficient for initial release?
  - What are the canonical supported breakpoints for parity sign-off in QA?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Context boundary discovery and shared component extraction plan.
- Milestone 2: My Course context extraction + destination adoption + preview wiring.
- Milestone 3: Course Picker and Welcome extraction/adoption + preview wiring.
- Milestone 4: Telemetry, QA parity pass across breakpoints, and release readiness.

## 16. QA Plan
- Automated:
  - LiveView/controller/component tests validating rendering parity contract for each context.
  - Authorization tests for permitted vs non-permitted roles.
  - Regression tests ensuring destination UI and preview consume same shared component/template path.
  - Telemetry emission tests for success/failure events.
- Manual:
  - Visual parity checks for all three contexts at agreed desktop/mobile breakpoints.
  - Keyboard and screen-reader traversal of preview controls and state changes.
  - Negative tests for missing/invalid image assets.
- Performance Verification:
  - Measure initial render/context-switch timings in test/staging with representative template data; confirm p95 targets.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
