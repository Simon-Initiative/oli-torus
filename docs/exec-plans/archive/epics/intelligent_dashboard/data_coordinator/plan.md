# Data Coordinator - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/intelligent_dashboard/data_coordinator/prd.md`
- FDD: `docs/epics/intelligent_dashboard/data_coordinator/fdd.md`
- Epic context: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/plan.md`

## Scope
Deliver `MER-5302` by implementing session-scoped request orchestration in `Oli.Dashboard.LiveDataCoordinator*`: one-active-plus-one-queued latest-intent control, token-based stale suppression, cache-aware read-through orchestration through stable cache APIs, deterministic timeout fallback, and incremental readiness/failure actions for LiveView hydration flows.

## Non-Functional Guardrails
- Keep strict one-way boundaries: coordinator depends on cache/runtime APIs; coordinator does not implement cache keying/TTL/LRU/revisit/coalescing policy.
- Enforce deterministic transition semantics and explicit transition-level errors for invalid events.
- Preserve tenant/context isolation by requiring normalized scope/context metadata on every coordinator action.
- Emit PII-safe telemetry for queue transitions, stale discards, cache consult outcomes, timeout fallback, and request lifecycle timing.
- LiveView-related integration work in this plan is test-only at this stage; do not wire coordinator behavior into production LiveView modules yet.
- No relational schema migration or backfill is introduced in this feature.
- No dedicated performance/load/benchmark testing is included in `MER-5302`; performance validation is deferred to separate tickets.
- Rollback posture is code-only (coordinator module/caller revert) with no data migration rollback.

## Clarifications & Default Assumptions
- Coordinator state is session-local and lifecycle-bound to dashboard LiveView state; no global scheduler process is introduced.
- Timeout control is configurable via coordinator options/application config and defaults to a safe baseline when unset.
- Queue policy is strictly latest-intent replacement: at most one active token and one queued token.
- Stale results may warm cache through cache facade APIs when identity checks pass, but stale token UI mutation is always blocked.
- For Phase 4, any LiveView integration proof is implemented in test code only (including a test-only LiveView harness if needed).
- Integrating coordinator behavior into real production LiveView code is explicitly out of scope for this plan stage.
- Cooperative cancellation of in-flight runtime work is out of scope for this feature and remains a follow-up.

## AC Traceability Targets
- AC-001: rapid scope cycling retains only one active and one latest queued request.
- AC-002: stale token completion does not mutate UI state.
- AC-003: partial cache hit applies cached required data immediately and loads only misses.
- AC-004: stale completion can warm cache without changing current UI scope state.
- AC-005: coordinator modules contain no cache policy implementation logic.
- AC-006: telemetry exposes queue/stale/cache/timing coordinator outcomes.
- AC-007: coordinator tests use mocked/stubbed cache/runtime dependencies where needed.
- AC-008: active build timeout emits deterministic fallback and preserves next-request responsiveness.

## Phase Gate Summary
- Gate A (after Phase 1): coordinator contracts, state model, and boundary constraints are deterministic and test-covered.
- Gate B (after Phase 2): request intake, queue replacement, and cache consult-first orchestration are stable.
- Gate C (after Phase 3): stale suppression, cache warming on stale completion, and incremental apply behavior are stable.
- Gate D (after Phase 4): timeout fallback and LiveView integration behavior are deterministic and resilient.
- Gate E (after Phase 5): observability/docs/regression gates are complete and release-ready.

## Phase 1: Coordinator Contracts, State Model, and Boundary Guardrails
- Goal: Establish coordinator public contracts, deterministic state transitions, and explicit boundary protections.
- Tasks:
  - [ ] Define/confirm `Oli.Dashboard.LiveDataCoordinator` public API (`new_session`, `request_scope_change`, `handle_oracle_result`, timeout hooks) and core typespecs.
  - [ ] Implement `Oli.Dashboard.LiveDataCoordinator.State` with explicit `idle`, `in_flight`, and `queued` transition helpers.
  - [ ] Implement transition validation errors for invalid events and preserve state integrity on invalid transitions.
  - [ ] Add coordinator boundary declarations forbidding cache policy logic (TTL/LRU/key/revisit/coalescing) inside coordinator modules.
  - [ ] Add token and action envelope primitives shared by later phases.
- Testing Tasks:
  - [ ] Add unit tests for valid/invalid state transitions and deterministic transition outputs.
  - [ ] Add boundary tests asserting coordinator modules do not expose/encode cache policy internals (AC-005).
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator/state_test.exs test/oli/dashboard/live_data_coordinator/boundary_test.exs`
  - [ ] Pass criteria: AC-005 references exist and all Phase 1 tests pass.
