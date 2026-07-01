# TRIAGE-2236 LTI Keyset Cache Reliability - Product Requirements Document

## 1. Overview

Improve Torus LTI launch reliability by making platform JWKS retrieval dependable at the moment it is needed for token validation. The system should investigate and explain why cached keysets can become stale or incomplete, and it should provide a safe fallback where launch-time cache misses behave like a read-through cache instead of requiring manual intervention or a later background retry.

## 2. Background & Problem Statement

Torus currently validates inbound LTI launches using `Oli.Lti.CachedKeyProvider`, which reads platform public keys from an ETS-backed cache populated by `Oli.Lti.KeysetRefreshWorker`. When a keyset is missing from cache or when the requested `kid` is not found in the cached keyset, the provider fails the launch immediately and only schedules an asynchronous Oban refresh for a future attempt.

That behavior created a production incident affecting Brightspace launches. Some valid launches failed because the requested `kid` was not present in the cached keyset. The system message claimed that an immediate refresh had been triggered, but the issue persisted for days until an operator manually forced a synchronous refresh through `preload_keys/1` in a production IEx session.

This exposes two product problems:

- Torus cannot currently guarantee recovery when cached JWKS content is missing, stale, or incomplete.
- The very first launch from a newly registered LMS can fail simply because the keyset was not already cached.

The work must first try to identify the actual failure mode behind the stale or incomplete cache. If the exact cause remains uncertain, the shipped behavior should still eliminate dependence on delayed background refresh for launch correctness.

## 3. Goals & Non-Goals
### Goals

- Determine the most plausible causes for a missing `kid` in a cached keyset and for failed automatic recovery after a launch-time cache miss.
- Make keyset retrieval reliable enough that valid launches do not require manual cache warming or production shell intervention.
- Treat the platform JWKS cache as a read-through cache for launch validation when cached data is absent or does not contain the requested `kid`.
- Ensure first launch from a registered LMS can succeed without requiring prior asynchronous cache population.
- Preserve clear, operator-usable diagnostics for cache state, refresh attempts, fetched key identifiers, and terminal failure reason.
- Avoid failing immediately on uncached keysets or cached `kid` misses by attempting a read-through fetch first, then surfacing the actual retrieval or lookup error if that fetch does not resolve the problem.

### Non-Goals

- Redesign the entire Torus LTI launch lifecycle beyond the keyset caching and validation boundary.
- Replace the existing LTI validation stack or `Lti_1p3` integration.
- Introduce long-lived persistence of platform keysets outside the scope required to make cache behavior reliable.
- Solve unrelated LMS configuration problems that are not caused by keyset retrieval or `kid` resolution.

## 4. Users & Use Cases

- Students: launch Torus from the LMS and enter successfully even when the platform keyset has not been cached yet.
- Instructors: launch Torus reliably after an LMS rotates signing keys without waiting for a later retry window or operator intervention.
- Support and operations staff: determine whether launch failure was caused by stale cache contents, failed refresh execution, unreachable JWKS URL, invalid JWKS payload, or a genuine missing `kid`.
- Engineers maintaining LTI integrations: reason about cache state and refresh behavior using deterministic logs, telemetry, and tests.

## 5. UX / UI Requirements

- User-facing launch errors must avoid claiming that recovery has already happened when the system only scheduled asynchronous work.
- Launch failures caused by JWKS retrieval should explain the actionable failure class in plain language without exposing tokens, claims, secrets, or raw key material.
- The first launch from a newly registered LMS should not fail solely because the keyset is uncached before Torus has attempted a read-through fetch.
- If a fresh JWKS fetch still cannot resolve the requested key, the error state should clearly indicate that the platform signing key could not be verified from the latest available keyset.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Reliability: launch validation must not depend solely on a previously warmed ETS entry when the platform JWKS endpoint is reachable.
- Security: Torus must continue validating signatures only against trusted HTTPS JWKS endpoints and must not relax signature verification rules to compensate for cache failures.
- Privacy: logs and telemetry must exclude raw JWTs, private key material, cookies, session contents, and other sensitive launch data.
- Performance: synchronous read-through refresh should only occur on cold cache or `kid` miss paths and should not materially slow healthy warm-cache launches.
- Maintainability: the cache contract should make it explicit when data came from warm cache versus a synchronous read-through refresh.
- Operability: support staff must be able to distinguish background refresh behavior from launch-path synchronous recovery behavior.

## 9. Data, Interfaces & Dependencies

