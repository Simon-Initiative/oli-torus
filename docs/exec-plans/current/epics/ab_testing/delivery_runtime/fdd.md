# Native Delivery Runtime Replacement - Functional Design Document

## 1. Executive Summary
Replace learner-facing UpGrade runtime behavior with native delivery calls into `Oli.Experiments`. Alternatives decision points use native assignment records for sticky condition selection, record native exposures when assigned content is applied, and hand evaluated attempt outcomes to the native rewards contract with idempotency keys.

This design satisfies FR-001 through FR-005 by keeping runtime decisions inside the native A/B testing domain, preserving first-option fallback when no active native experiment matches, and adding the remaining evaluated-attempt integration needed for reliable reward records. It assumes the domain contract slice has already introduced `Oli.Experiments`, native `experiment_*` tables, request/receipt structs, telemetry, and baseline runtime command tests.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Delivery alternatives rendering must request condition assignment through `Oli.Experiments.assign_condition/1` for active native experiments.
  - FR-002: Repeated delivery visits by the same enrollment must reuse the native sticky assignment record.
  - FR-003: Delivery must call `Oli.Experiments.record_exposure/1` after assigned alternatives content is applied.
  - FR-004: Evaluated activity attempts must create or confirm a native outcome and binary reward event for the relevant assignment without duplicating rewards on retries.
  - FR-005: Inactive, missing, or non-matching native experiments must render the first alternatives option consistently.
- Acceptance criteria mapping:
  - AC-001: Sections 4 and 5 route active native experiment selection through `Oli.Experiments.assign_condition/1`, not UpGrade.
  - AC-002: Sections 4, 6, and 7 rely on `experiment_assignments` uniqueness by experiment, decision point, and enrollment.
  - AC-003: Sections 4 and 5 define exposure recording from `DecisionPointStrategy` after selected content is applied.
  - AC-004: Sections 4, 5, 6, and 7 define outcome and reward idempotency keys based on activity attempt and assignment identity.
  - AC-005: Sections 4, 10, and 13 preserve first-option fallback for no-match and controlled error cases.
- Non-functional requirements:
  - Assignment remains local to PostgreSQL/Ecto and uses indexed native records on the delivery hot path.
  - Reward handoff is idempotent and must not double-count Thompson Sampling posterior updates.
  - Scope validation preserves institution, project, publication, section, user, and enrollment boundaries.
  - Runtime integration emits telemetry for assignment, fallback, exposure, reward success, and reward failure.
- Assumptions:
  - `Oli.Experiments` and the `experiment_*` tables from the domain contract are available before this slice is implemented.
  - MVP assignment is sticky by enrollment for each experiment decision point.
  - The native alternatives strategy continues to use the legacy strategy string `"upgrade_decision_point"` as a content marker until authoring lifecycle work introduces provider-neutral naming.
  - The MVP binary reward source is activity attempt correctness: score divided by out_of maps to `1.0` when the evaluated activity earns full credit and `0.0` otherwise.
  - Delivery code consumes `Oli.Experiments` request and receipt structs only; it does not read or mutate experiment-owned schemas directly.

## 3. Repository Context Summary
- What we know:
  - Torus is a Phoenix/Ecto monolith where backend domain rules belong under `lib/oli/`, and delivery runtime orchestration belongs in `lib/oli/delivery` and resource rendering modules.
  - `Oli.Experiments` already exposes `assign_condition/1`, `record_exposure/1`, `record_outcome/1`, and `record_reward/1` with `Scope`, request structs, receipts, native telemetry, and private Ecto schemas.
  - `lib/oli/resources/alternatives.ex` dispatches alternatives with strategy `"upgrade_decision_point"` to `Oli.Resources.Alternatives.DecisionPointStrategy`.
  - `DecisionPointStrategy` already calls `Oli.Experiments.assign_condition/1`, records exposure through `record_exposure/1`, and falls back to `display_first/1`.
  - Delivery attempts are evaluated through `Oli.Delivery.Attempts.ActivityLifecycle.Evaluate`, `Persistence`, `RollUp`, page lifecycle modules, and manual grading paths that set `lifecycle_state: :evaluated`, score, out_of, and date_evaluated.
  - Native persistence includes `experiment_assignments`, `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, `experiment_policy_states`, and `experiment_policy_updates`.
  - Existing domain tests cover assignment no-match fallback telemetry, sticky assignment reuse, exposure/outcome/reward idempotency, scope rejection for reused receipts outside caller scope, and Thompson Sampling reward update idempotency.
- Unknowns to confirm:
  - Whether reward handoff should run synchronously in the evaluation transaction or enqueue an Oban worker after evaluation commits. This design selects an after-commit synchronous call where practical, with Oban as the retry path if implementation cannot keep the evaluation transaction small.
  - Whether partial credit should be treated as success only at full credit or with a threshold. This design selects full-credit binary success for MVP because Thompson Sampling PRD scope is binary reward.
  - Whether a single activity evaluation should reward every active assignment visible on the page or only assignments linked to the evaluated activity's rendered alternative branch. This design selects assignment records whose selected alternative contained the evaluated activity resource.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` remains the only authoritative native runtime boundary. Delivery code builds explicit request structs and receives domain receipts or controlled errors.

