# Outcome Analytics And Research Visibility - Product Requirements Document

## 1. Overview

Define the MVP analytics needed to make each native A/B test understandable from its experiment-specific details page. This slice turns ClickHouse-backed experiment attributions and current runtime policy state into a dedicated Analytics tab for authors and researchers, with useful enrollment, condition, outcome, and adaptive-policy views inspired by UpGrade's Data tab.

## 2. Background & Problem Statement

Native A/B testing replaces UpGrade as the source of experiment behavior. Without native analytics and monitoring, authors, researchers, instructors, and operators cannot verify assignments, exposures, rewards, or adaptive policy behavior. Analytics must use the experiment xAPI/ClickHouse foundation and approved context query APIs rather than coupling directly to private PostgreSQL event persistence.

## 3. Goals & Non-Goals

### Goals

- Report assignment and exposure data by experiment, decision point, condition, project, and section from ClickHouse-backed experiment events.
- Show outcome reporting based on experiment xAPI events joined to existing attempt xAPI data and approved ClickHouse projections.
- Define timestamp and scope semantics for joining assignments, exposures, and attempts.
- Monitor missing exposures, missing outcomes, failed reward updates, assignment imbalance, xAPI emission failures, ETL lag, and ClickHouse query failures.
- Show Thompson Sampling current posterior state plus ClickHouse-backed reward counts, assignment share, policy-update history, and guardrail-triggered pauses.
- Add an Analytics tab to the existing experiment-specific details page; keep experiment configuration and section participation on a separate Configuration tab.
- Provide UpGrade-inspired, Torus-native views:
  - enrollment over time, split by condition;
  - condition-level enrollment and data-quality summaries;
  - condition-level comparison of the existing binary full-credit reward signal;
  - current Thompson Sampling policy state when applicable.
- Allow filters that are meaningful inside one experiment: participating section, condition, event/outcome type, and bounded time range.
- Include experiment data in dataset/download workflows.

### Non-Goals

- Build complex metric-query language parity with UpGrade.
- Reproduce UpGrade's site/experiment navigation or visual design exactly.
- Add arbitrary configured metrics; MVP outcome reporting uses the existing binary full-credit reward signal.
- Add metric display names, selectable statistics, or metric aggregation configuration.
- Model participant exclusions, exclusion reasons, or eligibility-rule outcomes. Missing or delayed experiment evidence may be reported as a data-quality gap, but it must not be labeled as a participant exclusion.
- Calculate or imply statistical significance, confidence intervals, effect sizes, causal estimates, or other statistical inference.
- Build a cross-experiment analytics dashboard.
- Decide long-term warehouse or research-data product architecture beyond dependency-removal needs.
- Monitor advanced adaptive algorithms outside the MVP Thompson Sampling policy.

## 4. Users & Use Cases

- Researchers and learning engineers: inspect experiment outcomes and adaptive policy state.
- Instructors: view release-relevant experiment information where product surfaces expose it.
- Administrators and operators: monitor failed reward updates, missing outcomes, and assignment imbalance.
- Engineers: validate native runtime behavior through approved ClickHouse-backed read models and current runtime policy inspection.

## 5. UX / UI Requirements

- The existing route at `/workspaces/course_author/:project_slug/experiments/:experiment_id` must expose Configuration and Analytics tabs without creating a second experiment identity or top-level analytics destination.
- The Analytics tab must preserve project and experiment authorization already enforced by the details LiveView.
- The initial view should show:
  - participant enrollments over time as a condition-split time-series or stacked column chart;
  - total participants and per-condition counts;
  - a by-condition table with configured weight, assignments/participants, exposures, outcomes/rewards, and data-quality gaps;
  - a condition comparison chart for average binary full-credit reward and sample count, clearly labeled as descriptive rather than inferential;
  - Thompson Sampling posterior/policy information only for adaptive experiments.
