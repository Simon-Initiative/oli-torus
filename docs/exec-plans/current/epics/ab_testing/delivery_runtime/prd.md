# Native Delivery Runtime Replacement - Product Requirements Document

## 1. Overview
Replace learner-facing UpGrade runtime behavior with native A/B testing assignment, exposure, and reward handoff through the A/B testing domain APIs. This slice preserves current alternatives behavior while making native assignment authoritative for delivery.

## 2. Background & Problem Statement
Today, delivery asks UpGrade for a condition, marks applied decision points, stores sticky state in section extrinsics, and logs correctness asynchronously. Native A/B testing must provide equivalent learner-facing behavior without remote UpGrade calls, while emitting assignment, exposure, outcome, and reward telemetry needed by analytics and Thompson Sampling through the xAPI/ClickHouse path.

## 3. Goals & Non-Goals
### Goals
- Assign learners to native experiment conditions during delivery through domain APIs.
- Reuse sticky native assignment records for repeat visits.
- Emit exposure telemetry when decision point content is applied.
- Hand off evaluated attempt outcomes as idempotent reward events for runtime policy updates and xAPI emission.
- Preserve fallback behavior when no active native experiment applies.

### Non-Goals
- Build rich authoring lifecycle controls or dashboards.
- Continue UpGrade runtime assignment, mark, or log support after cut-over.
- Implement Thompson Sampling posterior updates beyond the reward handoff contract.

## 4. Users & Use Cases
- Students: see stable alternative content for an experiment without assignment flicker.
- Instructors: deliver sections normally while native experiments apply behind the scenes.
- Learning engineers and researchers: receive reliable assignment, exposure, and outcome data through xAPI/ClickHouse for later analysis.

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
- Reward handoff must be idempotent so retries do not duplicate runtime policy updates or experiment telemetry.
- Runtime behavior must preserve section, enrollment, institution, and publication scoping.
- Failure modes must preserve safe fallback behavior where appropriate.

## 9. Data, Interfaces & Dependencies
- Depends on native A/B testing domain APIs and persistence.
- Uses delivery enrollment identity, alternatives decision points, evaluated attempts, and publication-backed content.
- Maintains sticky assignment and current policy state where needed for delivery correctness.
- Emits assignment, exposure, outcome association, and reward events through xAPI for analytics, datasets, and Thompson Sampling audit evidence.

## 10. Repository & Platform Considerations
- Backend logic should live in domain contexts rather than controllers or templates.
- Scenario tests are expected because the workflow spans authoring, publication, section delivery, enrollments, and attempts.
- Oban or existing background processing may be used where reward/outcome work is asynchronous.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track assignment requests, assignment reuse, exposure telemetry emission, reward handoff success/failure, xAPI emission failures, and fallback use.
- Success is measured by native delivery running without UpGrade runtime calls and with reliable runtime state plus xAPI experiment telemetry.

## 13. Risks & Mitigations
- Risk: Delivery hot paths become slower. Mitigation: keep assignment local and transactional, and add targeted performance review.
- Risk: Reward events duplicate on retries. Mitigation: require idempotency keys or equivalent unique constraints for runtime policy updates and emitted xAPI statements.
- Risk: Fallback behavior regresses. Mitigation: include first-option fallback tests for inactive or missing experiments.

## 14. Open Questions & Assumptions
### Open Questions
- Should first assignment happen on page render, decision point render, or attempt creation?
- Which evaluated attempt event is the authoritative source for MVP reward handoff?
- Which delivery runtime writes remain in PostgreSQL for correctness, and which exposure/reward records should be xAPI-only?

### Assumptions
- MVP assignment is sticky by enrollment and condition.
- Delivery code consumes domain APIs, not experiment-owned tables.

## 15. QA Plan
- Automated validation:
  - ExUnit and scenario tests for stickiness, weighted assignment, fallback, exposure telemetry, reward handoff, and project/section gating.
  - Tests for idempotent reward processing after repeated evaluated attempts or retries.
  - Tests or fakes proving experiment xAPI statements are emitted with scoped identifiers and without raw learner responses.
- Manual validation:
  - Validate multiple student users see stable condition content in a native experiment section.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