- `Oli.Resources.Alternatives.DecisionPointStrategy`: owns alternatives selection at render time. It builds an `AssignConditionRequest`, renders the selected condition, records exposure, and uses first-option fallback for no active experiment or controlled errors.
- `Oli.Resources.Alternatives.AlternativesStrategyContext`: carries delivery identity into strategy execution: enrollment, user, section slug, project slug, mode, and alternatives group metadata.
- `Oli.Experiments`: owns sticky assignment, exposure, outcome, reward, policy-state mutation, idempotency constraints, and native telemetry.
- New delivery reward handoff helper, placed under `lib/oli/delivery/experiments/` or `lib/oli/delivery/attempts/`, translates evaluated activity attempts into `RecordOutcomeRequest` and `RecordRewardRequest`. It must remain a caller of `Oli.Experiments`, not an owner of experiment schemas.
- Activity evaluation paths call the reward handoff helper after an activity attempt reaches `:evaluated` with score and out_of. The hook should be close to the existing roll-up or persistence boundary so standard evaluation, adaptive/client evaluation, manual grading, and page finalization use one path where possible.

### 4.2 State & Data Flow
Assignment and exposure flow:

1. Delivery renders a page containing an alternatives element whose group strategy is `"upgrade_decision_point"`.
2. `DecisionPointStrategy.select/2` resolves the alternatives group from `alternative_groups_by_id`.
3. The strategy builds `Scope` from section/project delivery context and calls `Oli.Experiments.assign_condition/1` with alternatives resource ID, alternatives revision ID, decision point key, and available condition codes.
4. `Oli.Experiments` returns a sticky assignment decision, reusing an existing `experiment_assignments` row when present.
5. The strategy renders only the matching alternatives child and hides the rest.
6. After content selection succeeds, the strategy calls `record_exposure/1` with an idempotency key based on alternatives resource, content revision, and enrollment.
7. If no active native experiment matches, or a controlled mismatch occurs, the strategy renders the first child and does not fabricate native assignment/exposure records.

Outcome and reward flow:

1. Activity evaluation persists part and activity attempt results through the existing attempts lifecycle.
2. After the activity attempt is evaluated, the delivery reward handoff locates native assignment records for the same section, user/enrollment, publication, and relevant page alternatives exposure.
3. For each eligible assignment, delivery calls `record_outcome/1` with activity attempt ID, resource attempt ID, activity resource ID, score, out_of, observed_at, and idempotency key `outcome:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>`.
4. Delivery then calls `record_reward/1` with `reward_value` `1.0` for full credit and `0.0` otherwise, reward source `"activity_attempt:evaluated"`, outcome ID, and idempotency key `reward:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>`.
5. `Oli.Experiments` persists the reward once and applies policy update idempotency through `experiment_policy_updates.reward_id`.
6. Reprocessing the same evaluated activity attempt returns reused receipts and must not double-count reward success/failure.

### 4.3 Lifecycle & Ownership
Native delivery only creates runtime evidence for experiments in the `:active` lifecycle state. Paused, completed, archived, draft, inactive, missing, or publication/section-mismatched definitions produce fallback behavior and no new runtime records.

Assignments are owned by `Oli.Experiments` for the lifetime of an active experiment decision point. Delivery owns only the decision to ask for assignment and the timing of exposure and reward calls. Attempt records remain owned by `Oli.Delivery.Attempts`; experiment outcomes store references to those attempts without changing attempt lifecycle semantics.

### 4.4 Alternatives Considered
- Keep UpGrade runtime calls as fallback when native assignment fails: rejected because it creates split-brain assignment sources and violates the native cut-over direction.
- Continue using section extrinsics as sticky state: rejected because native assignment records are authoritative and need analytics/reward joins.
- Record reward during initial page render: rejected because reward depends on evaluated activity outcomes and would bias policy state before evidence exists.
- Record only rewards and skip outcomes: rejected because analytics and audit need the outcome association that explains the binary reward.
- Add a feature flag for this runtime path: rejected for this work item because the PRD states no feature flags are present and `harness.yml` defaults feature flags to excluded. Normal deployment sequencing and tests are the rollout mechanism.
- Push all reward work to Oban immediately: not selected as the default because the MVP needs simple idempotent handoff first. Oban remains acceptable if implementation proves synchronous reward handoff makes evaluation transactions too large or too failure-prone.

