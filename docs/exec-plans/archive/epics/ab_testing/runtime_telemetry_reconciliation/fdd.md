# Runtime Telemetry Reconciliation - Functional Design Document

## 1. Executive Summary
Reconcile native A/B testing runtime telemetry so PostgreSQL remains the operational authority for delivery correctness while durable experiment event history moves to xAPI JSONL in S3 and product analytics reads move to ClickHouse-backed contracts.

This design satisfies FR-001 through FR-007 by auditing the already-created A/B testing event tables and analytics APIs, keeping `experiment_assignments` and current `experiment_policy_states` as runtime state, treating `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` as temporary scaffolding only, and using existing learner xAPI host statements with `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]` for durable attribution history. Existing PostgreSQL aggregate functions in `Oli.Experiments` are quarantined for operational/debug use and must not power dashboards, reports, or dataset exports.

The simplest adequate approach is not to remove every event table in this reconciliation slice until replacement runtime behavior is proven. The current end state is still removal: `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` must be dropped before the A/B testing MVP slice sequence is considered complete, after xAPI/ClickHouse history and replacement runtime state behavior are proven. This slice documents and enforces the corrected boundary, adds host-statement attribution contracts next to the runtime writes, and adds regression checks so later analytics work cannot deepen PostgreSQL event-log coupling while the temporary tables still exist.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Audit slices 1-5 and classify implementation, persistence, and context contracts as keep, modify, remove, or defer.
  - FR-002: PostgreSQL owns experiment definitions, decision points, conditions, lifecycle state, sticky assignment state, and current adaptive policy state needed for runtime assignment.
  - FR-003: Assignment, exposure, outcome, reward, and policy-update history must be emitted as xAPI statements with JSONL in S3 as durable event source.
  - FR-004: Dashboards, reports, monitoring queries, aggregate analytics, and dataset exports must use ClickHouse-backed read paths, not PostgreSQL experiment event-log tables.
  - FR-005: Delivery-facing A/B testing APIs must emit scoped, idempotent experiment xAPI while preserving runtime correctness.
  - FR-006: Existing or planned experiment exposure, outcome, reward, and policy-update PostgreSQL tables must be classified as transitional scaffolding, modified runtime state, removed persistence, or deferred cleanup, with a final removal path before the A/B testing MVP slice sequence is complete.
  - FR-007: Add tests, static checks, or review requirements that prevent product analytics coupling to PostgreSQL experiment event tables.
