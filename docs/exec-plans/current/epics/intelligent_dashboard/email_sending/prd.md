# Email Sending — PRD

## 1. Overview
Feature Name: Email Sending

Summary: Deliver a context-aware AI email drafting workflow from instructor dashboard entry points so instructors can send relevant outreach without leaving their current workflow. The feature provides AI-generated subject/body templates, explicit regeneration controls, deterministic placeholder personalization, and explicit send controls through the existing Torus email delivery path.

Links: `docs/epics/intelligent_dashboard/email_sending/informal.md`, `docs/epics/intelligent_dashboard/prd.md`, `docs/epics/intelligent_dashboard/edd.md`, `https://eliterate.atlassian.net/browse/MER-5257`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors need to manually draft outreach and copy context from multiple dashboard surfaces.
  - Existing email flows are not consistently aware of dashboard initiation context (student subset, assessment/content signal, performance/deadline cues).
  - Without deterministic placeholder realization, personalization quality and message consistency are fragile.
- Affected users/roles:
  - Instructors using Learning Dashboard student-support and assessment workflows.
  - Students receiving instructor outreach.
- Why now:
  - Epic `MER-5198` requires actionable AI-assisted outreach tied to scoped dashboard insights (`MER-5257`) and aligned with dashboard data/oracle architecture.

## 3. Goals & Non-Goals
- Goals:
  - Provide a reusable Draft Email modal callable from supported instructor dashboard locations.
  - Generate context-aware AI subject/body templates from a normalized context contract and selected tone.
  - Require explicit instructor action for regeneration and send.
  - Resolve supported placeholders per recipient before dispatch and avoid leaking resolvable raw tokens.
  - Send through existing Torus email delivery jobs with actionable success/failure feedback.
- Non-Goals:
  - Autonomous/scheduled email sending.
  - Student-facing authoring of AI outreach.
  - New outbound email provider integration.
  - Feature-flag rollout mechanics.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor role in section-scoped instructor dashboard context (LTI-authorized instructor flows).
- Use Cases:
  - Instructor opens Email from Student Support tile for struggling students and receives a neutral contextual draft.
  - Instructor opens Email from Assessments tile for incomplete assessment students and receives context-specific subject/body.
  - Instructor edits recipients, subject, body, and links, then sends explicit outreach.
  - Instructor selects a different tone and clicks `Generate new draft` to replace the current subject/body.

## 5. UX / UI Requirements
- Key Screens/States:
  - Draft Email modal titled `Draft Email` with recipient chips, subject, body, tone controls, `Generate new draft`, and `Send`.
  - Loading state for initial draft generation and regenerate action.
  - Validation/error states for empty recipients, invalid required fields, generation failure, and send failure.
  - Success banner state: `Email sent` after successful enqueue/dispatch path.
- Navigation & Entry Points:
  - Supported entry points include Student Support tile, Assessments tile, Student Overview, Content -> Student list, Learning Objectives -> Student list, and other dashboard-supported student-email actions.
  - Opening/closing modal does not navigate away from originating dashboard context.
- Accessibility:
  - Modal uses dialog semantics, trapped focus, Escape-to-close, and focus return to launcher.
  - Recipient chips are keyboard reachable/removable with announced updates for assistive technology.
  - Tone controls expose selected state; validation errors are programmatically linked and announced.
  - Visual truncation must not hide full recipient data from assistive technologies.
- Internationalization:
  - Modal labels, validation messages, and tone labels are externalized/localizable.
  - Placeholder labels and inserted static guidance text are localizable.
