# GenAI provider health and routing redesign — informal design

## Purpose and status

Restore dynamic GenAI routing by separating provider availability, ServiceConfig-tier capacity,
and request execution. Replace the current per-model, workload-driven breakers with
first-class Providers whose availability is determined by independent health probes.

This document captures the investigation and proposed design discussed on
2026-10-06. It is design input, not an implementation specification or a record of
completed changes. Timing values and unresolved policies below are proposals to
validate. No production code or runtime configuration was changed during the
investigation.

## Intended behavior

- Primary and secondary models must belong to the same configured Provider.
- Primary is generally more capable and slower; secondary is cheaper and faster.
- Prefer primary whenever its pool appears to have capacity.
- Select secondary when primary appears full and secondary appears to have capacity.
- If both are full, reject promptly as busy instead of waiting indefinitely or using
  backup as another overflow tier.
- Backup belongs to a different Provider and serves main-provider unavailability.
- Backup has its own bounded capacity and provider-health check.
- Each configured ServiceConfig tier owns one persisted pool capacity setting and one
  isolated production transport pool per application node. Capacity is not shared across
  different ServiceConfigs, even when they select the same RegisteredModel.
- Long, healthy responses must not cause provider failover merely because they take
  time to complete.
- Availability recovery must happen independently of user traffic, and will be driven solely by the health status checks.

## Investigation findings

The current implementation is rooted in `lib/oli/gen_ai/router.ex`, with execution
in `lib/oli/gen_ai/execution.ex`, health state in `lib/oli/gen_ai/breaker.ex`, counters
in `lib/oli/gen_ai/admission_control.ex`, and transport pools in
`lib/oli/gen_ai/hackney_pool.ex`.

The strongest code-level explanation for premature opening is normal long responses
tripping the latency threshold, compounded by broken recovery. Actual HTTP timeouts
are not required. Production logs and deployed model settings were not inspected,
so this is not a definitive reconstruction of the original production incident.

### Successful streams can open a breaker

Execution measures the entire streaming operation, including stream consumption and
response callbacks. The default breaker latency threshold is 6,000 milliseconds.
The breaker immediately evaluates its rolling p95 without a minimum sample count.
On the first completion, p95 is simply that request's duration. A successful
six-second response can therefore open a fresh breaker even when tokens arrive
steadily. Increasing HTTP receive timeouts does not fix this mismatch.

### Open breakers can remain open indefinitely

Cooldown expiry is processed only on a completion report or `Breaker.status/1`.
There is no timer to initiate recovery. The router calls `Breaker.snapshot/1`,
which only reads ETS and does not advance state. Once outstanding requests finish,
an open model receives no further traffic or reports to trigger recovery.

Existing recovery tests call `Breaker.status/1` and thus perform the transition
themselves. No production callers of that function were found under `lib/`.

### A single failure can open a fresh breaker

One error gives a 100% error rate against the default 20% threshold. There is no
minimum evidence requirement. The window retains the last 50 completions without
time-based expiry. Returned errors are not filtered to distinguish outages from bad
requests or application failures. Sharing this existing signal across models would
increase its impact rather than fix it.

### Half-open does not bound probes

The router blocks only the `:open` state. During `:half_open`, ordinary traffic is
admitted up to normal capacity limits. `half_open_remaining` counts successful
completions needed for recovery; it does not reserve or limit probe admissions.
Older in-flight requests can also be interpreted as recovery probes.

### Cancelled streams leak capacity

Dialogue cancellation in `lib/oli/gen_ai/dialogue/server.ex` kills the streaming
task with `Process.exit(pid, :kill)`. Execution releases admission counters in that
task's `try/after`, which cannot run after an untrappable kill. Repeated cancellations
can leave application model and shared-pool counters permanently occupied until
state is reset. This counter leak does not establish whether the actual transport
connection is reclaimed; that behavior requires separate verification.

### Health controls and capacity controls are coupled

