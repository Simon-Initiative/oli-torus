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
- Prefer primary whenever its bounded capacity is available.
- Select secondary only when primary capacity is exhausted.
- If both are full, reject promptly as busy instead of waiting indefinitely or using
  backup as another overflow tier.
- Backup belongs to a different Provider and serves main-provider unavailability.
- Backup has its own bounded capacity and provider-health check.
- Each configured ServiceConfig tier owns its concurrency limit and isolated
  production transport pool per application node. Capacity is not shared across
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
can leave model and pool capacity permanently occupied until state is reset.

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

The Claude adapter uses Anthropix rather than the Hackney transport used by the
OpenAI-compatible adapter. Application admission therefore needs an explicit meaning
independent of a particular HTTP client's connection counts.

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

Concurrency limits and production pool ownership belong to the ServiceConfig tier
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

### ServiceConfig: routing preferences and reserved capacity

ServiceConfig continues selecting primary, secondary, and backup models. Preserve
existing feature resolution and section overrides.

Each configured primary, secondary, or backup selection owns one maximum concurrent
request setting and one isolated production transport pool per application node.
Pool and admission identity is `(service_config_id, tier)`. A ServiceConfig has up to
three production pools; an unconfigured tier needs none. Pool identity follows the
ServiceConfig tier rather than the model's name or RegisteredModel ID.

For example, the same GPT-5 RegisteredModel can be DOT's primary with a limit of 100
and instructor recommendations' secondary with a limit of 200:

| ServiceConfig | Tier | Model | Concurrent-request limit per node |
|---|---|---|---:|
| DOT | Primary | GPT-5 | 100 |
| DOT | Secondary | Faster model | 1,000 |
| Instructor recommendations | Primary | More powerful model | 50 |
| Instructor recommendations | Secondary | GPT-5 | 200 |

DOT exhausting its primary allocation overflows to DOT's secondary without consuming
the GPT-5 allocation reserved for instructor recommendations. Limits are illustrative,
not verified sizing recommendations.

Use the admin label "Maximum concurrent requests" rather than "Maximum concurrent
connections": HTTP/2 can multiplex requests over a connection. One configured value
drives application admission and the adapter's corresponding transport sizing; do not
expose independently configurable model and pool limits.

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
deployment-wide. Accept `false`, `0`, `no`, and `off` as disabling values,
case-insensitively and after trimming whitespace.

While disabled, bypass observed Provider-health gating so stale or previously
unavailable health state cannot block normal routing. Continue respecting Provider
administrative disablement, ServiceConfig-tier concurrency limits, pool isolation,
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
- Exercise streaming when streaming availability is the behavior being protected.
- Use a dedicated deadline suitable for the chosen health-check model.
- Reserve probe capacity independently from ordinary model admission and saturated
  user-request transport pools.
- Do not route probes through normal fallback. A backup success must not mark the
  original Provider healthy.
- Have at most one probe in flight per Provider per monitoring node.
- Run network work in a monitored task; keep the coordinating process responsive.
- Handle task exit, deadline expiry, and cleanup explicitly.
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
- Mark unavailable after 4 consecutive failed probes.  The 4 is a default value but overridable via runtime environment variable.
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

Start with per-application-node monitors and health state, matching current local
admission state. This tests connectivity from the node making requests and avoids
introducing cluster leadership or consensus.

Consequences:

- Probe volume and cost multiply by active node count and Provider count.
- Nodes may legitimately disagree due to local connectivity failures.
- Add scheduling jitter and cap concurrent probes.
- Account for node count when sizing model capacity; per-node limits are not global
  account quota enforcement.

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
| Available | Primary available | Primary |
| Available | Primary full; secondary available | Secondary |
| Available | Primary and secondary full | Busy rejection |
| Available | Primary full; no secondary | Busy rejection |
| Unavailable | Backup Provider available; backup has capacity | Backup |
| Unavailable | Backup absent, unavailable, or full | Unavailable/busy rejection |
| Unknown at startup | Within capacity | Proposed: allow normal routing while immediate probe runs |

No latency-based demotion to secondary and no backup overflow for ordinary capacity
exhaustion. Monitor backup using exactly the same Provider-health mechanism as the
main Provider. Recovery probes remain independent while user traffic uses backup.

Request-level fallback is a separate policy from provider availability:

- Recommended: at most one backup attempt after an eligible availability failure,
  even before scheduled health checks have detected an outage.
- Require backup health and capacity to permit the attempt.
- Retry only before any response output or tool-call fragments have been exposed.
- After output begins, return an interrupted-stream error; do not silently combine
  answers from different models or duplicate tool effects.
- Do not retry invalid requests, caller cancellation, or application failures as
  though they were provider outages.
- Define eligible errors and timeout behavior explicitly; do not treat every 429 or
  generic error as a provider outage.
- Bound the total attempt budget, including any HTTP-client/SDK retries.

## Capacity and lifecycle correctness

Application-level concurrency limits should be authoritative and independent of
HTTP-client implementation or health-monitor configuration. Scope each capacity
budget to `(service_config_id, tier)` and use its single configured limit to size the
dedicated transport pool. Remove RegisteredModel-level `max_concurrent`, `pool_class`,
the shared fast/slow pools, and the separate shared-pool admission budget from the
target design.

### Admission and transport