- Filters must include participating section, condition, event/outcome type, and a time range. Defaults are all participating sections, all conditions, participant assignment/enrollment, and the experiment's observed lifetime.
- Charts must have an accessible table or textual summary, must not rely on color alone, and must remain usable in light/dark mode and at supported responsive widths.
- Loading, empty, delayed-data, ClickHouse-unavailable, and partial-data states must be distinct. A ClickHouse failure must not make the Configuration tab unavailable.
- Reporting surfaces must distinguish assignments, exposures, outcomes, rewards, and current PostgreSQL-backed posterior state clearly.
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
- Builds on the implemented `experiment_attributions` ClickHouse projection and `Oli.Experiments.ClickHouseAnalytics`; analytics work extends these contracts with time buckets, filter metadata, enrollment/condition summaries, and binary reward comparison data.
- Builds on `OliWeb.Workspaces.CourseAuthor.ExperimentDetailsLive`; the details page becomes tabbed instead of introducing a separate analytics route.
- Depends on lifecycle states that define which experiments appear in reporting.
- Uses analytics-facing context queries or read models rather than direct private PostgreSQL table access.
- Uses ClickHouse as the analytics serving store and xAPI JSONL in S3 as the durable event source for experiment history.

## 10. Repository & Platform Considerations

- Backend analytics reads should be context-owned, scoped, and backed by ClickHouse query APIs or projections.
- UI or LiveView work should reuse existing tabs, charts, tables, filter controls, and async-loading patterns where possible.
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

- What product label should Torus use for assignment-derived unique participants: “participants,” “enrollments,” or “assignments”?
- Which existing chart component should render the enrollment and outcome views, or should the slice introduce one shared component?

### Assumptions

- The experiment xAPI and OLAP foundation is complete before analytics dashboards are built.
- `experiment_attributions` is the MVP ClickHouse fact table; raw event details remain available through `raw_events` joins where necessary.
- PostgreSQL event-history tables have been removed and are not an analytics fallback.
- The assessment binding's normalized scored-page result is thresholded into the sole MVP binary reward signal and identified by `assessment_page:normalized_score`. Its technical reward-source label may be explained with fixed product copy, but there is no configurable metric display-name or statistic model in this slice.
- Charts and summaries are descriptive only. Arbitrary metric configuration, metric metadata/statistics, participant exclusion modeling, and statistical inference are follow-on work.
- Thompson Sampling monitoring is limited to MVP policy evidence.

## 15. QA Plan

- Automated validation:
  - ExUnit tests for scoped ClickHouse-backed analytics queries, read models, timestamp joins, dataset export inclusion, and Thompson Sampling policy-state reporting.
  - Performance-sensitive query tests or review for high-volume reporting paths.
- Manual validation:
  - Verify tab navigation, filters, charts/tables, delayed/empty/error states, assignment, exposure, reward, posterior-state, and ClickHouse evidence for controlled non-adaptive and Thompson Sampling experiments.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## Decision Log

### 2026-07-29 - Make analytics an experiment-details tab backed by ClickHouse

- Change: Defined the Analytics tab, its MVP charts/tables and filters, and the reward/outcome reporting boundary.
- Reason: Product direction now requires analytics inside the new experiment-specific details page and UpGrade-inspired research visibility, while the OLAP foundation has replaced the former PostgreSQL analytics assumptions.
- Evidence: `lib/oli_web/live/workspaces/course_author/experiment_details_live.ex`, `lib/oli/experiments/clickhouse_analytics.ex`, and `docs/exec-plans/current/epics/ab_testing/experiment_olap_foundation/`.
- Impact: UI placement and MVP content are no longer open; the FDD and plan must extend ClickHouse contracts and add a tabbed details experience.

### 2026-07-29 - Limit MVP outcomes to descriptive binary reward analytics

- Change: Deferred arbitrary configured metrics, metric display names/statistics, participant exclusions and exclusion reasons, and statistical inference.
- Reason: The current experiment model provides a binary full-credit reward and experiment evidence, but it does not provide first-class metric definitions, exclusion semantics, or inferential-analysis configuration.
- Evidence: `lib/oli/delivery/experiments/reward_handoff.ex`, `lib/oli/experiments/schemas/experiment_definition.ex`, and `priv/clickhouse/migrations/20260714120000_add_experiment_columns_to_raw_events.sql`.
- Impact: MVP outcome charts compare the existing binary full-credit reward descriptively with sample sizes; data-quality gaps must not be represented as participant exclusions.