Disabling all model breaker thresholds also disables its concurrency limit. Execution
still releases the model counter afterward even though admission did not increment
it. The primary-only switch bypasses both breaker checks and application admission,
so its apparent success can hide either health-state defects or capacity leaks.
Execution continues reporting breaker outcomes while the switch is enabled.

### Transport pools do not represent routing failure domains

All models share one of two global Hackney pools, fast or slow. Primary and secondary
cannot overflow on pool exhaustion if they share the exhausted pool. Backup can also
be blocked by outstanding main-provider requests when it shares their pool.

The Claude adapter uses Anthropix/Req/Finch rather than the Hackney transport used by
the OpenAI-compatible adapter. Pool isolation and capacity semantics must therefore
be established for each adapter's actual transport; creating a Hackney pool alone
does not isolate Claude requests.

### Current execution does not retry on backup

Despite the name `execute_with_fallback`, execution makes one selected-model call.
A failure affects subsequent routing but does not retry that request on backup.
An existing execution test explicitly asserts this behavior.

### Streaming adapters need correction

The installed Anthropix dependency has a hard-coded 30-second stream inactivity
cutoff that halts its stream. It also filters out SSE `error` and `ping` events.
The Claude wrapper can consequently report success for an incomplete stream.
Changing RegisteredModel receive timeouts alone does not remove that dependency
cutoff. Errors that raise during stream enumeration can also bypass normal outcome
reporting.

Anthropic documents in-stream errors, including overload errors, so HTTP status
handling alone is insufficient. Adapter completion/error semantics must be reliable
for both real requests and synthetic probes.

### Verification performed

- Ran 60 existing focused tests covering breaker, router, execution, admission, and
  the OpenAI-compatible provider: all passed.
- Ran five temporary isolated reproductions: all confirmed the asserted current
  behavior—one successful six-second completion opens a breaker; one bad-request
  error opens a fresh breaker; expired cooldown stays open on the router snapshot
  path; half-open admits more requests than its remaining probe count; killing a
  streaming task leaks admission slots.
- Reproduction tests and logs were temporary investigation artifacts, not durable
  repository regression coverage. Implementation must add permanent regression tests.

## Proposed domain model

### Provider: configured connection and availability boundary

Introduce a first-class Provider referenced by every RegisteredModel. A Provider
represents a configured connection such as "OpenAI production account" or
"Anthropic production," not merely a vendor enum.

Separate these concepts:

- Vendor identity: the upstream vendor, relevant to genuinely independent backup.
- Adapter type: the API protocol/implementation used to communicate with it.
- Provider record: endpoint, credentials, account/project/region context, and shared
  availability state for models using that connection.

The current `:open_ai` value means OpenAI-compatible protocol and can represent
different vendors. It is not a sufficient provider identity. Multiple Provider
records may be useful for different accounts, endpoints, projects, or regions of
the same vendor.

Provider should own:

- Display name
- Adapter type, for example OpenAI-compatible or Anthropic.
- Base URL or equivalent provider connection configuration.
- Encrypted API credentials and provider-specific credential/header settings.
- Organization/project settings and region context where applicable.
- Health-check model selection from its RegisteredModels' `health_check` flags,
  using the deterministic selection and automatic fallback described below.
- Probe interval, deadline, and availability/recovery policy.

Move API keys off RegisteredModel. Map existing secondary credential fields to their
actual provider-specific purpose instead of assuming every adapter uses a second
API key in the same way. Centralize credential rotation and connection validation.

### RegisteredModel: reusable inference configuration

RegisteredModel should retain:

- Provider reference.
- Model identifier and display name.
- Model capabilities and generation-specific settings.
- Model-specific request budgets/timeouts where needed.

Add `health_check`, a boolean attribute defaulting to `false`. It is an editable
field in the RegisteredModel UI and controls selection for its Provider's health
probes. It does not change the model's eligibility for ordinary ServiceConfig use.

Pool capacity settings and production pool ownership belong to the ServiceConfig tier
that selects the model. A RegisteredModel can serve different roles and receive
different capacity allocations in different ServiceConfigs.