## 5. Interfaces
- Alternatives selection:
  - Existing `Oli.Resources.Alternatives.select/2` dispatches `"upgrade_decision_point"` groups to `DecisionPointStrategy`.
  - `DecisionPointStrategy.select/2` accepts `%AlternativesStrategyContext{mode: :delivery}` and an alternatives element map containing `"children"` and `"alternatives_id"`.
- Native assignment:
  - `Oli.Experiments.assign_condition(%AssignConditionRequest{}) :: {:ok, %AssignmentDecision{}} | {:error, %ExperimentError{}}`
  - Required request fields: `%Scope{institution_id, project_id or project_slug, publication_id, section_id or section_slug, user_id, enrollment_id}`, `alternatives_resource_id`, `alternatives_revision_id`, `decision_point_key`, and `available_condition_codes`.
  - Delivery treats `%AssignmentDecision{status: :no_experiment}` as first-option fallback.
- Native exposure:
  - `Oli.Experiments.record_exposure(%RecordExposureRequest{}) :: {:ok, %ExposureReceipt{}} | {:error, %ExperimentError{}}`
  - Required request fields: scope, assignment_id, content_revision_id, idempotency_key, optional exposed_at.
  - Exposure failures are logged/telemetered but do not block content rendering.
- Native outcome:
  - `Oli.Experiments.record_outcome(%RecordOutcomeRequest{}) :: {:ok, %OutcomeReceipt{}} | {:error, %ExperimentError{}}`
  - Required request fields for this slice: scope, assignment_id, activity_attempt_id, resource_attempt_id, activity_resource_id, score, out_of, observed_at, idempotency_key.
- Native reward:
  - `Oli.Experiments.record_reward(%RecordRewardRequest{}) :: {:ok, %RewardReceipt{}} | {:error, %ExperimentError{}}`
  - Required request fields: scope, assignment_id, outcome_id, reward_value, reward_source, idempotency_key.
- Reward handoff helper:
  - Proposed public boundary inside delivery: `record_evaluated_activity(activity_attempt_id | %ActivityAttempt{}) :: :ok | {:error, term()}`.
  - It loads the activity attempt, resource attempt, resource access/enrollment identity, matching assignment records, computes binary reward, and calls `Oli.Experiments`.
  - It returns `:ok` when there is no matching native assignment so normal non-experiment delivery remains unaffected.

## 6. Data Model & Storage
- No new experiment tables are required for this slice. It uses the native tables from the domain contract:
  - `experiment_assignments` for sticky assignment by experiment, decision point, and enrollment.
  - `experiment_exposures` for idempotent applied-content evidence.
  - `experiment_outcomes` for evaluated activity attempt association.
  - `experiment_rewards` for binary reward events.
  - `experiment_policy_states` and `experiment_policy_updates` for policy updates and Thompson Sampling audit.
- No UpGrade assignment, mark, log, or extrinsic state should be written by this slice.
- If the implementation needs to query assignment candidates from delivery code, add or expose a context-owned `Oli.Experiments` query such as `assignments_for_evaluated_activity/1`; delivery must not join directly against private experiment schemas.
- Existing `has_experiments` project/section fields may remain as coarse gates only. They are not sticky assignment storage and must not imply external-provider availability.
- Reward metadata should remain minimal, such as activity attempt number or scoring source. Do not store raw student responses in experiment reward metadata.

## 7. Consistency & Transactions
- Assignment creation relies on `experiment_assignments_sticky_idx` and `experiment_assignments_key_idx` to resolve concurrent first visits.
- Exposure, outcome, and reward creation rely on unique idempotency keys. Reused receipts are valid success responses.
- Reward policy updates must remain atomic with reward persistence when synchronous. If Oban is introduced, the reward row is the durable source of truth and the policy update job is idempotent by `reward_id`.
- The activity attempt evaluation transaction should not be rolled back solely because native reward handoff fails after the attempt has been persisted. Reward handoff failures should produce telemetry and be retryable through idempotent calls.
- If reward handoff runs inside an existing evaluation transaction, it must avoid long-running queries and external calls. Native reward handoff must remain local database work.
- Scope validation must confirm the assignment belongs to the same section/enrollment/user before exposure, outcome, or reward receipts are reused.

