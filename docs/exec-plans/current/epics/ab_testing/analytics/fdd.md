# Outcome Analytics And Research Visibility - Functional Design Document

## 1. Executive Summary
Expand native A/B testing analytics from basic context-owned aggregate reads into release-ready reporting and monitoring for assignments, exposures, outcomes, rewards, runtime data quality, and Thompson Sampling policy state.

This FDD is superseded for implementation. Reporting, LiveView, exports, and operations code should consume approved A/B testing analytics APIs, but those APIs must be backed by the experiment xAPI/ClickHouse foundation for event history, large aggregates, dashboards, and dataset exports. PostgreSQL should be used only for low-volume operational state and current runtime policy inspection.

Supersession note, 2026-07-14: this FDD is no longer implementation-ready. It was written before the product requirement to avoid PostgreSQL-heavy experiment event logging and analytics. The current roadmap requires `runtime_telemetry_reconciliation` and `experiment_olap_foundation` before analytics. When this analytics slice resumes, rewrite this FDD so xAPI JSONL in S3 is the durable experiment event source, ClickHouse is the analytics serving store, and PostgreSQL is used only for low-volume operational state and current runtime policy inspection.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Report assignment and exposure counts by experiment, decision point, and condition.
  - FR-002: Report outcome and reward evidence from explicit native experiment outcome/reward records and their attempt references.
  - FR-003: Define timestamp and scope semantics for joining assignments, exposures, attempts, outcomes, and rewards.
  - FR-004: Surface missing exposures, missing outcomes, failed or delayed reward updates, and unexpected assignment imbalance through approved monitoring or reporting.
  - FR-005: Surface Thompson Sampling posterior state, reward counts, assignment share over time, delayed or missing rewards, and guardrail-triggered pauses.
- Acceptance criteria mapping:
  - AC-001: Sections 4, 5, and 13 define aggregate assignment and exposure read models grouped by experiment, decision point, and condition.
  - AC-002: Sections 4, 5, and 13 define outcome/reward inspection for controlled evaluated attempts through context-owned query APIs.
  - AC-003: Sections 4.2, 6, and 7 define scope and timestamp rules for assignment, exposure, attempt, outcome, reward, and policy update joins.
  - AC-004: Sections 4, 10, 11, and 13 define missing runtime evidence, delayed reward, failed policy update, and assignment imbalance visibility.
  - AC-005: Sections 4, 5, 6, and 13 define Thompson Sampling posterior, reward count, and assignment share reporting by condition.
- Non-functional requirements:
  - Analytics reads must preserve institution, project, publication, section, user, and enrollment scoping.
  - Reporting queries must not run on delivery hot paths.
  - Research-oriented views and exports must minimize learner-identifying data and default to aggregates.
  - Telemetry and AppSignal should make analytics read latency, failures, data-quality counts, and policy-state update failures observable.
  - Performance review is required for new aggregate queries and any read-model refresh path.
- Assumptions:
  - Native assignment, exposure, outcome, reward, and policy-state records from the domain, delivery-runtime, and Thompson Sampling slices are authoritative.
  - `Oli.Experiments.AnalyticsQuery` is the MVP query contract and may be extended additively with date windows, grouping options, and data-quality filters.
  - MVP reporting is scoped to native experiments only; legacy UpGrade analytics are not imported.
  - The first implementation can query PostgreSQL directly through `Oli.Experiments`; materialized read tables or ClickHouse projections are introduced only when query volume or export size requires them.
  - Instructor-facing surfaces show aggregate or release-relevant data only; researcher/admin surfaces may include attempt references when authorized, but not raw learner responses.

## 3. Repository Context Summary
- What we know:
  - Torus is a Phoenix/Ecto monolith where backend domain code belongs under `lib/oli/`, web and LiveView orchestration belongs under `lib/oli_web/`, and analytics infrastructure already exists under `lib/oli/analytics`.
  - `Oli.Experiments` owns native experiment persistence and exposes public request/query structs, including `AnalyticsQuery`.
  - Current `Oli.Experiments` analytics functions include `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1`.
  - `test/oli/experiments/analytics_test.exs` already verifies scoped summary/count/policy snapshot behavior and out-of-scope rejection.
  - Delivery reward handoff records outcomes and rewards from evaluated attempts through `Oli.Experiments`, with attempt references and deterministic idempotency keys.
  - Thompson Sampling policy state stores algorithm version, JSON prior/state, reward success/failure counts, assignment count, and last reward update provenance.
  - Existing analytics, xAPI, ClickHouse, instructor dashboard, and dashboard snapshot code provide surrounding reporting patterns; the rewritten design must use xAPI/ClickHouse for experiment event analytics and PostgreSQL only for operational/runtime inspection.
