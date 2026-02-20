# Data Cache PRD

Last updated: 2026-02-17
Feature: `data_cache`
Epic: `MER-5198`
Primary Jira: `MER-5303` Data Infra: InProcess/Revisit Cache and Tiered Limits
Related docs: `docs/epics/intelligent_dashboard/edd.md`, `docs/epics/intelligent_dashboard/data_oracles/prd.md`, `docs/epics/intelligent_dashboard/data_coordinator/prd.md`, `docs/epics/intelligent_dashboard/data_snapshot/prd.md`

## 1. Overview

This feature defines the dashboard cache subsystem used by live orchestration to accelerate repeated scope requests and revisit flows. It provides deterministic keying, TTL freshness, enrollment-tiered capacity, container-level LRU eviction, late-write support, and per-oracle miss coalescing.

`data_cache` is a storage and cache-policy layer. It is used by `data_coordinator`, but it does not implement queue/token request orchestration behavior.

Prototype alignment:
- Minimal in-process cache keyed by scope identity + oracle key already validates read-through wins for repeated scope requests.
- Cache behavior should stay storage-focused (`fetch`/`put`) while orchestration logic stays in coordinator/controller.

## 2. Background & Problem Statement

Repeated scope changes and revisit navigation can trigger redundant oracle loads and unstable perceived latency if no cache exists. A simplistic cache can also introduce correctness risks (cross-user leakage, stale overuse, memory growth, inconsistent partial completeness behavior).

The dashboard requires a cache subsystem that is:
- oracle-granular,
- container-aware,
- deterministic under partial/late completion,
- and clearly separated from request-control policy.

## 3. Goals & Non-Goals

Goals:
- Implement in-process cache for session-local speedups.
- Implement revisit cache for short-lived per-user return flows.
- Enforce deterministic keying, TTL, and enrollment-tiered container capacity.
- Support oracle-granular late writes and per-key miss coalescing.
- Expose a stable public API for coordinator read-through orchestration.

Non-Goals:
- Defining request queue and stale-token policy (handled by `data_coordinator`).
- Defining oracle contracts and dependency profiles (handled by `data_oracles`).
- Defining snapshot schema and CSV contract behavior (handled by `data_snapshot`).

## 4. Users & Use Cases

Users:
- Instructors switching between containers.
- Instructors returning to dashboard with explicit container params.
- Engineers integrating cache-aware orchestration.
- Operators monitoring cache hit rates and memory behavior.

Use cases:
- Warm in-session scope toggle served from in-process cache.
- Revisit hydration from node-wide per-user revisit cache on eligible flows.
- Partial container cache hit loads only missing required oracles.
- Late oracle completion for no-longer-active container still improves future hit rate.

## 5. UX / UI Requirements

- Warm scope transitions should feel faster and more stable than uncached transitions.
- Revisit flow should hydrate quickly when eligible cached payloads exist.
- Cache misses and cache subsystem degradation should fall back to build path without UI lockup.

## 6. Functional Requirements

| ID | Requirement | Priority |
|---|---|---|
| FR-001 | System SHALL implement in-process oracle cache keyed by dashboard context + container + oracle identity + version metadata. | P0 |
| FR-002 | System SHALL implement revisit oracle cache keyed by user + dashboard context + container + oracle identity + version metadata. | P0 |
| FR-003 | System SHALL enforce TTL freshness policy for in-process and revisit entries via configuration. | P0 |
| FR-004 | System SHALL enforce enrollment-tiered max container capacity with container-scoped LRU eviction for in-process cache. | P0 |
| FR-005 | System SHALL support oracle-granular writes, including late completion writes for previously viewed containers when identity guard passes. | P0 |
| FR-006 | System SHALL support deterministic partial-hit responses (`hits`, `misses`) for required oracle lookups. | P0 |
| FR-007 | System SHALL provide per-oracle miss coalescing API so concurrent requests for the same missing key share one build. | P1 |
| FR-008 | System SHALL enforce strict revisit eligibility: revisit cache reads occur only on explicit-container entry flows. | P0 |
| FR-009 | System SHALL expose cache public APIs consumed by coordinator; cache internals SHALL remain hidden from coordinator modules. | P0 |
| FR-010 | System SHALL NOT implement request queueing, token generation, or stale-result UI suppression policy. | P0 |
| FR-011 | System SHALL include extensive automated unit testing for cache key/policy/store behavior, and SHALL use mocked/stubbed dependencies (for example oracle payload producers and coalescing participants) where needed to validate end-to-end component interactions in tests. | P0 |

## 7. Acceptance Criteria

- AC-001: Given repeated lookups for same context/container/oracle identity within TTL, when cache is warm, then payload is returned from cache.
- AC-002: Given partial container completeness, when required lookup runs, then response includes deterministic `hits` and `misses` and only misses proceed to build.
- AC-003: Given capacity threshold breach, when new container payloads are written, then least-recently-used container entries are evicted as a group.
- AC-004: Given late oracle completion for prior container, when identity guard passes, then payload is written for that container key without affecting active UI scope directly.
- AC-005: Given revisit flow with explicit container params, when revisit cache has eligible payloads, then those payloads are returned prior to build.
- AC-006: Given revisit-ineligible flow (base mount without explicit container), revisit cache lookup is skipped.
- AC-007: Given concurrent misses for identical oracle key, exactly one build producer is elected and other requests await/shared result.
- AC-008: Given boundary inspection, cache modules contain no request queue/token orchestration logic.
- AC-009: Given cache unit test execution, mocked/stubbed producers/waiters and oracle payload sources are used where necessary to exercise coalescing, late writes, and boundary interactions end-to-end at component boundaries.

