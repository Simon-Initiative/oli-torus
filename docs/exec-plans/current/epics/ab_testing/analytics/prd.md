# Outcome Analytics And Research Visibility - Product Requirements Document

## 1. Overview
Define the MVP analytics and monitoring requirements needed to make native A/B testing observable for release confidence, instructor/research visibility, and Thompson Sampling review. This slice turns xAPI/ClickHouse experiment evidence and current runtime policy state into approved read surfaces.

## 2. Background & Problem Statement
Native A/B testing replaces UpGrade as the source of experiment behavior. Without native analytics and monitoring, authors, researchers, instructors, and operators cannot verify assignments, exposures, rewards, or adaptive policy behavior. Analytics must use the experiment xAPI/ClickHouse foundation and approved context query APIs rather than coupling directly to private PostgreSQL event persistence.

## 3. Goals & Non-Goals
### Goals
- Report assignment and exposure data by experiment, decision point, condition, project, and section from ClickHouse-backed experiment events.
- Show outcome reporting based on experiment xAPI events joined to existing attempt xAPI data and approved ClickHouse projections.
- Define timestamp and scope semantics for joining assignments, exposures, and attempts.
- Monitor missing exposures, missing outcomes, failed reward updates, assignment imbalance, xAPI emission failures, ETL lag, and ClickHouse query failures.
- Show Thompson Sampling current posterior state plus ClickHouse-backed reward counts, assignment share, policy-update history, and guardrail-triggered pauses.
- Include experiment data in dataset/download workflows.

### Non-Goals
- Build complex metric-query language parity with UpGrade.
- Decide long-term warehouse or research-data product architecture beyond dependency-removal needs.
- Monitor advanced adaptive algorithms outside the MVP Thompson Sampling policy.

## 4. Users & Use Cases
- Researchers and learning engineers: inspect experiment outcomes and adaptive policy state.
- Instructors: view release-relevant experiment information where product surfaces expose it.
- Administrators and operators: monitor failed reward updates, missing outcomes, and assignment imbalance.
- Engineers: validate native runtime behavior through approved ClickHouse-backed read models and current runtime policy inspection.

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
- Depends on experiment xAPI statements, ClickHouse projections or query contracts, dataset infrastructure, and current runtime policy-state inspection.
- Depends on lifecycle states that define which experiments appear in reporting.
- Uses analytics-facing context queries or read models rather than direct private PostgreSQL table access.
- Uses ClickHouse as the analytics serving store and xAPI JSONL in S3 as the durable event source for experiment history.

## 10. Repository & Platform Considerations
- Backend analytics reads should be context-owned, scoped, and backed by ClickHouse query APIs or projections.
- UI or LiveView work should reuse existing reporting patterns where possible.
- Telemetry and AppSignal should support operational visibility for xAPI emission failures, ETL lag, ClickHouse query failures, data-quality gaps, and latency.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track analytics read failures, missing exposure/outcome counts, reward update failures, assignment imbalance, xAPI emission failures, ETL lag, ClickHouse query failures, and Thompson Sampling posterior updates.
- Success is measured by release reviewers being able to verify native non-adaptive and adaptive workflows without private PostgreSQL event-table inspection.

## 13. Risks & Mitigations
- Risk: Reporting joins are ambiguous or misleading. Mitigation: define timestamp and scope semantics explicitly.
- Risk: Analytics couples directly to private PostgreSQL experiment tables. Mitigation: require approved ClickHouse-backed context queries or read models.
- Risk: Learner privacy is weakened by research views. Mitigation: scope access and minimize identifiable learner data.
- Risk: OLAP evidence lags runtime behavior. Mitigation: surface ETL lag and delayed evidence status distinctly from runtime failures.

## 14. Open Questions & Assumptions
### Open Questions
- What minimum analytics do researchers, authors, instructors, and administrators need before broad availability?
- Which ClickHouse projection/query shape should power project-level dashboards, section-level dashboards, and dataset exports?
- Should MVP outcome reporting join experiment xAPI events to existing attempt xAPI events, emit explicit experiment outcome events, or both?

### Assumptions
- The experiment xAPI and OLAP foundation is complete before analytics dashboards are built.
- PostgreSQL event rows, if retained, are not the source for dashboards or dataset exports.
- Thompson Sampling monitoring is limited to MVP policy evidence.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for scoped ClickHouse-backed analytics queries, read models, timestamp joins, dataset export inclusion, and Thompson Sampling policy-state reporting.
  - Performance-sensitive query tests or review for high-volume reporting paths.
- Manual validation:
  - Verify assignment, exposure, reward, posterior-state, and ClickHouse evidence for controlled non-adaptive and Thompson Sampling experiments.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