## 8. Caching Strategy
- No cross-request cache is required for MVP runtime assignment, exposure, outcome, or reward handoff.
- Sticky state is the `experiment_assignments` table, not section extrinsics or process memory.
- Active experiment lookup may later use a short-lived cache inside `Oli.Experiments`, but correctness must remain database-authoritative and cache invalidation must be tied to experiment lifecycle transitions.

## 9. Performance & Scalability Posture
- Assignment is on the page render hot path. It should remain a small number of indexed local queries by active experiment scope, decision point identity, and enrollment.
- Sticky assignment reuse should avoid policy selection and only read the existing assignment.
- Exposure recording should be idempotent and cheap; failure must not block learner rendering.
- Reward handoff runs after evaluation, not during page render. It may synchronously write outcome/reward records when the matching assignment set is small.
- If a page can expose many experiment decision points, reward handoff must batch or bound assignment lookup by section, enrollment, publication, and activity resource to avoid broad scans.
- Performance review should inspect assignment latency, exposure write latency, evaluated-attempt reward latency, reward retry throughput, and remaining UpGrade runtime references.

## 10. Failure Modes & Resilience
- No active native experiment: return `:no_experiment`, render first option, emit fallback telemetry.
- Active experiment condition mismatch: log/telemetry with `:invalid_condition`, render first option, and avoid exposure/reward writes for that assignment decision.
- Assignment persistence conflict: native context reads the winning assignment and returns a reused sticky decision.
- Exposure retry: unique idempotency key returns the existing exposure receipt.
- Evaluated attempt reprocessed: outcome and reward idempotency keys return existing receipts and policy state is not double-counted.
- Reward handoff cannot locate a matching assignment: return `:ok` and do nothing, because most evaluated attempts are not experiment-driven.
- Reward handoff fails after activity evaluation succeeds: emit telemetry/log with scoped non-sensitive IDs and allow retry. Do not call UpGrade.
- Native database unavailable during assignment: delivery uses first-option fallback only when the error is handled as learner-continuity fallback. The error must be observable.
- Native database unavailable during reward handoff: preserve the evaluated attempt and retry or report the failed reward handoff without changing learner-facing evaluation.

## 11. Observability
- Preserve native context telemetry:
  - `[:oli, :experiments, :assignment, :start]`
  - `[:oli, :experiments, :assignment, :stop]`
  - `[:oli, :experiments, :assignment, :exception]`
  - `[:oli, :experiments, :assignment, :reuse]`
  - `[:oli, :experiments, :assignment, :fallback]`
  - `[:oli, :experiments, :exposure, :recorded]`
  - `[:oli, :experiments, :reward, :recorded]`
  - `[:oli, :experiments, :policy, :updated]`
  - `[:oli, :experiments, :policy, :update_failed]`
- Add delivery-side reward handoff telemetry:
  - `[:oli, :experiments, :delivery_reward, :start]`
  - `[:oli, :experiments, :delivery_reward, :stop]`
  - `[:oli, :experiments, :delivery_reward, :exception]`
  - `[:oli, :experiments, :delivery_reward, :skipped]`
- Metadata should include non-sensitive IDs: experiment_id, assignment_id, decision_point_id, section_id, publication_id, activity_attempt_id, activity_resource_id, algorithm, and error type.
- Logs must not include learner names, LMS identifiers, raw activity responses, API tokens, or full activity payloads.
- AppSignal can consume telemetry/errors according to `docs/OPERATIONS.md`.

## 12. Security & Privacy
- All runtime calls must carry explicit `Scope` and rely on `Oli.Experiments` validation for institution, project, publication, section, enrollment, and user boundaries.
- Delivery must not expose private experiment schemas or raw assignment tables through controllers, LiveViews, or APIs.
- Reward metadata must avoid raw learner responses and any LMS-sourced personal identifiers.
- Cross-section, cross-enrollment, or cross-institution idempotency key reuse must return an invalid-scope error rather than leaking receipt details.
- Removing UpGrade runtime calls reduces external sharing of learner assignment and correctness data.

## 13. Testing Strategy
- ExUnit domain tests:
  - Keep existing `Oli.Experiments` runtime tests for no-experiment fallback, sticky assignment reuse, condition mismatch, exposure/outcome/reward idempotency, scope rejection, and Thompson Sampling update idempotency.
  - Add contract tests for any new context-owned query used by reward handoff to find assignments for evaluated activities.
- Alternatives delivery tests:
  - Verify `DecisionPointStrategy` calls native assignment and renders the selected condition.
  - Verify repeated selection for the same enrollment reuses the native assignment.
  - Verify exposure is recorded only after selected content is applied.
  - Verify inactive, missing, and condition-mismatched experiments render first option.
  - Verify assignment/exposure errors do not expose learner-facing failures.
