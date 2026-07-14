# Runtime Telemetry Reconciliation - Product Requirements Document

## 1. Overview
Reconcile the already-planned or already-implemented native A/B testing runtime work with the scalable telemetry boundary required before analytics development continues. This slice clarifies which experiment data belongs in PostgreSQL for delivery correctness, which experiment history must be emitted as xAPI JSONL to S3, and which reporting paths must be served from ClickHouse.

## 2. Background & Problem Statement
Earlier native A/B testing slices established assignment, exposure, outcome, reward, and Thompson Sampling behavior while some planning still assumed PostgreSQL event logs or aggregates could support later analytics. The updated scalability requirement invalidates that assumption. Without a reconciliation pass, future dashboards, exports, and research reports could deepen coupling to operational tables, create delivery performance risk, and make experiment event history harder to audit through the platform's existing xAPI/S3/ClickHouse analytics path.

## 3. Goals & Non-Goals
### Goals
- Audit A/B testing work from slices 1-5 and classify existing implementation or plans as keep, modify, remove, or defer.
- Make PostgreSQL authoritative only for experiment definitions, lifecycle state, sticky assignment state required for delivery correctness, and current adaptive policy state required for runtime assignment.
- Make xAPI JSONL in S3 the durable event source for assignment, exposure, outcome, reward, and policy-update history.
- Make ClickHouse the analytics serving store for dashboards, reports, monitoring, and dataset exports.
- Update context contracts so delivery can emit experiment xAPI statements while preserving idempotent runtime behavior.
- Quarantine or replace PostgreSQL-heavy event-log and aggregate-reporting assumptions before OLAP foundation and analytics work proceed.
- Require any retained PostgreSQL event-history tables to be removed before the A/B testing MVP slice sequence is complete.

### Non-Goals
- Build new ClickHouse schemas, ETL projections, dashboards, or dataset downloads beyond the contract changes needed to unblock the OLAP foundation slice.
- Redesign authoring lifecycle UI, delivery UI, or student-facing experiment behavior.
- Add new adaptive algorithms or change MVP Thompson Sampling assignment semantics.

## 4. Users & Use Cases
- Engineers: reconcile existing native A/B testing code and plans against clear data ownership rules before building analytics.
- Learning engineers and researchers: rely on durable experiment event history that can later support dashboards, exports, and audit review.
- Operators: avoid high-volume analytics workloads against PostgreSQL and monitor experiment telemetry through the existing observability stack.
- Students and instructors: continue receiving stable delivery behavior while telemetry and analytics boundaries are corrected behind the scenes.

## 5. UX / UI Requirements
- N/A

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Delivery hot paths must remain local, transactional, and idempotent for assignment correctness.
- High-volume experiment history, dashboards, exports, and aggregate reports must not depend on PostgreSQL event-log tables.
- xAPI emission must preserve institution, project, section, publication where available, decision point, condition, enrollment or learner reference where allowed, and idempotency scope without exposing raw learner responses unnecessarily.
- The reconciliation must be reviewable under security and performance lenses because it changes data ownership, reporting boundaries, and telemetry flow.

## 9. Data, Interfaces & Dependencies
- Depends on slices 1-5, including native `Oli.Experiments` APIs, native delivery runtime replacement, authoring lifecycle, and Thompson Sampling policy state.
- Depends on the existing xAPI upload pipeline, S3 JSONL durable storage, ClickHouse analytics infrastructure, dataset/export infrastructure, and AppSignal/telemetry observability.
- PostgreSQL remains authoritative for operational experiment state needed for synchronous delivery and adaptive assignment.
- xAPI JSONL in S3 becomes the durable event history for assignment, exposure, outcome, reward, and policy-update evidence.
- ClickHouse becomes the approved serving store for dashboards, reports, monitoring queries, and dataset exports.

## 10. Repository & Platform Considerations
- Backend reconciliation should preserve the A/B testing context boundary under `lib/oli/` and prevent delivery, authoring, and analytics code from querying experiment-owned persistence directly.
- Any retained PostgreSQL exposure, outcome, reward, or policy-update tables must be explicitly documented as transitional operational scaffolding, not product analytics sources, and must have an explicit removal gate in a later MVP slice.
- Regression tests or review checks should prevent product dashboards, exports, and large aggregates from reading PostgreSQL experiment event tables.
- Scenario or ExUnit coverage should focus on idempotent runtime behavior and xAPI emission contracts; OLAP schema and dashboard verification belongs to the following foundation and analytics slices.
- Jira should track this slice before the experiment OLAP foundation because later analytics work depends on the corrected boundary.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

- Migration notes must classify any existing `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates` usage as retained transitional scaffolding, modified runtime state, removed persistence, or deferred cleanup, and must identify the later MVP slice that removes the tables after replacement idempotency behavior and xAPI/ClickHouse history are proven.
- Rollout should sequence this reconciliation before new ClickHouse projections, dashboards, reports, or dataset exports are implemented.

## 12. Telemetry & Success Metrics
- Track experiment xAPI emission success/failure, idempotency conflicts, fallback to transitional PostgreSQL scaffolding, and any blocked analytics reads that attempt to use operational tables.
- Success is measured by documented source-of-truth ownership, updated context contracts, validated requirements, and downstream OLAP/analytics slices being able to proceed without PostgreSQL event-log assumptions.

## 13. Risks & Mitigations
- Risk: Runtime correctness is weakened by moving too much state out of PostgreSQL. Mitigation: keep sticky assignment and current adaptive policy state in PostgreSQL when required for synchronous delivery correctness.
- Risk: Analytics work continues to query transitional PostgreSQL event tables. Mitigation: add explicit regression checks or review requirements, document transitional tables as non-analytics sources, and require their removal before MVP completion.
- Risk: xAPI emission failures create gaps in durable experiment history. Mitigation: require idempotent emission contracts, operational telemetry, and follow-on OLAP data-quality monitoring.
- Risk: Reconciliation scope expands into full dashboard or ETL implementation. Mitigation: defer ClickHouse schema, ETL projections, dashboards, and exports to the experiment OLAP foundation and analytics slices.

## 14. Open Questions & Assumptions
### Open Questions
- Which of the existing or planned PostgreSQL event tables are still needed as transitional operational scaffolding after xAPI emission is authoritative for history?
- Which runtime actions need synchronous xAPI emission versus background emission through existing pipeline patterns?
- What exact automated check should prevent dashboards, exports, or large aggregate reports from querying PostgreSQL experiment event tables?
- Which later MVP slice should own the final drop migration for `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`?

### Assumptions
- Native A/B testing slices 1-5 have enough implementation or plan detail to audit against this boundary.
- Existing xAPI/S3/ClickHouse infrastructure is the strategic analytics path for experiment history.
- This slice updates contracts and reconciliation notes; the following OLAP foundation slice owns new ClickHouse projections and ETL implementation.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for idempotent assignment, exposure, reward, and policy-update emission contracts where runtime APIs are changed.
  - Tests or static review checks that product dashboards, exports, and large aggregate reads do not query PostgreSQL experiment event tables.
  - Requirements and PRD validation through the harness validation scripts.
- Manual validation:
- Engineering review classifies existing A/B testing implementation and planned tables as keep, modify, remove, or defer.
- Architecture review confirms PostgreSQL, xAPI/S3, and ClickHouse responsibilities are documented before OLAP foundation work begins.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
