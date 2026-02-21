# Data Coordinator PRD

Last updated: 2026-02-17
Feature: `data_coordinator`
Epic: `MER-5198`
Primary Jira: `MER-5302` Data Infra: Live Data Coordinator and Request Control
Related docs: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/data_oracles/prd.md`, `docs/epics/intelligent_dashboard/data_cache/prd.md`, `docs/epics/intelligent_dashboard/data_snapshot/prd.md`

## 1. Overview

This feature defines runtime request orchestration for Intelligent Dashboard scope changes. It controls in-flight and queued work, suppresses stale UI mutation, and emits incremental hydration updates as oracles complete.

`data_coordinator` is an orchestration layer, not a storage layer. It uses `data_cache` through a stable cache API boundary and does not own cache keying, TTL, capacity, revisit policy, or eviction implementation.

Prototype alignment:
- `LiveDataController` already models dependency resolution, cache read-through, miss loading, and projection assembly in one orchestration path.
- Production coordinator should preserve oracle-source observability (`cache`, `loaded`, `skipped_optional`, `error`) to support incremental readiness and debugging.

## 2. Background & Problem Statement

Without deterministic request control, rapid scope changes (`A -> B -> C`) can trigger unbounded background work and stale-result races that overwrite newer user intent. Without explicit coordinator/cache boundaries, orchestration and storage concerns can blur, leading to duplicated policy logic and brittle behavior.

The dashboard requires:
- bounded request concurrency,
- latest-intent semantics,
- strict stale-result suppression at UI apply points,
- and cache-aware orchestration that remains decoupled from cache internals.

## 3. Goals & Non-Goals

Goals:
- Implement one in-flight + one replaceable queued request policy per dashboard session.
- Ensure latest-intent behavior under rapid filter cycling.
- Ensure stale tokens never mutate UI state.
- Integrate cache lookup/write paths through explicit cache APIs.
- Emit deterministic incremental hydration events for tiles and projections.

Non-Goals:
- Defining oracle contracts and dependency declarations (handled by `data_oracles`).
- Defining cache key format, TTL, capacity, LRU, revisit retention, and coalescing internals (handled by `data_cache`).
- Defining snapshot shape and CSV projection contract (handled by `data_snapshot`).

## 4. Users & Use Cases

Users:
- Instructors rapidly changing dashboard scope.
- Engineers implementing LiveView hydration workflows.
- Operators monitoring queue pressure and stale-result suppression.

Use cases:
- Rapid scope changes preserve responsiveness and apply only latest scope state.
- Warm-scope transitions hydrate quickly from cache.
- Partial cache misses trigger bounded oracle loads and incremental updates.
- Stale in-flight completion can still warm cache for a prior container but cannot alter current UI state.

## 5. UX / UI Requirements

- Scope controls remain interactive during active builds.
- Tile/projection loading states advance incrementally as dependencies become ready.
- Older scope results are never displayed after a newer scope selection.
- Errors are scoped to affected dependencies and do not break entire dashboard shell.

## 6. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | System SHALL maintain at most one active scope request per dashboard session. | P0 |
| FR-002 | System SHALL maintain at most one queued scope request per dashboard session and replace queued request with latest intent. | P0 |
| FR-003 | System SHALL assign and propagate request tokens and SHALL suppress stale-token UI apply operations. | P0 |
| FR-004 | System SHALL emit incremental readiness events for oracle/projection completion and scoped failure events for dependency errors. | P0 |
| FR-005 | System SHALL consult cache before launching missing oracle loads using a stable cache API contract. | P0 |
| FR-006 | System SHALL write oracle completion results to cache through the cache API even when completion is stale for UI, provided identity guards pass. | P0 |
| FR-007 | System SHALL NOT implement cache keying, TTL, eviction, revisit retention, or miss coalescing logic inside coordinator modules. | P0 |
| FR-008 | System SHALL expose coordinator telemetry (queue replacement, stale discard, cache consult outcomes, build/apply latency). | P1 |
| FR-009 | System SHALL provide deterministic state transitions and transition-level validation errors for invalid coordinator events. | P1 |
| FR-010 | System SHALL enforce a one-way boundary: coordinator depends on cache API; cache does not depend on coordinator state machine internals. | P0 |
| FR-011 | System SHALL include extensive automated unit testing for coordinator state/action logic, and SHALL use mocked/stubbed dependencies (for example cache facade and oracle-result producers) where needed to validate end-to-end component interactions in tests. | P0 |
| FR-012 | System SHALL enforce a configurable hard timeout for active scope builds and emit deterministic timeout fallback state/events that keep the dashboard responsive and eligible for next-request processing. | P0 |

## 7. Acceptance Criteria

- AC-001: Given rapid scope cycling, when selections occur while one build is active, then only one active + one latest queued request is retained.
- AC-002: Given stale completion for token `T_old`, when result arrives after token `T_new` is active, then no UI assigns/events are applied from `T_old`.
- AC-003: Given cache lookup with partial hit, when request starts, then cached required payloads are applied immediately and only missing required oracles are loaded.
- AC-004: Given stale completion that passes cache identity checks, when it arrives, then cache is warmed for its original `(context, container, oracle)` key and UI remains unchanged.
- AC-005: Given boundary review, coordinator module code contains no cache policy implementation (TTL/LRU/key-building/revisit retention logic).
- AC-006: Given telemetry inspection, request queue transitions, stale discards, cache consult outcomes, and end-to-end scope transition timings are observable.
- AC-007: Given coordinator unit test execution, mocked/stubbed cache/runtime dependencies are used where necessary to exercise token guards, queue transitions, and stale-result handling end-to-end at component boundaries.
- AC-008: Given an active scope build exceeding configured timeout, coordinator emits deterministic timeout fallback state/events for that scope and remains available to process subsequent latest-intent requests.

## 8. Non-Functional Requirements

Performance:
- NFR-PERF-001: Scope-change transition handling at LiveView boundary p95 <= 100ms, p99 <= 150ms.
- NFR-PERF-002: Coordinator overhead (excluding oracle query runtime) p95 <= 25ms per transition.
- NFR-PERF-003: Cached required-oracle hydration dispatch p95 <= 50ms.

Reliability:
- NFR-REL-001: Zero stale-token UI mutations in automated race tests.
- NFR-REL-002: Deterministic queue replacement semantics under high-frequency toggling.

Operability:
- NFR-OPS-001: Queue pressure and stale discard rates are instrumented and alertable.
- NFR-OPS-002: Coordinator can degrade to explicit dependency error states without crashing LiveView session.

## 9. Data Model & APIs

No schema migration is required.

Notional coordinator public API:

- `Oli.Dashboard.LiveDataCoordinator.new_session/1`
  - Initializes session state (`idle`, request counter, empty queue).

- `Oli.Dashboard.LiveDataCoordinator.request_scope_change/3`
  - Input: coordinator state, normalized scope, dependency profile.
  - Output: updated state + action plan (`cache_lookup`, `start_oracle_load`, `emit_loading`).

- `Oli.Dashboard.LiveDataCoordinator.handle_oracle_result/4`
  - Input: state, request token, oracle key, oracle result envelope.
  - Output: updated state + action plan (`cache_write`, `emit_ready`, `emit_failure`, `start_queued`).

Coordinator-to-cache boundary contract (cache-owned implementation):

- `cache_lookup_required(context, container, oracle_keys, opts)`
- `cache_lookup_revisit(context, container, oracle_keys, opts)`
- `cache_write_oracle(context, container, oracle_key, payload, opts)`
- `cache_touch_container(context, container, opts)`

Boundary rule:
- Coordinator calls only cache public API.
- Coordinator passes context + oracle identity metadata; cache owns key construction and storage policy.

## 10. Integrations & Platform Considerations

- Integrates with `Oli.Dashboard.OracleRuntime` for oracle execution.
- Integrates with `Oli.Dashboard.Cache` and `Oli.Dashboard.RevisitCache` only through cache public interfaces.
- Integrates with LiveView handlers for params/events and async message application.
- Integrates with `Oli.InstructorDashboard.DataSnapshot` orchestration paths.

## 11. Feature Flagging, Rollout & Migration

- Internal infra behavior; no user-facing feature flag required.
- Rollout strategy:
  1. Wire coordinator in shadow mode telemetry (non-authoritative) for baseline comparisons.
  2. Enable authoritative apply path for selected dashboard routes.
  3. Remove legacy direct async apply handlers once parity is verified.

## 12. Analytics & Success Metrics

- `scope_request_started`, `scope_request_queued`, `scope_request_queue_replaced`, `scope_request_completed` counts.
- `scope_request_stale_discarded` count and rate.
- `scope_request_timeout` count and rate.
- Cache consult outcome counts (`full_hit`, `partial_hit`, `miss`) at coordinator boundary.
- Time-to-first-required-ready and time-to-required-complete latencies.

## 13. Risks & Mitigations

- Risk: queue churn under high-frequency toggling can starve intermediate selections.
  - Mitigation: explicit latest-intent policy + telemetry + optional debounce follow-up.
- Risk: stale apply bug in one LiveView handler path.
  - Mitigation: centralized apply guard by token and mandatory integration tests.
- Risk: coordinator accidentally absorbs cache policy decisions.
  - Mitigation: explicit boundary FR + interface-only dependency + code review checklist.

## 14. Open Questions & Assumptions

Assumptions:
- One active + one queued request remains correct for initial instructor dashboard interaction rates.
- Cache layer provides deterministic partial-hit semantics and identity-guarded writes.

Open questions:
- Should cooperative cancellation of in-flight runtime tasks be introduced after baseline stale suppression is stable?
- Should queue replacement optionally support a short debounce window in high-thrash scenarios?

## 15. Timeline & Milestones (Draft)

1. Define coordinator state machine and transition contracts.
2. Wire cache-boundary lookup/write actions and token guards.
3. Wire incremental readiness/failure event emission.
4. Land telemetry and race-condition regression tests.

## 16. QA Plan

- Unit tests:
  - state transitions (`idle`, `in_flight`, `queued`), queue replacement, invalid transitions.
  - token-based stale suppression at apply points.
  - use mocked/stubbed cache facade and oracle-result producers where needed to exercise end-to-end coordinator component interactions.
- Integration tests:
  - rapid scope changes (`A/B/C`) with deterministic latest-intent outcomes.
  - partial-hit cache path with incremental hydration.
  - stale completion warms cache but does not mutate UI.
  - active scope timeout emits deterministic fallback state and does not block subsequent requests.
- LiveView tests:
  - end-to-end event ordering and assign stability.

## 17. Definition of Done

- FR-001 through FR-012 implemented or explicitly deferred with rationale.
- AC-001 through AC-008 passing.
- No stale UI updates in automated race tests.
- Coordinator/cache boundary is explicit in code and docs, with coordinator using cache API only.

Prototype references:
- `lib/oli/instructor_dashboard/prototype/live_data_controller.ex`
- `lib/oli/instructor_dashboard/prototype/snapshot.ex`
- `lib/oli/instructor_dashboard/prototype/tile_registry.ex`

## 18. Decision Log

### 2026-02-17 - Incorporate Prototype Coordinator Flow and Source Metadata
- Change: Added explicit prototype-aligned orchestration expectations and oracle-source metadata guidance.
- Reason: Prototype confirmed that cache read-through + source attribution are key to incremental hydration behavior.
- Evidence: `lib/oli/instructor_dashboard/prototype/live_data_controller.ex`
- Impact: Refines interpretation of FR-004/FR-005/FR-008 and AC-003/AC-006.
