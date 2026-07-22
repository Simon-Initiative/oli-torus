# Thompson Sampling MVP Adaptive Policy - Functional Design Document

## 1. Executive Summary
Upgrade the existing `Oli.Experiments` Thompson Sampling placeholder into the MVP adaptive assignment policy for native A/B testing. The implementation remains inside the A/B testing domain boundary, uses Beta-Bernoulli posterior sampling for first assignment selection, updates only the assigned condition from idempotent binary rewards, and enables lifecycle-safe Thompson Sampling authoring after backend validation is available.

This design satisfies FR-001 through FR-006 by reusing the established `Oli.Experiments` policy, reward, policy-state, delivery, and LiveView authoring contracts. It avoids a new service boundary or client-side algorithm logic; delivery continues to ask for an assignment without knowing which algorithm is active, and authoring delegates adaptive validation to backend context commands.

## 2. Requirements & Assumptions
- Functional requirements:
  - FR-001: Implement non-contextual Thompson Sampling for A/B/N alternatives experiments using binary Beta-Bernoulli rewards.
  - FR-002: Persist per-condition posterior parameters, prior configuration, algorithm name/version, reward counts, assignment counts, and update provenance.
  - FR-003: For non-sticky first assignments, sample each active condition posterior and select the condition with the highest sampled value.
  - FR-004: Reward processing updates only the learner's assigned condition and remains idempotent when the same reward event is replayed.
  - FR-005: Support MVP guardrails for adaptive release: manual pause through lifecycle state, warm-up behavior, traffic allocation caps, fixed control allocation, and imbalance monitoring flags.
  - FR-006: Enable authorized users to create, edit, validate, and activate Thompson Sampling experiments through the A/B Testing authoring surface with safe defaults.
- Acceptance criteria mapping:
  - AC-001: Sections 4, 5, 6, 7, and 13 define Beta posterior state, binary success/failure reward updates, and deterministic test seams for sampling.
  - AC-002: Sections 5, 6, and 11 define policy metadata, posterior snapshots, update audit records, and approved inspection paths.
  - AC-003: Sections 4 and 7 preserve sticky assignment lookup before policy selection and use posterior sampling only for first assignments.
  - AC-004: Sections 4, 7, and 13 rely on reward idempotency keys and `experiment_policy_updates.reward_id` uniqueness so replayed rewards do not double-count.
  - AC-005: Sections 4, 5, 10, and 11 define guardrail behavior, fallback, telemetry, and audit evidence.
  - AC-006: Sections 4, 5, 12, and 13 replace the disabled authoring affordance with backend-validated Thompson Sampling configuration.
- Non-functional requirements:
  - Assignment remains performant on the delivery hot path and uses local Ecto/PostgreSQL data only.
  - Sampling behavior must be testable through an injectable or deterministic random source at the policy boundary, while production uses a real random generator.
  - Posterior updates must be auditable, scoped, and safe under reward retries and concurrent processing.
  - Authoring validation errors must be field-safe and must not expose learner identities or raw responses.
- Assumptions:
  - `domain_contract`, `delivery_runtime`, and `authoring_lifecycle` slices are available first, including `Oli.Experiments`, experiment tables, reward handoff, and weighted random authoring.
  - The MVP binary reward source is the delivery-runtime full-credit rule: `1.0` for full credit and `0.0` otherwise.
  - MVP priors default to Beta(1,1) for every active condition unless an authorized author/admin supplies valid positive alpha and beta values.
  - MVP supports exactly one alternatives decision point per experiment, matching the authoring lifecycle design.
  - Sticky assignment by experiment, decision point, and enrollment remains authoritative even when posterior state changes after assignment.

