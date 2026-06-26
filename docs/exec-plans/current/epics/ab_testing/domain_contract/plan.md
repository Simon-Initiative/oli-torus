# A/B Testing Domain Boundary And API Contract - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/domain_contract/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/domain_contract/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/domain_contract/requirements.yml`

## Scope
Implement the backend-only native A/B testing domain boundary described by the PRD and FDD. The work establishes `Oli.Experiments` as the owning context, introduces private persistence for experiment definitions and runtime evidence, defines stable public request/response structs, adds assignment policy contracts for weighted deterministic random and Thompson Sampling, and proves scope validation and persistence ownership through focused ExUnit coverage.

This plan covers FR-001, FR-002, FR-003, FR-004, and FR-005. It satisfies AC-001 by implementing the native data ownership model, AC-002 by implementing documented public API surfaces, AC-003 by keeping private schemas behind the context boundary, AC-004 by adding assignment and reward policy contracts, and AC-005 by enforcing multi-tenant scope validation.

Out of scope:
- Native authoring UI, analytics dashboard UI, or LiveView changes.
- Delivery-runtime cut-over from UpGrade to native assignment behavior.
- Migration of existing UpGrade experiments, assignments, or learner history.
- Full Thompson Sampling production tuning beyond the domain contract and auditable state/update path.

## Clarifications & Default Assumptions
- Public namespace defaults to `Oli.Experiments`.
- Private schemas live under `Oli.Experiments.Schemas.*` and are used only inside the `Oli.Experiments` context and context-level tests.
- Native experiment definitions may carry both project and optional section scope; delivery calls must still validate section, publication, user, and enrollment consistency before writing assignments or exposures.
- Weighted deterministic random assignment is production-ready in this slice; Thompson Sampling exposes the behavior contract and durable state/update shape needed by the later Thompson Sampling slice.
- The initial binary reward command accepts a caller-provided `reward_value` and idempotency key. Later delivery work selects the authoritative attempt-derived reward source.
- Analytics work in this slice is limited to context-owned aggregate read functions over PostgreSQL records; ClickHouse and dashboard work remain in later analytics slices.
- Scenario tests are not required for this contract-only slice because learner-facing delivery behavior does not change.