- Acceptance criteria mapping:
  - AC-001: Sections 3, 4, 6, and 14 classify the prior slices and affected tables/contracts.
  - AC-002: Sections 4, 6, and 7 define PostgreSQL operational ownership and exclude product analytics history.
  - AC-003: Sections 4, 5, 6, and 11 define xAPI event contracts, identifiers, and idempotency fields.
  - AC-004: Sections 4, 5, 6, and 9 define ClickHouse as the serving store for dashboards, reports, monitoring queries, and exports.
  - AC-005: Sections 4, 7, 10, and 13 define idempotent runtime behavior and duplicate-emission checks.
  - AC-006: Sections 6, 14, and 16 classify `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, `experiment_policy_updates`, and equivalent event-log usage, and identify the later removal gate.
  - AC-007: Sections 5, 13, and 15 define coupling checks and review gates for dashboard/export/aggregate code.
- Non-functional requirements:
  - Delivery assignment and reward update paths remain local, transactional, and indexed.
  - Durable event emission must not add external network calls to the delivery transaction; it uses the existing xAPI pipeline.
  - Event payloads carry scoped identifiers and idempotency keys without raw learner responses.
  - The design must be reviewable under security and performance lenses.
- Assumptions:
  - Slices 1-5 have introduced `Oli.Experiments`, native `experiment_*` tables, delivery assignment/exposure/reward calls, and Thompson Sampling state.
  - The existing xAPI upload pipeline remains the strategic path for S3 JSONL storage and local/direct ClickHouse upload.
  - The following `experiment_olap_foundation` slice owns ClickHouse schema/projection changes, ETL parsing, and dataset/export implementation.
  - No feature flag is added for this reconciliation; rollout is sequencing and review-gate based.

## 3. Repository Context Summary
- What we know:
  - `Oli.Experiments` is the native A/B testing context and currently owns public APIs for assignment, exposure, outcome, reward, lifecycle, authoring, policy-state inspection, and PostgreSQL-backed aggregate reads.
  - `priv/repo/migrations/20260625120000_create_experiment_tables.exs` created `experiment_definitions`, `experiment_decision_points`, `experiment_conditions`, `experiment_assignments`, `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, `experiment_policy_states`, and `experiment_policy_updates`.
  - `experiment_assignments` is required for sticky delivery behavior. `experiment_policy_states` is required for current Thompson Sampling runtime assignment. Definition, decision-point, condition, and lifecycle rows are required for authoring/runtime configuration.
  - `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` currently provide idempotency, reward-to-policy update integrity, and operational inspection, but they must not become durable product analytics history.
  - `Oli.Experiments.experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1` currently query PostgreSQL. These functions need explicit classification before analytics work continues.
  - Existing xAPI infrastructure includes `Oli.Analytics.XAPI.emit/2`, `Oli.Analytics.XAPI.StatementBundle`, Broadway-backed `Oli.Analytics.XAPI.UploadPipeline`, `Oli.Analytics.XAPI.S3Uploader`, local `Oli.Analytics.XAPI.ClickHouseUploader`, schema validation, and ClickHouse backfill tooling.
  - ClickHouse currently has a unified `raw_events` table and direct upload transforms for attempt, page, part, video, and page-view events. Experiment-specific transforms/projections are not in this slice.
  - Dataset generation and exports are owned by `Oli.Analytics.Datasets` and related infrastructure, not by `Oli.Experiments`.