- Unknowns to confirm:
  - Which MVP surface ships first: author/research LiveView inside the course author workspace, admin/operator monitoring view, CSV export, or a combination.
  - Whether researchers need learner-level CSV rows in the MVP or aggregate condition-level exports are sufficient for release confidence.
  - The product-approved assignment imbalance thresholds and missing outcome/reward lateness windows.
  - Whether ClickHouse projection is needed for the first production release or can wait until direct PostgreSQL aggregates show real pressure.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` remains the read owner and exposes analytics-specific functions that return public maps or structs. Private Ecto schemas under `Oli.Experiments.Schemas` remain internal to the context.

- `Oli.Experiments`: public API for experiment analytics and data-quality reads. It validates `AnalyticsQuery.scope` before every read.
- `Oli.Experiments.AnalyticsQuery`: additive query request struct. Extend it with optional `started_at`, `ended_at`, `group_by`, `include_attempt_refs?`, and `data_quality_only?` fields as implementation needs.
- `Oli.Experiments.Analytics`: optional internal module if `lib/oli/experiments.ex` needs extraction. It may own query construction, aggregation, and read-model refresh logic, but stays behind the public context.
- Authoring/research UI: a LiveView under the course author workspace can show experiment-level summaries, condition counts, and Thompson Sampling state for authorized authors, researchers, and admins.
- Admin/operator UI: an admin LiveView or existing operational surface can show failed policy updates, missing exposures/outcomes, delayed rewards, and imbalance flags across scoped experiments.
- Export boundary: if CSV export is needed, implement it as a web-layer caller of `Oli.Experiments` aggregate/detail APIs. Do not export by directly querying private schemas.
- Telemetry/AppSignal: analytics reads emit query latency, failure, and data-quality-count telemetry with PII-safe metadata.

### 4.2 State & Data Flow
Analytics query flow:

1. Caller builds `%AnalyticsQuery{scope: scope, experiment_id: experiment_id}` and optional filters.
2. `Oli.Experiments` validates scope and confirms the experiment belongs to the requested project, publication, section, and institution context.
3. The context reads native assignment, exposure, outcome, reward, and policy-state records with scoped joins to experiment definitions.
4. The context returns aggregate rows grouped by experiment, decision point, condition, and optional time bucket.
5. UI/export code renders the public response without receiving private schemas.

Timestamp semantics:

- Assignment time is `experiment_assignments.assigned_at`; it is the participant entry timestamp for an experiment decision point.
- Exposure time is `experiment_exposures.exposed_at`; it means assigned content was applied/rendered for the learner.
- Outcome time is `experiment_outcomes.observed_at`; it means an evaluated attempt result was associated with an assignment.
- Reward time is `experiment_rewards.processed_at`; it means a binary or configured reward event was persisted.
- Policy update time is `experiment_policy_updates.inserted_at`; it means the reward changed policy state or was recorded as an update attempt.
- Reporting date windows filter on the event type being queried. Cross-event health checks compare timestamps in assignment-to-exposure-to-outcome-to-reward order.

Scope semantics:

- Project scope limits experiment definitions by `project_id`.
- Publication scope limits runtime evidence to records created for that publication when present.
- Section scope limits assignment, exposure, outcome, and reward evidence to learners in that section.
- User/enrollment scope is accepted only for learner-specific debugging and must not be the default for researcher/instructor aggregate views.
- Institution scope is always enforced through section or experiment ownership and never inferred from user-provided IDs alone.

### 4.3 Lifecycle & Ownership
Analytics reads include experiments in lifecycle states relevant to review: `:active`, `:paused`, `:completed`, and optionally `:archived` when explicitly requested. Draft experiments may appear in authoring setup views but should not produce runtime-evidence reports.

`Oli.Experiments` owns the analytics definitions, join semantics, and data-quality calculations. `Oli.Analytics` and ClickHouse own broader platform analytics pipelines but are not the authoritative source for native experiment assignment, exposure, reward, or policy-state evidence in the MVP.

### 4.4 Alternatives Considered
- Query private `experiment_*` schemas directly from LiveViews or analytics modules: rejected because it violates the domain contract and makes schema refactors unsafe.
- Build a ClickHouse projection first: superseded. The current roadmap now requires the xAPI/ClickHouse OLAP foundation before analytics implementation.
- Add a complex metric query language: rejected because the PRD explicitly excludes UpGrade parity and advanced metric query capabilities.
- Store denormalized analytics snapshots for every runtime write immediately: not selected because it adds consistency and repair complexity before aggregate query pressure is proven.
- Expose learner-level rows by default: rejected because aggregate reporting satisfies most release-review needs and better preserves learner privacy.

## 5. Interfaces
- Existing aggregate APIs:
  - `Oli.Experiments.experiment_summary(%AnalyticsQuery{}) :: {:ok, map()} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.assignment_counts(%AnalyticsQuery{}) :: {:ok, [map()]} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.exposure_counts(%AnalyticsQuery{}) :: {:ok, [map()]} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.reward_counts(%AnalyticsQuery{}) :: {:ok, [map()]} | {:error, %ExperimentError{}}`
  - `Oli.Experiments.policy_state_snapshot(%AnalyticsQuery{}) :: {:ok, [map()]} | {:error, %ExperimentError{}}`
- New or expanded read APIs:
  - `outcome_counts(%AnalyticsQuery{})`: counts outcomes by experiment, decision point, condition, activity resource, and optional time bucket.
  - `reward_quality_summary(%AnalyticsQuery{})`: returns delayed rewards, missing rewards for outcomes, failed policy updates, and replay/reuse counts where available.
  - `exposure_quality_summary(%AnalyticsQuery{})`: returns assignments without exposure, exposure lag, and exposure-to-assignment ratios by condition.
  - `assignment_balance(%AnalyticsQuery{})`: returns condition assignment shares, expected share when available, absolute/relative imbalance, and threshold status.
  - `thompson_sampling_summary(%AnalyticsQuery{})`: returns algorithm version, prior config, posterior alpha/beta or success/failure values by condition, reward counts, assignment share, last update timestamp, and guardrail status.
  - `experiment_event_detail(%AnalyticsQuery{})`: optional admin/researcher-only detail read that returns attempt and assignment references without raw responses or learner names.
- UI/export interfaces:
  - Author/research view consumes aggregate and Thompson Sampling summary APIs.
  - Admin/operator view consumes data-quality summary APIs.
  - CSV export, if included, is generated from public analytics responses and includes scope metadata, generated timestamp, and applied filters.
- Error contract:
  - Use `%ExperimentError{type, message, details}` with existing types such as `:invalid_scope`, `:not_found`, `:invalid_request`, and `:persistence_error`.
  - Analytics errors must be field-safe and must not leak learner identifiers or raw query details.

## 6. Data Model & Storage
- No new runtime source-of-truth tables are required.
- Existing native experiment tables remain authoritative:
  - `experiment_definitions`
  - `experiment_decision_points`
  - `experiment_conditions`
  - `experiment_assignments`
  - `experiment_exposures`
  - `experiment_outcomes`
  - `experiment_rewards`
  - `experiment_policy_states`
  - `experiment_policy_updates`
- Add indexes only if query plans require them. Candidate indexes include compound indexes for:
  - assignments by `experiment_id`, `decision_point_id`, `condition_id`, `section_id`, `assigned_at`;
  - exposures by `assignment_id`, `condition_id`, `section_id`, `exposed_at`;
  - outcomes by `assignment_id`, `activity_attempt_id`, `activity_resource_id`, `observed_at`;
  - rewards by `assignment_id`, `condition_id`, `processed_at`;
  - policy updates by `policy_state_id`, `reward_id`, `inserted_at`.
- If aggregates become expensive, introduce context-owned read models such as `experiment_condition_daily_metrics` or a ClickHouse projection. They must be derived from native records, refresh idempotently, and be exposed only through `Oli.Experiments`.
- Learner-level export rows, if approved, should include stable internal references needed for research audit and omit learner names, emails, LMS IDs, raw responses, and full activity payloads.

## 7. Consistency & Transactions
- Analytics reads are read-only and must not mutate assignment, exposure, outcome, reward, or policy state.
- Missing-evidence calculations use read-committed native records and may be eventually accurate for rewards if reward handoff or policy update retry is asynchronous.
- Data-quality windows must account for expected delay:
  - missing exposure is an assignment with no exposure after a configured grace period from `assigned_at`;
  - missing outcome is an exposure with no outcome after a configured grace period or after an evaluated attempt should have been available;
  - missing reward is an outcome with no reward after a configured grace period from `observed_at`;
  - failed policy update is a reward whose policy update is absent after a configured grace period or whose update path emitted failure telemetry.
- Policy-state snapshots read the latest persisted `experiment_policy_states` row and may join to `last_updated_from_reward_id` for provenance.
- If read models are introduced, refresh jobs must be idempotent by experiment, decision point, condition, and time bucket. Direct source-of-truth queries remain the fallback for correctness checks.

## 8. Caching Strategy
- No cache is required for MVP correctness.
- UI pages may use normal LiveView assign state for the current request/session, but should refresh from `Oli.Experiments` when filters change.
- Do not cache learner-level detail exports across scopes.
- If aggregate read models are introduced, they should be ClickHouse-backed analytics projections rather than PostgreSQL event-log aggregates.
- Any future Cachex-backed summary cache must be scoped by experiment, section/publication filters, query date window, and caller-safe grouping options, and invalidated or aged out based on runtime event arrival.

## 9. Performance & Scalability Posture
- Reporting is not on the learner delivery hot path.
- Aggregate reads should require indexed scans bounded by experiment, section, publication, and optional date windows.
- Large exports should stream or page results rather than loading all rows into LiveView memory.
- Assignment imbalance and missing-evidence summaries should aggregate in SQL and avoid pulling row-level learner data into Elixir unless a detail drilldown is explicitly requested.
- Thompson Sampling snapshots are small because MVP experiments have one decision point and a small number of active conditions.
- Performance review should inspect query plans for aggregate reads, worst-case section sizes, export memory behavior, and any read-model refresh job duration.

## 10. Failure Modes & Resilience
- Out-of-scope query: return `{:error, %ExperimentError{type: :invalid_scope}}`; do not reveal whether unrelated experiment evidence exists.
- Missing experiment: return `:not_found` or an empty scoped response according to the specific API contract.
- Late reward or policy update: report as delayed/missing after the configured grace period; do not treat as data loss until retry paths are exhausted.
- Assignment imbalance threshold exceeded: surface a warning or guardrail status; analytics does not pause experiments directly unless a later lifecycle command is explicitly invoked.
- Malformed policy state: return a bounded analytics error, emit telemetry, and keep other aggregate sections visible where possible.
- Large query timeout: return a scoped error and recommend narrower filters or use an export/read-model path.
- ClickHouse or downstream analytics unavailable: native PostgreSQL reads continue because the MVP read source is `Oli.Experiments`.

## 11. Observability
- Preserve existing experiment telemetry for assignment, exposure, reward, policy update, and analytics query paths.
- Add or standardize analytics telemetry:
  - `[:oli, :experiments, :analytics, :query, :start]`
  - `[:oli, :experiments, :analytics, :query, :stop]`
  - `[:oli, :experiments, :analytics, :query, :exception]`
  - `[:oli, :experiments, :analytics, :data_quality]`
  - `[:oli, :experiments, :analytics, :export]`
- Metadata should include non-sensitive IDs and tags: experiment_id, project_id, section_id, publication_id, algorithm, lifecycle_state, query_name, result_count, data_quality_status, and error_type.
- AppSignal should surface analytics query failures, slow queries, data-quality counts, reward update failures, and Thompson Sampling guardrail statuses.
- Logs must not include learner names, LMS identifiers, emails, raw activity responses, API tokens, or raw SQL with user-provided values.

## 12. Security & Privacy
- Every analytics read validates `AnalyticsQuery.scope` through `Oli.Experiments`.
- Instructor-facing views must be scoped to the section and avoid learner-level rows by default.
- Researcher/admin views may include attempt or assignment references only behind existing authorization checks and only when the PRD-approved surface requires them.
- Exported data must minimize learner-identifying fields and include only aggregate rows unless a learner-level export is explicitly authorized.
- Private schemas under `Oli.Experiments.Schemas` must not be returned to LiveViews, controllers, CSV serializers, or other contexts.
- Reward, outcome, and policy-state metadata must not expose raw student responses or LMS personal identifiers.
- Security review must check authorization, cross-scope query rejection, export content, and absence of direct private-schema coupling outside `Oli.Experiments`.

## 13. Testing Strategy
- ExUnit analytics context tests:
  - scoped assignment and exposure counts by experiment, decision point, and condition;
  - outcome and reward counts for a controlled evaluated attempt;
  - out-of-scope analytics queries reject without leaking evidence;
  - timestamp filters use the correct event timestamp for assignment, exposure, outcome, reward, and policy update queries;
  - missing exposure, missing outcome, missing reward, failed policy update, and assignment imbalance summaries;
  - Thompson Sampling summary includes algorithm version, prior/posterior state, reward counts, assignment counts, last update provenance, and assignment share.
- Privacy/security tests:
  - public analytics responses are maps/structs that do not expose `Oli.Experiments.Schemas`;
  - default instructor/research aggregate responses exclude learner names, emails, LMS IDs, and raw responses;
  - learner-level detail APIs require authorized scope and return only approved references.
- UI or LiveView tests, if a surface is built in this slice:
  - renders assignments, exposures, outcomes/rewards, and Thompson Sampling state distinctly;
  - shows data-quality warnings for missing/delayed evidence and imbalance;
  - handles empty, loading, error, and no-access states.
- Scenario tests:
  - Use `Oli.Scenarios` if implementation spans authoring, publishing, section delivery, enrollment, learner exposure, evaluated attempt, reward handoff, and analytics verification.
  - Cover at least one non-adaptive native experiment and one Thompson Sampling experiment when scenario DSL support is available.
- Performance checks:
  - inspect query plans or add targeted tests for high-volume aggregate paths;
  - verify exports stream/page large result sets if learner-level exports are implemented.
- Validation gates:
  - Run targeted `mix test test/oli/experiments/analytics_test.exs`.
  - Run related context/runtime/reward handoff tests when query semantics depend on those records.
  - Run targeted LiveView tests when UI is implemented.
  - Run scenario validation and targeted scenario runner when scenario coverage is added.
  - Run `mix format`.
  - Run harness requirements trace and work-item validation.

## 14. Backwards Compatibility
- Existing native analytics APIs remain additive. Existing callers of `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1` should continue to work.
- Legacy UpGrade analytics are not imported or displayed as native experiment evidence.
- Existing native experiment operational records remain valid for runtime behavior, but dashboards, large aggregates, and dataset exports must use xAPI/ClickHouse-backed evidence.
- Existing delivery, attempt, xAPI, and gradebook analytics remain unchanged. Experiment analytics adds reporting around experiment-specific records and attempt references.
- No feature flag is required for the FDD scope. If implementation introduces a new user-facing surface gradually, use normal routing/authorization or a separate approved rollout decision.

## 15. Risks & Mitigations
- Risk: Reporting joins are misleading. Mitigation: define event-specific timestamp and scope semantics in this FDD and test each join path.
- Risk: Analytics code couples to private experiment schemas outside the context. Mitigation: keep all queries inside `Oli.Experiments`, add coupling tests, and review for schema aliases in web/analytics code.
- Risk: Aggregate queries become expensive. Mitigation: start with scoped/indexed PostgreSQL queries, inspect plans, and introduce context-owned read models only when needed.
- Risk: Learner privacy is weakened by exports. Mitigation: default to aggregate rows, require authorization for detail reads, and omit learner names, LMS IDs, emails, raw responses, and full payloads.
- Risk: Delayed rewards look like data loss. Mitigation: use explicit grace periods and distinguish delayed, missing, failed, and processed states.
- Risk: Thompson Sampling posterior state is hard to interpret. Mitigation: return prior config, posterior values, reward counts, assignment share, algorithm version, and last update provenance in one summary response.
- Risk: Operators cannot act on warnings. Mitigation: include experiment, decision point, condition, section/publication filters, and lifecycle state in monitoring responses so owners can pause or investigate through existing lifecycle controls.

## 16. Open Questions & Follow-ups
- Confirm the first MVP surface: author/research LiveView, admin/operator monitoring view, CSV export, or all three.
- Confirm product-approved thresholds for assignment imbalance and grace periods for missing exposure, outcome, reward, and policy updates.
- Confirm whether learner-level research exports are required for MVP or deferred behind aggregate-only reporting.
- Confirm whether ClickHouse projection is needed before broad availability or only after PostgreSQL aggregate performance is measured.
- Confirm the final authorization roles for researcher visibility versus instructor release visibility.

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
- `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`
- `docs/exec-plans/current/epics/ab_testing/analytics/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/fdd.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/analytics_query.ex`
- `lib/oli/experiments/schemas/assignment.ex`
- `lib/oli/experiments/schemas/exposure.ex`
- `lib/oli/experiments/schemas/outcome.ex`
- `lib/oli/experiments/schemas/reward.ex`
- `lib/oli/experiments/schemas/policy_state.ex`
- `lib/oli/experiments/schemas/policy_update.ex`
- `lib/oli/delivery/experiments/reward_handoff.ex`
- `test/oli/experiments/analytics_test.exs`