- Definition of Done:
  - Coordinator API/types compile and are deterministic.
  - Transition model is test-covered for success and invalid-event cases.
  - Boundary constraints are explicit in docs/tests.
- Gate:
  - Gate A passes when coordinator contracts and state primitives are stable for orchestration wiring.
- Dependencies:
  - None.
- Parallelizable Work:
  - State transition implementation and boundary guardrail tests can proceed in parallel once API contracts are frozen.

## Phase 2: Scope Request Intake, Queue Replacement, and Cache Consult-First Orchestration
- Goal: Implement latest-intent request intake with one-active/one-queued semantics and cache-first required lookup behavior.
- Tasks:
  - [ ] Implement `request_scope_change` behavior for one active + one replaceable queued request semantics (AC-001).
  - [ ] Integrate required cache consult through cache facade APIs and deterministic partial-hit action shaping (AC-003).
  - [ ] Ensure only missing required dependencies are scheduled for runtime load, while cache hits emit immediate readiness actions.
  - [ ] Normalize context/scope metadata at coordinator entry points to preserve tenant/context isolation constraints.
  - [ ] Keep coordinator/cache boundary strict by consuming cache facade only (no key/TTL/eviction logic in coordinator).
- Testing Tasks:
  - [ ] Add unit tests for queue replacement and deterministic action outputs under rapid request sequences.
  - [ ] Add integration-style coordinator tests for cache full-hit, partial-hit, and miss paths using mocked cache responses.
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator/request_scope_change_test.exs test/oli/dashboard/live_data_coordinator/cache_integration_test.exs`
  - [ ] Pass criteria: AC-001 and AC-003 behaviors are verified by deterministic passing tests.
- Definition of Done:
  - Request intake enforces one active + one replaceable queued request.
  - Cache consult-first flow emits deterministic immediate-hit and load-miss actions.
  - Coordinator entry normalization and boundary protections are test-covered.
- Gate:
  - Gate B passes when request intake and cache consult orchestration are stable for result-handling integration.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Queue replacement logic and cache consult action-shaping tests can run in parallel after state/action contracts are established.

## Phase 3: Oracle Result Handling, Stale Suppression, and Cache Warm-Through
- Goal: Implement result application semantics for active/stale tokens, including stale-safe cache writes and queued promotion.
- Tasks:
  - [ ] Implement `handle_oracle_result` for active token readiness/failure progression with deterministic completion handling.
  - [ ] Enforce stale-token UI suppression while allowing identity-guarded cache writes for stale completions via cache API (AC-002, AC-004).
  - [ ] Promote queued request to active after active request completion and emit deterministic follow-up actions.
  - [ ] Ensure scoped dependency failure behavior degrades gracefully without crashing coordinator session state.
  - [ ] Preserve one-way boundary constraints when applying completion logic.
- Testing Tasks:
  - [ ] Add unit tests for stale-vs-active token behavior and queued promotion semantics.
  - [ ] Add integration tests with mocked/stubbed cache/runtime producers to validate stale cache warming plus UI suppression (AC-007).
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator/result_handling_test.exs test/oli/dashboard/live_data_coordinator/stale_suppression_test.exs`
  - [ ] Pass criteria: AC-002, AC-004, and AC-007 are proven by passing tests.
- Definition of Done:
  - Stale completions never produce UI apply actions.
  - Identity-valid stale completions can warm cache through facade calls.
  - Queued promotion and completion actions are deterministic and test-covered.
- Gate:
  - Gate C passes when stale suppression and warm-through semantics are stable and deterministic.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Stale suppression tests and queued-promotion logic can run in parallel before final completion-path composition.

