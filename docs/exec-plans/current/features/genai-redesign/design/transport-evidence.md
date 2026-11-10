# Phase 1 transport evidence and execution contract

Phase 1 is complete for the Hackney/OpenAI path. Provider schema and node-local pool
reconciliation are Phase 2; routing to persisted tier pools is Phase 3. This record
settles their transport contract and records the installed-version evidence, rather
than claiming that those later-phase components already exist. Claude/Anthropic
implementation and runtime verification are deferred by the explicit instruction
in the FDD; no Hackney guarantees in this record apply to Claude.

Versions from `mix.lock`: Hackney 1.25.0, HTTPoison 2.2.3, Anthropix 0.6.2,
Req 0.5.16, Finch 0.20.0. Recheck evidence when dependencies, adapter call paths,
or transport options change.

## Verified Hackney behavior

`test/oli/gen_ai/transport_pool_semantics_test.exs` runs real HTTP/1.1 requests
against a loopback server without upstream credentials or API calls:

| Concern | Evidence and decision |
| --- | --- |
| Occupancy | `get_stats/1`'s `in_use_count` counts checked-out connections, including incomplete streamed bodies. `free_count` and `count/1` count retained idle sockets, not active requests. |
| Capacity | At a fixed limit and one origin, additional requests queue; reuse of an idle same-origin connection retains the expected bound. |
| Multiple origins | The installed pool reuses an idle socket before checking the active limit. The test using `localhost` and `127.0.0.1` as distinct origins reproduces occupancy above the limit. Keep each tier generation tied to one origin; use a new generation for origin changes and prohibit redirect/proxy behavior that shares one pool across destination origins. |
| Checkout timeout | An explicit finite `checkout_timeout` returns `:checkout_timeout`; the pending checkout is eventually removed. It is separate from connection and response timeouts. |
| Pending caller death | Killing a queued caller removes its pending checkout. |
| Stream lifetime | Both raw Hackney body consumption and the actual `OpenAICompliantProvider.stream/4` retain checkout while the response is incomplete. |
| Completion | Full SSE token and completion events flow through the OpenAI adapter, then occupancy returns to baseline. |
| Cancellation | `stop_async/1` alone retains checkout in a living caller. Explicit `close/1` releases it. The adapter finalizer now does both; its regression test throws from the response consumer and keeps the caller alive while checking reclamation. |
| Process death | Killing the raw response caller, the HTTPoison async owner, or the full OpenAI SSE caller eventually reclaims checkout. |
| In-place shrink | With two active requests and a pending third, lowering the limit to one still starts the waiter when one active request finishes. Do not use in-place resizing. |
| Replacement and isolation | An independent new pool accepts work while the old pool is occupied. The new pool enforces its own capacity and removes timed-out waiters. Combined occupancy intentionally exceeds the new capacity. After old work finishes, stopping the drained old pool does not disrupt the active replacement request. |

These are controlled dependency/adapter tests, not proof of all interleavings or a
production load benchmark. Later reconciliation and routing tests must exercise
the actual configured tier integration, process restarts, repeated replacements,
and endpoint changes.

## Immediate replacement policy

On capacity or endpoint change, create a uniquely identified pool generation with
the desired capacity and publish it as current only after successful creation.
New selections use it immediately. Old checked-out requests and already-pending
checkouts may finish or time out, and a request that selected the old generation
just before publication may still use it. Temporary combined capacity above the
new setting is explicitly accepted; do not subtract old occupancy from new capacity.
Do not kill old work to enforce a lower combined count or pause the tier to drain.

Keep every retiring generation visible with its actual checked-out and queued
statistics. Retire a generation only when its checkouts and waiters have cleared
and request startup can no longer use it. A single empty snapshot does not prove
this: Hackney automatically creates a missing named pool on a later checkout.

The Phase 2/3 integration must use a transport-start lifecycle fence: resolve the
current generation at request start and coordinate generation retirement with that
startup boundary. A stale routing plan must refresh its transport before beginning
HTTP I/O, or fail locally as busy if its generation has been retired. Never allow
an old plan to recreate a retired pool with Hackney defaults. The fence protects
pool lifecycle, not capacity; it must not span stream consumption or introduce
application admission counters, leases, or a bounded request-task registry.
Implementation and integration tests for this fence belong with the pool manager
and adapter option plumbing in Phases 2 and 3. Retain failed-retirement state and
emit an operational error rather than dropping visibility of an active pool.

## Execution contract

- Logical production identity is `(service_config_id, tier)`; physical pools also
  have a unique generation. Distinct ServiceConfigs, primary, secondary, backup,
  probes and administrative transport remain isolated. Do not allocate unbounded
  permanent BEAM atoms from ServiceConfig IDs or generation numbers.
- Transport context includes logical identity, generation, one configured origin,
  and checkout timeout. Both generate and stream must actually use the selected
  pool; the model-derived pool in today's adapter will be replaced in Phase 3.
- Use a **1,000 ms checkout timeout** initially. This is a finite implementation
  default, separately configurable from connect, receive inactivity and total
  inference budgets. Tune from checkout-wait telemetry rather than calling zero
  timeout atomic. The verification tests use shorter timeouts to exercise waiting.
- Map `:checkout_timeout` to local busy. Do not mutate Provider health, try secondary
  again after timeout, or trigger backup from contention. Those routing/error
  changes are Phase 3 work; no new timeout is enabled in the legacy router here.
- Use an explicit administrative pool without ServiceConfig context, initially
  capacity four per resolved origin per node. Probe pools remain separate, with one inference in flight
  per Provider monitor; production limits cannot prevent probing.
- Bound complete requests and SDK retries in Phase 3 so abandoned retiring work
  cannot survive indefinitely. A stuck retirement stays visible and alerts; do not
  silently close active work or discard accounting.

## Claude limitation and deferral

The current Claude adapter passes only receive timeout to Anthropix; it does not
select an isolated Finch instance. Anthropix forwards options to Req; Finch HTTP/1
has pool size and optional `in_use_connections` metrics. Those are source-level
capabilities, not runtime verification of the existing Claude adapter. Finch HTTP/2
multiplexing cannot be bounded by socket count alone. Anthropix also has separate
task ownership, a 30-second stream wait and filtered SSE events.

Per the FDD's explicit instruction, leave Claude implementation unchanged and carry
this as a documented limitation for future work. Do not claim that Hackney pool
creation isolates Claude, or enable a Claude pool-only guarantee without separate
verification. This deferred limitation is not a blocker to Phase 1 closure for the
Hackney/OpenAI path.
