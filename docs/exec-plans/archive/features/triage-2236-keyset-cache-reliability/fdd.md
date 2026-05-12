# TRIAGE-2236 LTI Keyset Cache Reliability - Functional Design Document

## 1. Executive Summary

This design changes Torus keyset resolution from fail-fast-plus-background-refresh to read-through-on-miss while preserving the current ETS cache and Oban refresh worker. The simplest adequate approach is to keep `Oli.Lti.KeysetCache` as the warm-path authority, keep `Oli.Lti.KeysetRefreshWorker` for periodic and operator-triggered background warming, and extend `Oli.Lti.CachedKeyProvider` so launch-time cold-cache and cached-`kid`-miss paths synchronously fetch the latest JWKS before returning an error.

This design satisfies `FR-002` through `FR-009` and directly implements `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`, and `AC-007` without introducing a new persistence layer or broad LTI launch redesign.

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001`: capture enough diagnostics and operational context to explain plausible stale-cache and failed-recovery causes after implementation.
  - `FR-002`, `FR-005`, `FR-006`: cold-cache launch paths must read through instead of failing immediately, so first launch from a valid registration can succeed. This maps to `AC-001`.
  - `FR-003`, `FR-004`, `FR-005`: cached `kid` misses must synchronously refresh and repopulate ETS before returning a terminal key lookup failure. This maps to `AC-002` and `AC-005`.
  - `FR-007`: warm-cache hits must stay cache-only. This maps to `AC-003`.
  - `FR-008`: logs and telemetry must explain cache source, refresh path, key ids, and terminal classification. This maps to `AC-004` and `AC-006`.
  - `FR-009`: user-facing messages must describe actual recovery behavior, not just queued work. This maps to `AC-007`.
- Non-functional requirements:
  - Launch validation remains HTTPS-only and must not weaken signature verification.
  - Warm-cache performance remains the primary path; synchronous network fetch is reserved for exceptional miss paths.
  - The design must remain operable in the existing Phoenix, ETS, and Oban runtime without new infrastructure.
- Assumptions:
  - `Lti_1p3.KeyProvider.get_public_key/2` may perform synchronous work as long as it returns the same success and error shapes expected by launch validation.
  - Existing HTTP client behavior in `Lti_1p3.Config.http_client!/0` is acceptable for launch-path read-through requests.
  - The repository-local harness contract files were not present at intake, so this FDD relies on `AGENTS.md`, the PRD, and current LTI module boundaries.

## 3. Repository Context Summary

- What we know:
  - [cached_key_provider.ex](./lib/oli/lti/cached_key_provider.ex) currently schedules Oban refresh and fails immediately on `:keyset_not_cached` and `:key_not_found`.
  - [keyset_cache.ex](./lib/oli/lti/keyset_cache.ex) stores `%{keys, fetched_at, expires_at}` in ETS and exposes warm-path lookup APIs that are already suitable for the success path.
  - [keyset_refresh_worker.ex](./lib/oli/lti/keyset_refresh_worker.ex) already encapsulates HTTPS validation, HTTP fetch, JWKS parsing, TTL extraction, and cache population for asynchronous refresh.
  - Existing tests in [cached_key_provider_test.exs](./test/oli/lti/cached_key_provider_test.exs), [keyset_cache_test.exs](./test/oli/lti/keyset_cache_test.exs), and [keyset_refresh_worker_test.exs](./test/oli/lti/keyset_refresh_worker_test.exs) already cover most of the current seams.
- Unknowns to confirm:
  - Whether any `lti_1p3` caller logic assumes the current specific `reason` atoms for cache miss failure.
  - Whether operator tooling or dashboards currently parse the existing log strings and need compatibility-preserving message keys.
  - Which OTP coordination primitive is the best fit for per-URL single-flight fetch ownership in this codebase.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- `Oli.Lti.CachedKeyProvider` becomes the read-through coordinator.
  - Warm hit: return cached JWK immediately.
  - Cold cache: synchronously fetch, populate cache, retry lookup, then return success or classified error. Covers `AC-001`, `AC-004`, and `AC-006`.
  - Cached `kid` miss: synchronously refresh, overwrite cache, retry lookup, then return success or classified error. Covers `AC-002`, `AC-005`, and `AC-006`.
  - Per-URL single-flight request coalescing is part of the initial implementation. If one request is already fetching a JWKS for a given `key_set_url`, later requests for that same URL wait for the first fetch attempt to finish and then re-read ETS instead of triggering duplicate HTTP fetches.
  - Continue to expose `preload_keys/1` and `refresh_all_keys/0` for manual and background operations.
- `Oli.Lti.KeysetCache` remains the in-memory storage boundary.
  - No new storage backend.
  - Keep `fetched_at` and `expires_at`.
  - Optionally extend cached metadata with lightweight source context only if needed for diagnostics.
- `Oli.Lti.KeysetRefreshWorker` remains the asynchronous maintainer.
  - Background refresh still warms cache and supports periodic reliability posture.
  - Shared fetch/parse/cache code should be extracted so both synchronous and asynchronous paths use the same JWKS parsing and TTL logic.
- Shared fetch module:
  - Introduce a narrow internal helper such as `Oli.Lti.KeysetFetcher` or a private extracted function module.
  - Responsibilities: HTTPS validation, HTTP GET, JWKS JSON validation, TTL extraction, and normalized result tuples.
  - This avoids duplicating fetch logic between launch path and worker path.
- Single-flight coordinator:
  - Introduce a small coordination boundary such as `Oli.Lti.KeysetFetchCoordinator` keyed by `key_set_url`.
  - Responsibilities: grant a single active fetch owner per URL, let same-URL waiters block with a bounded timeout, and signal completion so waiters re-read ETS after the shared fetch finishes.
  - This coordinator is not a cache and does not own JWKS data. It only suppresses duplicate in-flight fetches.

### 4.2 State & Data Flow

1. Launch validation calls `CachedKeyProvider.get_public_key(key_set_url, kid)`.
2. Provider checks `KeysetCache.get_public_key/2`.
3. If warm hit:
   - return cached `JOSE.JWK`
   - emit warm-cache diagnostics
   - satisfies `AC-003`
4. If cache is missing:
   - if another request is already fetching the same `key_set_url`, wait for that attempt to complete and then retry ETS lookup
   - otherwise perform synchronous fetch using shared fetch helper
   - on successful JWKS load, write to ETS and retry key lookup
   - if the requested `kid` is found, return success and record `cache_source=sync_cold_fill`
   - if fetch fails or loaded keyset still cannot satisfy lookup, return classified error
   - satisfies `AC-001`, `AC-004`, and `AC-006`
5. If cache exists but `kid` is absent:
   - acquire the same per-URL single-flight ownership used by cold-cache fill
   - if another request is already refreshing that `key_set_url`, wait for completion and then retry ETS lookup
   - otherwise perform synchronous refresh using shared fetch helper
   - overwrite ETS entry with fresh JWKS and updated TTL
   - retry key lookup
   - if the requested `kid` is found, return success and record `cache_source=sync_refresh_after_kid_miss`
   - if not found or refresh fails, return classified error
   - satisfies `AC-002`, `AC-005`, and `AC-006`
6. Background refresh remains available:
   - keep `schedule_refresh/1` and `schedule_refresh_all/0`
   - do not depend on queued work for correctness of the current launch

### 4.3 Lifecycle & Ownership

- Cache ownership:
  - ETS remains the only keyset cache store in scope.
  - `KeysetCache` owns insertion, expiration, and deletion semantics.
- Fetch ownership:
  - Synchronous fetch is owned by `CachedKeyProvider` because launch correctness depends on it.
  - Asynchronous fetch is owned by `KeysetRefreshWorker` because background warming is an operational concern.
  - Shared parsing and normalization belongs in a helper module, not split across both callers.
- Error ownership:
  - `CachedKeyProvider` owns translation from low-level fetch/lookup outcomes into user-facing `reason`/`msg` maps expected by the LTI validation boundary.
  - Worker logs operational failures but does not define launch-path messaging.

### 4.4 Alternatives Considered

- Keep the current async-only refresh design:
  - rejected because it directly violates `FR-005` and fails `AC-001` and `AC-002`.
- Bypass cache entirely and always fetch JWKS synchronously:
  - rejected because it would regress warm-path performance, increase external dependency on every launch, and violate `FR-007`.
- Persist keysets in the database:
  - rejected because the PRD does not require durable storage and ETS already satisfies the intended steady-state behavior.
- Skip single-flight coordination and accept duplicate miss-path fetches:
  - rejected because the first implementation should already prevent thundering herd behavior during cold-cache and rotation incidents.
  - repeated same-URL fetches would add avoidable load to the LMS JWKS endpoint at exactly the moment Torus is recovering from a miss.

## 5. Interfaces

- Existing public interface stays stable:
  - `CachedKeyProvider.get_public_key(key_set_url, kid) -> {:ok, JOSE.JWK.t()} | {:error, %{reason: atom(), msg: String.t()}}`
- New internal interface:
  - `KeysetFetcher.fetch_and_cache(key_set_url) -> {:ok, %{keys: list(), fetched_at: DateTime.t(), expires_at: DateTime.t(), ttl_seconds: integer()}} | {:error, fetch_reason}`
- New coordination interface:
  - `KeysetFetchCoordinator.run(key_set_url, fun) -> {:ok, result} | {:error, reason}`
  - semantics:
    - first caller for a URL executes `fun`
    - concurrent callers for the same URL wait for completion up to a bounded timeout
    - waiters re-read ETS after owner completion rather than trusting an in-memory return value alone
- Existing cache interface remains:
  - `KeysetCache.get_public_key/2`
  - `KeysetCache.put_keyset/3`
  - `KeysetCache.get_keyset/1`
  - `KeysetCache.delete_keyset/1`
- Existing worker interface remains:
  - `KeysetRefreshWorker.schedule_refresh/1`
  - `KeysetRefreshWorker.schedule_refresh_all/0`
- Log and telemetry payload interface:
  - required fields: `key_set_url`, `requested_kid`, `lookup_source`, `cached_key_ids`, `refreshed_key_ids`, `cache_fetched_at`, `cache_expires_at`, `outcome`
  - values must remain non-sensitive and should omit raw token or full JWKS payload content

## 6. Data Model & Storage

- No new database tables or migrations are required.
- ETS cached value may remain `%{keys, fetched_at, expires_at}`.
- If diagnostic needs justify it, cached entry may add:
  - `last_refresh_source` with values like `background`, `preload`, `sync_cold_fill`, `sync_refresh_after_kid_miss`
  - this is optional and should stay in-memory only
- The design intentionally does not persist negative cache results.

## 7. Consistency & Transactions

- There is no cross-process transaction boundary because ETS writes and HTTP fetches are not transactional.
- Consistency model:
  - warm reads are eventually refreshed based on TTL or explicit refresh
  - sync miss paths update ETS before retrying lookup in the same request
  - the current request must only succeed after the refreshed cache has been written and re-read
- Concurrent read-through misses on the same URL are coalesced through the single-flight coordinator.
  - one fetch owner performs the network call
  - same-URL waiters re-read ETS after completion
  - if the owner fails, waiters surface the same terminal condition after the shared attempt completes or times out

## 8. Caching Strategy

- Primary cache remains ETS in `KeysetCache`.
- TTL continues to come from `Cache-Control: max-age` when present, else default TTL.
- Expired entries are treated as uncached and trigger the same synchronous read-through behavior as first use. This supports `AC-001`.
- Cached `kid` miss is treated as a refresh trigger, not an immediate terminal failure. This supports `AC-002`.
- Read-through fetches are coalesced per `key_set_url` so only one in-flight HTTP fetch for a URL happens at a time.
- Background Oban refresh remains useful for proactive warming and administrative recovery, but not correctness of the current launch.

## 9. Performance & Scalability Posture

- Warm path remains unchanged and in-memory, satisfying `FR-007` and `AC-003`.
- Exceptional miss paths add one synchronous network call and one ETS write before retry.
- Read-through launch latency is acceptable because it trades one-time delay for correctness and removal of manual intervention.
- Per-URL single-flight coordination prevents thundering herd amplification on miss paths and reduces redundant load on the JWKS endpoint.

## 10. Failure Modes & Resilience

- JWKS URL invalid or insecure:
  - return classified error immediately after validation failure
  - worker continues to discard these as permanent configuration problems
- HTTP/network failure during read-through:
  - return classified fetch failure for the current launch
  - diagnostics must show that sync recovery was attempted
  - covers `AC-004`
- Single-flight owner crashes or waiters time out:
  - waiting callers fail in a bounded way rather than blocking indefinitely
  - diagnostics must show whether the request was fetch owner or waiter and whether the shared wait timed out
- JWKS JSON invalid or missing `"keys"`:
  - return classified parse failure for the current launch
  - covers `AC-004`
- Refreshed JWKS still missing requested `kid`:
  - return classified key-not-found-after-refresh failure
  - covers `AC-005`
- Background refresh enqueue or execution failure:
  - no longer blocks correctness of the current launch if sync refresh succeeded
  - remains visible as an operational issue
- Misleading user-facing copy:
  - replace “background job has been scheduled” launch-path copy with text that reflects whether Torus attempted synchronous recovery and why it still failed
  - covers `AC-007`

## 11. Observability

- Add structured logging around every `get_public_key/2` outcome:
  - warm hit
  - sync cold fill attempted/succeeded/failed
  - sync refresh after cached `kid` miss attempted/succeeded/failed
  - single-flight waiter resumed after shared fetch
  - single-flight wait timeout or owner failure
- Include explicit AC traceability in implementation comments or test names for:
  - `AC-001`, `AC-002`, `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`
- Diagnostic fields:
  - `lookup_source`
  - `requested_kid`
  - `cached_key_ids_before_refresh`
  - `refreshed_key_ids`
  - `cache_fetched_at`
  - `cache_expires_at`
  - `error_reason`
- If telemetry hooks already exist in the LTI boundary, emit corresponding structured events; otherwise structured logs are the minimum acceptable outcome for this slice.

## 12. Security & Privacy

- Keep HTTPS validation for all JWKS fetches.
- Do not log raw JWTs, full JWKS payloads, private keys, cookies, or session data.
- Logging key ids is acceptable because they are public signing-key identifiers and necessary for diagnosis.
- Maintain existing JOSE and `lti_1p3` signature verification behavior; this design changes cache population timing, not trust rules.

## 13. Testing Strategy

- Unit and integration coverage in `CachedKeyProvider` tests:
  - cold-cache success path for `AC-001`
  - cached `kid` miss followed by successful sync refresh for `AC-002`
  - warm-cache hit without HTTP fetch for `AC-003`
  - unreachable endpoint, invalid JSON, and invalid JWKS for `AC-004`
  - refreshed JWKS still missing `kid` for `AC-005`
  - log or telemetry assertions for lookup source and refresh-path classification for `AC-006`
  - user-facing error copy assertions showing truthful messaging for `AC-007`
- Single-flight coverage:
  - concurrent cold-cache requests for the same `key_set_url` perform one HTTP fetch and all callers resolve from the shared result
  - concurrent cached-`kid`-miss requests for the same `key_set_url` perform one refresh and then re-read ETS
  - waiter timeout or owner failure returns a bounded classified failure rather than hanging
- Shared fetch helper tests:
  - HTTPS URL validation
  - cache-control TTL extraction
  - normalized fetch result shape
- Worker regression tests:
  - confirm asynchronous refresh still uses shared fetch logic and still populates ETS correctly

## 14. Backwards Compatibility

- Public key provider behavior remains compatible at the interface level.
- Warm-cache launches remain unchanged.
- Error `reason` atoms should be preserved. `:key_not_found_in_keyset` continues to cover the case where the cache was refreshed but still does not contain the requested `kid`, with diagnostics showing that refresh was attempted.
- Background refresh APIs remain in place, so operational playbooks using `preload_keys/1` or worker refresh remain valid.

## 15. Risks & Mitigations

- Launch latency spikes on miss paths: keep sync fetch only on miss paths and monitor frequency.
- Single-flight coordination complexity: keep the coordinator narrow, keyed only by `key_set_url`, with bounded waits and explicit cleanup on both success and failure.
- Divergence between sync and async parsing logic: centralize fetch/parse/cache behavior in a shared helper module.
- Operators may lose previous log cues: preserve comparable log coverage while adding structured fields rather than replacing observability wholesale.

## 16. Open Questions & Follow-ups

- Choose the concrete coordinator primitive for single-flight ownership:
  - dedicated GenServer
  - `Registry` plus monitored task ownership
  - another minimal OTP primitive already used in the repo
- Decide the waiter timeout budget relative to the existing 10-second HTTP timeout so shared fetch waiting fails predictably.
- Confirm whether structured telemetry events should be added alongside logs in this same slice or in the next implementation phase.

## 17. References

- [prd.md](./docs/exec-plans/current/triage-2236-keyset-cache-reliability/prd.md)
- [requirements.yml](./docs/exec-plans/current/triage-2236-keyset-cache-reliability/requirements.yml)
- [cached_key_provider.ex](./lib/oli/lti/cached_key_provider.ex)
- [keyset_cache.ex](./lib/oli/lti/keyset_cache.ex)
- [keyset_refresh_worker.ex](./lib/oli/lti/keyset_refresh_worker.ex)
- [cached_key_provider_test.exs](./test/oli/lti/cached_key_provider_test.exs)
- [keyset_refresh_worker_test.exs](./test/oli/lti/keyset_refresh_worker_test.exs)
