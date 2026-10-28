# Phase 2 runtime and rollout contract

Phase 2 adds configuration, independent probes and transport reconciliation in
observe-only mode. `Runtime.snapshot/0` reports `observe_only: true`; existing
Router/Execution calls still use the legacy model credentials, pools and breakers.
Provider-health routing, request-level fallback and production use of the new tier
transport are Phase 3. Administration and operational dashboards remain Phase 4.

Phase 3 supersedes this version-specific observe-only state; see
`docs/exec-plans/current/features/genai-redesign/design/phase-3-execution.md`.

## Persistence and compatibility

The generated migration creates one **OpenAI production** Provider, following the
latest explicit FDD decision. It copies the first keyed model's encrypted key,
secondary/organization key and endpoint, ordered by model ID, and associates every
existing model with that Provider. A missing key remains missing; it is not replaced
with a fabricated credential. The lowest-ID model is flagged for probes. The migration
is tested with real ciphertext and heterogeneous legacy endpoints and adapters.

Model `configured_provider` uses `provider_id`, preserving the existing `provider`
adapter enum until execution cutover. Legacy keys and endpoints are retained, so
heterogeneous existing request configurations and rollback continue to work. Provider
credential edits currently affect independent probes; ordinary requests retain their
legacy configuration until Phase 3. New Provider-backed model creation derives transitional connection copies automatically, so new clients need not duplicate credentials in input. Do not remove or overwrite existing legacy connection fields during this observe-only phase.

Capacities are persisted on ServiceConfig, initially 100 per tier rather than copied
from every selected model. These are initial defaults requiring allocation review,
not production sizing advice. Configured tiers have pools; absent tiers do not.
`capabilities` and `required_capabilities` are explicit string lists, including empty
lists. Context validation enforces distinct same-Provider primary/secondary, different
backup Provider, required capabilities, and positive non-null capacities.

Existing migrated backup relationships or unassociated raw legacy inserts can fail
those new rules. `Configuration.audit_service_config/1` and runtime snapshot
`service_config_issues` expose repair needs without changing existing request routing.
Provider deletion is restricted while models reference it. Existing incomplete
Providers can be administratively disabled without first supplying keys; enabling
requires valid endpoint and credential settings.

Rollback removes the additive columns and Provider table while preserving original
legacy model data. New Provider records and Provider-only edits made after migration
would be discarded by rollback; export/reconcile those edits before an operational
rollback. Stop the new runtime before rolling schema back or starting old binaries.
The migration/rollback tests use isolated schemas and do not roll back the application's
live schema.

## Configuration consistency

Use the GenAI context for writes. Configuration edits and probe designation share a
PostgreSQL transaction-level advisory lock across nodes, with Provider row locking
for individual designation operations. Flag edits, moves and deletion reconcile both
affected Providers in the same transaction. Multiple flags remain legal; the lowest-ID
flagged model wins. With no flags, the lowest-ID model is persisted as flagged.

Normal context transactions publish a payload-free PubSub invalidation after commit.
Calls nested within a caller-owned transaction do not publish prematurely; the
30-second durable reload repairs them and any missed notification. Each reload uses
batched Provider/model/configuration queries and one fallback flag update, independent
of Provider count. It omits legacy model credentials from the runtime projection.
When monitoring is disabled, reload does not change probe flags merely due to the
override. Explicit configuration edits retain the normal designation invariant.

Each serving application node starts `RuntimeSupervisor`, its bounded probe task
supervisor, `PoolManager` and `Runtime`. Tests start owned instances explicitly to
avoid background database polling or vendor requests from unrelated sandbox tests.
Two independent runtime instances are tested against the same database and through
missed-invalidation reload; the database-lock race test uses separate connections.

## Transport lifecycle

`PoolManager` owns logical pool coordinators, including `(service_config_id, tier)`,
`{:probe, provider_id}`, and an explicit administrative pool per Provider/resolved
origin. Administrative capacity is four per origin per node; the key hashes the
origin instead of placing endpoint credentials in telemetry metadata.