- Screenshots/Mocks:
  - Figma and Jira attachments referenced in `docs/epics/intelligent_dashboard/email_sending/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale:
  - Initial draft generation and regenerate actions should provide visible progress state within 200ms and complete within existing GenAI completion service SLOs for instructor dashboard flows.
  - Per-recipient send pipeline must process in bounded linear behavior with respect to recipient count and avoid N+1 personalization lookups.
- Reliability:
  - Draft generation timeout/failure must degrade gracefully without closing modal.
  - Send pipeline must return deterministic success/failure outcomes and avoid silent partial success reporting.
- Security & Privacy:
  - Only authorized instructors can access/send from section-scoped context.
  - Prompt inputs/logging must avoid unnecessary PII exposure; sensitive fields are redacted in error logs/telemetry payloads.
  - Placeholder substitution must be whitelist-based and non-evaluative.
- Compliance:
  - WCAG 2.1 AA keyboard and screen-reader requirements for modal interactions.
  - Auditability of send action (actor, section, recipient count, timestamp, outcome).
- Observability:
  - Emit telemetry for modal_opened, draft_generated, draft_regenerated, send_attempted, send_succeeded, send_failed, and validation_blocked with section + entry-point + situation key dimensions.
  - Track generation latency and send outcome counters for AppSignal dashboards/alerts.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None required for baseline workflow unless implementation introduces persisted draft/session state.
- Context Boundaries:
  - Instructor dashboard non-UI domain service for context building, prompt composition, generation facade, and template realization.
  - LiveView/UI modal for interaction state and user edits.
- APIs / Contracts:
  - Context Builder input: section slug/id, entry-point metadata, selected students/filters.
  - Context Builder output: normalized email generation context including situation contract and personalization-ready recipient fields.
  - Generation Facade input: normalized context + tone + prompt template contract.
  - Generation Facade output: `subject_template`, `body_template`.
  - Send Pipeline input: edited templates + resolved recipient list + instructor/section context.
  - Send Pipeline output: enqueue/send result summary (recipient counts, failures if any).
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Open modal, edit recipients/subject/body, regenerate draft, send email | Section-scoped and entry-point authorized |
| Student | None | No access to instructor dashboard email tooling |
| Institution Admin | Same as instructor only when acting in authorized instructional context | Must satisfy section permissions |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Reuses existing instructor authorization context for dashboard routes and actions.
- GenAI (if applicable):
  - Uses existing synchronous completion generator through a thin instructor-dashboard facade.
  - Prompt assembly includes situation/tone/personalization constraints and deterministic output schema.
  - Fallback behavior returns recoverable error to UI when generation fails.
- External services:
  - Existing outbound email delivery integration path only; no new provider.
- Caching/Perf:
  - Reuse dashboard context/oracle-derived data where possible to avoid repeated expensive reads across entry points.
- Multi-tenancy:
  - Context building, generation inputs, and send dispatch are strictly bounded to the current section/institution authorization context.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - `% of modal opens that produce initial draft successfully`.
  - `% of send attempts that succeed without validation or delivery errors`.
  - `Median time from modal open to successful send`.
  - `% of sends where context-specific situation token is present in generated output quality review samples`.
- Events:
  - `instructor_dashboard.email_draft_opened`
  - `instructor_dashboard.email_draft_generated`
  - `instructor_dashboard.email_draft_regenerated`
  - `instructor_dashboard.email_send_attempted`
  - `instructor_dashboard.email_send_succeeded`
  - `instructor_dashboard.email_send_failed`
  - `instructor_dashboard.email_validation_blocked`

## 13. Risks & Mitigations
- Weak contextual relevance across entry points -> enforce stable situation contract and shared context-builder service with contract tests.
- Placeholder leakage or unsafe substitution -> strict whitelist token replacement and send-path validation tests.
- Accessibility regressions in chip-heavy modal interactions -> add focused keyboard/screen-reader regression coverage and explicit manual a11y script.
- User confusion around tone behavior/regeneration semantics -> explicit UI affordance and tests confirming no auto-regeneration on tone selection.
- Partial dispatch ambiguity on send failures -> return per-recipient result summary and actionable retry messaging.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing Torus email delivery jobs are production-ready for one-job-per-recipient dispatch at expected instructor dashboard scales.
  - Existing GenAI completion stack can support prompt size and latency needs for this workflow.
  - Supported placeholder token set is finalized to the whitelist listed in this PRD unless expanded in follow-up.
- Open Questions:
  - Should manual recipient additions be constrained to enrolled section learners only, or permit arbitrary external email addresses?
  - What maximum recipient count should be enforced per send action for operational safety?
  - What exact fallback copy should appear when generation fails before any draft is produced?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Implement non-UI domain services (context builder, situation contract, prompt composer, generation facade, placeholder realization).
- Milestone 2: Build reusable Draft Email modal with recipient/tone/edit/regenerate behaviors and accessibility semantics.
- Milestone 3: Integrate send pipeline with validation, enqueue/dispatch, and success/error feedback.
- Milestone 4: Complete automated/manual QA, telemetry verification, and acceptance sign-off.

## 16. QA Plan
- Automated:
  - Unit tests for situation contract mapping, prompt composition, and placeholder substitution.
  - LiveView/component tests for modal open state, tone selection semantics, regenerate behavior, recipient chip interactions, validation gating, and focus management.
  - Integration tests for send pipeline dispatch count, authorization scoping, and generation/send error handling.
- Manual:
  - Keyboard-only walkthrough across all primary controls and chip remove/add paths.
  - Screen-reader verification for dialog labeling, dynamic recipient announcements, and validation announcements.
  - Context-quality spot checks across supported entry points (Student Support, Assessments, Student Overview, Content, Learning Objectives) to confirm drafts reflect initiating situation.
  - Risk focus areas: cross-entry-point context fidelity, recipient chip accessibility at overflow, and per-recipient placeholder resolution in final sent content.
- Oli.Scenarios Recommendation:
  - Status: Not applicable
  - Rationale: This feature is primarily instructor-dashboard LiveView/UI plus service orchestration and is better validated through targeted unit, LiveView, and integration tests.
  - Existing Coverage Signal: No existing YAML-driven `Oli.Scenarios` coverage was found for instructor intelligent dashboard email workflows or related tile entry-point interactions.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] If feature flags are required, rollout/rollback posture is documented; otherwise Section 11 contains only the required no-feature-flag statement