## 8. Non-Functional Requirements

Performance:
- NFR-PERF-001: Cache lookup p95 <= 5ms, p99 <= 10ms per key.
- NFR-PERF-002: Multi-key required lookup p95 <= 20ms for typical required sets.
- NFR-PERF-003: Miss coalescing overhead p95 <= 3ms.

Reliability:
- NFR-REL-001: No cross-user revisit payload leakage in automated tests.
- NFR-REL-002: TTL expiry behavior is deterministic and test-covered.
- NFR-REL-003: Identity-guarded writes prevent key/version mismatches.

Scalability:
- NFR-SCALE-001: In-process memory is bounded by enrollment-tiered container limits.
- NFR-SCALE-002: Eviction executes at container granularity, not per-oracle random churn.

## 9. Data Model & APIs

No relational schema migration.

Notional cache public API:

- `Oli.Dashboard.Cache.lookup_required/4`
  - Input: context, container, required oracle keys, opts.
  - Output: `%{hits: %{oracle_key => payload}, misses: [oracle_key], source: :inprocess | :mixed}`.

- `Oli.Dashboard.Cache.lookup_revisit/4`
  - Input: user/context/container/oracle keys, opts.
  - Output: `%{hits: %{oracle_key => payload}, misses: [oracle_key]}`.

- `Oli.Dashboard.Cache.write_oracle/6`
  - Writes one oracle payload with identity/version guards.

- `Oli.Dashboard.Cache.coalesce_or_build/3`
  - Ensures one producer per missing key, others await same result.

- `Oli.Dashboard.Cache.touch_container/3`
  - Updates container recency for LRU tracking.

Key shapes (from data design):
- In-process: `{:dashboard_oracle, oracle_key, dashboard_context_id, container_type, container_id_or_nil, oracle_version, data_version}`
- Revisit: `{:dashboard_revisit_oracle, user_id, dashboard_context_id, container_type, container_id_or_nil, oracle_key, oracle_version, data_version}`

## 10. Integrations & Platform Considerations

- Used by `Oli.Dashboard.LiveDataCoordinator` through public cache APIs.
- Must support oracle outputs from mixed datastores (Postgres and ClickHouse) transparently.
- Revisit cache remains node-local in baseline and requires per-user scoping.
- Supports `Oli.InstructorDashboard.DataSnapshot` read-through patterns.

## 11. Feature Flagging, Rollout & Migration

- No user-facing feature flag required.
- Rollout strategy:
  1. Introduce cache API and instrumentation.
  2. Enable read-through in coordinator path.
  3. Tune TTL/capacity thresholds using observed metrics.

## 12. Analytics & Success Metrics

- In-process hit/miss rate by container type and oracle key.
- Revisit hit/miss rate for eligible flows.
- TTL expiry and eviction counts.
- Miss coalescing rates (`coalesced`, `producer`, `waiter`).
- Average and p95 container count held per session.

## 13. Risks & Mitigations

- Risk: stale data overuse.
  - Mitigation: TTL freshness controls + identity/version keys + explicit fallback load path.
- Risk: memory pressure on large sections.
  - Mitigation: enrollment-tiered container caps + container-scoped LRU eviction.
- Risk: hidden coupling with coordinator internals.
  - Mitigation: API-only integration and explicit non-goal forbidding queue/token logic in cache.

## 14. Open Questions & Assumptions

Assumptions:
- TTL defaults defined in this PRD are acceptable for baseline.
- Revisit cache remains intentionally narrow (selected oracle subset only).

Open questions:
- Should some oracle domains adopt shorter TTL defaults in follow-up tuning?
- Should miss coalescing scope remain node-local only, or require cross-node coordination in later phases?

## 15. Timeline & Milestones (Draft)

1. Implement keying + in-process/revisit stores + API facade.
2. Implement TTL, capacity, LRU, and identity-guarded writes.
3. Implement miss coalescing and revisit eligibility rules.
4. Land instrumentation and tuning workflow.

## 16. QA Plan

- Unit tests:
  - key composition/parsing, TTL expiry, container eviction, identity guard behavior.
  - mocked/stubbed oracle payload producers and coalescing participants where needed to exercise end-to-end cache component interactions.
- Integration tests:
  - read-through lookup order and partial-hit behavior.
  - late write behavior across container switches.
  - revisit eligibility and no-cross-user leakage.
- Concurrency tests:
  - coalesced miss producer/waiter behavior under contention.

## 17. Definition of Done

- FR-001 through FR-011 implemented or explicitly deferred with rationale.
- AC-001 through AC-009 passing.
- Metrics for hits/misses/evictions/ttl/coalescing available.
- Clear one-way boundary present: coordinator uses cache API; cache does not implement coordinator orchestration policy.

Prototype references:
- `lib/oli/instructor_dashboard/prototype/in_process_cache.ex`
- `lib/oli/instructor_dashboard/prototype/live_data_controller.ex`
- `lib/oli/instructor_dashboard/prototype/scope.ex`

## 18. Decision Log

### 2026-02-17 - Align Cache PRD to Prototype Baseline Identity and Layer Split
- Change: Added prototype alignment language for scope+oracle key identity and strict storage-vs-orchestration separation.
- Reason: Prototype confirms this boundary is effective and keeps coordinator/cache responsibilities clear.
- Evidence: `lib/oli/instructor_dashboard/prototype/in_process_cache.ex`, `lib/oli/instructor_dashboard/prototype/live_data_controller.ex`
- Impact: Clarifies FR-001/FR-006/FR-010 and AC-002/AC-008 expectations.