Do not move every timeout to Provider: a long-running reasoning model and a fast
model can legitimately require different request budgets. Provider probe deadlines
are separate from normal inference timeouts.

Remove per-model breaker thresholds, rolling health windows, and half-open controls.

### Provider health-check model selection

The Provider health monitor uses the first RegisteredModel belonging to that Provider
whose `health_check` attribute is `true`. Define "first" deterministically as the
lowest RegisteredModel ID; do not rely on unspecified database result ordering.

If every RegisteredModel for the Provider has `health_check = false`, the system
sets `health_check = true` on the first RegisteredModel for that Provider, persists
that change, and uses that model for health probes. This is an automatic designation,
not merely an in-memory fallback. If multiple models are flagged, use the first
flagged model; the flag is not required to be unique within a Provider.

Reconcile selection when flags or Provider membership change, or when a selected
model is deleted. Apply the same automatic designation rule if no flagged models
remain. Clearing all flags therefore does not disable Provider health monitoring.
Coordinate fallback designation safely across nodes so concurrent reconciliation
does not override an administrator's newer selection. A Provider without any
RegisteredModels has no model to designate and cannot perform an inference probe;
surface that configuration state without fabricating a successful health check.

### ServiceConfig: routing preferences and pool capacity

ServiceConfig continues selecting primary, secondary, and backup models. Preserve
existing feature resolution and section overrides.

Each configured primary, secondary, or backup selection owns one persisted capacity
setting that configures one isolated production transport pool per application node.
Pool identity is `(service_config_id, tier)`. A ServiceConfig has up to three
production pools; an unconfigured tier needs none. Pool identity follows the
ServiceConfig tier rather than the model's name or RegisteredModel ID.

For example, the same GPT-5 RegisteredModel can be DOT's primary with a pool capacity
of 100 and instructor recommendations' secondary with a pool capacity of 200:

| ServiceConfig | Tier | Model | Pool capacity per node |
|---|---|---|---:|
| DOT | Primary | GPT-5 | 100 |
| DOT | Secondary | Faster model | 1,000 |
| Instructor recommendations | Primary | More powerful model | 50 |
| Instructor recommendations | Secondary | GPT-5 | 200 |

DOT's primary appearing full selects DOT's secondary without consuming the GPT-5
pool allocated to instructor recommendations. Values are illustrative, not verified
sizing recommendations.

For Hackney's connection-based implementation, use the admin label "Maximum
checked-out connections" or "Pool capacity." This is not a transport-independent
maximum concurrent inference request limit. For HTTP/1.1 streaming, verify that one
active inference occupies one checked-out connection throughout stream consumption.
For multiplexed transports, connection count alone does not bound concurrent
requests; the transport must support equivalent request or stream capacity, or the
design must explicitly acknowledge different semantics. Do not expose separate
application admission or model capacity settings.

Validate:

- Primary and secondary are distinct models on the same Provider.
- Backup references a different Provider.
- Backup meets the intended different-vendor/failure-domain requirement; merely
  selecting a second connection record for the same vendor may not satisfy it.
- Required model capabilities are compatible with the feature using the config.

## Independent provider health monitoring

### Global environment override

Add `GENAI_HEALTH_CHECKS_ENABLED`, defaulting to `true`. Setting it to `false`
disables all GenAI Provider health checks on the application node, including initial,
recurring, and recovery probes. Apply the variable to every node to disable checks
deployment-wide.

While disabled, bypass observed Provider-health gating so stale or previously
unavailable health state cannot block normal routing. Continue respecting Provider
administrative disablement, ServiceConfig-tier pool capacities, pool isolation,
and request-level error/fallback policy. This override must not recreate the old
primary-only bypass: primary-to-secondary capacity overflow remains active.

Show health monitoring as disabled in operational state rather than presenting
Providers as successfully checked. Do not mark failed probes successful or mutate
RegisteredModel `health_check` flags merely because the override is active. After
checks are re-enabled, start with unknown observed health and schedule an immediate
probe under the normal startup policy. Environment changes take effect on node
restart unless runtime reload support is explicitly implemented.

