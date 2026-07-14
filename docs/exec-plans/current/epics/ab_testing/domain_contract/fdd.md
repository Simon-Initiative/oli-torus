# A/B Testing Domain Boundary And API Contract - Functional Design Document

## 1. Executive Summary
Create a native A/B testing backend domain owned by `Oli.Experiments`. This context will own experiment persistence, assignment policy contracts, delivery/runtime commands, authoring lifecycle commands, reward feedback, and analytics-facing reads. The first implementation slice should introduce the persistence and context boundary without replacing delivery behavior, building UI, or exposing Ecto schemas outside the context.

The design satisfies FR-001 through FR-005 by defining private experiment tables and public domain request/response structs. Later delivery, authoring, analytics, and Thompson Sampling slices consume these APIs instead of joining directly against experiment-owned schemas.

Revision note, 2026-07-14: this FDD predates the product requirement to route heavy experiment event history and analytics through xAPI/S3/ClickHouse. Treat PostgreSQL persistence described here as operational state only unless the reconciliation slice explicitly keeps a table for idempotency or runtime correctness. Dashboards, dataset exports, and large aggregate analytics must not be implemented against PostgreSQL experiment event-log tables.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: `Oli.Experiments` owns native persistence for experiment definitions, decision points, conditions, assignments, exposures, outcome associations, rewards, and policy state.
  - FR-002: The context exposes stable APIs for delivery assignment and exposure, authoring lifecycle, analytics reads, and reward feedback.
  - FR-003: Non-domain code uses public context functions or approved read models only; private Ecto schemas and query modules stay internal to `Oli.Experiments`.
  - FR-004: Assignment policies implement a common behavior for weighted deterministic random assignment and Thompson Sampling reward updates.
  - FR-005: Public commands carry explicit institution, project, publication, section, user, and enrollment scope where applicable.
- Acceptance criteria mapping:
  - AC-001: Section 6 defines the owned native data model for every MVP experiment record type.
  - AC-002: Section 5 defines delivery, authoring, analytics, and reward feedback API surfaces with request and response responsibilities.
  - AC-003: Sections 4.1, 5, and 15 state that non-domain code must not directly access private experiment schemas or queries.
  - AC-004: Sections 4.1, 5, 6, and 7 define baseline weighted assignment and Thompson Sampling policy-state and reward contracts.
  - AC-005: Sections 2, 5, 6, and 12 define scope rules for project, section, user, enrollment, and institution boundaries.
- Non-functional requirements:
  - Runtime assignment must be local to PostgreSQL/Ecto and transaction-safe for delivery hot paths.
  - Request and response structs must use domain language and stable IDs rather than returning raw schemas.
  - The design must preserve Torus publication immutability and multi-tenant access boundaries.
  - Telemetry hooks must exist for later latency, error, reward-processing, assignment-reuse, and policy-state monitoring.
- Assumptions:
  - Native A/B testing starts fresh; existing UpGrade experiments, assignments, and learner participation are not migrated.
  - MVP assignment is individual and sticky by `enrollment_id` within a section and experiment.
  - Native experiments initially target alternatives decision points whose condition codes correspond to alternatives group option names.
  - Thompson Sampling uses binary rewards and per-condition Beta-Bernoulli state.
  - `has_experiments` on projects and sections remains as a coarse gate until the native lifecycle slice replaces or refines it.