- Unknowns to confirm:
  - Whether experiment xAPI statements should use a new `:experiment` category or split categories such as `:experiment_assignment` and `:experiment_reward`. This design selects `:experiment` to keep pipeline routing simple until the OLAP slice defines projections.
  - Whether every runtime action should emit synchronously to the xAPI Broadway producer or whether some should enqueue an Oban job after commit. This design uses after-success pipeline emission from the context and keeps retry/idempotency in the event contract.
  - Which later MVP slice owns the final drop migration for `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`. This design recommends the final removal gate after `experiment_olap_foundation` proves ClickHouse projections and before `analytics` or `manual_qa` is marked complete.
  - The exact ClickHouse projection names and ETL field extraction rules are deferred to `experiment_olap_foundation`.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` remains the runtime owner. This slice adds a narrow telemetry sub-boundary and changes the analytics-read posture without creating a separate service.

- `Oli.Experiments`: continues to validate scope, create sticky assignments, record temporary exposure/outcome/reward rows while replacement idempotency is being introduced, update current policy state, and return domain receipts.
- `Oli.Experiments.Telemetry`: internal operational telemetry only. It emits `:telemetry.execute/3` metadata for runtime observability and duplicate suppression, not learner xAPI statements.
- `Oli.Experiments.XAPI.Attributions`: builds normalized attribution maps and attaches attribution arrays to existing learner xAPI host statements.
- `Oli.Analytics.XAPI`: unchanged upload boundary used for S3 JSONL and direct local ClickHouse upload.
- `Oli.Analytics.XAPI.Events.Experiment.*`: optional event modules, one per event type, if the implementation follows existing attempt event patterns.
- `Oli.Experiments.AnalyticsQuery` and PostgreSQL aggregate functions: retained only for low-volume operational inspection or temporarily deprecated wrappers. They must not be used by product dashboards, reports, monitoring queries, or dataset exports.
- `Oli.Analytics.ClickhouseAnalytics`, ClickHouse migrations, backfill, and dataset modules: remain the future serving/read infrastructure. This slice defines the handoff contract but does not build new projections.

### 4.2 State & Data Flow
Assignment flow:

1. Delivery calls `Oli.Experiments.assign_condition/1`.
2. `Oli.Experiments` validates scope, reuses or creates `experiment_assignments`, and returns `%AssignmentDecision{}`.
3. Assignment decisions are retained in render context when alternatives are precomputed.
4. Assignment evidence may be represented as operational telemetry. Learner-facing xAPI history is attached to semantic host statements when exposure, outcome, reward, rollup, or media interaction evidence exists.

Exposure flow:

1. Delivery calls `record_exposure/1` after assigned content is applied.
2. PostgreSQL exposure row insertion or receipt reuse preserves runtime idempotency.
3. `Oli.Experiments.XAPI.Attributions` builds an exposure attribution.
4. Delivery emits the existing `page_viewed` statement with the attribution array attached.

Outcome and reward flow:

1. Evaluated attempt reward handoff calls `record_outcome/1` and `record_reward/1`.
2. PostgreSQL outcome and reward rows remain temporary operational records and idempotency guards until replacement idempotency is implemented.
3. Evaluated attempt xAPI generation attaches outcome and reward attributions to the canonical `part_attempt_evaluated` host statement.
4. Activity and page attempt host statements may carry rollup attributions where the rolled-up scope is unambiguous.
5. Reward processing that changes Thompson Sampling state emits compact operational telemetry with previous/next policy state hashes. Policy updates are not modeled as learner xAPI.

Media flow:

1. Video/media xAPI events are built through the existing `Oli.Analytics.XAPI.construct_bundle/2` paths.
2. When the media content element appears inside the learner's selected experiment-backed alternatives branch, the video host statement carries a `media_interaction` attribution.
3. Media attribution is based on existing learner assignment/page content evidence and does not require the experiment to still be active at the later media event timestamp.

Analytics flow:

1. Future dashboards, reports, monitoring queries, and dataset exports call analytics/query APIs backed by ClickHouse from the following OLAP and analytics slices.
2. Any remaining PostgreSQL aggregate reads in `Oli.Experiments` are documented as operational inspection only and tested/reviewed so product analytics callers do not use them.
3. Current policy inspection can still read `experiment_policy_states` directly through `Oli.Experiments` because it is runtime state, not historical analytics.

### 4.3 Lifecycle & Ownership
PostgreSQL ownership:

- Keep: `experiment_definitions`, `experiment_decision_points`, `experiment_conditions`, `experiment_assignments`, `experiment_policy_states`.
- Modify/classify: `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` become temporary operational scaffolding for idempotency, runtime association, retry, and policy-state mutation.
- Remove later: `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` must be dropped after xAPI/ClickHouse projections are proven and replacement runtime idempotency exists. The drop migration is a required MVP completion gate, not optional cleanup.
- Defer: ClickHouse projections, ETL transforms, dataset export fields, and dashboard query APIs to `experiment_olap_foundation` and `analytics`.

xAPI/S3 ownership:

- Durable learner-facing event history for exposures, outcomes, rewards, rollups, and media interactions through attribution arrays on existing host statements.
- Operational assignment and policy-update evidence may be emitted through internal telemetry, but policy updates are not learner xAPI statements.
- Historical reload/backfill source for ClickHouse.

ClickHouse ownership:

- Serving store for dashboards, reports, monitoring, large aggregates, and dataset exports.
- Query contracts and projections are defined in the following slice.

### 4.4 Alternatives Considered
- Remove PostgreSQL event tables immediately: rejected because `experiment_rewards` and `experiment_policy_updates` currently enforce idempotency and prevent duplicate Thompson Sampling posterior updates.
- Keep PostgreSQL aggregate APIs as first analytics release: rejected because the PRD explicitly changes the scalability boundary and later analytics would deepen the wrong coupling.
- Emit xAPI directly from delivery callers: rejected because delivery should not know event shapes or policy internals; `Oli.Experiments` owns runtime receipts and can emit consistently.
- Build ClickHouse schemas in this slice: rejected because this slice is reconciliation and contract work. The next slice owns OLAP implementation.
- Add a new feature flag: rejected because the PRD states no feature flags are present and the safer rollout path is sequencing before analytics work.

## 5. Interfaces
- Internal telemetry boundary:
  - `Oli.Experiments.Telemetry.emit(event, payload, keyword()) :: :ok`
  - This boundary emits internal operational telemetry only.
- xAPI attribution boundary:
  - `Oli.Experiments.XAPI.Attributions.attributions_for_page_view(...) :: [map()]`
  - `Oli.Experiments.XAPI.Attributions.attributions_for_part_attempt(...) :: [map()]`
  - `Oli.Experiments.XAPI.Attributions.attributions_for_activity_attempt([map()]) :: [map()]`
  - `Oli.Experiments.XAPI.Attributions.attributions_for_page_attempt([map()]) :: [map()]`
  - `Oli.Experiments.XAPI.Attributions.attributions_for_media_event([map()]) :: [map()]`
  - `Oli.Experiments.XAPI.Attributions.attach_attributions(statement, [map()]) :: map()`
- Emission semantics:
  - Emit only after the corresponding runtime transaction succeeds.
  - Emit once for newly created runtime evidence. Receipt reuse returns success without duplicate emission unless implementation can prove the original event was not emitted and marks the replay with the same idempotency key.
  - Never let xAPI pipeline failure roll back assignment, exposure, outcome, reward, or policy-state writes. The xAPI pipeline already persists failed bundles for replay.
- xAPI statement contract:
  - Existing host statements retain their existing `actor`, `verb`, `object`, `result`, `context`, and `timestamp` semantics.
  - Experiment data is attached only through `context.extensions["http://oli.cmu.edu/extensions/experiment_attributions"]`.
  - The attribution extension is an array because one host statement can represent zero, one, or many experiment attributions.
  - Canonical host statements are `page_viewed` for exposure, `part_attempt_evaluated` for outcome/reward, `activity_attempt_evaluated` and `page_attempt_evaluated` for rollups, and video/media statements for media interactions inside selected alternatives.
- Required context extensions:
  - `experiment_id`, `experiment_uuid`, `project_id`, `section_id`, `publication_id` where available, `decision_point_id`, `alternatives_resource_id`, `alternatives_revision_id`, `condition_id`, `condition_code`, `assignment_id`, `assignment_key`, `enrollment_id` or learner reference where allowed, `user_id`, `algorithm`, `policy_version`, `event_type`, `idempotency_key`.
  - Event-specific references such as `exposure_id`, `outcome_id`, `reward_id`, `policy_update_id`, `activity_attempt_id`, `resource_attempt_id`, `activity_resource_id`, `reward_value`, `reward_source`, `previous_policy_state_hash`, `next_policy_state_hash`, and `guardrail_action`.
- Category and bundle:
  - Use the existing host event category, such as `:page_viewed`, attempt summary bundles, or `:video`.
  - No dedicated learner-facing `:experiment` xAPI category is introduced.
  - Bundle partition remains `:section` for delivery/runtime host statements.
- Analytics coupling check:
  - Add a focused test or static assertion that scans product dashboard/export/reporting modules for aliases/imports of `Oli.Experiments.Schemas.Exposure`, `Outcome`, `Reward`, `PolicyUpdate`, and calls to PostgreSQL aggregate functions where the caller is not explicitly operational/admin inspection.
  - Code review must treat new product analytics reads against `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, or `experiment_policy_updates` as a blocker.