## 3. Repository Context Summary
- What we know:
  - `Oli.Experiments` owns native A/B testing domain rules, private schemas, public request/receipt structs, lifecycle commands, assignment, reward recording, analytics reads, and telemetry.
  - `Oli.Experiments.Policies.Policy` already defines `assign/3` and `record_reward/3`; `WeightedRandom` is deterministic and `ThompsonSampling` currently exists as a placeholder.
  - Current `ThompsonSampling.assign/3` selects by posterior mean rather than drawing from a Beta posterior, and current state stores `successes`/`failures` without explicit alpha/beta prior fields.
  - `experiment_policy_states` already stores `algorithm`, `algorithm_version`, JSON `state`, JSON `prior_config`, aggregate reward counts, assignment count, and `last_updated_from_reward_id`.
  - `experiment_policy_updates` stores previous/next policy state, reward ID, condition ID, algorithm version, and update reason with a unique reward constraint.
  - Runtime assignment already checks for an existing sticky assignment before invoking the policy module.
  - Delivery reward handoff already records outcomes and rewards through `Oli.Experiments.record_outcome/1` and `record_reward/1` with idempotency keys derived from activity attempt and assignment IDs.
  - `OliWeb.Workspaces.CourseAuthor.ExperimentsLive` currently creates weighted random experiments and shows disabled Thompson Sampling "Coming soon" copy.