## 3. Repository Context Summary
- What we know:
  - Torus is a Phoenix/Ecto monolith where backend domain code belongs under `lib/oli/`, with web code in `lib/oli_web/` acting as transport or UI orchestration.
  - Current UpGrade integration is concentrated in `lib/oli/delivery/experiments.ex`, `lib/oli/resources/alternatives/decision_point_strategy.ex`, `lib/oli/delivery/experiments/log_worker.ex`, and UpGrade JSON builders under `lib/oli/delivery/experiments/`.
  - Existing authoring surfaces use `Oli.Authoring.Experiments.get_latest_experiment/1` to locate an alternatives revision whose content strategy is `upgrade_decision_point`.
  - Alternatives groups are represented by revisions with resource type alternatives and content options; `Oli.Resources.alternatives_groups/2` returns group `id`, `title`, `options`, and `strategy`.
  - Published delivery resolves immutable published resources through publications and published resources, while sections reference publications.
  - Enrollment identity exists in `Oli.Delivery.Sections.Enrollment`; evaluated attempts provide score/outcome evidence through `Oli.Delivery.Attempts.Core.ActivityAttempt`.
  - Existing project and section `has_experiments` flags are the only native persistence currently related to experimentation.
- Unknowns to confirm:
  - Whether the public namespace should remain `Oli.Experiments` or use `Oli.ABTesting`; this design selects `Oli.Experiments` because Torus already has `Oli.Authoring.Experiments` and the shorter domain name fits local context naming.
  - The final analytics read surface required by researchers and instructors; this FDD defines aggregate query contracts and read-model ownership, leaving exact UI/report shape to the analytics slice.
  - The authoritative binary reward source for Thompson Sampling; this FDD defines the reward command shape and idempotency key, while the delivery and Thompson Sampling slices select the concrete attempt-derived signal.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` becomes the owning domain context under `lib/oli/experiments.ex`, with implementation modules under `lib/oli/experiments/`.

- `Oli.Experiments`: public context boundary for delivery, authoring, analytics, and reward feedback.
- `Oli.Experiments.Schemas.*`: private Ecto schemas for owned persistence. These modules are not aliased from delivery, authoring, analytics, web, or tests outside context-level contract tests.
- `Oli.Experiments.Scope`: validated scope struct used by all cross-domain calls. It carries the relevant institution, project, publication, section, user, and enrollment IDs.
- `Oli.Experiments.Delivery`: internal service for assignment lookup, first assignment creation, exposure recording, and fallback decisions.
- `Oli.Experiments.Authoring`: internal service for draft experiment creation, validation, lifecycle state transitions, and decision-point/condition synchronization from alternatives content.
- `Oli.Experiments.Analytics`: internal service for approved aggregates and read models.
- `Oli.Experiments.Rewards`: internal service for outcome association and idempotent reward recording.
- `Oli.Experiments.Policies`: assignment policy boundary. `WeightedRandom` and `ThompsonSampling` implement the same behavior so delivery code never branches on algorithm details.

Later replacement code in `Oli.Resources.Alternatives.DecisionPointStrategy` should call `Oli.Experiments.assign_condition/1` and `Oli.Experiments.record_exposure/1`. The current UpGrade module remains untouched in this slice except where a later cut-over introduces an anti-corruption adapter or removes it.

### 4.2 State & Data Flow
Authoring flow:

1. Authoring creates or updates native experiment definitions through `Oli.Experiments.create_experiment/1`, `update_experiment/2`, and lifecycle commands.
2. The context stores experiment records, decision points, conditions, and algorithm configuration linked to project and publication/resource identifiers.
3. Definitions reference Torus content by stable IDs: project, publication where applicable, alternatives group resource, alternatives group revision, and decision point key/title.

Delivery assignment flow:

1. Alternatives delivery builds an `AssignConditionRequest` with scope, alternatives group identity, decision point identity, and available condition codes.
2. `Oli.Experiments.assign_condition/1` validates scope, locates an active matching experiment, and checks for an existing assignment by experiment, decision point, and enrollment.
3. If a sticky assignment exists, the context returns it without invoking a policy.
4. If no assignment exists, the selected policy chooses a condition inside a database transaction, the assignment is inserted, and the selected condition is returned.
5. If no active experiment matches, the response is `{:ok, %AssignmentDecision{status: :no_experiment}}`; delivery preserves first-option fallback.

Exposure and reward flow:

1. Delivery calls `record_exposure/1` after assigned decision point content is applied. The call is idempotent for assignment, decision point, content revision, and enrollment.
2. Evaluated attempts call `record_outcome/1` or `record_reward/1` with an idempotency key derived from attempt identity and reward source.
3. Reward recording stores the event once and delegates policy-state updates to the configured policy in the same transaction or an Oban-backed retry path selected by the later delivery/runtime slice.

Analytics flow:

1. Analytics callers use context functions such as `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1`.
2. The context may query private tables or maintain read models, but callers receive domain structs or maps with scoped aggregate data only.

### 4.3 Lifecycle & Ownership
`Oli.Experiments` owns records from draft definition through archived/completed experiment state. Publication content remains immutable: experiments choose which published alternative to show; they do not mutate revisions or published resources during delivery.

Lifecycle states for the contract are `:draft`, `:active`, `:paused`, `:completed`, and `:archived`. Runtime assignment only applies to `:active` experiments. `:paused`, `:completed`, and `:archived` experiments do not create new assignments; delivery receives `:no_experiment` or an inactive response and falls back according to the delivery-runtime slice.

Assignments are owned by the native domain and are sticky for the lifetime of the experiment unless a later explicit lifecycle requirement defines participant reassignment. Exposures, outcome associations, reward events, and policy updates are append-oriented audit records with idempotency constraints.

### 4.4 Alternatives Considered
- Keep using `Oli.Delivery.Experiments` as the native context: rejected because that namespace is delivery-specific and currently describes UpGrade transport. It would blur ownership for authoring, analytics, and policy state.
- Put experiment fields directly on alternatives revisions: rejected because published content is immutable and runtime assignment/exposure/reward state belongs to section/enrollment delivery, not authoring content.
- Build a separate service boundary now: rejected because the PRD explicitly excludes a separately deployed runtime and the MVP needs local transactional behavior.
- Allow analytics to query experiment tables directly: rejected because it violates FR-003 and makes schema refactors unsafe. Approved context-owned read models provide the needed reporting boundary.

## 5. Interfaces
- Public context module: `Oli.Experiments`.
- Shared request scope:
  - `%Oli.Experiments.Scope{institution_id, project_id, project_slug, publication_id, section_id, section_slug, user_id, enrollment_id}`.
  - Scope validation confirms the section belongs to the project/publication where supplied and the enrollment belongs to the section/user where supplied.
- Authoring commands:
  - `create_experiment(%CreateExperimentRequest{}) :: {:ok, %ExperimentDefinition{}} | {:error, %ExperimentError{}}`
  - `update_experiment(experiment_id, %UpdateExperimentRequest{}) :: {:ok, %ExperimentDefinition{}} | {:error, %ExperimentError{}}`
  - `activate_experiment(experiment_id, %LifecycleRequest{}) :: {:ok, %ExperimentDefinition{}} | {:error, %ExperimentError{}}`
  - `pause_experiment/2`, `complete_experiment/2`, and `archive_experiment/2` follow the same lifecycle request pattern.
- Delivery commands:
  - `assign_condition(%AssignConditionRequest{}) :: {:ok, %AssignmentDecision{}} | {:error, %ExperimentError{}}`
  - `record_exposure(%RecordExposureRequest{}) :: {:ok, %ExposureReceipt{}} | {:error, %ExperimentError{}}`
  - `record_outcome(%RecordOutcomeRequest{}) :: {:ok, %OutcomeReceipt{}} | {:error, %ExperimentError{}}`
  - `record_reward(%RecordRewardRequest{}) :: {:ok, %RewardReceipt{}} | {:error, %ExperimentError{}}`
- Analytics queries:
  - `experiment_summary(%AnalyticsQuery{}) :: {:ok, %ExperimentSummary{}} | {:error, %ExperimentError{}}`
  - `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, and `policy_state_snapshot/1`.
