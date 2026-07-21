# Experiment XAPI And OLAP Foundation - Product Requirements Document

## 1. Overview
Establish the xAPI, ETL, ClickHouse, dataset, and query-contract foundation required for native A/B testing analytics. This slice makes experiment assignment, exposure, outcome, reward, and adaptive policy-update evidence durable through the existing xAPI/S3 path and queryable through ClickHouse without turning PostgreSQL event-history tables into the analytics source. Experiment learner-facing evidence is attached to existing xAPI statements as zero-or-more experiment attribution extensions rather than emitted as a new experiment xAPI object type.

## 2. Background & Problem Statement
Native A/B testing needs trustworthy experiment history for release confidence, research review, dashboards, monitoring, and exports. The runtime telemetry reconciliation slice clarified that PostgreSQL may keep low-volume operational state for delivery correctness, but high-volume experiment history must flow through xAPI JSONL in S3 and ClickHouse. Without this foundation, downstream analytics would either depend on temporary PostgreSQL event-history tables or build reporting on incomplete, inconsistent, or non-replayable telemetry.

## 3. Goals & Non-Goals
### Goals
- Define canonical experiment attribution extensions for existing xAPI statements, including page views, evaluated attempts, and media events that occur inside decision point alternatives.
- Ensure experiment runtime paths emit those statements through existing Torus xAPI emitters without heavy synchronous analytics writes.
- Extend production ETL, local direct ClickHouse upload, and backfill/replay behavior so experiment attributions land in queryable ClickHouse structures.
- Provide ClickHouse schema, a compact attribution projection/table, and approved query contracts for project-level and section-level experiment analytics.
- Integrate experiment attribution data with the existing dataset/export infrastructure.
- Define observability and data-quality checks for emission, attribution extraction, ingest, query, and missing-event failure modes.
- Provide replacement idempotency/runtime contracts and update `priv/repo/migrations/20260625120000_create_experiment_tables.exs` so temporary PostgreSQL exposure, outcome, reward, and policy-update history tables are not part of the final native A/B testing schema.

### Non-Goals
- Build final dashboards or full instructor/research UX beyond the minimum query contracts needed by the analytics slice.
- Provide complex metric-query language parity with UpGrade.
- Decide long-term research warehouse strategy beyond reusing the existing xAPI/S3/ClickHouse path.
- Add new adaptive policies or change Thompson Sampling assignment semantics.

## 4. Users & Use Cases
- Learning engineers and researchers: rely on durable, replayable experiment evidence for downstream analysis.
- Engineers: implement dashboards, reports, monitoring, and exports against approved ClickHouse-backed contracts rather than private PostgreSQL event tables.
- Operators: observe xAPI emission failures, ETL lag, ClickHouse ingest/query failures, and experiment data-quality gaps.
- Authors and instructors: benefit from later analytics surfaces that reflect assignment, exposure, reward, and outcome evidence without affecting learner delivery performance.

## 5. UX / UI Requirements
- N/A

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Experiment xAPI emission must preserve delivery correctness and avoid direct S3, ClickHouse, or expensive analytics work inside learner-facing transactions.
- Existing xAPI statements may carry zero or more experiment attributions. Multiple decision points can be used within one page, activity, or media interaction, so analytics must not assume a single experiment, decision point, condition, or assignment per raw xAPI row.
- ClickHouse-backed query contracts must support scoped reads by institution, project, section, experiment, decision point, condition, learner/enrollment reference where allowed, publication where available, algorithm, policy version, attribution role, host event type, and event timestamp from the attribution projection. Detailed page/resource/activity/media context is read by joining `experiment_attributions.raw_event_hash` back to `raw_events.event_hash`.
- Experiment telemetry must avoid exposing learner names, raw learner responses, LMS identifiers, full request payloads, or unnecessary policy internals in statements, exports, logs, or monitoring metadata.
- Backfill and replay behavior must be deterministic enough to rebuild ClickHouse experiment history from durable xAPI JSONL.
- Reporting and export paths must not query temporary PostgreSQL event-history tables for product analytics.

## 9. Data, Interfaces & Dependencies
- Depends on runtime telemetry reconciliation and its source-of-truth boundary for PostgreSQL, xAPI/S3, and ClickHouse.
- Depends on existing xAPI emitters, S3 JSONL durable storage, Lambda/SQS ETL path, ClickHouse migrations or projections, local direct uploader behavior, backfill tooling, and dataset/export infrastructure.
- Depends on runtime assignment, exposure, reward handoff, and Thompson Sampling policy state from earlier native A/B testing slices.
- Defines experiment attribution contracts for existing xAPI statements. Page-view statements carry exposure attribution, part-attempt statements carry canonical outcome/reward attribution, activity/page-attempt statements may carry rollup attribution, and media statements may carry attribution when the media element is rendered within a decision point alternative.
- Defines policy-update evidence as operational experiment telemetry/projection data rather than learner activity xAPI.
- Defines ClickHouse read contracts for downstream project-level analytics, section-level analytics, monitoring, and dataset exports.

## 10. Repository & Platform Considerations
- Backend changes should preserve the `Oli.Experiments` domain boundary and route analytics-facing reads through approved ClickHouse-backed query modules or read models.
- Existing xAPI pipeline patterns should be reused instead of introducing a separate analytics ingestion path.
- Local development and rebuild workflows must support experiment attributions through direct ClickHouse upload and backfill paths so engineers can validate analytics without production-only infrastructure.
- Code review should include security, performance, backend, and requirements lenses because this work changes telemetry shape, data storage, and analytics access boundaries.
- Jira should track this slice before downstream analytics/dashboard work because those surfaces depend on the query contracts and ClickHouse projections created here.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