- Evaluated-attempt reward tests:
  - Standard auto-graded activity evaluation records outcome and reward once.
  - Reprocessing the same evaluated attempt returns reused receipts and does not create duplicate rewards or policy updates.
  - Partial or incorrect results map to binary reward `0.0`; full-credit results map to `1.0`.
  - Manual grading and client/adaptive evaluation paths use the same handoff or are explicitly covered by follow-up tests if their hook point differs.
  - Non-experiment activity attempts skip reward handoff without error.
- Scenario tests:
  - Add `Oli.Scenarios` coverage for authoring alternatives, publishing, section delivery, enrollment, native assignment, stable repeated visit, exposure record, evaluated attempt, and idempotent reward handoff.
  - Add fallback scenario coverage for no active native experiment and first-option rendering.
- Static/security/performance checks:
  - Search for remaining delivery runtime calls to UpGrade assignment, mark, and log behavior.
  - Confirm reward metadata does not include raw responses.
  - Review query plans or indexes for assignment lookup and reward handoff lookup when implementation adds those queries.
- Validation gates:
  - Run targeted `mix test` for `test/oli/experiments/runtime_test.exs`, alternatives delivery tests, and reward handoff tests.
  - Run targeted scenario runner for new scenario coverage.
  - Run `mix format`.
  - Run harness requirements trace and FDD validation.

## 14. Backwards Compatibility
- Learner-visible fallback behavior remains first-option rendering when no active native experiment applies.
- Existing UpGrade-backed assignments and extrinsic state are not migrated and do not become native assignment authority.
- Existing alternatives groups using strategy `"upgrade_decision_point"` continue to route to the native decision-point strategy during the transition.
- Non-experiment pages and activities should behave exactly as before; reward handoff is a no-op when no matching native assignment exists.
- Existing attempt lifecycle, scoring, grade update, xAPI, and analytics flows remain authoritative for normal learner progress. Experiment outcome/reward records are additional native evidence.

## 15. Risks & Mitigations
- Risk: Delivery hot path slows down. Mitigation: use indexed native assignment lookups, reuse sticky records, avoid external calls, and monitor assignment telemetry.
- Risk: Reward events duplicate on retries. Mitigation: derive deterministic idempotency keys from activity attempt and assignment IDs and rely on unique constraints.
- Risk: Policy state double-counts rewards. Mitigation: keep `experiment_policy_updates.reward_id` unique and test repeated reward processing.
- Risk: Reward handoff associates the wrong assignment with an activity. Mitigation: use context-owned scoped queries that join through exposure/assignment identity and activity resource relationships rather than broad section scans.
- Risk: Scope data is incomplete when alternatives strategy only has slugs. Mitigation: resolve slugs to IDs before domain calls where possible and fail with observable fallback when required delivery scope is missing.
- Risk: Manual grading or adaptive/client evaluation bypasses reward handoff. Mitigation: hook near the common evaluated-attempt roll-up boundary and add tests for each evaluation path.
- Risk: Existing UpGrade-named strategy confuses future maintainers. Mitigation: document it as a transition marker in this slice and move provider-neutral naming to authoring lifecycle/cut-over follow-up.

## 16. Open Questions & Follow-ups
- Confirm the MVP binary reward rule: full-credit success only versus a configurable correctness threshold.
- Confirm whether reward handoff should be synchronous after evaluation commit or Oban-backed from the first implementation.
- Confirm the exact assignment-to-activity association rule for pages where one alternatives decision point controls multiple activities.
- Follow up with authoring lifecycle work to rename or replace the legacy `"upgrade_decision_point"` strategy marker.
- Follow up with analytics work to define reporting semantics for outcome/reward timestamps and delayed reward retries.

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
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/native_cutover/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/prd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/requirements.yml`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/assign_condition_request.ex`
- `lib/oli/experiments/record_exposure_request.ex`
- `lib/oli/experiments/record_outcome_request.ex`
- `lib/oli/experiments/record_reward_request.ex`
- `lib/oli/experiments/scope.ex`
- `lib/oli/resources/alternatives.ex`
- `lib/oli/resources/alternatives/alternatives_strategy_context.ex`
- `lib/oli/resources/alternatives/decision_point_strategy.ex`
- `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex`
- `lib/oli/delivery/attempts/activity_lifecycle/persistence.ex`
- `lib/oli/delivery/attempts/activity_lifecycle/roll_up.ex`
- `priv/repo/migrations/20260625120000_create_experiment_tables.exs`
- `test/oli/experiments/runtime_test.exs`