## Phase 4: Timeout Fallback and LiveView Integration Wiring
- Goal: Add configurable hard timeout behavior and integrate coordinator actions into LiveView apply paths with strict token guards.
- Tasks:
  - [ ] Implement active request timeout scheduling/cancellation and deterministic timeout fallback actions/events (AC-008).
  - [ ] Ensure timeout fallback keeps coordinator available for subsequent latest-intent requests.
  - [ ] Implement LiveView integration proof only in test code using a dedicated test harness LiveView (or equivalent test adapter) with centralized token apply guards.
  - [ ] Preserve scoped error behavior so affected dependencies degrade gracefully without collapsing dashboard shell.
  - [ ] Confirm timeout and apply paths do not introduce cache policy logic into coordinator/live integration modules and do not modify production LiveView modules.
- Testing Tasks:
  - [ ] Add timeout-focused coordinator tests validating fallback determinism and post-timeout request continuity.
  - [ ] Add/extend LiveView integration tests using test-only harness modules for event ordering, stale suppression on apply, and timeout fallback rendering behavior.
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator/timeout_test.exs test/oli/dashboard/live_data_coordinator/liveview_integration_test.exs`
  - [ ] Pass criteria: AC-008 and integration token-guard behavior pass with deterministic test outcomes.
- Definition of Done:
  - Timeout fallback behavior is deterministic and configurable.
  - Coordinator remains responsive to subsequent requests after timeout paths.
  - LiveView integration proof uses only test code/harnesses and does not change production LiveView modules.
- Gate:
  - Gate D passes when timeout and test-only LiveView integration paths are stable and test-verified, with no production LiveView wiring introduced.
- Dependencies:
  - Phase 3.
- Parallelizable Work:
  - Timeout engine implementation and test-only LiveView integration test authoring can proceed in parallel after result-handling contracts are stable.

## Phase 5: Observability, Documentation Sync, and Release Gate
- Goal: Finalize telemetry coverage, documentation alignment, and regression readiness for coordinator rollout.
- Tasks:
  - [ ] Implement/verify coordinator telemetry events for request start/queue/replace/stale discard/timeout/cache consult/complete (AC-006).
  - [ ] Validate telemetry metadata is PII-safe and scoped to coordinator operational diagnostics.
  - [ ] Update feature docs with final boundary decisions, timeout assumptions, and rollout/rollback posture.
  - [ ] Confirm no schema migration/backfill requirements are introduced.
  - [ ] Capture follow-up tuning notes for queue churn and timeout threshold calibration.
- Testing Tasks:
  - [ ] Add/extend observability tests validating event names and metadata normalization for coordinator paths.
  - [ ] Run full targeted coordinator suite and broader regression checks.
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator`
  - [ ] Command(s): `mix test test/oli/dashboard`
  - [ ] Command(s): `mix test`
  - [ ] Pass criteria: all targeted tests and regression suite pass; no boundary regressions are introduced.
- Definition of Done:
  - Telemetry coverage and metadata hygiene are complete.
  - Coordinator docs and operational guidance are synchronized with implementation.
  - Final regression gate is green.
- Gate:
  - Gate E passes when observability/doc/regression readiness is complete.
- Dependencies:
  - Phase 4.
- Parallelizable Work:
  - Documentation updates and telemetry test authoring can run in parallel before final regression execution.

## Parallelisation Notes
- Phase 1 is the root gate.
- After Gate A, Phase 2 begins request-intake/cache-consult behavior.
- Phase 3 starts after Phase 2 because result-handling depends on request/action contracts.
- Phase 4 starts after Phase 3 and can split into timeout-engine work and LiveView integration work.
- Phase 5 starts after Phase 4 and can split docs/observability updates from regression execution until final gate.

## Implementation Notes

### 2026-02-24 - Phase 5 Delivery Notes
- Implemented coordinator telemetry events for `request_started`, `request_queued`, `request_queue_replaced`, `request_stale_discarded`, `request_timeout`, `cache_consult`, and `request_completed`.
- Enforced PII-safe metadata normalization for coordinator telemetry; excluded `user_id`, `dashboard_context_id`, `container_id`, and payload/hit bodies.
- Timeout completion now emits deterministic fallback + per-oracle timeout failures, then promotes queued work when present.
- Confirmed this feature introduces no schema migration or backfill.
- Follow-up tuning retained: queue churn thresholding/debounce policy and timeout threshold calibration remain post-baseline operational tasks.
