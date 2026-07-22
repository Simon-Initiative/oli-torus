# Native Delivery Runtime Replacement - Product Requirements Document

## 1. Overview
Replace learner-facing UpGrade runtime behavior with native A/B testing assignment, exposure, and reward handoff through the A/B testing domain APIs. This slice preserves current alternatives behavior while making native assignment authoritative for delivery.

## 2. Background & Problem Statement
Today, delivery asks UpGrade for a condition, marks applied decision points, stores sticky state in section extrinsics, and logs correctness asynchronously. Native A/B testing must provide equivalent learner-facing behavior without remote UpGrade calls, while adding assignment/exposure/reward records needed by analytics and Thompson Sampling.

## 3. Goals & Non-Goals
### Goals
- Assign learners to native experiment conditions during delivery through domain APIs.
- Reuse sticky native assignment records for repeat visits.
- Record exposures when decision point content is applied.
- Hand off evaluated attempt outcomes as idempotent reward events.
- Preserve fallback behavior when no active native experiment applies.

### Non-Goals
- Build rich authoring lifecycle controls or dashboards.
- Continue UpGrade runtime assignment, mark, or log support after cut-over.
- Implement Thompson Sampling posterior updates beyond the reward handoff contract.

## 4. Users & Use Cases
- Students: see stable alternative content for an experiment without assignment flicker.
- Instructors: deliver sections normally while native experiments apply behind the scenes.
- Learning engineers and researchers: receive reliable assignment, exposure, and outcome data for later analysis.

## 5. UX / UI Requirements
- Student-facing content rendering must match the assigned condition and remain stable across refreshes and later activity attempts.
- When no active native experiment applies, delivery must preserve first-option fallback behavior.
- No new student-facing explanation is required for MVP runtime assignment.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Assignment must be local, transactional, and performant on delivery hot paths.
- Reward handoff must be idempotent so retries do not duplicate rewards.
- Runtime behavior must preserve section, enrollment, institution, and publication scoping.
- Failure modes must preserve safe fallback behavior where appropriate.

## 9. Data, Interfaces & Dependencies
- Depends on native A/B testing domain APIs and persistence.
- Uses delivery enrollment identity, alternatives decision points, evaluated attempts, and publication-backed content.
- Produces assignment, exposure, outcome association, and reward-event records for analytics and Thompson Sampling.

## 10. Repository & Platform Considerations
- Backend logic should live in domain contexts rather than controllers or templates.
- Scenario tests are expected because the workflow spans authoring, publication, section delivery, enrollments, and attempts.
- Oban or existing background processing may be used where reward/outcome work is asynchronous.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track assignment requests, assignment reuse, exposure recording, reward handoff success/failure, and fallback use.
- Success is measured by native delivery running without UpGrade runtime calls and with reliable assignment/exposure/reward records.

## 13. Risks & Mitigations
- Risk: Delivery hot paths become slower. Mitigation: keep assignment local and transactional, and add targeted performance review.
- Risk: Reward events duplicate on retries. Mitigation: require idempotency keys or equivalent unique constraints.
- Risk: Fallback behavior regresses. Mitigation: include first-option fallback tests for inactive or missing experiments.

## 14. Open Questions & Assumptions
### Open Questions
- Should first assignment happen on page render, decision point render, or attempt creation?
- Which evaluated attempt event is the authoritative source for MVP reward handoff?

### Assumptions
- MVP assignment is sticky by enrollment and condition.
- Delivery code consumes domain APIs, not experiment-owned tables.

## 15. QA Plan
- Automated validation:
  - ExUnit and scenario tests for stickiness, weighted assignment, fallback, exposure recording, reward handoff, and project/section gating.
  - Tests for idempotent reward processing after repeated evaluated attempts or retries.
- Manual validation:
  - Validate multiple student users see stable condition content in a native experiment section.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
