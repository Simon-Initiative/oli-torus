# Thompson Sampling MVP Adaptive Policy - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/thompson_sampling/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/thompson_sampling/fdd.md`

## Scope
Deliver MVP non-contextual Thompson Sampling for native A/B/N alternatives experiments inside `Oli.Experiments`. The plan covers Beta-Bernoulli policy math, auditable policy state, first-assignment posterior sampling, idempotent reward updates, MVP guardrails, lifecycle validation, authoring enablement, inspection metadata, telemetry, and targeted verification.

Revision note, 2026-07-14: this completed plan reflects the previous assumption that PostgreSQL policy-update rows are the durable audit/reporting path. Current posterior state may remain in PostgreSQL for runtime assignment, but reward and policy-update history used by reports, dashboards, and dataset exports must be reconciled to xAPI/S3/ClickHouse.

Out of scope:
- Contextual bandits, continuous rewards, score-delta optimization, multi-objective rewards, and other adaptive algorithms.
- Migration of UpGrade-backed experiments or learner assignments.
- A full analytics dashboard beyond the approved inspection/read surface required for policy metadata.
- A broad React application rewrite; the authoring work stays in the existing course-author LiveView surface.
- A scoped feature flag for this work item. `harness.yml` defaults feature flags to excluded, and the PRD states no feature flags are present.

## Clarifications & Default Assumptions
- Default binary reward source is the existing full-credit delivery reward handoff: `1.0` for full credit and `0.0` otherwise.
- Default priors are Beta(1,1) for every active condition. Custom priors are supported in backend validation; the first UI pass may expose defaults with limited advanced editing if product has not finalized admin-only controls.
- MVP guardrails are planned as backend-enforced configuration for manual pause, warm-up assignment count, maximum condition share, optional fixed control allocation, and imbalance monitoring.
- Existing sticky assignment semantics remain authoritative. Thompson Sampling samples only for first assignment when no sticky assignment exists.
- Existing `experiment_*` tables are reused. No migration is planned unless implementation discovers a required index or constraint gap.
- Telemetry is included because `harness.yml` defaults telemetry to included. Performance requirements are addressed through phase gates and tests, but no separate feature flag or formal performance budget document is required.
- Code review and issue tracking are expected in the normal workflow because `harness.yml` includes them by default.

## Phase 1: Policy Math And State Shape
- Goal: Replace the placeholder Thompson Sampling policy with testable Beta-Bernoulli posterior sampling and explicit prior/posterior state for FR-001, FR-002, FR-003, AC-001, AC-002, and AC-003.
- Tasks:
  - [x] Update `Oli.Experiments.Policies.ThompsonSampling` to use algorithm version `thompson_sampling:v2`.
  - [x] Define pure helpers for normalizing per-condition state from `policy_config`, `prior_config`, and observed counts.
  - [x] Implement Beta posterior sampling per active condition and choose the highest sampled condition.
  - [x] Add a deterministic test seam for sampling through policy context or non-persisted policy config.
  - [x] Update `record_reward/3` to return next state with `prior_alpha`, `prior_beta`, `successes`, `failures`, `posterior_alpha`, and `posterior_beta`.
  - [x] Keep reward updates scoped to the supplied assigned `condition_code`.
  - [x] Preserve weighted random policy behavior and tests.
- Testing Tasks:
  - [x] Add policy unit tests for default Beta(1,1), valid custom priors, invalid prior rejection, deterministic sampled selection, and success/failure posterior updates.
  - [x] Update existing placeholder tests that expect `thompson_sampling:v1` or posterior-mean behavior.
  - Command(s): `mix test test/oli/experiments/policy_test.exs`
- Definition of Done:
  - Policy tests prove posterior sampling, binary reward updates, explicit posterior state, and scoped condition mutation.
  - No caller outside `Oli.Experiments` needs algorithm-specific delivery logic.
- Gate:
  - Phase 1 is complete only when policy tests pass and weighted random behavior is unchanged.
- Dependencies:
  - Existing `Oli.Experiments.Policies.Policy` behavior and policy structs.
- Parallelizable Work:
  - Inspection-read planning from Phase 5 can be sketched in parallel, but implementation should wait for the final state shape from this phase.

## Phase 2: Context Normalization, Transactions, And Idempotency
- Goal: Persist and mutate Thompson Sampling policy state safely through `Oli.Experiments` for FR-002, FR-004, AC-002, and AC-004.
- Tasks:
  - [x] Add context-level normalization for Thompson Sampling `policy_config` and `prior_config`.
  - [x] Initialize `experiment_policy_states` for Thompson Sampling with normalized priors, explicit per-condition posterior state, `thompson_sampling:v2`, zero reward counts, and zero assignment count.
  - [x] Update `get_or_create_policy_state/2` behavior so missing Thompson Sampling state is initialized from experiment conditions and policy config rather than an empty map.
  - [x] Lock the relevant policy-state row or add equivalent optimistic retry behavior during reward policy updates.
  - [x] Ensure `experiment_policy_updates.reward_id` remains the durable policy-update idempotency boundary.
  - [x] Ensure assignment count and reward counters are changed only inside `Oli.Experiments`.
  - [x] Add telemetry metadata for algorithm version, selected condition, reward class, and update error type without learner-identifying data.