- Rollout should sequence xAPI statement contracts, ETL/ClickHouse ingestion, dataset export support, and idempotency replacement before downstream dashboards or reports depend on experiment data.
- Migration work must replace any runtime idempotency or duplicate-update protection still provided by `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`.
- This work item owns updating `priv/repo/migrations/20260625120000_create_experiment_tables.exs` to match the final native A/B testing schema; `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` must not be created by that migration after this slice is complete.

## 12. Telemetry & Success Metrics
- Track experiment attribution emission success/failure, statement validation failures, attribution extraction failures, ETL lag, ingest failures, ClickHouse query failures, dataset export failures, missing exposure/outcome/reward evidence, delayed policy-update evidence, and any fallback to transitional PostgreSQL scaffolding.
- Success is measured by experiment attributions being emitted on existing xAPI events, durably stored, replayable into ClickHouse, queryable through approved contracts, exportable through datasets, and the temporary PostgreSQL event-history tables being removed from the schema.

## 13. Risks & Mitigations
- Risk: xAPI statements omit fields needed for downstream analytics joins. Mitigation: require canonical experiment attribution payloads with stable identifiers, scope fields, timestamps, algorithm fields, policy version, and a parent raw event reference before ETL implementation.
- Risk: Pages, activities, or media interactions contain multiple decision point alternatives, making flat raw-event experiment columns misleading. Mitigation: represent experiment details as an attribution array on the host xAPI statement and project one ClickHouse attribution row per experiment/decision-point assignment.
- Risk: Delivery performance regresses from analytics emission. Mitigation: reuse the existing xAPI pipeline and keep direct S3/ClickHouse work out of learner-facing transactions.
- Risk: Learner privacy is weakened through event metadata or exports. Mitigation: constrain statement payloads and exports to necessary scoped identifiers and exclude raw responses or unnecessary personal data.
- Risk: ClickHouse projections cannot be rebuilt consistently. Mitigation: require local direct upload and backfill/replay support from durable xAPI JSONL.
- Risk: Temporary PostgreSQL event tables become permanent dependencies. Mitigation: enforce query contracts that read from ClickHouse, replace runtime idempotency dependencies, and update the existing native A/B testing migration so those tables are absent from the final schema.

## 14. Open Questions & Assumptions
### Open Questions
- Which existing xAPI host events should receive experiment attribution beyond page views, part attempts, activity attempts, page attempts, and media events?
- Whether later dashboard or export query pressure justifies denormalizing additional host/media/attempt fields into the attribution projection. The current design keeps the attribution projection compact and uses `raw_event_hash` joins for detailed host context.

### Assumptions
- The existing xAPI/S3/ClickHouse path is the strategic analytics pipeline for native experiment history.
- Existing xAPI statements can carry `experiment_attributions` arrays in `context.extensions`; each attribution represents one experiment assignment role such as exposure, outcome, reward, or rollup.
- Media xAPI statements can carry experiment attributions when the media element is part of a selected decision point alternative.
- Runtime telemetry reconciliation has already classified temporary PostgreSQL event-history tables as transitional scaffolding only.
- This slice owns the final removal of `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`.
- Downstream outcome analytics and research visibility will consume the contracts and projections defined here.
- Thompson Sampling current runtime policy state remains in PostgreSQL where needed for assignment, while policy-update history is emitted and served through xAPI/ClickHouse.

## 15. QA Plan
- Automated validation:
  - ExUnit tests for experiment attribution construction on existing xAPI host statements, required fields, privacy constraints, and runtime emission calls.
  - ETL, migration, or integration tests for ClickHouse ingestion/projection behavior where repository tooling supports it.
  - Tests for local direct ClickHouse upload, backfill/replay handling, dataset export inclusion, and ClickHouse-backed query contracts.
  - Regression checks that dashboards, reports, exports, and large aggregate reads do not query temporary PostgreSQL event-history tables.
  - Migration tests or schema assertions verify `priv/repo/migrations/20260625120000_create_experiment_tables.exs` does not create `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates`.
- Manual validation:
  - Run a controlled native experiment and verify assignment, exposure, media attribution where applicable, reward/outcome, and policy-update evidence appears in xAPI output, ClickHouse query results, and dataset exports.
  - Inspect operational telemetry for emission, ingest, lag, query, missing-event, and export failure signals.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes

## Decision Log
### 2026-07-16 - Use Existing xAPI Host Events For Experiment Attribution
- Change: Replaced dedicated experiment xAPI event-type requirements with zero-or-more experiment attribution extensions on existing xAPI statements, including media events inside decision point alternatives.
- Reason: A page can contain multiple independent decision points, so flat single-experiment fields on `page_viewed` would be misleading and a new experiment object type is less semantically aligned with learner telemetry.
- Evidence: Design review in this work item; existing xAPI host events include page views, evaluated attempts, and video/media events.
- Impact: ETL and ClickHouse analytics must extract attribution arrays into attribution-level rows instead of treating `raw_events` as one experiment event per row.

### 2026-07-20 - Keep Attribution Projection Compact
- Change: Refined the ClickHouse attribution projection to keep stable experiment query dimensions and `raw_event_hash` as the parent reference, while leaving detailed host/media/attempt context on `raw_events`.
- Reason: Repeating video URLs, attempt GUIDs, page/activity/part identifiers, and content element details in every attribution row duplicates raw event data and increases schema churn.
- Evidence: Implementation review of `priv/clickhouse/migrations/20260714120000_add_experiment_columns_to_raw_events.sql`, local uploader, backfill SQL, and Lambda ETL extraction.
- Impact: Query contracts filter directly on high-value attribution dimensions and join to `raw_events` when they need detailed host statement context.