- Unknowns to confirm:
  - Whether alpha/beta priors should be author-facing for all authors or limited to administrators. This design allows backend support and recommends exposing defaults to authors while reserving advanced edits for permitted administrators if product requires it.
  - The final guardrail set required for production launch. This design selects a concrete MVP set so planning can proceed, but individual thresholds should be product-approved before implementation.
  - Whether analytics UI will show full policy-state detail or a reduced operational summary. This FDD requires context-owned inspection data and leaves dashboard presentation to the analytics slice.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Experiments` remains the owning boundary. The Thompson Sampling slice changes policy behavior, policy-state normalization, authoring validation, and adaptive configuration rendering without exposing private schemas to delivery or web code.

- `Oli.Experiments.Policies.ThompsonSampling`: implements Beta posterior sampling and binary reward updates. It owns algorithm versioning and pure policy math.
- `Oli.Experiments`: normalizes Thompson Sampling `policy_config`, creates initial policy state, validates activation readiness, applies guardrails, invokes policy assignment, and persists policy updates.
- `Oli.Experiments.Schemas.PolicyState`: continues to store JSON state and prior config; changeset validation may be tightened for Thompson Sampling through context validation rather than schema-specific algorithm branches.
- `Oli.Experiments.Schemas.PolicyUpdate`: remains the audit trail for every processed reward update.
- `Oli.Delivery.Experiments.RewardHandoff`: remains the delivery caller that translates evaluated attempts into binary reward events; no Thompson-specific logic belongs there.
- `OliWeb.Workspaces.CourseAuthor.ExperimentsLive`: replaces disabled "Coming soon" controls with adaptive form fields and lifecycle errors, while calling `Oli.Experiments` for validation and persistence.
- Analytics or inspection callers use `Oli.Experiments.policy_state_snapshot/1` or existing analytics summary functions, not private tables.

### 4.2 State & Data Flow
Authoring flow:

1. Authorized user selects Thompson Sampling in the A/B Testing authoring form.
2. LiveView submits algorithm `:thompson_sampling`, one alternatives decision point, active conditions, prior settings, and guardrail settings in `policy_config`.
3. `Oli.Experiments.create_experiment/1` or `update_experiment/2` validates project scope, condition mappings, binary reward readiness, priors, and guardrails.
4. The context persists the definition graph and initializes `experiment_policy_states` with algorithm version, per-condition posterior state, prior config, assignment count `0`, and reward counts `0`.
5. Activation revalidates current alternatives content, active condition mappings, priors, guardrails, and reward readiness before moving the experiment to `:active`.

Assignment flow:

1. Delivery calls `Oli.Experiments.assign_condition/1` exactly as it does for weighted random.
2. The context returns an existing sticky assignment when one exists for experiment, decision point, and enrollment.
3. For first assignments, the context loads active conditions and Thompson policy state, applies assignment guardrails, and calls `ThompsonSampling.assign/3`.
4. The policy samples from each condition's Beta posterior and returns the highest sampled condition.
5. The context inserts the assignment and increments assignment count in a transaction where policy-state assignment counters are maintained.

Reward flow:

1. Evaluated attempts produce idempotent binary rewards through the delivery reward handoff.
2. `Oli.Experiments.record_reward/1` reuses an existing reward receipt when the idempotency key has already been processed.
3. For a new reward, the context resolves the assignment and assigned condition, locks or transactionally updates the policy state, and calls `ThompsonSampling.record_reward/3`.
4. The policy increments only the assigned condition's posterior success or failure count and returns previous/next state plus aggregate counter deltas.
5. The context persists `experiment_policy_updates` with `reward_id` uniqueness and updates `experiment_policy_states.last_updated_from_reward_id`.

### 4.3 Lifecycle & Ownership
Thompson Sampling experiment definitions, policy state, assignments, rewards, and updates are owned by `Oli.Experiments`. Authoring resources remain owned by authoring/resources, and delivery attempts remain owned by delivery attempts.

Only `:active` Thompson Sampling experiments can create new assignments. `:paused`, `:completed`, `:archived`, and `:draft` states do not create new assignments; manual pause is the primary operator guardrail. Existing sticky assignments remain stable and auditable after later rewards update the posterior.

### 4.4 Alternatives Considered
- Keep posterior-mean selection in `ThompsonSampling.assign/3`: rejected because FR-003 specifically requires sampling active condition posteriors.
- Store alpha/beta values only as derived counters in `state`: rejected because FR-002 requires persisted prior configuration and auditable posterior metadata. The state should make prior and observed counts explicit enough for inspection.
- Put Thompson Sampling in a background service: rejected because delivery assignment needs local transactionality and the domain contract explicitly keeps native A/B testing inside the Phoenix/Ecto application.
- Add algorithm branches to delivery reward handoff: rejected because delivery should not know which policy is active; `Oli.Experiments` owns reward-to-policy mutation.
- Enable authoring before backend validation is complete: rejected because lifecycle validation must block unsafe adaptive experiments.
- Add a scoped feature flag: not selected because the PRD states no feature flags for this work item and `harness.yml` defaults feature flags to excluded. Rollout uses normal deployment sequencing plus lifecycle/guardrail controls.

## 5. Interfaces
- Policy behavior:
  - `Oli.Experiments.Policies.ThompsonSampling.assign(policy_config, policy_state, context) :: {:ok, %PolicyAssignment{}} | {:error, term()}`
  - Required context fields: `conditions`, `assignment_key`, and optional `rng` or `random_seed` used only for deterministic tests.
  - `policy_state` shape per condition:
    - `"prior_alpha"`: positive number.
    - `"prior_beta"`: positive number.
    - `"successes"`: non-negative integer observed reward successes.
    - `"failures"`: non-negative integer observed reward failures.
    - `"posterior_alpha"`: prior alpha plus successes.
    - `"posterior_beta"`: prior beta plus failures.
  - Production assignment samples `Beta(posterior_alpha, posterior_beta)` per active condition and selects the maximum sample.
  - Tests can inject a deterministic sampler into `policy_config` or policy context without persisting a test-only function.
- Reward policy:
  - `ThompsonSampling.record_reward(policy_config, policy_state, %{condition_code, reward_value})`
  - `reward_value >= 1.0` increments success; all other binary MVP rewards increment failure.
  - The returned `PolicyUpdate` includes algorithm version `thompson_sampling:v2`, previous state, next state, update reason `"binary_reward"`, and aggregate success/failure counter delta.
- Authoring commands:
  - `CreateExperimentRequest.algorithm` and `UpdateExperimentRequest.algorithm` accept `:thompson_sampling` for graph requests after this slice.
  - `policy_config` accepts:
    - `"priors"`: per-condition or default alpha/beta prior settings.
    - `"guardrails"`: warm-up count, traffic cap, optional fixed control allocation, imbalance threshold, and manual pause behavior.
    - `"reward_source"`: `"activity_attempt:full_credit"` for MVP.
  - Validation rejects non-positive alpha/beta values, malformed per-condition prior keys, unsupported reward sources, impossible traffic caps, and guardrails that cannot be enforced.
- Lifecycle:
  - `activate_experiment/2` validates Thompson Sampling readiness instead of returning "coming soon" for project-authored graph experiments.
  - `pause_experiment/2` remains the manual pause mechanism and must be visible as a guardrail state in authoring and inspection output.
- Inspection:
  - `policy_state_snapshot/1` or `experiment_summary/1` returns algorithm, algorithm version, prior config, posterior per condition, assignment count, reward counts, last update timestamp/reward ID, and guardrail state for authorized analytics or operations callers.

## 6. Data Model & Storage
- Reuse `experiment_definitions`:
  - `algorithm = :thompson_sampling`.
  - `policy_config` stores normalized Thompson Sampling config:
    - `"reward_source" => "activity_attempt:full_credit"`.
    - `"priors" => %{"default" => %{"alpha" => 1.0, "beta" => 1.0}, "conditions" => %{...}}`.
    - `"guardrails" => %{"warm_up_assignments" => integer, "max_condition_share" => number, "fixed_control_allocation" => number | nil, "imbalance_threshold" => number, "manual_pause_enabled" => true}`.
- Reuse `experiment_policy_states`:
  - `algorithm = :thompson_sampling`.
  - `algorithm_version = "thompson_sampling:v2"`.
  - `prior_config` stores the normalized prior settings used to initialize or interpret state.
  - `state` stores per-condition posterior metadata by `condition_code`.
  - `reward_success_count`, `reward_failure_count`, `assignment_count`, and `last_updated_from_reward_id` remain aggregate inspection fields.
- Reuse `experiment_policy_updates`:
  - Each reward update stores previous/next posterior state, condition ID, reward ID, algorithm version, and update reason.
  - Existing unique `reward_id` constraint remains the durable idempotency guard.
- No new table is required for MVP guardrails. Guardrail state is derived from policy config, assignments, rewards, lifecycle state, and policy state.
- Add no raw learner responses, names, LMS identifiers, or activity payloads to Thompson Sampling policy config or state.

## 7. Consistency & Transactions
- Sticky assignment lookup happens before policy invocation and remains keyed by experiment, decision point, and enrollment.
- First assignment creation runs in a transaction that:
  - validates active experiment scope;
  - loads active conditions;
  - locks or safely updates the policy-state row when assignment counters or guardrail counters are changed;
  - applies guardrails;
  - samples and inserts assignment;
  - handles unique assignment conflicts by reading the winning sticky assignment.
- Reward recording remains idempotent by reward idempotency key and policy update `reward_id`.
- Posterior updates for Thompson Sampling must lock the relevant `experiment_policy_states` row or use equivalent optimistic update semantics to avoid lost updates when rewards arrive concurrently.
- Assignment count and reward counters must be changed only by `Oli.Experiments`, never by delivery, authoring, or analytics code.
- Activation validates priors and guardrails in the same transaction as the state transition to `:active`.

## 8. Caching Strategy
- No new cross-request cache is required.
- Thompson Sampling assignment and posterior update correctness is database-authoritative.
- If active experiment lookup is already cached by runtime work, lifecycle transitions, policy config edits, pause actions, and condition edits must invalidate the cache through `Oli.Experiments`.
- Do not cache posterior samples or sampled condition choices outside the persisted sticky assignment record.

## 9. Performance & Scalability Posture
- Assignment remains on the delivery hot path, so Thompson Sampling must add only bounded work proportional to the number of active conditions in one decision point.
- A/B/N condition counts are expected to be small for MVP; sampling one Beta value per active condition is acceptable.
- Sticky assignment reuse avoids policy sampling and policy-state writes.
- Reward updates occur after evaluation, not during page render, and use indexed reward/update idempotency keys.
- Guardrail checks should use already-loaded policy state and indexed assignment counts rather than broad scans.
- Performance review should inspect first-assignment latency, sticky-assignment latency, policy-state row lock contention under reward bursts, and analytics snapshot query cost.

## 10. Failure Modes & Resilience
- Invalid prior config: reject create/update/activation with field-safe validation errors and do not persist malformed adaptive config.
- Missing reward readiness: block activation with a lifecycle validation error explaining that binary reward handoff is unavailable.
- No active conditions: return an invalid-condition error and preserve delivery fallback behavior.
- Sampler failure or malformed policy state: emit policy assignment telemetry with error type and use controlled delivery fallback rather than exposing learner errors.
- Concurrent first assignment: unique assignment constraints resolve the race, and the losing request returns the existing sticky assignment.
- Concurrent reward updates: policy-state locking or optimistic update retry prevents lost posterior increments.
- Replayed reward: existing reward receipt is returned, `experiment_policy_updates` is not duplicated, and posterior counts do not change.
- Guardrail pause: lifecycle state `:paused` prevents new assignment creation while preserving existing assignments and audit state.
- Guardrail threshold exceeded: new first assignments follow the configured constraint or flag telemetry/inspection state; sticky assignments still return unchanged.
- Database unavailable during assignment: delivery follows existing controlled fallback behavior and emits observable errors.
- Database unavailable during reward processing: evaluated attempt remains persisted; reward handoff can be retried idempotently.

## 11. Observability
- Preserve existing context telemetry:
  - `[:oli, :experiments, :assignment, :start]`
  - `[:oli, :experiments, :assignment, :stop]`
  - `[:oli, :experiments, :assignment, :exception]`
  - `[:oli, :experiments, :assignment, :reuse]`
  - `[:oli, :experiments, :reward, :recorded]`
  - `[:oli, :experiments, :policy, :updated]`
  - `[:oli, :experiments, :policy, :update_failed]`
- Add or extend Thompson Sampling metadata:
  - algorithm and algorithm version;
  - experiment ID, decision point ID, section ID, publication ID;
  - selected condition ID/code;
  - guardrail action such as `:none`, `:warm_up`, `:traffic_cap`, `:fixed_control`, `:imbalance_flag`, or `:paused`;
  - reward value class `:success` or `:failure`;
  - non-sensitive error type.
- Inspection paths should expose assignment share, reward counts, posterior alpha/beta by condition, last update provenance, and guardrail state to authorized researchers/operators.
- AppSignal can consume telemetry/errors according to `docs/OPERATIONS.md`.
- Logs must not include learner names, LMS identifiers, raw responses, API tokens, or full activity payloads.

## 12. Security & Privacy
- All authoring and lifecycle commands must validate project/institution scope and caller authorization before accepting Thompson Sampling configuration.
- Delivery calls continue to validate section, publication, user, enrollment, and institution scope through `Oli.Experiments`.
- Authoring validation and inspection output may show aggregate counts and condition-level posterior values but must not expose learner identities.
- Reward and policy metadata stores only binary reward evidence and audit references; it must not store raw student response data.
- Private experiment schemas remain private to `Oli.Experiments`; LiveViews and analytics callers receive public structs or maps only.
- Guardrail and policy config edits must be rejected for unauthorized users even if browser params include adaptive fields.

## 13. Testing Strategy
- ExUnit policy tests:
  - initialize default Beta(1,1) state for each condition.
  - accept valid custom alpha/beta priors and reject zero, negative, missing, or non-numeric priors.
  - sample active condition posteriors and select the highest sampled value using deterministic injected sampler values.
  - prove posterior updates increment success or failure for only the assigned condition.
  - preserve `thompson_sampling:v2` algorithm version in assignments and updates.
- ExUnit context/runtime tests:
  - create and activate a Thompson Sampling experiment when reward readiness, priors, guardrails, and condition mappings are valid.
  - reject activation when reward readiness is missing, priors are invalid, guardrails are invalid, or condition mappings drift.
  - first assignment uses posterior sampling and later visits reuse the sticky assignment after posterior state changes.
  - replaying the same reward event returns a reused receipt and does not add a second policy update.
  - concurrent reward updates do not lose success/failure increments.
  - guardrails pause, constrain, or flag adaptive assignment according to selected MVP behavior.
- LiveView tests:
  - Thompson Sampling is selectable instead of disabled "Coming soon" copy.
  - form validation shows field errors for priors, guardrails, reward readiness, and activation blockers.
  - unauthorized authors cannot create, update, activate, pause, or inspect adaptive configuration outside their scope.
- Scenario tests:
  - Use `Oli.Scenarios` for an end-to-end authoring -> publish -> section delivery -> sticky assignment -> evaluated attempt -> posterior update flow.
  - Include a replay/idempotency scenario for evaluated reward handoff when feasible with current scenario directives.
- Analytics/inspection tests:
  - approved inspection path returns algorithm version, prior config, posterior values, reward counts, assignment counts, and update provenance.
  - responses exclude learner identities and raw responses.
- Validation gates:
  - Run targeted `mix test` for `test/oli/experiments/policy_test.exs`, `test/oli/experiments/context_test.exs`, `test/oli/experiments/runtime_test.exs`, authoring LiveView tests, and reward handoff tests.
  - Run targeted scenario runner for new Thompson Sampling scenario coverage.
  - Run `mix format`.
  - Run harness requirements trace and FDD validation.

## 14. Backwards Compatibility
- Weighted random experiments remain unchanged and continue to use `Oli.Experiments.Policies.WeightedRandom`.
- Existing sticky assignments remain authoritative and are never reassigned because Thompson Sampling posterior state changes.
- Existing reward idempotency keys, outcome records, and policy update records remain valid.
- Existing Thompson Sampling placeholder tests must be updated for real posterior sampling and explicit prior state.
- The disabled authoring affordance is replaced only after backend validation is implemented; deployments before this slice continue blocking Thompson Sampling authoring.
- No existing UpGrade-backed experiments or assignments are migrated into native Thompson Sampling records.

## 15. Risks & Mitigations
- Incorrect sampling implementation: keep policy math isolated, add deterministic sampler tests, and compare sampled-selection behavior against known seeded cases.
- Reward mapping biases posterior state: keep MVP reward source explicit as full-credit binary reward and audit reward source/update provenance.
- Early over-allocation to one condition: enforce warm-up and traffic-cap/fixed-control guardrails and expose imbalance telemetry.
- Lost posterior updates under concurrent reward processing: lock policy-state rows or retry optimistic updates and test concurrent reward paths.
- Authoring enables unsafe experiments too early: activation revalidates reward readiness, priors, guardrails, lifecycle state, and condition mappings in backend context code.
- Policy state becomes hard to inspect: persist explicit prior config, posterior state, algorithm version, aggregate counters, and policy update records.
- Delivery latency regresses: keep assignment work bounded by active condition count and rely on sticky assignment reuse for repeat visits.

## 16. Open Questions & Follow-ups
- Confirm whether custom priors are available to all authorized authors or only administrators; backend should support both without changing persisted shape.
- Confirm the production MVP guardrail thresholds for warm-up count, max condition share, fixed control allocation, and imbalance monitoring.
- Confirm whether analytics UI will expose full posterior state in the Thompson Sampling slice or defer presentation to the analytics work item.
- Confirm whether partial-credit activities should remain binary failure for MVP or whether a later requirement will add threshold-based binary reward mapping.

## 17. References
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`
- `docs/exec-plans/current/epics/ab_testing/thompson_sampling/requirements.yml`
- `docs/exec-plans/current/epics/ab_testing/plan.md`
- `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/authoring_lifecycle/fdd.md`
- `docs/exec-plans/current/epics/ab_testing/references/EASI_ThompsonSampling.ipynb`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/TESTING.md`
- `docs/OPERATIONS.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/attempt.md`
- `lib/oli/experiments.ex`
- `lib/oli/experiments/policies/thompson_sampling.ex`
- `lib/oli/experiments/schemas/policy_state.ex`
- `lib/oli/delivery/experiments/reward_handoff.ex`
- `lib/oli_web/live/workspaces/course_author/experiments_live.ex`