- Testing Tasks:
  - [x] Add context/runtime tests for initial policy-state creation, idempotent reward replay, assigned-condition-only update, and concurrent reward updates.
  - [x] Add tests proving reused reward receipts do not create duplicate policy updates or change posterior counts.
  - Command(s): `mix test test/oli/experiments/context_test.exs test/oli/experiments/runtime_test.exs`
- Definition of Done:
  - Thompson Sampling policy state is auditable and replay-safe.
  - Concurrent reward processing cannot lose success/failure increments under the chosen locking or retry approach.
- Gate:
  - Phase 2 is complete only when reward idempotency and policy-state concurrency tests pass.
- Dependencies:
  - Phase 1 state shape and policy update contract.
- Parallelizable Work:
  - Authoring form markup can be prepared in parallel against placeholder field names, but submit/activation behavior should wait for context validation.

## Phase 3: Assignment Guardrails And Runtime Behavior
- Goal: Apply Thompson Sampling safely on first assignment while preserving sticky assignment and MVP guardrails for FR-003, FR-005, AC-003, and AC-005.
- Tasks:
  - [x] Add backend guardrail validation for warm-up assignment count, maximum condition share, optional fixed control allocation, imbalance threshold, and manual pause support.
  - [x] Apply guardrails inside first-assignment flow after sticky assignment lookup and before policy sampling.
  - [x] Increment or derive assignment counters consistently when a new Thompson Sampling assignment is created.
  - [x] Ensure paused, completed, archived, draft, invalid, or condition-mismatched experiments use existing controlled fallback behavior.
  - [x] Emit telemetry for guardrail action values such as `:none`, `:warm_up`, `:traffic_cap`, `:fixed_control`, `:imbalance_flag`, and `:paused`.
  - [x] Keep delivery student UI unchanged except for the assigned alternative content.
- Testing Tasks:
  - [x] Add runtime tests proving first assignment samples, repeated visits reuse sticky assignments, and posterior changes do not reassign existing learners.
  - [x] Add guardrail tests for pause, warm-up, cap/fixed-control behavior, and imbalance flag telemetry or inspection state.
  - [x] Add fallback tests for malformed policy state, no active conditions, and controlled policy errors.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs`
- Definition of Done:
  - First assignments use Thompson Sampling only when valid and active.
  - Existing sticky assignments remain stable across posterior updates and guardrail changes.
  - Guardrail behavior is observable and covered by tests.
- Gate:
  - Phase 3 is complete only when runtime tests prove sticky assignment preservation and selected MVP guardrail behavior.
- Dependencies:
  - Phase 2 normalized policy state and safe transaction behavior.
- Parallelizable Work:
  - LiveView copy and read-only display work from Phase 4 can proceed in parallel, but activation should remain blocked until this phase passes.

## Phase 4: Authoring And Lifecycle Enablement
- Goal: Replace the disabled Thompson Sampling affordance with lifecycle-safe authoring controls for FR-006 and AC-006.
- Tasks:
  - [x] Update `Oli.Experiments.create_experiment/1` and `update_experiment/2` validation to accept Thompson Sampling graph requests when priors, reward source, guardrails, and condition mappings are valid.
  - [x] Update `activate_experiment/2` validation to allow Thompson Sampling only when reward readiness, priors, guardrails, lifecycle state, and condition mappings pass.
  - [x] Keep unsafe condition edits blocked after assignments exist.
  - [x] Update `OliWeb.Workspaces.CourseAuthor.ExperimentsLive` to present a selectable Thompson Sampling option with safe defaults.
  - [x] Add authoring controls for default priors and MVP guardrails without exposing implementation internals.
  - [x] Replace "Coming soon" disabled copy with validation states and form-safe errors.
  - [x] Enforce existing project author/admin authorization and avoid trusting browser-submitted adaptive fields.
- Testing Tasks:
  - [x] Add context tests for Thompson Sampling create/update/activation success and validation failures.
  - [x] Add LiveView tests for selectable Thompson Sampling, default priors, guardrail fields, validation errors, activation blockers, and unauthorized access.
  - Command(s): `mix test test/oli/experiments/context_test.exs test/oli_web/live/workspaces/course_author/experiments_live_test.exs`
- Definition of Done:
  - Authorized users can create or update Thompson Sampling experiments only with valid adaptive configuration.
  - Activation is backend-gated and field-safe errors are shown without exposing learner identities.
- Gate:
  - Phase 4 is complete only when context and LiveView tests pass and weighted random authoring remains unchanged.
- Dependencies:
  - Phase 3 runtime and guardrail behavior.
- Parallelizable Work:
  - Inspection response tests from Phase 5 can proceed once the public read shape is agreed.

## Phase 5: Inspection, Telemetry, And Operational Evidence
- Goal: Expose enough metadata for research review and operations while preserving privacy for FR-002, FR-005, AC-002, and AC-005.
- Tasks:
  - [x] Add or extend `Oli.Experiments` inspection/read functions such as `policy_state_snapshot/1` or existing analytics summary output.
  - [x] Include algorithm, algorithm version, prior config, posterior alpha/beta per condition, assignment count, reward success/failure counts, last update provenance, and guardrail state.
  - [x] Ensure inspection responses use authorized public structs or maps and never return private schemas.
  - [x] Add telemetry assertions or handler-based tests for Thompson Sampling assignment, reward update, guardrail action, and policy update failures where practical.
  - [x] Review logs/metadata to exclude learner names, LMS identifiers, raw activity responses, API tokens, and full activity payloads.
  - [x] Add notes for AppSignal/telemetry observability in the execution record or PR description.
- Testing Tasks:
  - [x] Add analytics/inspection tests for posterior state visibility and privacy boundaries.
  - [x] Add telemetry metadata tests for non-sensitive IDs and guardrail action.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/experiments/runtime_test.exs`