Each Provider has one health-monitor/breaker implementation. Normal completions do
not directly update its availability state. Slow responses, invalid user prompts,
cancellations, and application parsing errors cannot open it.

The monitor schedules a small real inference request against the RegisteredModel
selected by the `health_check` rule above. A generic reachability request, model-list endpoint, or
public vendor status page is not an adequate substitute for exercising inference
with the configured endpoint and credentials.

### Probe contract

- Use the same Provider endpoint, credentials, and adapter as ordinary traffic.
- Use a fixed tiny prompt and bounded output; no user content is needed.
- Verify successful protocol completion, not an exact generated sentence.
- Use a dedicated deadline suitable for the chosen health-check model.
- Do not route probes through normal fallback. A backup success must not mark the
  original Provider healthy.
- Have at most one probe in flight per Provider per monitoring node.
- Run network work in a monitored task; keep the coordinating process responsive.
- Handle task exit, deadline expiry, and cleanup explicitly.
- Handle all vendor specific error messages, capturing that information in a way
  that surfaces up eventually to a UI so that Admins can see things like
  "OpenAI provider is failing because we have run out of money" or
  "Anthropic is failing due to service unavailability"
- Ensure stale results from replaced credentials/configuration or older probes cannot
  overwrite current health state.

Validate the health-check configuration when saved, including credentials and model
access. Changing or retiring the selected model must not silently invalidate the
monitor.

### State and recovery

Use a smaller state machine:

```text
Unknown -- initial probe evidence --> Available or Unavailable

Available -- repeated failed probes --> Unavailable
Unavailable -- repeated successful probes --> Available
```

Probing continues regardless of availability and user traffic. User requests never
serve as half-open probes, so no user-admission probe budget is needed.

Initial tuning proposal consists of two different probing schedules.  One for regular
health monitoring and recovery, and a more aggressive schedule during determination of unavailability.

- Probe every 3 minutes.  The 3 minutes is a default value but is overridable via runtime environment variable.  This is the regular heath monitoring and also the recovery schedule.
- After a first failed probe, probe every 30 seconds.  The 30 seconds is default value but overridable via runtime environment variable. This is the schedule for determiniation of unavailability.
- Mark unavailable after 3 consecutive failed probes.  The 3 is a default value but overridable via runtime environment variable.
- After marked unavailable, go back to the regular, recovery schedule and probe every 3 minutes.
- Restore availability after 2 consecutive successful probes. The 2 value is a default but overridable via runtime environment variable.

Detection latency includes scheduling intervals and probe deadlines. Define whether
intervals are measured from probe start or completion; prevent overlap either way.
Use distinct failure and recovery thresholds to limit flapping.

Track last completed check, last success, next scheduled check, consecutive results,
and a safe failure category. Distinguish invalid probe configuration from observed
provider unavailability in operational state and presentation.

Recommended startup policy: schedule an immediate first probe and allow bounded
normal traffic while health is unknown. Define stale-health behavior explicitly so
a failed monitor cannot leave the Provider permanently marked available. The exact
staleness cutoff and routing policy remain open.

### Scope and deployment

Start with per-application-node monitors and health state, matching node-local
transport pools. This tests connectivity from the node making requests and avoids
introducing cluster leadership or consensus.

Consequences:

- Probe volume and cost multiply by active node count and Provider count.
- Nodes may legitimately disagree due to local connectivity failures.
- Add scheduling jitter and cap concurrent probes.
- Account for node count when sizing pool capacity; per-node limits do not enforce
  global upstream request or token quotas.

Only introduce shared/leader-based probing if operational scale warrants it and the
loss of node-local connectivity evidence is addressed.

## Deliberate limitations of synthetic probing

A successful probe establishes that one representative inference request succeeded.
It does not prove every model, capability, request size, or quota at the Provider is
healthy.