## Phase 1: Persistence Foundation
- Goal: Add private native experiment persistence that captures every MVP record type owned by `Oli.Experiments` for FR-001 and AC-001.
- Tasks:
  - [x] Create Ecto migrations for `experiment_definitions`, `experiment_decision_points`, `experiment_conditions`, `experiment_assignments`, `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, `experiment_policy_states`, and `experiment_policy_updates`.
  - [x] Add foreign keys from AB-owned tables to stable Torus identity tables where referential integrity is required; do not add AB-specific columns to existing project, publication, section, enrollment, user, resource, revision, or attempt tables.
  - [x] Add unique indexes for experiment UUIDs, decision point keys, condition codes, sticky assignment keys, exposure/outcome/reward idempotency keys, policy-state rows, and policy updates by reward.
  - [x] Add private Ecto schemas and changesets under `lib/oli/experiments/schemas/`.
  - [x] Keep schema modules unreferenced from `lib/oli_web/`, `lib/oli/delivery/`, `lib/oli/authoring/`, and analytics callers outside the new context.
- Testing Tasks:
  - [x] Add migration/schema tests for required fields, foreign keys, unique constraints, lifecycle state values, and idempotency constraints.
  - [ ] Add an ownership smoke test that public tests interact through `Oli.Experiments` fixtures/helpers rather than direct schema mutation.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - All MVP record types from the FDD are represented in database tables and private schemas.
  - Constraints prevent duplicate sticky assignments and duplicate idempotent runtime evidence.
  - Persistence ownership remains internal to the new context boundary.
- Gate:
  - Do not begin public API implementation until migrations, schemas, and ownership tests pass.
- Dependencies:
  - Existing project, publication, section, enrollment, user, resource, revision, and attempt schemas.
- Parallelizable Work:
  - Migration/index implementation and private changeset tests can proceed in parallel after table naming and foreign-key choices are settled.

## Phase 2: Public Context Types And Scope Validation
- Goal: Establish stable domain request/response structs and scope validation for FR-002, FR-003, FR-005, AC-002, AC-003, and AC-005.
- Tasks:
  - [ ] Add `lib/oli/experiments.ex` as the public context boundary.
  - [ ] Add public structs for `Scope`, authoring requests, delivery requests, analytics queries, receipts, assignment decisions, experiment definitions, and `ExperimentError`.
  - [ ] Implement scope validation that confirms project, publication, section, user, enrollment, and institution consistency for the relevant command.
  - [ ] Normalize error returns to `{:ok, domain_struct}` or `{:error, %ExperimentError{}}`.
  - [ ] Add authoring lifecycle functions for create, update, activate, pause, complete, and archive with allowed state transitions.
  - [ ] Ensure public functions return domain structs or maps, not private Ecto schemas.
- Testing Tasks:
  - [ ] Add context API tests for valid creation/update/lifecycle paths and invalid state transitions.
  - [ ] Add scope tests for cross-project, cross-publication, cross-section, cross-user, and cross-enrollment rejection.
  - [ ] Add response-shape tests proving public APIs do not return `Oli.Experiments.Schemas.*` structs.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Public APIs and struct boundaries match the FDD interface contract.
  - Scope validation protects institution, project, publication, section, user, and enrollment boundaries.
  - Non-domain consumers have no need to query or mutate private persistence directly.
- Gate:
  - Do not implement runtime assignment writes until validated scopes and stable public request/response types exist.
- Dependencies:
  - Phase 1 persistence foundation.
- Parallelizable Work:
  - Public struct definitions, lifecycle state validation, and scope validation tests can be split once the persistence IDs are available.

## Phase 3: Assignment, Exposure, Outcome, And Reward Commands
- Goal: Implement the delivery-facing write path and idempotent runtime evidence contract for FR-002, FR-005, AC-002, and AC-005.
- Tasks:
  - [ ] Implement active experiment lookup by scope, alternatives resource/revision, decision point key, and available condition codes.
  - [ ] Implement `assign_condition/1` with sticky assignment reuse by experiment, decision point, and enrollment.
  - [ ] Insert first assignments inside a transaction that is safe under concurrent requests.
  - [ ] Return `:no_experiment` assignment decisions when no active native experiment matches.
  - [ ] Implement `record_exposure/1`, `record_outcome/1`, and `record_reward/1` with idempotency-key handling and receipt responses.
  - [ ] Add telemetry events for assignment start/stop/exception, reuse, fallback, exposure recording, reward recording, and invalid-condition failures.
- Testing Tasks:
  - [ ] Add tests for active experiment matching and no-experiment fallback responses.
  - [ ] Add sticky assignment tests for repeated calls by the same enrollment.
  - [ ] Add concurrency or conflict tests proving duplicate first assignments collapse to one persisted assignment.
  - [ ] Add idempotency tests for exposure, outcome, and reward commands.
  - [ ] Add telemetry assertions for success and failure paths where practical.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Delivery-facing APIs can assign, expose, associate outcomes, and record rewards through the public context without changing existing learner-facing delivery code.
  - Runtime writes are scoped, transactional, and idempotent.
  - Telemetry is available for later operational monitoring.
- Gate:
  - Do not wire any delivery cut-over until this contract passes targeted tests and later delivery-runtime work explicitly opts in.
- Dependencies:
  - Phase 1 persistence foundation.
  - Phase 2 public context types and scope validation.
- Parallelizable Work:
  - Exposure/outcome/reward idempotency can be implemented alongside assignment lookup once shared scope validation is stable.

## Phase 4: Policy Behavior And Algorithm Implementations
- Goal: Define and implement assignment policy contracts for weighted deterministic random assignment and Thompson Sampling state updates for FR-004 and AC-004.
- Tasks:
  - [ ] Add `Oli.Experiments.Policies.Policy` behavior for `assign/3` and `record_reward/3`.
  - [ ] Implement weighted deterministic random assignment using experiment, decision point, enrollment, configured weights, and a stable salt.
  - [ ] Implement Thompson Sampling contract support over persisted policy state, binary reward events, posterior state, algorithm version, and policy update audit rows.
  - [ ] Ensure assignment code calls the policy behavior instead of branching on algorithm details outside the policy boundary.
  - [ ] Ensure reward recording delegates policy updates idempotently by reward ID.
- Testing Tasks:
  - [ ] Add policy behavior tests with shared examples for assignment and reward-update expectations.
  - [ ] Add weighted deterministic tests proving stable repeat selection for the same assignment key and distribution over many keys.
  - [ ] Add Thompson Sampling state/update tests for binary reward acceptance, posterior persistence, update audit records, and idempotent reward replay.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
- Definition of Done:
  - Both required algorithms are available behind one policy contract.
  - Weighted deterministic random assignment is usable by the native runtime contract.
  - Thompson Sampling has durable, auditable state and update semantics for the later dedicated slice.
- Gate:
  - Do not mark the domain contract complete until assignment and reward commands exercise policy behavior through tests.
- Dependencies:
  - Phase 3 assignment and reward command paths.
- Parallelizable Work:
  - Weighted deterministic policy tests and Thompson Sampling state/update tests can proceed in parallel against the shared behavior.

## Phase 5: Analytics Reads, Guardrails, And Final Validation
- Goal: Complete approved read surfaces, coupling guardrails, and validation evidence for FR-002, FR-003, AC-002, and AC-003.
- Tasks:
  - [ ] Implement context-owned analytics read functions for experiment summary, assignment counts, exposure counts, reward counts, and policy state snapshots.
  - [ ] Keep analytics responses aggregate-first and scoped by institution, project, publication, section, and experiment.
  - [ ] Add lightweight guardrail coverage that detects direct references to private schemas from non-context production modules.
  - [ ] Confirm no `lib/oli_web/` or existing delivery/authoring modules were changed to depend on private experiment persistence.
  - [ ] Update work-item documentation only if implementation decisions materially differ from the PRD/FDD/plan.
  - [ ] Run harness traceability and work-item validation.
- Testing Tasks:
  - [ ] Add analytics read tests for scoped aggregates and rejected out-of-scope queries.
  - [ ] Add guardrail tests or static checks for private schema references outside `lib/oli/experiments/`.
  - [ ] Run the full targeted experiment context suite.
  - Command(s): `mix test test/oli/experiments`
  - Command(s): `mix format`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/domain_contract --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/domain_contract --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/domain_contract --check plan`