- The work centers on `Oli.Lti.CachedKeyProvider`, `Oli.Lti.KeysetCache`, and `Oli.Lti.KeysetRefreshWorker`.
- The key input is the registration `key_set_url` and the JWT header `kid` supplied during LTI launch validation.
- Read-through behavior may require a synchronous fetch path that can populate `KeysetCache` and immediately retry key lookup during the same request.
- Existing asynchronous refresh remains a candidate for background warming and periodic maintenance, but it should no longer be the only recovery path for launch-time cache miss conditions.
- Any instrumentation should capture the requested `kid`, fetched key ids, cache age or freshness context when available, refresh path used, and terminal outcome using non-sensitive metadata only.

## 10. Repository & Platform Considerations

- Torus is a Phoenix application with LTI validation logic in Elixir, so reliability changes should stay at the server boundary rather than moving key resolution into frontend code.
- The current implementation uses ETS for fast in-memory reads and Oban for asynchronous refresh jobs; the PRD should preserve that context while correcting launch-time correctness behavior.
- Verification should focus on targeted ExUnit coverage for cold-cache launch success, `kid` rotation recovery, refresh failure handling, and truthful user-facing error behavior.
- Repository-local harness contract files such as `harness.yml` and the standard docs bundle were not present at intake, so this PRD relies on the repository guidance available in `AGENTS.md` and the existing LTI code structure.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Emit structured diagnostics for launch-time key lookup showing whether resolution came from warm cache, synchronous read-through refresh, or asynchronous background refresh state.
- Emit structured diagnostics when a requested `kid` is absent, including requested `kid`, cached key ids before refresh, fetched key ids after refresh when available, and final classification.
- Success signal: first launch from a valid registered LMS succeeds without requiring prior manual or scheduled cache warming.
- Success signal: a platform key rotation that introduces a new `kid` can recover during the same launch attempt when the fresh JWKS endpoint contains that key.
- Success signal: support can identify why a key lookup failed without remote shell access.

## 13. Risks & Mitigations

- Synchronous fetch on launch-path failures could add latency: restrict synchronous refresh to cold-cache and `kid`-miss paths, and keep warm-cache hits unchanged.
- JWKS endpoints can be temporarily unavailable: surface clear failure classifications and keep background refresh available for later warming.
- A fresh fetch may still return stale or incomplete platform data: log fetched key ids and freshness context so Torus can distinguish local cache issues from upstream LMS issues.
- User-facing messaging can drift from real behavior: align copy with the actual refresh path taken and whether recovery happened within the current request.

## 14. Open Questions & Assumptions
### Open Questions

- What exact production condition caused the stale or incomplete cached keyset for the affected Brightspace registration?
- Did the asynchronous refresh job fail to enqueue, fail to execute, retry unsuccessfully, or refresh to the same stale platform data?
- Should successful synchronous read-through refresh also enqueue or update a background refresh cadence, or is updating the current cache entry sufficient?
- Do we need explicit cache freshness metadata beyond `fetched_at` and `expires_at` to diagnose repeated `kid` misses over time?

### Assumptions

- The Brightspace JWKS endpoint is expected to be reachable over HTTPS during normal launch conditions.
- Manual `preload_keys/1` success is evidence that synchronous fetching can resolve at least some incidents that asynchronous scheduling does not recover quickly enough.
- Treating the keyset cache as read-through on miss is an acceptable tradeoff because those paths are exceptional and correctness is more important than avoiding a one-time network request.
- Existing ETS caching remains appropriate for warm-path performance as long as miss recovery is made reliable.

## 15. QA Plan

- Automated validation:
  - ExUnit coverage for launch-time cold-cache lookup that performs synchronous fetch and succeeds when the JWKS endpoint returns the requested key.
  - ExUnit coverage for cached keyset `kid` miss that performs synchronous refresh, updates cache contents, and succeeds when the refreshed JWKS contains the new key.
  - Regression coverage proving warm-cache hits do not perform unnecessary HTTP fetches.
  - Tests for unreachable JWKS URL, invalid JSON, invalid JWKS shape, and persistent post-refresh missing-`kid` failures.
  - Tests for truthful error messaging and diagnostics on each terminal failure class.
- Manual validation:
  - Verify first launch from a valid registration succeeds without preloading keys.
  - Simulate platform key rotation and verify a single affected launch can recover after a synchronous refresh.
  - Verify support-oriented logs and telemetry clearly show cache source, refresh action, and final outcome.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
