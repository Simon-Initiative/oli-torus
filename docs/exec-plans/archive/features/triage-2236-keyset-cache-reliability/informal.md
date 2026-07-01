# Informal Work Summary: TRIAGE-2236 LTI Keyset Cache Reliability

## Incident

This work item captures a production incident where a small subset of instructors and students could not access Torus from Brightspace.

- Ticket: `TRIAGE-2236`
- Title: `Torus link fails to connect users`
- Status at intake: `IN PROGRESS`
- Affected platform keyset URL:
  `[redacted Brightspace JWKS URL]`

Observed behavior:

- Torus rejected some launches because the JWT `kid` was not present in the cached keyset.
- The runtime error indicated that Torus would trigger a keyset refresh, but the issue persisted for multiple days.
- The incident was only resolved after manually connecting to the production IEx shell and forcing a refresh:

```elixir
Oli.Lti.CachedKeyProvider.preload_keys("[redacted Brightspace JWKS URL]")
```

## Current implementation behavior

The current LTI key provider uses an ETS-backed cache and treats launch-time cache misses as fail-fast conditions:

- if the keyset is not cached, launch validation fails and an Oban refresh job is scheduled
- if the keyset is cached but the requested `kid` is missing, launch validation fails and an Oban refresh job is scheduled
- synchronous fetching is only used by `preload_keys/1`, which is currently an operational/manual recovery path

This means the user-facing error text promises an immediate recovery path, but the launch itself does not wait for that refresh to complete. If the refresh job is delayed, not executed, fails repeatedly, or refreshes to the same stale data, affected launches continue to fail.

## Problem to solve

We need to determine why the `kid` was missing from the cached keyset and why the refresh path did not recover automatically in production. If the root cause cannot be pinned down with confidence, we still need a reliable product behavior that prevents the same class of outage.

The preferred safety behavior is to treat the JWKS cache as a read-through cache:

- on cold cache, synchronously fetch the keyset before failing due to keyset retrieval
- on `kid` miss in cached data, synchronously refresh the keyset from the keyset URL before failing due to key lookup
- if that read-through attempt still fails, surface the actual error that occurred, such as:
  - the JWKS URL could not be reached
  - the keyset could not be loaded or parsed
  - the requested `kid` is still absent from the freshly fetched keyset

## Why this matters

This incident affects both reliability and first-use experience:

- it can block valid instructors and students from entering Torus
- it makes launch recovery depend on delayed background execution or manual operator intervention
- it causes the first launch from a newly registered LMS to fail when the keyset has not been pre-cached yet

The desired end state is that LTI key validation behaves predictably for both warm-cache and cold-cache cases, with clear diagnostics when the platform keyset itself is unavailable or invalid.
