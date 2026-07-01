# TRIAGE-2236 LTI Keyset Cache Reliability - Delivery Plan

Scope and reference artifacts:

- PRD: `./docs/exec-plans/current/triage-2236-keyset-cache-reliability/prd.md`
- FDD: `./docs/exec-plans/current/triage-2236-keyset-cache-reliability/fdd.md`

## Scope

Implement the keyset-cache reliability work described in the PRD and FDD by converting launch-path
key lookup from fail-fast-plus-background-refresh to read-through-on-miss, adding per-URL
single-flight request coalescing, preserving ETS as the warm-path cache, keeping Oban background
refresh for proactive maintenance, and improving diagnostics and user-facing messaging so launch
failures reflect the actual recovery behavior that occurred.

Check off tasks in the plan as they are completed, and update the plan as needed if implementation details or requirements clarifications arise.

## Clarifications & Default Assumptions

- The authoritative work-item artifacts are [prd.md](./docs/exec-plans/current/triage-2236-keyset-cache-reliability/prd.md) and [fdd.md](./docs/exec-plans/current/triage-2236-keyset-cache-reliability/fdd.md).
- Repository-local harness contract files such as `harness.yml` and the standard docs bundle were not present at intake, so this plan follows the repository guidance available in `AGENTS.md` and the current LTI module boundaries.
- `:key_not_found_in_keyset` remains the terminal reason when the latest available keyset still does not contain the requested `kid`; diagnostics must show whether a refresh was attempted.
- A successful synchronous read-through refresh does not also need to enqueue a background refresh job.
- Per-URL single-flight request coalescing is in scope for the initial implementation, not deferred follow-up work.
- During implementation, task checkboxes in this plan should be updated as work is completed so phase status remains accurate.

## Phase 1: Shared Fetch And Cache Boundaries

- Goal: Extract a shared JWKS fetch-and-cache boundary so synchronous and asynchronous refresh paths use the same HTTPS validation, parsing, TTL, and cache update logic.
- Tasks:
  - [x] Add a narrow shared helper such as `Oli.Lti.KeysetFetcher` to own HTTPS validation, HTTP fetch, JWKS parsing, TTL extraction, and normalized result tuples. Supports `FR-002`, `FR-003`, `FR-004`, `FR-005`.
  - [x] Refactor `Oli.Lti.KeysetRefreshWorker` to use the shared helper without changing its external scheduling interface. Supports `FR-004`, `FR-008`.
  - [x] Keep `Oli.Lti.KeysetCache` as the ETS authority and preserve the current stored shape unless minimal in-memory metadata is needed for diagnostics. Supports `FR-004`, `FR-007`, `FR-008`.
  - [x] Confirm `preload_keys/1` uses the same shared fetch path so manual operational recovery matches launch-path parsing behavior. Supports `FR-001`, `FR-004`.
- Testing Tasks:
  - [x] Add unit tests for shared fetch helper success, HTTPS validation failures, invalid JSON, invalid JWKS shape, and TTL extraction.
  - [x] Update worker tests to prove asynchronous refresh still populates ETS correctly through the shared helper.
  - [x] Run targeted LTI unit tests for fetch helper, cache, and worker boundaries.
  - Command(s): `mix test test/oli/lti/keyset_fetcher_test.exs test/oli/lti/keyset_refresh_worker_test.exs test/oli/lti/keyset_cache_test.exs test/oli/lti/cached_key_provider_test.exs`, `mix format`
- Definition of Done:
  - One shared implementation path exists for JWKS fetch, parse, TTL selection, and cache population.
  - Background refresh and manual preload continue to work through that shared path.
  - This phase provides the reusable foundation for `AC-001`, `AC-002`, `AC-004`, and `AC-005`.
- Gate:
  - Do not change launch-path provider behavior until the shared fetch boundary is tested and stable.
- Dependencies:
  - None.
- Parallelizable Work:
  - Helper extraction and worker refactor can proceed in parallel once the normalized fetch result contract is fixed.

## Phase 2: Launch-Path Read-Through Resolution

- Goal: Make `CachedKeyProvider.get_public_key/2` recover synchronously from cold-cache and cached-`kid`-miss conditions before surfacing a terminal error.
- Tasks:
  - [x] Refactor `CachedKeyProvider.get_public_key/2` so warm hits remain cache-only and uncached keysets trigger synchronous read-through fetch before failure. Supports `FR-002`, `FR-005`, `FR-006`. Covers `AC-001`.
  - [x] Refactor cached `kid` miss handling so it performs synchronous refresh, updates ETS, retries lookup, and only then returns `:key_not_found_in_keyset` if the fresh keyset still lacks the key. Supports `FR-003`, `FR-004`, `FR-005`. Covers `AC-002`, `AC-005`.
  - [x] Keep warm-cache hits free of unnecessary HTTP fetches. Supports `FR-007`. Covers `AC-003`.
  - [x] Remove launch-path dependence on “background job has been scheduled” semantics for correctness of the current request. Supports `FR-005`, `FR-009`.
- Testing Tasks:
  - [x] Add `CachedKeyProvider` tests for cold-cache launch success after synchronous fetch. Covers `AC-001`.
  - [x] Add `CachedKeyProvider` tests for cached `kid` miss recovery after synchronous refresh. Covers `AC-002`.
  - [x] Add regression tests proving warm-cache hits do not perform extra HTTP fetches. Covers `AC-003`.
  - [x] Add terminal failure tests for unreachable JWKS URL, invalid JSON, invalid JWKS payload, and post-refresh missing-`kid` behavior. Covers `AC-004`, `AC-005`.
  - [x] Run targeted provider tests after the refactor.
  - Command(s): `mix test test/oli/lti/cached_key_provider_test.exs`, `mix format`
