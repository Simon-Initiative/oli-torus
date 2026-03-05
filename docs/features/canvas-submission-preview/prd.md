# Canvas Submission Preview for LTI Grades — PRD

## 1. Overview
Feature Name: Canvas Submission Preview for LTI Grades

Summary: Add Canvas-specific AGS metadata so Canvas Submission Details can open a meaningful preview instead of showing `No Preview Available` for Torus-graded submissions. The preview destination is the existing Torus attempt review experience, with correct permissions for student self-review and instructor/admin review.

Links: Conversation notes (March 5, 2026), `lib/oli/grading.ex`, `lib/oli_web/controllers/page_delivery_controller.ex`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Torus posts standard AGS line item and score payloads, but does not include Canvas-specific submission preview metadata.
  - In Canvas Submission Details, grades posted from Torus can show `No Preview Available`.
  - Torus already has attempt review routes and permission checks, but Canvas does not receive preview linkage.
- Affected users/roles:
  - Students trying to review what was graded from Canvas.
  - Instructors/admins trying to review learner submissions from Canvas Submission Details.
  - Institutions using Canvas as the LMS for Torus LTI 1.3 sections.
- Why now:
  - This closes a high-friction grading/review workflow gap for Canvas-integrated courses and reduces support load around missing submission previews.

## 3. Goals & Non-Goals
- Goals:
  - Enable Canvas Submission Details preview for Torus-graded submissions.
  - Route preview to Torus attempt review pages with role-appropriate authorization.
  - Keep non-Canvas LMS behavior unchanged.
  - Instrument and monitor preview payload generation and preview-launch reliability signals.
- Non-Goals:
  - Define a cross-LMS universal preview behavior beyond IMS AGS standards.
  - Redesign Torus review page UX.
  - Add new grading models or alter score calculations.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Student enrolled in a Canvas-launched Torus section.
  - Instructor or admin with review access in the same section.
  - Torus operators monitoring integration health.
- Use Cases:
  - A student opens Canvas Submission Details and previews the exact Torus attempt review page tied to the posted grade.
  - An instructor opens Canvas Submission Details and reviews the learner attempt through Torus instructor-authorized review flow.
  - Torus posts grades for non-Canvas LMS platforms without sending Canvas-only fields.

## 5. UX / UI Requirements
- Key Screens/States:
  - Canvas Submission Details should display an available preview for Torus-submitted grades when Canvas metadata is present.
  - Torus review page should continue to show existing authorized views for student and instructor/admin roles.
  - Unauthorized review access should keep current Torus not-authorized behavior.
- Navigation & Entry Points:
  - Entry point starts in Canvas Submission Details preview action.
  - Destination is Torus review route for the resolved attempt in the correct section.
- Accessibility:
  - Existing Torus review pages must preserve current keyboard and screen-reader behavior; no accessibility regression is introduced by this feature.
  - Error and not-authorized states remain programmatically conveyed.
- Internationalization:
  - No new learner-facing Torus strings are required for baseline implementation.
  - Any new operational/admin messages introduced during implementation must use existing localization patterns.
- Screenshots/Mocks:
  - None

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: Emit telemetry/AppSignal metrics for AGS post latency and Canvas-extension application rate; alert when grade-post failure rate exceeds 2% over 15 minutes for Canvas sections.
- Reliability: If Canvas extension payload generation fails, Torus still posts standards-compliant AGS scores when possible and records degraded-mode telemetry.
- Security & Privacy: Review URL generation must remain section-scoped and authorization-enforced; no sensitive learner data is embedded in query params; logs redact personally identifiable content.
- Compliance: Existing WCAG 2.1 AA expectations for Torus review surfaces remain intact; review access remains auditable via existing request/log traces.
- Observability: Add telemetry events for extension-applied, extension-skipped (with reason), and preview-url-resolution outcomes; ensure AppSignal tags include platform type and section identifier.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None required for baseline feature.
- Context Boundaries:
  - `Oli.Grading` remains the Torus boundary for AGS line item/score payload composition.
  - Delivery attempt context resolves attempt GUID and review URL source data.
  - Existing review authorization remains in delivery controller/liveview layers.
- APIs / Contracts:
  - AGS line item create/update payload composition must support Canvas-specific extension fields when section LMS is Canvas.
  - AGS score payload composition must support Canvas submission extension fields including preview/review link data.
  - Attempt-to-review-URL resolver contract must return canonical section review URL for the selected attempt.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Student | Preview own reviewed attempt from Canvas into Torus | Must pass existing `can_access_attempt?` checks |
| Instructor | Preview learner attempt from Canvas into Torus | Uses existing instructor authorization path |
| Admin (content/system) | Preview learner attempt from Canvas into Torus | Uses existing admin override behavior |
| Unauthorized user | No review access | Receives current not-authorized behavior |