## 6. Data Model & Storage
- PostgreSQL tables retained as operational source:
  - `experiment_definitions`: keep as experiment definition/lifecycle source.
  - `experiment_decision_points`: keep as runtime matching source.
  - `experiment_conditions`: keep as runtime condition/config source.
  - `experiment_assignments`: keep as sticky assignment source and assignment idempotency guard.
  - `experiment_policy_states`: keep as current adaptive policy state for runtime assignment.
- PostgreSQL tables classified as temporary operational scaffolding:
  - `experiment_exposures`: retain only for exposure idempotency and reward eligibility until xAPI-backed operational alternatives are designed. Not an analytics source. Must be dropped before MVP completion.
  - `experiment_outcomes`: retain only for evaluated-attempt association and reward idempotency until replacement behavior exists. Not an analytics source. Must be dropped before MVP completion.
  - `experiment_rewards`: retain only for reward idempotency and policy update input until replacement behavior exists. Not an analytics source. Must be dropped before MVP completion.
  - `experiment_policy_updates`: retain only for preventing duplicate posterior updates and short-term operational audit until replacement behavior exists. Durable audit/reporting history is xAPI/S3/ClickHouse. Must be dropped before MVP completion.
- New PostgreSQL migrations:
  - No new persistent table is required by default.
  - Add comments or module documentation if implementation wants explicit table classification near schemas.
  - Optional: add an `xapi_emitted_at` or `xapi_event_id` field only if implementation proves duplicate suppression cannot be handled by deterministic xAPI idempotency keys and the upload pipeline. The simpler default is no schema change.