- Definition of Done:
  - Launch-path key lookup reads through on cold cache and cached `kid` miss.
  - Warm-cache behavior remains cache-only.
  - Terminal fetch and lookup failures occur only after the read-through attempt has been exhausted.
- Gate:
  - Do not add coordination or observability signoff until read-through behavior is correct for single-request success and failure paths.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Cold-cache and cached-`kid`-miss test additions can proceed in parallel once the provider control flow is agreed.

## Phase 3: Per-URL Single-Flight Coordination

- Goal: Prevent thundering herd behavior by ensuring only one in-flight read-through fetch runs per `key_set_url` at a time.
- Tasks:
  - [x] Introduce a narrow coordination boundary such as `Oli.Lti.KeysetFetchCoordinator` keyed by `key_set_url`. Supports `FR-002`, `FR-003`, `FR-007`, `FR-008`.
  - [x] Make cold-cache misses wait on an existing same-URL fetch owner and re-read ETS after completion instead of starting duplicate HTTP fetches. Supports `FR-002`, `FR-005`, `FR-007`. Covers `AC-001`, `AC-006`.
  - [x] Make cached-`kid`-miss refreshes use the same single-flight ownership and waiter behavior. Supports `FR-003`, `FR-005`, `FR-007`, `FR-008`. Covers `AC-002`, `AC-006`.
  - [x] Add bounded timeout and owner-cleanup behavior so waiters fail predictably if the owner crashes or hangs. Supports `FR-008`.
- Testing Tasks:
  - [x] Add concurrency tests proving multiple cold-cache requests for the same URL produce one HTTP fetch and shared success resolution. Covers `AC-001`, `AC-006`.
  - [x] Add concurrency tests proving multiple cached-`kid`-miss requests for the same URL produce one refresh and shared ETS re-read behavior. Covers `AC-002`, `AC-006`.
  - [x] Add bounded-failure tests for waiter timeout or owner failure. Supports `FR-008`.
  - [x] Run targeted provider and coordinator tests.
  - Command(s): `mix test test/oli/lti/cached_key_provider_test.exs`, `mix format`
- Definition of Done:
  - Duplicate same-URL read-through fetches are coalesced.
  - Waiters resolve from the shared fetch result or fail in a bounded, diagnosable way.
  - Single-flight behavior is covered by concurrency-focused regression tests.
- Gate:
  - Do not finalize observability and user-facing error text until single-flight owner and waiter outcomes are stable.
- Dependencies:
  - Phase 2.
- Parallelizable Work:
  - Coordinator implementation and concurrency test scaffolding can proceed in parallel once the coordinator API is fixed.

## Phase 4: Diagnostics, Messaging, And Final Verification

- Goal: Make launch failures diagnosable and user-visible copy truthful, then verify the full slice against the work item requirements.
- Tasks:
  - [x] Add structured logs and any in-scope telemetry for warm hits, sync cold fill, sync refresh after cached `kid` miss, shared-fetch waiter success, and shared-fetch timeout or owner failure. Supports `FR-001`, `FR-008`. Covers `AC-006`.
  - [x] Include non-sensitive diagnostics such as `requested_kid`, cached key ids before refresh, refreshed key ids, lookup source, and cache freshness context when available. Supports `FR-001`, `FR-008`. Covers `AC-004`, `AC-005`, `AC-006`.
  - [x] Update user-facing error messages so they describe actual current-request recovery behavior and do not claim that queued background work already resolved the problem. Supports `FR-009`. Covers `AC-007`.
  - [x] Reconcile any test fixtures, docs, and operational comments to describe the new read-through and single-flight behavior accurately. Supports `FR-001`, `FR-009`.
- Testing Tasks:
  - [x] Add log or telemetry assertions for lookup source, refresh-attempt visibility, and terminal classification. Covers `AC-004`, `AC-005`, `AC-006`.
  - [x] Add assertions for truthful user-facing error copy after failed synchronous recovery. Covers `AC-007`.
  - [x] Run targeted LTI tests, compile, and formatting gates for the touched backend surfaces.
  - Command(s): `mix test test/oli/lti`, `mix compile`, `mix format`
- Definition of Done:
  - Operators can distinguish warm-cache success, synchronous recovery success, and terminal failure from logs and in-scope telemetry.
  - User-facing copy reflects actual read-through behavior.
  - The implementation satisfies `FR-001` through `FR-009` and `AC-001` through `AC-007`.
- Gate:
  - Final signoff requires green targeted tests, clear diagnostics, truthful copy, and intact requirements traceability.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Diagnostic assertions and user-facing copy refinement can proceed in parallel once failure classifications are stable.

## Parallelization Notes

- Phase 1 helper extraction and worker refactor are parallel-safe once the fetch helper return contract is fixed.
- In Phase 2, cold-cache and cached-`kid`-miss test additions can be developed in parallel against the agreed provider behavior.
- In Phase 3, coordinator implementation and concurrency test scaffolding are parallel-safe once the coordinator API and timeout budget are fixed.
- Phase 4 logging assertions and error-copy refinement can overlap after provider outcomes and single-flight states stop changing.

## Phase Gate Summary

- Gate A: shared JWKS fetch/parse/cache behavior must be centralized and tested before launch-path provider refactor begins.
- Gate B: launch-path read-through must work correctly for cold-cache, cached-`kid`-miss, warm-hit, and terminal failure cases before concurrency coordination is added.
- Gate C: per-URL single-flight coordination must be stable under concurrency before observability and copy are finalized.
- Gate D: final signoff requires targeted tests, compile/format gates, truthful user-facing messaging, and complete requirements traceability.