- Definition of Done:
  - Approved analytics reads cover the MVP contract without direct external table access.
  - Coupling guardrails make FR-003 reviewable.
  - Plan validation, requirements traceability, targeted tests, and formatting pass.
- Gate:
  - The work item is ready for implementation completion review only after all harness validation commands and targeted backend tests pass.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Analytics aggregate tests and static coupling checks can proceed in parallel once public read models and private schema module names are stable.

## Parallelization Notes
- Phase 1 should start first because every later phase depends on table names, constraints, and private schema modules.
- Phase 2 can begin once the core definition, decision point, condition, and assignment schemas are sketched, but scope validation must finish before delivery-style writes.
- Phase 3 and Phase 4 can overlap after the policy behavior is defined: assignment command work can use the weighted policy while Thompson Sampling state tests are built separately.
- Phase 5 can start analytics read design during Phase 3, but final guardrail checks should wait until production modules settle.
- No frontend, Gleam, or scenario work is planned for this slice unless implementation drifts beyond the backend contract.

## Phase Gate Summary
- Gate A: Persistence and private schema ownership are complete before public APIs are implemented.
- Gate B: Public context structs and scope validation pass before assignment, exposure, outcome, or reward writes are introduced.
- Gate C: Runtime evidence writes are transactional, idempotent, and telemetry-instrumented before policy behavior is considered complete.
- Gate D: Weighted deterministic assignment and Thompson Sampling policy-state contracts pass tests before analytics and final validation closeout.
- Gate E: Analytics reads, private-schema guardrails, targeted ExUnit tests, `mix format`, and harness validation pass before the work item is marked complete.