- Policy behavior:
  - `@callback assign(policy_config, policy_state, assignment_context) :: {:ok, %PolicyAssignment{}} | {:error, term()}`
  - `@callback record_reward(policy_config, policy_state, reward_context) :: {:ok, %PolicyUpdate{}} | {:error, term()}`
  - Weighted deterministic random assignment uses stable input such as experiment, decision point, enrollment, and salt to choose by configured weights.
  - Thompson Sampling uses policy state with prior, posterior, algorithm version, reward counts, and update provenance.
- Error contract:
  - `%ExperimentError{type, message, details}` with types such as `:not_found`, `:invalid_scope`, `:invalid_state`, `:invalid_condition`, `:conflict`, and `:persistence_error`.

## 6. Data Model & Storage
Create private schemas and migrations for tables under an `experiment_` prefix to make ownership clear:

- `experiment_definitions`
  - `id`, `uuid`, `institution_id`, `project_id`, `publication_id`, `section_id`, `slug`, `name`, `description`, `state`, `assignment_unit`, `algorithm`, `policy_config`, `started_at`, `ended_at`, timestamps.
  - Indexes on `project_id`, `publication_id`, `section_id`, `state`, and unique `uuid`.
- `experiment_decision_points`
  - `id`, `experiment_id`, `alternatives_resource_id`, `alternatives_revision_id`, `decision_point_key`, `title`, `position`, timestamps.
  - Unique index on `experiment_id`, `decision_point_key`.