- xAPI storage:
  - JSONL in S3 is the durable history. Event idempotency is represented in statement extensions and should feed deterministic ClickHouse `event_hash` generation in the OLAP slice.
- ClickHouse:
  - No schema changes in this slice. Follow-on work decides whether experiment fields land in `raw_events` nullable columns, a new experiment projection, or materialized views.

## 7. Consistency & Transactions
- Assignment, exposure, outcome, reward, and policy-state writes remain transactionally consistent in PostgreSQL where they are needed for runtime behavior.
- xAPI emission happens after successful writes and must be idempotent by event idempotency key.
- If xAPI emission fails, the runtime operation remains successful. The existing xAPI pipeline failure handling persists failed bundles or surfaces upload failures for replay.
- Reward and policy update consistency remains based on `experiment_rewards.idempotency_key` and `experiment_policy_updates.reward_id`.
- `experiment_policy_states` remains the synchronous source for Thompson Sampling assignment. ClickHouse lag must not affect runtime assignment.
- PostgreSQL aggregate reads do not participate in runtime consistency and should be removed, deprecated, or restricted before product analytics work begins.

## 8. Caching Strategy
- No new cache is required.
- Do not cache emitted experiment event history in process memory.
- Active experiment lookup caches, if present from prior slices, remain independent and must not substitute for xAPI durable history.
- ClickHouse or dataset query caching is deferred to the OLAP/analytics slices.

## 9. Performance & Scalability Posture
- Runtime writes remain bounded to existing indexed PostgreSQL operations for assignment, exposure, outcome, reward, and policy updates.
- xAPI emission must enqueue into the existing Broadway pipeline and must not perform S3 or ClickHouse network work in the delivery transaction.
- Product analytics and large aggregates over assignment/exposure/outcome/reward history must not query PostgreSQL. This prevents hot operational tables from becoming report/export workloads.
- The static/review gate should focus on dashboard, report, export, and dataset code paths because those are the highest-risk sources of broad scans.
- The following slice must define ClickHouse projections with query shapes for assignment counts, exposure counts, reward/outcome joins, policy-update history, and dataset exports.

