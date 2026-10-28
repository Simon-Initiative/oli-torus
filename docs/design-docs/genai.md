# Generative AI configuration and execution

Torus resolves a feature's section override, falling back to its global
`FeatureConfig`, to one `ServiceConfig`. Features include student dialogue,
instructor recommendations and instructor email. Sharing a ServiceConfig
intentionally shares its production transport pools on each application node.

## Configuration and administration

- **Provider** owns the configured adapter, endpoint template, encrypted API and
  organization credentials, administrative enablement and independent probe policy.
  It is a connection/availability boundary, not a vendor enum.
- **RegisteredModel** requires an explicit Provider ID and selects a model identifier, capabilities, a
  health-check candidate flag, connection timeout and response inactivity timeout.
- **ServiceConfig** selects distinct primary/secondary models on the same Provider
  and an optional backup on a different Provider, required capabilities, and one
  persisted pool capacity for each tier.

Authorized administrators use `/admin/gen_ai/providers`,
`/admin/gen_ai/registered_models`, and `/admin/gen_ai/service_configs`. Socket mounts
recheck authorization. Editing must be enabled before writes. Provider credentials
are write-only: blank retains a stored credential; explicit organization-key clearing
is separate. Errors never show raw provider responses or credentials. Model and
ServiceConfig forms replace the former shared-pool and breaker controls.

Provider administration displays administrative and observed state separately, the
selected probe model, last check/success, next check and safe diagnostics. Missing
configuration, disabled checks, unknown/stale health and actual unavailability are
distinct. ServiceConfig diagnostics display actual node-local checked-out occupancy,
configured capacity, queued checkouts and retiring pool generations. Runtime failure
is displayed as unavailable diagnostic information, never invented healthy state.

## Independent availability

Only tiny synthetic inference probes update observed Provider availability.
Ordinary duration, errors, cancellation, checkout contention and administrative tests
never change health. Lowest-ID flagged model is selected; if no model is flagged,
the lowest-ID model is automatically flagged transactionally. Multiple flags are
allowed. No-model and incomplete-credential states are explicit configuration errors.

Default policy is one probe every 180,000 ms (including recovery), 30,000 ms after a
first suspected failure, a 10,000 ms probe deadline, three consecutive failures to
mark unavailable, and two consecutive successes to recover. Schedules are jittered,
start immediately, run from completion and permit one in-flight probe per Provider,
with four concurrent probes per node. Probes have separate transport capacity.
Structurally valid unknown health is initially eligible. Previously available health
is stale after two regular intervals plus deadline and locally ineligible until
fresh evidence; staleness does not fabricate a synthetic outage.

`GENAI_HEALTH_CHECKS_ENABLED=false` disables probes and observed-health gating on that
node. Administrative disablement and all production capacity limits still apply.
Restart after environment changes; re-enabling starts unknown and probes immediately.
See `docs/OPERATIONS.md` for environment overrides, rollout and rollback.

## Pool capacity and best-effort routing

Actual transport pools are the sole capacity authority, keyed by
`(service_config_id, tier)` on each node. Different ServiceConfigs have independent
pools even for the same RegisteredModel. Primary, secondary and backup are isolated.
No application request counters, admission leases or atomic reservations are used.

When main is eligible, inspect primary checked-out occupancy. If it appears full,
inspect secondary; when both appear full or secondary is absent, return busy.
Observed main unavailability or administrative disablement may select eligible backup
if its pool appears available. Backup is not capacity overflow.

Observation and checkout are deliberately non-atomic: simultaneous requests can both
select primary, secondary can be selected just as primary frees, and busy can race a
newly available connection. The transport enforces its actual limit. Checkout waiting
is bounded at 1,000 ms; expiry is local busy without health mutation, secondary
reselection or backup failover. Model connection timeout (default 8,000 ms), response
inactivity timeout (default 60,000 ms), and a total 300,000 ms inference deadline are
separate budgets. Both attempts share the original total deadline.