- A cheap health-check model can work while primary fails or is throttled.
- A health-check model can fail or be retired while production models still work.
- Model/model-group rate limits can differ; 429s are not automatically evidence of a
  provider-wide outage.
- A short request does not prove long streams will remain healthy.
- Scheduled checks introduce an outage detection interval.

Accept these limitations for the stated goal of broad provider-outage detection.
Keep real-request failures, stalls, and durations visible through telemetry without
reintroducing workload-driven per-model breakers.

An optional later refinement is to let qualifying real-request availability failures
request an earlier probe. Deduplicate and rate-limit those requests; they still must
not directly change availability state. Defer this unless observed detection latency
is inadequate.

## Routing and request fallback

| Main Provider | Capacity | Decision |
|---|---|---|
| Available | Primary appears to have capacity | Primary |
| Available | Primary appears full; secondary appears to have capacity | Secondary |
| Available | Primary and secondary appear full | Busy rejection |
| Available | Primary appears full; no secondary | Busy rejection |
| Unavailable | Backup Provider eligible; backup appears to have capacity | Backup |
| Unavailable | Backup absent, unavailable, or full | Unavailable/busy rejection |
| Unknown at startup | Pool appears to have capacity | Proposed: allow normal routing while immediate probe runs |

No latency-based demotion to secondary and no backup overflow for ordinary capacity
exhaustion. Monitor backup using exactly the same Provider-health mechanism as the
main Provider. Recovery probes remain independent while user traffic uses backup.

Request-level fallback is a separate policy from provider availability:

- Recommended: at most one backup attempt after an eligible availability failure,
  even before scheduled health checks have detected an outage.
- Require backup Provider eligibility and the same best-effort pool occupancy check
  to permit the attempt; bound its checkout waiting too.
- Retry only before any response output or tool-call fragments have been exposed.
- After output begins, return an interrupted-stream error; do not silently combine
  answers from different models or duplicate tool effects.
- Do not retry invalid requests, caller cancellation, or application failures as
  though they were provider outages.
- Define eligible errors and timeout behavior explicitly; do not treat every 429 or
  generic error as a provider outage.
- Bound the total attempt budget, including any HTTP-client/SDK retries.

## Capacity and lifecycle correctness

Each tier's actual transport pool is its sole capacity authority. Persist one pool
capacity setting for `(service_config_id, tier)` and use checked-out occupancy as a
routing hint. Do not maintain application request counters, admission budgets,
admission leases, or bounded request-task registries as a second representation of
occupied capacity. Remove RegisteredModel-level `max_concurrent`, `pool_class`, and
the shared fast/slow pools from the target design.

### Admission and transport

Capacity-based routing is explicitly best effort:

1. When the main Provider is eligible, inspect primary's checked-out occupancy
   against its configured pool capacity.
2. If primary appears to have capacity, execute through primary's pool.
3. If primary appears full, inspect secondary and execute through its pool if
   capacity appears available.
4. If both appear full, or primary is full and secondary is absent, return busy.
5. When the main Provider is unavailable, apply the equivalent capacity check to
   backup, subject to backup Provider eligibility.

The occupancy check and subsequent checkout are deliberately not atomic. Concurrent
requests may both observe an available primary slot and select primary; one may
then queue briefly. Secondary may be selected just before primary frees capacity,
and busy may be returned just as capacity becomes available. The transport pool
enforces its actual connection limit; the router observes occupancy for selection.

Specify a finite transport-pool checkout timeout, with its exact value left to
implementation. It is separate from connection establishment, response inactivity,
and total inference deadlines. If checkout cannot complete within that timeout,
return a local busy/capacity error. Do not change Provider health, use backup for
local contention, or make another secondary attempt after checkout timeout in the
initial design. Secondary selection happens only during the initial occupancy
check. A zero-duration checkout timeout must not be described as an atomic "try
checkout" operation.

Keep dedicated production pools for primary, secondary, and backup. A Hackney pool
isolates only calls that actually use it. For Claude's Anthropix/Req/Finch path,
implementation must explicitly choose equivalent isolated transport capacity and
occupancy-based routing where supported, or standardize the transport so all
supported adapters satisfy the design. If neither is practical, record an unresolved
limitation; do not claim Hackney pool creation isolates Claude traffic.