## 10. Failure Modes & Resilience
- xAPI pipeline suppressed in test/dev config: runtime behavior succeeds; tests can assert event builder output or use pipeline fakes.
- xAPI emit fails after PostgreSQL write: log/telemetry captures failure; runtime write remains committed; failed bundles follow existing replay behavior where available.
- Duplicate runtime call: PostgreSQL idempotency returns existing receipt; xAPI duplicate suppression relies on deterministic idempotency key. Do not double-count in ClickHouse projections.
- ClickHouse unavailable: delivery and authoring continue. Product analytics/reporting surfaces should show unavailable/lagging data in later slices.
- S3 upload failure: existing upload pipeline persists failed bundles; operators use upload/backfill tooling.
- PostgreSQL event table queried by new product analytics code: static check or review gate flags the change before merge.
- Existing analytics tests expecting PostgreSQL aggregates: update or reclassify them as operational-only tests, not product analytics evidence.

## 11. Observability
- Preserve existing `Oli.Experiments` telemetry for assignment, fallback, reward, policy update, lifecycle, and authoring validation.
- Add experiment xAPI emission telemetry:
  - `[:oli, :experiments, :xapi, :emit, :start]`
  - `[:oli, :experiments, :xapi, :emit, :stop]`
  - `[:oli, :experiments, :xapi, :emit, :exception]`
  - `[:oli, :experiments, :xapi, :emit, :skipped_duplicate]`
- Metadata should include non-sensitive IDs and tags: experiment_id, decision_point_id, section_id, publication_id, condition_id, event_type, algorithm, idempotency_key hash, emitted? flag, and error type.
- AppSignal should surface xAPI emission failures, skipped duplicates, and unexpected PostgreSQL analytics coupling checks according to `docs/OPERATIONS.md`.
- Logs must avoid learner names, LMS identifiers, raw responses, and full policy state. Use compact hashes for previous/next policy state in xAPI statements when detailed state would be too large or privacy-sensitive.

## 12. Security & Privacy
- Reuse existing `Oli.Experiments.Scope` validation before emitting event statements.
- xAPI statements may include learner/user/enrollment references only where already allowed by Torus xAPI conventions. Do not include learner names, LMS identifiers, raw activity responses, or full request payloads.
- Reward/outcome statements include scores, reward value, and attempt references only when required for experiment evidence.
- Analytics reads must enforce project, section, institution, and role scope in the ClickHouse-backed API introduced by later slices.
- PostgreSQL private schemas remain private to `Oli.Experiments`; web, dataset, dashboard, and analytics callers must not query event scaffolding tables directly.
- Security review must check xAPI payload minimization and absence of cross-section/cross-institution leakage through event extensions.

## 13. Testing Strategy
- ExUnit contract tests:
  - `page_viewed`, `part_attempt_evaluated`, `activity_attempt_evaluated`, `page_attempt_evaluated`, and video/media host statements attach the expected experiment attribution arrays.
  - Assignment and policy update paths emit internal operational telemetry only.
  - Replaying the same runtime evidence does not create duplicate PostgreSQL runtime state or duplicate attribution rows downstream.
  - xAPI emission failures do not roll back runtime writes.
  - Policy-state updates still update current PostgreSQL state for Thompson Sampling.