## 10. Integrations & Platform Considerations
- LTI 1.3: Continue standard AGS score passback while conditionally adding Canvas-specific extension data only for Canvas platform instances.
- GenAI (if applicable): Not applicable.
- External services: Depends on Canvas interpretation of AGS extension metadata; Torus must degrade gracefully if Canvas ignores or rejects extension fields.
- Caching/Perf: No new cache layer required; URL resolution should use existing attempt lookup patterns.
- Multi-tenancy: All attempt lookup and review URL generation must remain section/institution scoped and never cross tenant boundaries.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Canvas sections with successful preview-enabled score submissions >= 98%.
  - Reduction in Canvas `No Preview Available` reports for Torus-posted grades.
  - No increase in unauthorized review access events.
- Events:
  - `lti_ags.canvas_extension_applied`
  - `lti_ags.canvas_extension_skipped`
  - `lti_ags.canvas_preview_url_resolved`
  - `lti_ags.canvas_preview_url_resolution_failed`

## 13. Risks & Mitigations
- Canvas payload expectations may change -> isolate Canvas mapping logic and cover with integration tests against expected JSON contracts.
- Wrong attempt URL can show mismatched attempt -> use deterministic latest-attempt selection contract and add regression tests for multi-attempt scenarios.
- Library-level extension support may be incomplete -> fail safely to standards-only AGS post and surface explicit telemetry for skipped extension behavior.

## 14. Open Questions & Assumptions
- Assumptions:
  - Canvas-specific AGS extension support is available in `lti_1p3` after companion library work.
  - Existing Torus review endpoints are the desired destination for both student and instructor/admin preview entry.
  - Canvas preview behavior is driven by payload metadata and does not require new Torus UI routes.
- Open Questions:
  - Should Torus always use `/sections/:section_slug/review/:attempt_guid` as canonical preview target, or choose a student lesson review route for student launches?
  - For pages with multiple relevant attempts, should preview target latest submitted attempt or latest evaluated attempt?
  - What fallback user-facing behavior is expected in Canvas when preview metadata is rejected?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Finalize Canvas payload contract and Torus attempt URL resolution rules.
- Milestone 2: Implement Torus AGS payload integration with Canvas-specific extension facilities.
- Milestone 3: Add automated coverage and telemetry/AppSignal instrumentation.
- Milestone 4: Validate in Canvas staging and complete release sign-off.

## 16. QA Plan
- Automated:
  - Unit tests for Canvas extension payload builders in Torus grading flow.
  - Integration tests asserting AGS line item/score JSON contains Canvas extension fields only for Canvas sections.
  - Authorization regression tests confirming student/instructor/admin review access behavior remains correct via preview URLs.
  - Telemetry tests for extension applied/skipped and preview URL resolution outcomes.
- Performance Validation:
  - Verify telemetry/AppSignal dashboards for AGS post latency and failure thresholds in staging after deployment.
  - Validate alert wiring for Canvas extension failure/skipped anomaly rates.
- Manual:
  - Validate student preview from Canvas Submission Details opens the expected Torus attempt review page.
  - Validate instructor/admin preview for the same submission opens authorized review successfully.
  - Validate non-Canvas LMS grade passback remains unchanged.
  - Focus areas for manual testing based on risky or hard-to-automate behavior:
    - Cross-role review authorization outcomes when launched from Canvas.
    - Multi-attempt submissions resolving to the intended attempt preview target.
    - Graceful behavior when extension payload is skipped or rejected.
- Oli.Scenarios Recommendation:
  - Status: Suggested
  - Rationale: The feature is primarily integration payload behavior plus existing review workflow access checks. Scenario coverage can help verify end-to-end learner/instructor workflows, but core risk is best covered first by integration and controller/liveview tests.
  - Existing Coverage Signal: Existing `Oli.Scenarios` coverage is present for core learner/instructor workflows in `test/scenarios`, but no explicit Canvas submission-preview scenario was identified.
  - Infrastructure Support Status: Supported
  - Scenario Infrastructure Expansion Required: No
  - Required Scope (AC/workflows): Learner attempt creation/submission and instructor review-access workflow validation at high level, without vendor-specific UI detail assertions.
  - Planned Artifacts: Candidate additions under `test/scenarios/delivery/` with companion runner module in `test/scenarios/` if team elects scenario coverage.
  - Validation Commands: `mix test test/scenarios`
  - Planning Handoff: If scenario coverage is selected in planning, schedule it as additive coverage after core integration tests.
- LiveView Testing Recommendation:
  - Status: Suggested
  - Rationale: No new LiveView is introduced, but review entry behavior and role-based state rendering should keep regression checks where review surfaces are LiveView-driven.
  - Affected UI Surface: `OliWeb.Delivery.Student.ReviewLive` and existing review route integration points.
  - Required Scope (events/states): Authorized vs unauthorized mount paths and role-based review rendering states.
  - Planned Artifacts: Targeted updates to existing review LiveView test modules.
  - Validation Commands: `mix test test/oli_web/live/delivery/student/review_live_test.exs`

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] If feature flags are required, rollout/rollback posture is documented; otherwise Section 11 contains only the required no-feature-flag statement