### Installed transport verification gate

The pool-only design is conditional on verifying the installed Hackney version,
not assumptions drawn from another release. Confirm:

- Which statistic represents checked-out occupancy.
- Whether the configured limit bounds checked-out connections rather than only
  retained idle connections.
- What happens when the pool reaches that limit.
- How checkout timeout and cancellation remove pending checkout requests.
- Whether streaming retains its checkout until stream completion.
- Whether task termination, including `:kill`, reliably releases or closes the
  associated connection and reclaims pool capacity.

Verify each other adapter's actual transport against its documented capacity and
cleanup semantics as well. If these guarantees cannot be established, resolve the
transport limitation before treating the pool-only design as implementable.

### Fairness boundary and limitations

ServiceConfig ID is the pool isolation boundary. Different ServiceConfigs
have independent production capacity even when they select the same model. Features
or sections referencing the same ServiceConfig intentionally share its tier pools;
independent pools require distinct ServiceConfigs. Section overrides use the
resolved ServiceConfig's pools.

This provides local capacity isolation, not guaranteed fairness at the upstream
provider or across the application's shared CPU, memory, and networking. All
ServiceConfigs using a Provider still share its account quotas. Combined allocations
can exceed upstream request/token limits even when every individual tier is under
capacity. Initial sizing must account for total allocations and node count. Add
provider-wide rate control only if needed; it is not an initial additional concurrency
setting.

Fixed pool allocations intentionally do not borrow unused capacity from other
ServiceConfigs. This trades some utilization for predictable isolation. Do not add
automatic borrowing in the initial design.

### Lifecycle and configuration

- Ensure reliable stream and connection cleanup on completion, cancellation, errors,
  and process death, including `:kill`; verify eventual capacity reclamation.
- Enforce transport pool limits even when Provider-health checks are disabled or
  administratively overridden.
- Keep backup transport capacity separate from main-provider requests, which can
  remain in flight after failover.
- Keep probe transport capacity separate so production saturation cannot block
  probes or manufacture an outage.
- Persist pool settings with the ServiceConfig tier and propagate changes to every
  application node. Current admin pool resizing affects only the handling node.
- On a capacity change, create a new pool with the desired capacity and immediately
  route new selections to it. Let old checked-out work and already-pending checkouts
  finish or time out. Total occupancy can temporarily exceed the new setting while
  old pools drain; the new pool enforces its own capacity. Keep old generations
  visible and retire them safely after all work and stale selections are resolved.
- Safely reconcile pool creation, resizing, restart, retirement, model reassignment,
  and endpoint/configuration changes. Do not reuse connections to an obsolete
  endpoint or lose accounting for checked-out connections still in flight; drain
  retiring pools safely while keeping their occupancy visible.
- Route administrative test calls through the appropriate production pool when a
  ServiceConfig is supplied, or an explicit administrative transport pool otherwise.

Provider health probes retain separate small transport capacity per Provider and
monitoring node. They do not consume any ServiceConfig production allocation or
depend on its pools. This is the explicit infrastructure exception to production
pool ownership by ServiceConfig tier.

## Observability and administration

Provide one clear Provider-health view showing:

- Administrative state and observed availability.
- Health-check model and probe settings.
- Last check, last success, next check, and stale/unknown status.
- Consecutive failures/successes and safe failure category.

Expose the editable `health_check` boolean in the RegisteredModel UI. The Provider
view should show the model actually selected, including an automatically designated
model, so administrators can understand the effect of flags and their ordering.

Keep separate telemetry for:

- Probe results, duration, state changes, and monitor failures.
- Router selection reason and busy/unavailable rejection.
- Checked-out occupancy and configured capacity per ServiceConfig tier, with
  selected-model identity for diagnosis.
