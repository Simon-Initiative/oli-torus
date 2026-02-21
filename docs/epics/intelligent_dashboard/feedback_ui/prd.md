# AI Recommendation Feedback UI — PRD

## 1. Overview
Feature Name: AI Recommendation Feedback UI

Summary: Add instructor-facing controls to rate recommendation quality, provide qualitative feedback, and request regenerated recommendations. This feature defines UI behavior and backend integration contracts so feedback and regeneration are reliable, accessible, and state-consistent.

Links: `docs/epics/intelligent_dashboard/feedback_ui/informal.md`, `docs/epics/intelligent_dashboard/summary_tile/prd.md`, `docs/epics/intelligent_dashboard/ai_infra/informal.md`, `https://eliterate.atlassian.net/browse/MER-5250`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Recommendation usefulness cannot be captured in structured or qualitative feedback loops.
  - Regeneration semantics are underspecified at UI level for loading/error and duplicate submissions.
  - Accessibility requirements for icon-only actions and feedback modal need explicit implementation requirements.
- Affected users/roles:
  - Instructors consuming recommendations in Learning Dashboard.
- Why now:
  - Recommendation quality and iterative usefulness depend on quick feedback and regenerate workflows.

## 3. Goals & Non-Goals
- Goals:
  - Provide thumbs-up/down feedback actions for each recommendation instance.
  - Provide additional-feedback modal with free-text submission.
  - Support regenerate action with clear in-flight and failure behavior.
  - Ensure keyboard/screen-reader accessibility for all controls.
- Non-Goals:
  - Redesigning recommendation prompt generation logic.
  - Implementing organization-wide feedback analytics pipelines.
  - Changing summary section layout beyond required control placement.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section-scoped dashboard context.
- Use Cases:
  - Instructor marks recommendation as useful and optionally adds narrative feedback.
  - Instructor marks recommendation as bad and requests alternate recommendation.
  - Instructor receives clear confirmation after submitting additional feedback.

## 5. UX / UI Requirements
- Key Screens/States:
  - Recommendation controls: thumbs up, thumbs down, regenerate.
  - Post-thumb state: show `Additional feedback` action.
  - Additional feedback modal: input, submit, cancel.
  - Regenerate states: idle, thinking, error fallback.
- Navigation & Entry Points:
  - Controls appear within summary recommendation area.
- Accessibility:
  - Icon-only controls expose accessible names.
  - Tooltips available on hover/focus and associated via ARIA.
  - Modal focus trapping, focus return, keyboard-only operation.
  - Submission/error confirmations announced to assistive tech.
- Internationalization:
  - User-facing labels/tooltips/messages externalized for localization.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/feedback_ui/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Duplicate thumbs submissions for same recommendation instance are rejected idempotently.
  - Regeneration failure does not clear last-known recommendation.
- Security & Privacy:
  - Instructor authorization required for feedback/regenerate actions.
  - Free-text feedback sanitized and not logged with PII-rich context.
- Compliance:
  - WCAG 2.1 AA for icon controls, tooltips, and modal semantics.
- Observability:
  - Minimal events: sentiment submitted, additional feedback submitted, regenerate succeeded/failed.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None required in this story if backend contract persists via existing mechanism.
- Context Boundaries:
  - UI components in instructor dashboard.
  - Backend integration via recommendation feedback/regeneration service contract.
- APIs / Contracts:
  - `submit_sentiment(recommendation_id, sentiment)`
  - `submit_additional_feedback(recommendation_id, feedback_text)`
  - `regenerate_recommendation(scope_context, recommendation_id)`
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Submit sentiment, submit additional feedback, regenerate recommendation | Section-scoped access only |
| Student | None | Feature not exposed to students |
| Admin | View/operate in admin-authorized contexts | Same auth controls apply |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Uses existing instructor role and section access rules.
- GenAI (if applicable):
  - Regeneration delegates to recommendation infrastructure; UI remains model-agnostic.
- External services:
  - Qualitative feedback route to configured admin channel integration as defined by backend.
- Caching/Perf:
  - Regen response must invalidate stale recommendation presentation in dashboard state.
- Multi-tenancy:
  - Feedback/recommendation interactions constrained to section context.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Sentiment capture rate per recommendation view.
  - Regeneration success rate.
  - Additional feedback submission completion rate.
- Events:
  - `recommendation.sentiment_submitted`
  - `recommendation.additional_feedback_submitted`
  - `recommendation.regenerate_result`

## 13. Risks & Mitigations
- Modal accessibility regressions -> add explicit accessibility-focused component tests and manual screen-reader checks.
- Duplicate feedback race conditions -> include server-side idempotency by recommendation instance.
- Regenerate failure confusion -> preserve prior content and show explicit fallback messaging.

## 14. Open Questions & Assumptions
- Assumptions:
  - Recommendation instance IDs are available to bind feedback actions.
  - Backend endpoint for admin-channel routing exists in `ai_infra` delivery path.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement feedback controls and state transitions.
- Implement additional feedback modal workflow.
- Integrate regeneration and failure handling.
- Complete accessibility and regression testing.

## 16. QA Plan
- Automated:
  - Component tests for thumbs state transitions and duplicate-prevention behavior.
  - Modal tests: open/submit/cancel/focus trap/focus return.
  - Integration tests for regenerate success/failure handling.
- Manual:
  - Keyboard-only traversal and tooltip verification.
  - Screen-reader validation for icon labels and modal announcements.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
