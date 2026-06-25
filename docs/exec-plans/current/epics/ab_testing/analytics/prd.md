# Outcome Analytics And Research Visibility - Product Requirements Document

## 1. Overview
Define the MVP analytics and monitoring requirements needed to make native A/B testing observable for release confidence, instructor/research visibility, and Thompson Sampling review. This slice turns native assignment, exposure, outcome, reward, and policy-state records into approved read surfaces.

## 2. Background & Problem Statement
Native A/B testing replaces UpGrade as the source of experiment behavior. Without native analytics and monitoring, authors, researchers, instructors, and operators cannot verify assignments, exposures, rewards, or adaptive policy behavior. Analytics must use A/B testing context APIs or approved read models rather than coupling directly to private persistence.

## 3. Goals & Non-Goals
### Goals
- Report assignment and exposure data by experiment, decision point, and condition.
- Show outcome reporting based on attempt data and/or explicit experiment events.
- Define timestamp and scope semantics for joining assignments, exposures, and attempts.
- Monitor missing exposures, missing outcomes, failed reward updates, and assignment imbalance.
- Show Thompson Sampling posterior state, reward counts, assignment share, and guardrail-triggered pauses.

### Non-Goals
- Build complex metric-query language parity with UpGrade.
- Decide long-term warehouse or research-data product architecture beyond dependency-removal needs.
- Monitor advanced adaptive algorithms outside the MVP Thompson Sampling policy.

## 4. Users & Use Cases
- Researchers and learning engineers: inspect experiment outcomes and adaptive policy state.
- Instructors: view release-relevant experiment information where product surfaces expose it.
- Administrators and operators: monitor failed reward updates, missing outcomes, and assignment imbalance.
- Engineers: validate native runtime behavior through approved read models.

## 5. UX / UI Requirements
- Reporting surfaces must distinguish assignments, exposures, outcomes, rewards, and posterior state clearly.
- Any instructor-facing view must avoid exposing unnecessary learner data.
- Monitoring views or exports must make delayed/missing rewards and imbalance visible enough for release decisions.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Analytics reads must preserve institution, project, section, user, and enrollment scoping.
- Reporting queries must avoid delivery hot-path regressions and be reviewed for performance.
- Research exports or views must minimize learner data exposure.

## 9. Data, Interfaces & Dependencies
- Depends on A/B testing-owned assignment, exposure, outcome, reward, and policy-state records.
- Depends on lifecycle states that define which experiments appear in reporting.
- Uses analytics-facing context queries or read models rather than direct private table access.
- May integrate with ClickHouse or existing analytics paths only where appropriate for reporting, not as runtime source of truth.

## 10. Repository & Platform Considerations
- Backend analytics reads should be context-owned and scoped.
- UI or LiveView work should reuse existing reporting patterns where possible.
- Telemetry and AppSignal should support operational visibility for failures and latency.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track analytics read failures, missing exposure/outcome counts, reward update failures, assignment imbalance, and Thompson Sampling posterior updates.
- Success is measured by release reviewers being able to verify native non-adaptive and adaptive workflows without private database inspection.

## 13. Risks & Mitigations
- Risk: Reporting joins are ambiguous or misleading. Mitigation: define timestamp and scope semantics explicitly.
- Risk: Analytics couples directly to private experiment tables. Mitigation: require approved context queries or read models.
- Risk: Learner privacy is weakened by research views. Mitigation: scope access and minimize identifiable learner data.

## 14. Open Questions & Assumptions
### Open Questions
- What minimum analytics do researchers, authors, instructors, and administrators need before broad availability?
- Should MVP outcome reporting join existing attempt data or persist explicit experiment event metrics?

### Assumptions
- Native runtime assignment and exposure records are authoritative before analytics dashboards are built.
- Thompson Sampling monitoring is limited to MVP policy evidence.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for scoped analytics queries, read models, timestamp joins, and Thompson Sampling policy-state reporting.
  - Performance-sensitive query tests or review for high-volume reporting paths.
- Manual validation:
  - Verify assignment, exposure, reward, and posterior-state evidence for controlled non-adaptive and Thompson Sampling experiments.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