- Checkout wait duration, checkout timeouts, and queue depth where available.
- Connection cleanup failures and pool lifecycle errors.
- Real-request outcomes, time to first token, inter-chunk stalls, total duration,
  cancellations, and interrupted streams.
- Backup attempts and whether any output had already been exposed.

Do not use total response duration as availability evidence. Avoid logging credentials,
raw provider error payloads, or user prompts. Credential rotation should revalidate
the connection and invalidate obsolete probe results.

The current primary-only switch bypasses admission as well as health routing. A
future operational override should have explicit semantics and preserve capacity
protection; do not carry forward the current coupling by accident.

## Migration and rollout considerations

### Initial Provider data migration

Build a migration that creates exactly one Provider named "OpenAI production" initially. Find
the first RegisteredModel with API keys, ordered by RegisteredModel ID, and migrate
its API keys to that Provider. Link **every existing RegisteredModel** to this same
Provider, including models that have no API keys. Do not create a Provider per model
or group existing models into multiple Providers during this initial migration.
Migrate encrypted credentials without exposing their values in logs or artifacts.

This single-Provider assignment is the initial data state. Administrators can create
additional Providers and reassign models afterward to establish distinct provider
failure domains and satisfy the backup routing requirements.

- Add the editable RegisteredModel `health_check` boolean, defaulting to `false`.
  Resolve and validate each Provider's probe model using the selection rule, and
  persist automatic designation when none of its models is flagged.
- Audit ServiceConfigs against same-Provider primary/secondary and independent backup
  requirements.
- Assign pool capacities to each configured ServiceConfig tier and replace shared
  fast/slow transport pools with tier-owned pools. Existing per-model limits cannot
  simply be copied into every ServiceConfig without reviewing the resulting combined
  provider allocations.
- Replace model concurrency and shared pool-size admin controls with persisted
  ServiceConfig-tier pool settings and ensure all nodes reconcile updates.
- Verify installed transport bounds, occupancy, checkout timeout/cancellation, resize,
  and stream cleanup behavior before enabling pool-only routing. Resolve each
  adapter's isolation strategy and correct stream outcome reporting.
- Observe probes without using them to divert production requests initially, then
  enable provider-health routing in a controlled rollout.
- Reset or replace obsolete breaker/counter state deliberately during deployment.
- Remove old per-model health fields and misleading fallback abstractions only after
  their replacements are wired through admin views, telemetry, and tests.
- Define rollback behavior and the disposition of the primary-only override.

These are planning considerations, not an approved implementation sequence. Schema
migrations must follow repository policy: generated filenames and explicit `up/0`
and `down/0` functions.

## Required verification for implementation

- Long successful user streams never change Provider availability.
- User errors and cancellations do not directly change Provider availability.
- Probe failures and successes drive the intended thresholds and recovery without
  any user traffic or diagnostic status calls.
- One in-flight probe per Provider; deadlines, task crashes, monitor restart, stale
  results, and configuration changes are handled deterministically.
- A full user pool cannot prevent probing or occupy reserved backup capacity.
- Primary appearing full selects secondary; both appearing full returns busy; main
  outage selects eligible backup subject to its pool capacity.
- Concurrent selection races may queue, but checkout waiting is bounded; checkout
  timeout returns local busy without another secondary attempt or Provider failover.
- Pool contention never changes Provider health or triggers backup fallback.
- Saturating one ServiceConfig does not consume another's tier pools, including
  when the same RegisteredModel is primary in one and secondary in the other.
- Features and sections resolving to the same ServiceConfig share its tier pools.
- Separate ServiceConfigs and backup retain transport isolation. Each adapter
  actually uses its designated pools and satisfies its documented connection,
  request, or stream capacity semantics, including under multiplexing.
- All installed Hackney verification-gate questions above have evidence from the
  installed dependency, including pending-checkout removal and streaming ownership.
- Limit changes reach every node; reductions drain existing work, and model changes
  or pool removal preserve cleanup for requests in flight.