- `experiment_conditions`
  - `id`, `experiment_id`, `decision_point_id`, `condition_code`, `option_id`, `label`, `weight`, `active`, `position`, timestamps.
  - Unique index on `decision_point_id`, `condition_code`.
- `experiment_assignments`
  - `id`, `experiment_id`, `decision_point_id`, `condition_id`, `institution_id`, `section_id`, `enrollment_id`, `user_id`, `publication_id`, `assigned_by_policy`, `policy_version`, `assignment_key`, `assigned_at`, timestamps.
  - Unique index on `experiment_id`, `decision_point_id`, `enrollment_id`.
- `experiment_exposures`
  - `id`, `assignment_id`, `experiment_id`, `decision_point_id`, `condition_id`, `section_id`, `enrollment_id`, `user_id`, `publication_id`, `content_revision_id`, `exposed_at`, `idempotency_key`, timestamps.
  - Unique index on `idempotency_key`.
- `experiment_outcomes`
  - `id`, `assignment_id`, `activity_attempt_id`, `resource_attempt_id`, `activity_resource_id`, `score`, `out_of`, `metadata`, `observed_at`, `idempotency_key`, timestamps.
  - Unique index on `idempotency_key`.
- `experiment_rewards`
  - `id`, `assignment_id`, `outcome_id`, `experiment_id`, `decision_point_id`, `condition_id`, `reward_value`, `reward_source`, `processed_at`, `idempotency_key`, `metadata`, timestamps.
  - Unique index on `idempotency_key`.
- `experiment_policy_states`
  - `id`, `experiment_id`, `decision_point_id`, `algorithm`, `algorithm_version`, `state`, `prior_config`, `reward_success_count`, `reward_failure_count`, `assignment_count`, `last_updated_from_reward_id`, timestamps.
  - Unique index on `experiment_id`, `decision_point_id`, `algorithm`.
- `experiment_policy_updates`
  - `id`, `policy_state_id`, `reward_id`, `condition_id`, `previous_state`, `next_state`, `algorithm_version`, `update_reason`, timestamps.
  - Unique index on `reward_id` for update idempotency.

Foreign keys should point to existing projects, sections, enrollments, users, publications, resources, revisions, and activity attempts where applicable. Delete behavior should preserve audit history; prefer restricted deletes or nullified optional references over cascading learner evidence.