For verified Hackney 1.25.0 HTTP/1.1, capacity means **Maximum checked-out
connections**, with an inference retaining its checkout during stream consumption.
A connection count does not bound requests on multiplexed transports. Such adapters
need equivalent request/stream capacity and verification before support is claimed.
Claude transport is unsupported. Routing and administrative calls return an explicit
unsupported-adapter error rather than invoking the old Anthropix implementation.
Null completions require a resolved null Provider; OpenAI completions require the
selected managed transport pool. Calls without transport context fail explicitly.

Every node reconciles configuration on committed invalidations and periodic reload.
Routing reads protected configuration snapshots without database queries or waiting
behind reloads; it reads actual pool occupancy rather than caching a counter.
Credential/model/endpoint changes invalidate stale selections. Resize uses an
immediate new generation, with old started/queued work finishing under its existing
budgets. Temporary combined occupancy above the new capacity is intentional. Old
generations stay visible until their actual checkouts, queues and startups clear;
restart adopts surviving generations. In-place Hackney shrinking is not used.

## Execution, streaming and administrative calls

`Router` creates a selection plan, `Execution` owns request deadline and retry
boundaries, and `Completions` passes exact context to `ManagedOpenAI`. The adapter
uses Provider credentials and the chosen real pool in sync and streaming modes.
At most one distinct eligible backup attempt is allowed for connection failures,
pre-output inactivity, and HTTP 500/502/503/504. Generic 429, invalid input/protocol,
application errors, cancellation and local contention do not trigger retry.
Once any content/tool fragment is exposed, failure is an interrupted stream.

SSE requires terminal completion, handles errors/truncation, bounds incomplete and
complete events, ignores null role content, and retains content arriving with finish.
Normal/error exits close connections. Owner monitoring and an independent deadline
guardian reclaim transport even on cancellation, `:kill`, or a blocked callback;
caller callbacks must themselves return for control to return to that caller.
Dialogue discards partial assistant/tool state on a final returned error and tags
engagements to ignore stale replies.

`Administrative.generate/4` uses normal production selection when a ServiceConfig
is supplied. Without one, it uses explicit administrative transport capacity of four
per Provider/resolved origin/node. It shares bounded Execution ownership/deadlines
but never retries an administrative attempt as production backup. UI test calls run
asynchronously with a 10,000 ms total budget and render a safe success/category only.

## Observability and compatibility

AppSignal receives independent probe outcomes/transitions, reconciliation duration,
request outcomes/duration/first output/interruption/cancellation/backup, routing
selections/busy rejection, actual occupancy/capacity/queue depth, checkout causes and
pool lifecycle/cleanup events. Raw identifier-bearing telemetry preserves tier/node
context; metric tags use bounded categories. No prompts, URLs, credentials or raw
provider error bodies are emitted by these signals.

Hackney's public connect operation combines checkout and TCP/TLS establishment.
`pool.startup_ms` is explicitly combined timing, not pure queue wait. Native checkout
timeouts separately report an elapsed upper bound through checkout timeout; causes
distinguish timeout, owner cancellation, startup deadline and transport failure.
Pure successful per-request checkout wait is not exposed by this installed API.

Legacy admission/breaker services are no longer supervised and old control/metric
wiring is retired. Old admission/breaker modules and model routing-policy columns
remain, but have no authority over managed production requests. Model connection
settings and direct legacy adapter execution have been removed. The primary-only
override is removed. See the operational runbook before cutover: the single-Provider
migration cannot automatically represent heterogeneous legacy endpoints or repair
same-Provider backup relationships.

Implementation and dependency evidence:
`docs/exec-plans/current/features/genai-redesign/plan.md`,
`docs/exec-plans/current/features/genai-redesign/design/transport-evidence.md`, and
`docs/exec-plans/current/features/genai-redesign/design/phase-3-execution.md`.