- Backup unavailability and saturation have explicit, bounded failure behavior.
- Completed, cancelled, errored, and killed streams eventually reclaim pool capacity,
  including abrupt task termination with `:kill`.
- Health overrides do not disable pool limits.
- With `GENAI_HEALTH_CHECKS_ENABLED=false`, no Provider probes run, stale observed
  health does not gate routing, primary-to-secondary overflow and capacity protection
  remain active, and administratively disabled Providers remain disabled. Re-enabling
  checks starts normal probing without reusing stale availability evidence.
- Streaming adapters detect in-stream errors, truncation, and inactivity correctly.
- At most one eligible fallback occurs before output; none occurs after output or
  tool-call fragments are exposed.
- Provider identity and ServiceConfig validation enforce the intended boundaries.
- Provider probes select the lowest-ID flagged RegisteredModel for that Provider;
  multiple flags are resolved deterministically and other Providers' models are excluded.
- When all flags are false, the lowest-ID model is persisted with `health_check = true`
  and used for probing. Flag edits, deletion, membership changes, and concurrent node
  reconciliation preserve this behavior without overwriting newer admin choices.
- The RegisteredModel UI can edit `health_check`, and a Provider with no models
  exposes the missing probe configuration accurately.
- Credential migration, rotation, and admin presentation do not expose secrets.
- Node-local monitoring behavior and total probe load are understood under scaling.

## Open decisions

1. Exact Provider identity fields and how to enforce different-vendor backup when
   multiple records can represent the same vendor.  Punt on this, do nothing.
2. Detailed reconciliation lifecycle for Provider health-check model selection.
   Selection is decided: use the first RegisteredModel with `health_check = true`,
   or persist `true` on the first model when none is flagged, ordered by model ID.

4. Classification and routing consequences of invalid credentials, invalid probe
   configuration, and probe-specific/model-specific throttling.  Punt, do nothing.
5. Detailed adapter-specific pool lifecycle and transport sizing, plus the transport pool for
   administrative tests without a ServiceConfig and finite checkout timeout value.
   Production capacity keys and pool ownership are decided: `(service_config_id, tier)`, with one persisted pool capacity
   setting and an isolated transport pool per configured tier per node.
6. Eligible request-level fallback errors and total deadline/retry budget.
7. Administrative overrides, rollout gates, and retirement of the primary-only switch. Yes, delete the primary-only override switch.
8. Whether real-request failures should eventually accelerate probes. NO.

## Future work

Outside this redesign's scope, evaluate Anthropic's OpenAI-compatible endpoint as a way to reuse Torus's OpenAI-compatible adapter and configured Hackney pools, subject to feature compatibility and Anthropic's production-use guidance.

## References

- Current implementation: `lib/oli/gen_ai/router.ex`,
  `lib/oli/gen_ai/breaker.ex`, `lib/oli/gen_ai/execution.ex`,
  `lib/oli/gen_ai/admission_control.ex`, `lib/oli/gen_ai/hackney_pool.ex`.
- Model/config schemas: `lib/oli/gen_ai/completions/registered_model.ex`,
  `lib/oli/gen_ai/completions/service_config.ex`.
- Adapters: `lib/oli/gen_ai/completions/open_ai_compliant_provider.ex`,
  `lib/oli/gen_ai/completions/claude_provider.ex`.
- Dialogue cancellation: `lib/oli/gen_ai/dialogue/server.ex`.
- Existing tests: `test/oli/gen_ai/`.
- Original routing design: `docs/exec-plans/archive/features/genai-routing/prd.md`,
  `docs/exec-plans/archive/features/genai-routing/fdd.md`.
- [Anthropic streaming documentation](https://platform.claude.com/docs/en/build-with-claude/streaming):
  documents streaming lifecycle, ping events, and in-stream overload errors.
- [Anthropic rate limits](https://platform.claude.com/docs/en/api/rate-limits):
  documents model/model-group and account/workspace quota distinctions.
- [OpenAI rate limits](https://developers.openai.com/api/docs/guides/rate-limits):
  documents organization/project and model quota distinctions.