## 7. Consistency & Transactions
- Assignment creation runs in a single `Repo.transaction/1` that validates scope, locks or upserts the assignment key, invokes the policy, inserts the assignment, and updates assignment counts where the policy state requires it.
- Sticky assignment reuse reads by the unique assignment key and does not mutate policy state.
- Exposure, outcome, reward, and policy update writes are idempotent through unique idempotency keys.
- Reward recording and Thompson Sampling posterior update should be atomic when synchronous. If later runtime work uses Oban for reward processing, the reward event is the durable source of truth and the policy update job must be retryable and idempotent by `reward_id`.
- Lifecycle transitions validate allowed state moves and reject condition changes that would invalidate existing assignments unless a later lifecycle slice defines an explicit migration rule.
- Analytics queries read committed domain records and must not influence assignment or policy state.

## 8. Caching Strategy
No cross-request cache is required for the contract slice. Delivery assignment correctness depends on PostgreSQL uniqueness and transactional reads.

Later delivery work may add short-lived caching for active experiment definitions by section/publication/decision point, but assignment, exposure, reward, and policy state remain database-authoritative. Any cache must be invalidated on lifecycle transitions and condition changes.

## 9. Performance & Scalability Posture
- Assignment is on a delivery hot path and should use indexed lookups by active experiment scope, decision point, and enrollment.
- The unique assignment index prevents duplicate assignment under concurrent requests.
- Exposure and reward writes are append-oriented and indexed by assignment, experiment, decision point, section, enrollment, and idempotency key.
- Analytics aggregates should be implemented through scoped queries or materialized/read-model tables when direct aggregates become expensive; reporting must not add joins to delivery hot paths.
- Thompson Sampling state is per experiment and decision point. Updates should lock the relevant policy-state row or use optimistic update semantics to avoid lost posterior updates.
- Performance review should focus on first assignment latency, sticky assignment latency, reward processing throughput, and aggregate reporting queries.

## 10. Failure Modes & Resilience
- No active or matching experiment: return `:no_experiment`; delivery uses first-option fallback.
- Invalid scope: return `{:error, %ExperimentError{type: :invalid_scope}}` and do not create assignment or exposure records.
- Condition mismatch between published alternatives and experiment definition: return `:invalid_condition`; delivery falls back and telemetry records the mismatch.
- Concurrent first assignment: the unique assignment constraint resolves races; loser reads the existing assignment and returns the same condition.
- Exposure retry: idempotency key returns the existing exposure receipt.
- Reward retry: idempotency key returns the existing reward receipt and does not double-count policy state.
- Policy update failure after reward persistence: retry by `reward_id`; analytics can report delayed or failed policy updates.
- Database unavailable: return a scoped error to callers. Delivery-runtime slice decides whether to fall back to first option for learner continuity.

## 11. Observability
Emit telemetry events from the public context boundary:

- `[:oli, :experiments, :assignment, :start | :stop | :exception]`
- `[:oli, :experiments, :assignment, :reuse]`
- `[:oli, :experiments, :assignment, :fallback]`
- `[:oli, :experiments, :exposure, :recorded]`
- `[:oli, :experiments, :reward, :recorded]`
- `[:oli, :experiments, :policy, :updated]`
- `[:oli, :experiments, :policy, :update_failed]`
- `[:oli, :experiments, :analytics, :query]`

Telemetry metadata should include scoped non-sensitive IDs such as experiment, decision point, section, publication, algorithm, lifecycle state, and error type. Logs should avoid learner names, LMS identifiers, and raw request payloads. AppSignal can consume telemetry/error reporting according to `docs/OPERATIONS.md`.

## 12. Security & Privacy
- Public APIs must validate institution/project/section/enrollment scope before reading or writing experiment records.
- Authoring lifecycle functions require existing project author/admin authorization at the caller boundary and revalidate project identity in the context.
- Delivery functions require section/enrollment/user consistency.
- Analytics reads must enforce caller scope and minimize personally identifiable learner data; aggregate responses should be the default.
- Private schemas should not be returned from context functions or rendered directly in LiveViews/controllers.
- Reward and outcome metadata should store only evidence required for experiment operation and research review, avoiding raw student response payloads unless a later approved requirement explicitly needs them.