Transport pool exhaustion alone cannot implement immediate overflow. The installed
Hackney implementation queues checkout requests when full, and observing occupancy
before sending does not atomically reserve a slot. Keep an atomic application
reservation against the ServiceConfig-tier budget:

1. Try to reserve primary capacity before issuing a provider request.
2. If full, immediately attempt that ServiceConfig's secondary reservation.
3. If admitted, execute through the selected tier's dedicated transport pool.
4. Release the reservation on completion or owner process death.

Provider unavailability selects that ServiceConfig's backup and reserves its capacity
instead. Healthy primary/secondary saturation still returns busy and does not use
backup as another overflow tier.

One limit and one admission budget per tier are sufficient. Transport pooling remains
responsible for connection reuse and transport protection. Adapter-specific handling
must preserve the same maximum active-request semantics: the OpenAI-compatible
adapter currently uses Hackney, whereas Claude uses Anthropix/Req/Finch. Creating a
Hackney pool for Claude alone would not isolate its actual transport. Configure a
dedicated transport pool through each adapter, or standardize transports during
implementation. Do not equate HTTP/2 socket count with concurrent request count.

### Fairness boundary and limitations

ServiceConfig ID is the fairness and reservation boundary. Different ServiceConfigs
have independent production capacity even when they select the same model. Features
or sections referencing the same ServiceConfig intentionally share its tier budgets;
independent reservations require distinct ServiceConfigs. Section overrides use the
resolved ServiceConfig's pools.

This provides local capacity isolation, not guaranteed fairness at the upstream
provider or across the application's shared CPU, memory, and networking. All
ServiceConfigs using a Provider still share its account quotas. Combined allocations
can exceed upstream request/token limits even when every individual tier is under
capacity. Initial sizing must account for total allocations and node count. Add
provider-wide rate control only if needed; it is not an initial additional concurrency
setting.

Fixed reservations intentionally do not borrow unused capacity from other
ServiceConfigs. This trades some utilization for predictable isolation. Do not add
automatic borrowing in the initial design.

### Lifecycle and configuration

- Use admission leases tied to the executing process.
- Monitor owners and reclaim reservations on process death, including `:kill`.
- Make release idempotent so completion and death notifications cannot double-release.
- Enforce capacity even when provider-health checks are disabled or administratively
  overridden.
- Reserve backup capacity separately from main-provider requests, which can remain
  in flight after failover.
- Reserve probe capacity separately so saturation cannot manufacture an outage.
- Align transport capacity with application admission to avoid hidden pool queues.
- Persist limits with the ServiceConfig tier and propagate configuration changes to
  every application node. Current admin pool resizing affects only the handling node.
- When lowering a limit below current occupancy, let existing work finish and deny
  new admissions until occupancy falls below the new limit.
- Reconcile pool creation, restart, model reassignment, and removal safely. A change
  of selected model must not reuse connections to an obsolete endpoint or lose the
  accounting for requests still in flight.
- Route ordinary model calls, including admin test actions, through the relevant
  capacity reservation. Define an explicit administrative test budget when no
  ServiceConfig context exists, rather than bypassing admission silently.

Provider health probes retain a separate small reserved transport budget per Provider
and monitoring node. They do not consume any ServiceConfig production allocation or
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
- Per-ServiceConfig-tier in-flight capacity, reclaimed leases, and saturation,
  with selected-model identity for diagnosis.
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

- Inventory RegisteredModels by actual endpoint, credential context, vendor, and
  adapter before grouping them into Providers. Adapter enum alone is insufficient.
- Create Provider records and migrate encrypted credentials without exposing values
  in logs or artifacts.
- Link every RegisteredModel to the correct Provider; reconcile conflicting settings.
- Add the editable RegisteredModel `health_check` boolean, defaulting to `false`.
  Resolve and validate each Provider's probe model using the selection rule, and
  persist automatic designation when none of its models is flagged.
- Audit ServiceConfigs against same-Provider primary/secondary and independent backup
  requirements.
- Assign concurrency limits to each configured ServiceConfig tier and replace shared
  fast/slow transport pools with tier-owned pools. Existing per-model limits cannot
  simply be copied into every ServiceConfig without reviewing the resulting combined
  provider allocations.
- Replace model concurrency and shared pool-size admin controls with persisted
  ServiceConfig-tier limits and ensure all nodes reconcile updates.
- Correct stream outcome reporting and admission cleanup before enabling routing.
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
- Primary saturation selects secondary; both full rejects; main outage selects backup.
- Saturating one ServiceConfig does not consume another's tier reservations, including
  when the same RegisteredModel is primary in one and secondary in the other.
- Features and sections resolving to the same ServiceConfig share its tier budget.
- Dedicated pools use the correct transport for both adapters, without hidden queues
  defeating immediate overflow or HTTP/2 multiplexing bypassing admission limits.
- Limit changes reach every node; reductions drain existing work, and model changes
  or pool removal preserve cleanup for requests in flight.
- Backup unavailability and saturation have explicit, bounded failure behavior.
- Cancellation and abrupt process death reclaim all admission leases exactly once.
- Health overrides do not disable concurrency limits.
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
   configuration, and probe-specific/model-specific throttling.
5. Detailed adapter-specific pool lifecycle and transport sizing, plus the budget for
   administrative tests without a ServiceConfig. Production capacity keys and pool
   ownership are decided: `(service_config_id, tier)`, with one configured concurrency
   limit and an isolated transport pool per configured tier per node.
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