- Definition of Done:
  - Operators and researchers have an approved inspection path for policy evidence.
  - Telemetry and logs support debugging without leaking private learner data.
- Gate:
  - Phase 5 is complete only when inspection and telemetry tests pass.
- Dependencies:
  - Phase 2 state shape and Phase 3 guardrail decisions.
- Parallelizable Work:
  - Scenario coverage from Phase 6 can start once authoring and runtime flows are stable enough to express.

## Phase 6: End-To-End Workflow Coverage And Release Hardening
- Goal: Validate the full authoring-to-delivery-to-reward workflow and prepare implementation for review and release.
- Tasks:
  - [x] Add `Oli.Scenarios` coverage for authoring alternatives, creating a Thompson Sampling experiment, publishing, section delivery, sticky assignment, evaluated attempt reward, and posterior update.
  - [x] Add scenario or ExUnit replay coverage for reward idempotency if current scenario directives can express it cleanly.
  - [x] Run targeted policy, context, runtime, authoring LiveView, reward handoff, analytics/inspection, and scenario tests.
  - [x] Run `mix format`.
  - [x] Run a focused performance review of assignment hot-path queries, sticky reuse, guardrail checks, reward update row locking, and inspection query cost.
  - [x] Run a focused security/privacy review of scope validation, authoring authorization, inspection responses, telemetry metadata, and reward/policy metadata.
  - [x] Document unresolved product decisions in the PR or execution record: custom prior audience, final guardrail thresholds, analytics UI ownership, and partial-credit reward policy.
- Testing Tasks:
  - [x] Validate scenario files with `Oli.Scenarios.validate_file/1` while authoring.
  - [x] Run the targeted scenario runner or ExUnit scenario module added for this work.
  - [x] Run all targeted ExUnit modules touched by the implementation.
  - Command(s): `mix test test/oli/experiments/policy_test.exs test/oli/experiments/context_test.exs test/oli/experiments/runtime_test.exs test/oli/delivery/experiments/reward_handoff_test.exs test/oli/experiments/analytics_test.exs test/oli_web/live/workspaces/course_author/experiments_live_test.exs`
  - Command(s): `mix format`
- Definition of Done:
  - The complete Thompson Sampling workflow is covered by targeted automated tests and at least one workflow-level integration path.
  - Security, privacy, telemetry, and performance concerns from the FDD are explicitly checked.
  - Requirements FR-001 through FR-006 and AC-001 through AC-006 have implementation proof.
- Gate:
  - Phase 6 is complete only when targeted tests, formatting, scenario validation/execution, security review, performance review, and harness validation pass.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Final review notes can be prepared while test runs execute, but release readiness waits for all gates.

## Parallelization Notes
- Phase 1 and the read-shape portion of Phase 5 can be discussed in parallel, but Phase 5 implementation should wait for the final state shape.
- Phase 2 backend normalization and Phase 4 authoring markup can proceed concurrently if the backend owns final validation and the UI remains blocked until context tests pass.
- Phase 3 guardrails and Phase 4 lifecycle validation are tightly coupled; review them together even if separate commits are used.
- Scenario work in Phase 6 can start once Phases 3 and 4 provide stable authoring and runtime behavior.
- Security, privacy, telemetry, and performance checks should be distributed through Phases 2 through 6 rather than deferred entirely to the end.

## Phase Gate Summary
- Gate A: Policy math and state-shape tests prove Beta-Bernoulli sampling and scoped binary reward updates.
- Gate B: Context persistence tests prove auditable policy state, idempotent reward replay, and safe concurrent updates.
- Gate C: Runtime tests prove first-assignment sampling, sticky reuse, fallback behavior, and MVP guardrails.
- Gate D: Authoring and lifecycle tests prove Thompson Sampling can be selected and activated only with valid configuration.
- Gate E: Inspection and telemetry tests prove operational evidence is visible without leaking learner data.
- Gate F: End-to-end workflow tests, targeted ExUnit tests, scenario validation, `mix format`, security review, performance review, and harness validation all pass.
