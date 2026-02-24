# Data Cache - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/intelligent_dashboard/data_cache/prd.md`
- FDD: `docs/epics/intelligent_dashboard/data_cache/fdd.md`
- Epic context: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/plan.md`

## Scope
Deliver `MER-5303` by implementing the reusable dashboard cache subsystem in `Oli.Dashboard.*`: deterministic keying, in-process and revisit cache tiers, TTL freshness, enrollment-tiered container LRU eviction, oracle-granular late writes, per-key miss coalescing, and a stable cache facade consumed by coordinator/snapshot layers.

## Non-Functional Guardrails
- Keep strict one-way boundaries: cache provides storage/policy APIs; coordinator owns request queue/token logic.
- Enforce tenant/user isolation in revisit cache keys and tests (no cross-user payload leakage).
- Keep memory bounded with enrollment-tiered container caps and container-level eviction behavior.
- Emit PII-safe telemetry for lookup/write/eviction/TTL/coalescing outcomes.
- No relational schema migration or backfill is introduced in this feature.
- No dedicated performance benchmark or latency-threshold testing is included in `MER-5303`; performance validation is deferred to separate tickets.
- Rollback posture is code-only (module/config revert) with no data migration rollback.

## Clarifications & Default Assumptions
- In-process cache is session-local and lifecycle-bound to dashboard session state; revisit cache is node-local and supervised shared storage.
- Cache facade API names follow PRD/FDD notional contracts (`lookup_required`, `lookup_revisit`, `write_oracle`, `coalesce_or_build`, `touch_container`) even if some wrappers are added for compatibility.
- Revisit lookup is called only when coordinator marks request as explicit-container revisit eligible.
- Miss coalescing scope is node-local for baseline; cross-node coalescing is out of scope.
- `oracle_version` and `data_version` metadata are treated as required inputs for canonical cache keys.
- Cache failures degrade to miss/fallback semantics rather than crashing dashboard session flows.

## AC Traceability Targets
- AC-001: warm repeated lookup returns cache hit within TTL.
- AC-002: required lookup returns deterministic `hits` and `misses`.
- AC-003: container-scoped LRU eviction occurs when tier cap is exceeded.
- AC-004: identity-guarded late write for prior container succeeds without direct UI side effects.
- AC-005: revisit-eligible explicit-container entry can hydrate from revisit cache.
- AC-006: revisit-ineligible flow skips revisit lookup.
- AC-007: concurrent identical misses coalesce to one producer path.
- AC-008: cache modules contain no request queue/token orchestration logic.
- AC-009: test suite uses mocked/stubbed participants where needed for boundary interaction coverage.

## Phase Gate Summary
- Gate A (after Phase 1): cache contracts and key/policy primitives are deterministic and boundary-safe.
- Gate B (after Phase 2): in-process TTL/LRU/capacity behavior is correct and bounded by tests.
- Gate C (after Phase 3): revisit cache eligibility/isolation guarantees are verified.
- Gate D (after Phase 4): coalescing and late-write semantics are stable with telemetry and boundary assertions.
- Gate E (after Phase 5): integration, documentation, and regression checks are complete.

## Phase 1: Cache Contracts, Keys, and Policy Primitives
- Goal: Establish stable cache facade contracts and deterministic key/policy foundations required by all storage behaviors.
- Tasks:
  - [ ] Define/confirm `Oli.Dashboard.Cache` facade interfaces and public typespecs for required/revisit lookup, write, coalescing, and touch operations.
  - [ ] Implement `Oli.Dashboard.Cache.Key` for canonical in-process and revisit key build/parse behavior including version metadata.
  - [ ] Implement `Oli.Dashboard.Cache.Policy` config readers for TTL and enrollment-tiered container caps.
  - [ ] Add boundary guardrails in module docs and tests to keep coordinator queue/token policy out of cache modules (AC-008).
  - [ ] Add telemetry metadata schema for lookup/write outcomes (PII-safe fields only).
- Testing Tasks:
  - [ ] Add unit tests for key composition/parsing, identity guard checks, and policy tier calculation.
  - [ ] Add boundary tests asserting cache modules do not expose or depend on request queue/token state concepts.
  - [ ] Command(s): `mix test test/oli/dashboard/cache/key_test.exs test/oli/dashboard/cache/policy_test.exs test/oli/dashboard/cache/boundary_test.exs`
  - [ ] Pass criteria: AC-008 references exist and all Phase 1 tests pass.
- Definition of Done:
  - Cache API/type contracts are codified and compile.
  - Key/policy primitives are deterministic and test-covered.
  - Boundary constraints are explicit in docs/tests.
- Gate:
  - Gate A passes when contracts and deterministic key/policy primitives are stable for store implementation.
- Dependencies:
  - None.
- Parallelizable Work:
  - Key module implementation and policy/config implementation can proceed in parallel once facade contracts are frozen.

## Phase 2: In-Process Store, TTL Freshness, and Container LRU
- Goal: Implement bounded session-local in-process caching with deterministic required-lookup semantics.
- Tasks:
  - [ ] Implement `Oli.Dashboard.Cache.InProcessStore` read/write paths keyed by canonical cache identity.
  - [ ] Implement TTL expiry handling and stale-entry miss behavior for required lookup flow (AC-001).
  - [ ] Implement container recency tracking and tiered container-level LRU eviction (AC-003).
  - [ ] Implement deterministic `lookup_required` response composition (`hits`, `misses`, source tagging) for partial completeness (AC-002).
  - [ ] Wire `touch_container` updates for recency consistency.
- Testing Tasks:
  - [ ] Add unit tests for warm-hit behavior, TTL expiry, partial-hit deterministic ordering, and container-eviction correctness.
  - [ ] Add integration-style cache facade tests for required lookup behavior over multi-container writes.
  - [ ] Command(s): `mix test test/oli/dashboard/cache/in_process_store_test.exs test/oli/dashboard/cache/lookup_required_test.exs`
  - [ ] Pass criteria: AC-001, AC-002, and AC-003 behaviors are verified by passing tests.
- Definition of Done:
  - In-process cache supports deterministic reads/writes and bounded eviction behavior.
  - TTL and LRU behavior are deterministic and test-covered.
  - Required lookup output contract is stable for coordinator integration.
- Gate:
  - Gate B passes when in-process behavior is production-safe and bounded by tests.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Eviction/recency implementation and lookup-response shaping tests can run in parallel after in-process key schema is stable.

## Phase 3: Revisit Cache Tier and Eligibility Enforcement
- Goal: Add node-local revisit cache behavior with strict eligibility and user isolation.
- Tasks:
  - [ ] Implement `Oli.Dashboard.RevisitCache` storage and lookup APIs using canonical revisit keys with `user_id`.
  - [ ] Enforce strict revisit eligibility gates for explicit-container entry flows only (AC-005, AC-006).
  - [ ] Apply revisit TTL policy and error-to-fallback behavior (degrade to miss).
  - [ ] Ensure revisit writes/reads preserve user/context/container identity guards.
  - [ ] Emit revisit lookup telemetry outcomes without payload content.
- Testing Tasks:
  - [ ] Add unit tests for revisit eligibility/ineligibility and TTL expiry semantics.
  - [ ] Add isolation tests proving no cross-user leakage for same context/container/oracle keys.
  - [ ] Command(s): `mix test test/oli/dashboard/cache/revisit_cache_test.exs test/oli/dashboard/cache/revisit_isolation_test.exs`
  - [ ] Pass criteria: AC-005 and AC-006 pass, and reliability guardrails for user isolation are covered.
- Definition of Done:
  - Revisit tier is available with strict eligibility and user isolation.
  - Revisit failures degrade safely to cache-miss behavior.
  - Telemetry captures revisit outcomes with privacy-safe metadata.
- Gate:
  - Gate C passes when revisit behavior is deterministic, isolated, and test-verified.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Phase 3 can run in parallel with Phase 2 after Phase 1 because revisit tier does not depend on in-process eviction internals.

## Phase 4: Miss Coalescing, Late Writes, and Facade Composition
- Goal: Complete concurrency and write-path behavior by adding miss coalescing and identity-guarded late write support.
- Tasks:
  - [ ] Implement `Oli.Dashboard.Cache.MissCoalescer` with producer/waiter semantics for identical missing keys (AC-007).
  - [ ] Implement facade-level `coalesce_or_build` and integrate with lookup/write flow.
  - [ ] Implement `write_oracle` identity guard behavior for active and late container writes (AC-004).
  - [ ] Compose in-process + revisit + coalescing behavior in `Oli.Dashboard.Cache` facade with deterministic error handling.
  - [ ] Add telemetry for coalescing claim outcomes, identity-guard rejections, and late-write acceptance.
- Testing Tasks:
  - [ ] Add concurrency tests for single-producer/multi-waiter miss coalescing behavior.
  - [ ] Add tests for late write acceptance/rejection based on identity guard metadata.
  - [ ] Add boundary interaction tests using mocked/stubbed producer/waiter participants where needed (AC-009).
  - [ ] Command(s): `mix test test/oli/dashboard/cache/miss_coalescer_test.exs test/oli/dashboard/cache/write_oracle_test.exs test/oli/dashboard/cache/facade_integration_test.exs`
  - [ ] Pass criteria: AC-004, AC-007, and AC-009 are demonstrated by deterministic passing tests.
- Definition of Done:
  - Coalescing and late-write behavior are integrated and stable.
  - Facade composition across cache tiers is deterministic under concurrent misses.
  - Telemetry and boundary interaction tests are in place.
- Gate:
  - Gate D passes when concurrency and write-path semantics are proven by targeted tests.
- Dependencies:
  - Phase 2 and Phase 3.
- Parallelizable Work:
  - Miss coalescer implementation and late-write guard tests can run in parallel before final facade composition merge.

## Phase 5: Coordinator/Snapshot Integration Proof, Docs, and Release Gate
- Goal: Finalize cache-consumer integration proof points and complete operational/documentation readiness.
- Tasks:
  - [ ] Add or update integration tests at cache-consumer boundaries validating read-through lookup behavior without embedding queue/token policy in cache modules.
  - [ ] Validate cache fallback behavior when stores/coalescer are unavailable (miss + load path continuity).
  - [ ] Verify and document configuration knobs (TTL and capacity tiers), telemetry events, and rollback posture.
  - [ ] Update feature docs with final boundary decisions and follow-up tuning notes.
  - [ ] Confirm no schema migration/backfill requirements are introduced.
- Testing Tasks:
  - [ ] Add/extend targeted integration tests that exercise coordinator-facing cache API usage and deterministic partial-hit behavior.
  - [ ] Run full targeted cache suite and a broader regression pass.
  - [ ] Command(s): `mix test test/oli/dashboard/cache`
  - [ ] Command(s): `mix test test/oli/dashboard/live_data_coordinator`
  - [ ] Command(s): `mix test`
  - [ ] Pass criteria: all targeted tests and regression suite pass; no boundary regressions are introduced.
- Definition of Done:
  - Cache subsystem is integration-ready for coordinator/snapshot consumers.
  - Operational docs/configuration guidance is complete.
  - Final regression gate is green.
- Gate:
  - Gate E passes when integration proof points, documentation updates, and regression checks are complete.
- Dependencies:
  - Phase 4.
- Parallelizable Work:
  - Documentation/configuration updates can run in parallel with targeted integration test authoring; final gate requires both complete.

## Parallelisation Notes
- Phase 1 is the root gate.
- After Gate A, Phase 2 (in-process tier) and Phase 3 (revisit tier) can proceed in parallel.
- Phase 4 starts after both Phase 2 and Phase 3 complete because facade composition depends on both tiers.
- Phase 5 starts after Phase 4 and can split into two tracks: integration/regression testing and docs/operational handoff.