Each `TransportPool` creates atom-free uniquely identified native generations.
Capacity, model, Provider version or endpoint changes create and select a replacement
without stopping existing work. Retiring generations remain observable until checked-out
occupancy, native checkout queues and startup work are gone. Capacity overlap is
accepted. Surviving native pools are adopted for retirement after coordinator restart.
One resolved HTTP origin is enforced per generation. Endpoint templates use the same
realization as the existing OpenAI adapter.

Only a checked-out single-use request reference leaves `TransportPool.connect/3`.
Connection workers perform blocking network startup while the coordinator remains
responsive to replacement, cancellation and diagnostic calls. A finite per-call timer
bounds the total connect-plus-checkout budget; native checkout is separately bounded
(initially 1,000 ms). Brief startup records and monitors protect handoff and retirement;
they are not admission leases, do not bound request-task counts, and are never read
for capacity-based routing. They are discarded at handoff. Actual stream occupancy
and release remain entirely in Hackney.

A guardian keeps an unclaimed transferred connection safe until the caller acknowledges
it. Coordinator death before claim closes the connection even if the caller remains
alive. Caller death cancels queued startup; cancelled workers must actually terminate
before their generation can retire. The transport must be used for one request and
closed on every exit path. Future Phase 3 callers must use this logical startup API;
they must not initiate HTTP calls using physical names copied from snapshots.

## Monitoring and safe diagnostics

There is one monitor and at most one active probe per Provider per node. Only synthetic
probe results change observed availability. Ordinary request outcomes have no input
into these monitors. Probes use Provider keys, shared OpenAI endpoint/header/request
construction, a fixed tiny prompt, bounded output and a bounded response body. They
require a complete valid response rather than particular generated wording. Separate
probe pools remain usable under production saturation, including during reconciliation.

A dedicated total deadline kills stuck network work; monitor configuration changes
cancel obsolete probes and reject old results and timers. Killing the monitor also
terminates its network task. Probe-task capacity exhaustion, local pool busy and local
pool unavailability do not manufacture an upstream outage. Safe snapshots distinguish
missing models, invalid configuration, disabled checks and administrative disablement.

Unknown health initially permits pool-limited traffic in the proposed Phase 3 policy.
A previously available observation becomes stale after two regular intervals plus the
probe deadline without a completed check; snapshots mark it stale and ineligible rather
than leaving it permanently available. This only computes operational status; it does
not fabricate a failed probe. Environment changes take effect at node restart.

| Startup environment variable | Default |
| --- | ---: |
| `GENAI_HEALTH_CHECKS_ENABLED` | `true` |
| `GENAI_PROBE_INTERVAL_MS` | 180000 |
| `GENAI_PROBE_FAILURE_INTERVAL_MS` | 30000 |
| `GENAI_PROBE_DEADLINE_MS` | 10000 |
| `GENAI_PROBE_FAILURE_THRESHOLD` | 3 |
| `GENAI_PROBE_RECOVERY_THRESHOLD` | 2 |
| `GENAI_MAX_CONCURRENT_PROBES` | 4 |

Persisted optional Provider policy fields override these timing/threshold defaults.
Schedules run from completion with jitter and no overlapping probes. After a failed
check the failure interval applies until unavailable; unavailable recovery uses the
regular interval. A successful check while available resets failure evidence; recovery
from unavailable requires the configured consecutive successes.

Telemetry includes health probe duration/outcome/category, health state transitions,
monitor errors, reconciliation duration/counts, checkout duration/outcome and pool
lifecycle events. Tests assert safe event contracts and absence of credentials and
raw response errors. AppSignal dashboards and admin display integration are Phase 4.
Claude/Anthropic transport changes and runtime verification remain explicitly deferred;
no Hackney isolation or health-probe guarantee is asserted for that adapter.