## 13. Testing Strategy
- ExUnit contract tests for `Oli.Experiments` public APIs:
  - create/update definitions with valid and invalid condition sets.
  - active experiment lookup by project, section, publication, and decision point.
  - sticky assignment reuse by enrollment.
  - weighted deterministic assignment returns a valid condition and respects configured weights across deterministic samples.
  - invalid scope rejects cross-section or cross-enrollment calls.
  - exposure, outcome, reward, and policy update idempotency.
  - private schema leakage checks by asserting public responses are domain structs.
- Policy tests:
  - weighted deterministic random assignment is stable for the same assignment key and changes distribution over many keys.
  - Thompson Sampling behavior contract accepts binary rewards and produces auditable policy updates, with detailed posterior math covered in the later Thompson Sampling slice.
- Migration/schema tests:
  - required foreign keys, unique constraints, lifecycle enum validation, idempotency constraints, and key indexes.
- Scenario tests:
  - Not required for this contract-only slice unless implementation crosses authoring, publishing, and delivery behavior. Later delivery-runtime work should use `Oli.Scenarios` for end-to-end assignment/exposure/reward workflows.
- Validation gates:
  - Run targeted `mix test` files for the context and migrations.
  - Run `mix format` for Elixir changes.
  - Run harness requirements and work-item validation after FDD changes.

## 14. Backwards Compatibility
- This slice adds native domain persistence and APIs without changing learner-facing behavior.
- Existing UpGrade-backed experiments are not migrated and existing UpGrade runtime calls continue until the native cut-over and delivery-runtime slices replace them.
- Existing `has_experiments` project and section flags remain available as coarse gates during transition.
- Existing alternatives content remains publication-backed; native experiment definitions reference content but do not mutate published revisions.
- API structs should be versionable through additive fields so later analytics and Thompson Sampling work can extend responses without forcing direct schema dependencies.

## 15. Risks & Mitigations
- Risk: The context becomes a heavy pseudo-service. Mitigation: keep it as an internal Phoenix context with Ecto persistence, narrow public structs, and no separate deployment boundary.
- Risk: Delivery hot path slows down. Mitigation: use indexed local queries, sticky assignment lookup, transactional upsert, and telemetry for assignment latency.
- Risk: Direct table coupling appears in later slices. Mitigation: mark schemas private by module placement and review rule; expose analytics read functions and read models through `Oli.Experiments`.
- Risk: Publication and section scope are confused. Mitigation: require explicit `Scope` validation and store publication/section/enrollment IDs on assignment and exposure records.
- Risk: Rewards double-count and bias Thompson Sampling. Mitigation: require reward idempotency keys and unique `reward_id` policy updates.
- Risk: Analytics needs exceed the initial read contract. Mitigation: define context-owned read models as the extension point, not direct external joins.

## 16. Open Questions & Follow-ups
- Confirm whether the selected public namespace `Oli.Experiments` is acceptable or whether the team prefers `Oli.ABTesting`.
- Confirm whether experiment definitions are project-wide only for MVP or may be section-specific at creation time.
- Confirm whether `publication_id` should be required on native experiment definitions at activation or only on runtime assignment/exposure records.
- Confirm the MVP binary reward source for Thompson Sampling in the delivery/runtime and Thompson Sampling slices.
- Confirm the minimum analytics read models needed before broad availability.

## 17. References
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/OPERATIONS.md`
- `docs/PRODUCT_SENSE.md`
- `docs/STACK.md`
- `docs/TESTING.md`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/prd.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/prd.md`
- `docs/exec-plans/current/epics/ab_testing/analytics/prd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`
- `lib/oli/authoring/experiments.ex`
- `lib/oli/delivery/experiments.ex`
- `lib/oli/delivery/experiments/log_worker.ex`
- `lib/oli/resources/alternatives.ex`
- `lib/oli/resources/alternatives/decision_point_strategy.ex`
- `priv/repo/migrations/20230302142539_has_experiments.exs`