- Static/review gate tests:
  - Product dashboard, dataset, export, and report code must not alias private `Oli.Experiments.Schemas.Exposure`, `Outcome`, `Reward`, or `PolicyUpdate`.
  - Product analytics callers must not call PostgreSQL-backed `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, or `experiment_summary/1` unless explicitly listed as operational/admin inspection.
  - Direct SQL/Ecto references to `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` outside `Oli.Experiments` fail or are flagged.
- xAPI tests:
  - Existing host statements with zero, one, or many experiment attributions validate against the xAPI schema.
  - Statement context includes required experiment identifiers and no raw learner responses.
  - Existing host event categories continue to build bundles with `partition: :section`; no dedicated learner-facing `:experiment` category is introduced.
- Regression tests:
  - Existing `test/oli/experiments/analytics_test.exs` should be reclassified or adjusted so PostgreSQL aggregate functions are operational-only, not evidence for product analytics.
- Validation gates:
  - Run targeted `mix test` for `test/oli/experiments/*`, xAPI event tests, and any coupling-check tests.
  - Run `mix format`.
  - Run harness FDD verification and work-item validation.

## 14. Backwards Compatibility
- Existing native experiments, assignments, lifecycle controls, and Thompson Sampling runtime state remain valid.
- Existing event tables are not dropped in this slice. They are retained as temporary operational scaffolding to avoid destabilizing runtime idempotency, but must be removed by a later MVP slice before the A/B testing MVP is complete.
- Existing `Oli.Experiments` aggregate functions may remain temporarily, but their documentation and allowed callers must change. They should be treated as deprecated for product analytics until replaced by ClickHouse-backed contracts.
- Existing xAPI attempt, page, part, video, upload, backfill, and ClickHouse health behavior remains unchanged.
- Existing analytics FDD/plan artifacts that propose PostgreSQL reporting are superseded for implementation by this reconciliation and the following OLAP foundation.

## 15. Risks & Mitigations
- Risk: xAPI emission gaps make durable event history incomplete. Mitigation: emit after successful runtime writes, include deterministic idempotency keys, instrument failures, and rely on existing failed-bundle replay behavior.
- Risk: PostgreSQL event rows continue to power product analytics by convenience. Mitigation: add static/review gates, update docs, and mark aggregate functions operational-only.
- Risk: Removing PostgreSQL analytics too aggressively breaks runtime policy updates. Mitigation: keep reward and policy-update rows as temporary scaffolding only until a later design replaces their idempotency role, then require a drop migration before MVP completion.
- Risk: Event payloads expose too much learner data. Mitigation: use scoped IDs and compact metadata, avoid raw responses and learner names, and include security review.
- Risk: This slice drifts into OLAP implementation. Mitigation: defer ClickHouse schema/projection/query work to `experiment_olap_foundation`.
- Risk: ClickHouse lag is mistaken for runtime failure. Mitigation: later analytics surfaces must distinguish runtime state from OLAP evidence freshness.

## 16. Open Questions & Follow-ups
- Confirm whether the xAPI category should be one `:experiment` category or per-event categories before OLAP implementation.
- Confirm whether duplicate receipt reuse should emit explicit `*_reused` xAPI events for assignments only or for every runtime event type.
- Confirm whether an `xapi_emitted_at` operational field is necessary or whether deterministic idempotency keys and pipeline replay are sufficient.
- Confirm which MVP slice owns the final drop migration; recommended gate is after `experiment_olap_foundation` proves projections and replacement idempotency, and before `analytics` or `manual_qa` can be marked complete.
- Follow up in `experiment_olap_foundation` with ClickHouse schema/projection design, direct uploader transforms, S3 backfill behavior, and dataset export fields.
- Follow up in `analytics` by rewriting superseded PostgreSQL-backed reporting APIs to use ClickHouse-backed contracts.

## 17. References
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/DESIGN.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/PRODUCT_SENSE.md`
- `docs/STACK.md`
- `docs/TESTING.md`
- `docs/TOOLING.md`
- `docs/design-docs/attempt.md`
- `docs/design-docs/attempt-handling.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/scoped_feature_flags.md`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/prd.md`
- `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/analytics/fdd.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/analytics_query.ex`
- `lib/oli/analytics/xapi.ex`
- `lib/oli/analytics/xapi/statement_bundle.ex`
- `lib/oli/analytics/xapi/upload_pipeline.ex`
- `lib/oli/analytics/xapi/s3_uploader.ex`
- `lib/oli/analytics/xapi/clickhouse_uploader.ex`
- `lib/oli/analytics/clickhouse_analytics.ex`
- `lib/oli/analytics/datasets.ex`
- `priv/repo/migrations/20260625120000_create_experiment_tables.exs`
- `priv/clickhouse/migrations/20260326213833_initialize.sql`
