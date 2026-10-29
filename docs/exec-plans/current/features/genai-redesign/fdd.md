# GenAI Provider Health and Routing Redesign - Functional Design Document

## 1. Executive Summary

Replace workload-driven model breakers and application admission counters with independently probed Provider health and isolated per-ServiceConfig-tier transport pools. The router uses observed pool occupancy as a best-effort hint; the transport enforces capacity and bounds checkout waiting. Backup handles Provider outages or eligible pre-output request failures, never ordinary pool contention. This design is conditional on verifying the installed transports' capacity and cleanup behavior. `docs/exec-plans/current/features/genai-redesign/informal.md` is the detailed source of product decisions and investigation findings.

## 2. Requirements & Assumptions

- Functional scope: Provider configuration and independent monitoring, deterministic probe model selection, tier-pool routing, bounded contention, guarded backup retry, stream correctness, administration, observability, and migration (FR-001 through FR-021; AC-001 through AC-021).
- Non-functional scope: per-node isolation and bounded checkout, safe credential handling, reliable cleanup, configuration propagation, and adapter-specific capacity semantics. Global provider request/token quotas and capacity borrowing are outside scope.
- Assume non-atomic observation and checkout; a short bounded queue, a secondary selected just before primary frees, or a busy result just as space opens are acceptable. Initial unknown health allows normal pool-limited routing while an immediate probe runs. Previously available health becomes stale after two regular probe intervals plus its deadline, and is locally ineligible until fresh evidence returns.
- Decisions marked as proposals or open in the informal design remain open below. Installed-Hackney verification and current implementation evidence are linked in the phase-specific design and execution records.

## 3. Repository Context Summary (before implementation)

- `Oli.GenAI.Router` currently reads per-model breakers and uses `AdmissionControl` model and shared-pool counters; `Execution` reports user outcomes to breakers and releases counters in `after`. `RoutingPlan` carries model-derived pool and admission state. A killed task can bypass that cleanup.
- `Oli.GenAI.HackneyPool` manages shared fast/slow pools; `OpenAICompliantProvider` constructs its Hackney pool from the model in both sync and async calls, so selected tier identity must reach the actual request. `ClaudeProvider` uses Anthropix/Req/Finch, not that Hackney pool. `Completions.Provider` currently has no stream transport options argument.
- `FeatureConfig` resolves global and section-specific ServiceConfigs. Existing admin LiveViews manage models, ServiceConfigs, and local pool controls. `Oli.Application` supervises current pool, admission, breaker and telemetry infrastructure. `docs/design-docs/genai.md` describes the existing system and will need reconciliation as implementation lands.
- `mix.lock` pins Hackney 1.25.0, Anthropix 0.6.2, Req 0.5.16 and Finch 0.20.0. Local Hackney source exposes `in_use_count`, `queue_count`, `checkout_timeout`, and a checkout queue; source inspection alone is not proof of end-to-end cancellation, resizing, streaming, or process-death behavior. Confirm these against the installed versions and actual adapter call paths (AC-014, AC-015).

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- The GenAI context owns persisted Provider/model/ServiceConfig CRUD and validation; the Provider is a configured connection and availability boundary, distinct from vendor identity and protocol adapter. A Provider carries name, adapter, endpoint, encrypted credentials and applicable headers/account/region, administrative state, and probe policy. RegisteredModels retain model identity, generation settings and model-specific request timeouts (AC-001, AC-002).
- A node-local Provider monitor owns observed availability. One supervised monitor per Provider per node schedules and coordinates probes; its network task uses a separate Provider/node probe transport and never invokes normal routing or fallback. A production pool cannot block probes, and probe results from backup never establish main Provider health (AC-004 through AC-006).
- A node-local pool manager reconciles persisted tier settings and owns actual transport lifecycle. Pool identity is `(service_config_id, tier)`; production primary, secondary and backup are independent even for the same model. Features and sections resolving to one ServiceConfig share its pools. Probe pools and explicit administrative pools are separate infrastructure exceptions (AC-008, AC-013, AC-017).
- Router reads Provider eligibility and transport occupancy, returns a plan containing the resolved ServiceConfig, tier, model, transport handle and reason. Execution passes that handle and timeout to the adapter for both generate and stream. Actual transport pool occupancy is the sole capacity authority; no per-request admission counters, leases, or bounded task registry are introduced (AC-009 through AC-011).
- Execution owns a single request's response exposure and optional retry. Adapters normalize real protocol completion and failures, including stream events. The admin surface uses existing authorized GenAI context/LiveView patterns and displays health and capacity semantics (AC-012, AC-016, AC-018).

### 4.2 State & Data Flow

1. Resolve feature and optional section override to ServiceConfig; load selected models and their Providers. Validate primary/secondary are distinct models on one Provider, backup belongs to a different Provider. Different-vendor enforcement is deferred (AC-002).
2. If main Provider is eligible, inspect primary checked-out occupancy against its configured capacity. Select primary if it appears available; otherwise select secondary if configured and it appears available; otherwise return busy. If main is unavailable, check backup eligibility and its own occupancy; absent/unavailable backup yields unavailable and apparent saturation yields busy. Never route capacity overflow to backup (AC-009, AC-010).
3. Pass the chosen transport handle to the adapter. Occupancy and checkout are not atomic. A finite, separately configured checkout timeout bounds any queue; timeout maps to local busy, without changing health, attempting secondary again, or invoking backup for contention (AC-011).
4. For an eligible upstream availability failure, Execution may attempt backup at most once, only before any response or tool-call fragment is exposed, and only if its Provider and pool qualify. It applies the same finite checkout timeout and a total attempt budget including SDK retries. Cancellation, invalid input, application failures, generic errors and every 429 are not automatically eligible. Once output is exposed, report interrupted stream. The implemented initial policy uses one 300,000 ms total deadline, connection failures and pre-output inactivity, plus HTTP 500/502/503/504; see the Phase 3 contract (AC-012).
5. Probes use a tiny fixed prompt and bounded output, exercise the configured endpoint, credentials and adapter, and require protocol completion rather than exact text. Independent probe results alone update observed availability; user outcomes and contention remain telemetry only (AC-004, AC-005, AC-016).

### 4.3 Lifecycle & Ownership

- Emergency primary-only mode bypasses runtime caches, observed health, secondary and backup selection/retry. Read only the current primary model and Provider from the database and provision its bounded transport through an independent pool manager outside normal runtime reconciliation. Keep Provider disablement, credentials, primary capacity, deadlines and cancellation effective; expose the mode in diagnostics, startup logs and router telemetry. Environment changes require restart on every node; per-node application configuration can change the mode immediately (AC-021).

- Each configured tier has one persisted capacity setting and one isolated production pool per node. For Hackney label it “Maximum checked-out connections” or “Pool capacity”; do not describe it as a universal concurrent-request limit. Verify an HTTP/1.1 inference retains its checkout throughout streaming. Multiplexed transports must supply equivalent request/stream capacity or explicitly expose different semantics (AC-008, AC-014, AC-015).
- Reconcile startup and committed configuration changes on every node. Creation failures are visible and requests fail explicitly rather than silently sharing another pool. On model/endpoint change, retain visibility and cleanup of checked-out old connections while retiring/draining the old transport; prevent old endpoint connections from serving new configuration. Avoid silently losing active occupancy across a restart or pool generation change (AC-013).
- On capacity change, create a fresh pool at the desired size and immediately route new selections to it. Old checked-out work and already-pending checkouts finish or time out. Combined occupancy across old and new pools may temporarily exceed the new setting until old generations drain. Keep retiring generations visible and retire them safely only after active work, pending checkouts, and stale selections are resolved; do not introduce separate admission counters (AC-013, AC-014).
- Completion, cancellation, errors and task death, including `:kill`, must eventually release or close transport resources. Ordinary cleanup should close streams on all exit paths; process-death behavior requires evidence from the actual transport and owner relationship. Do not assume `try/after` runs on `:kill` (AC-016).
- Probe selection uses the lowest-ID flagged model; if none is flagged, persist `health_check=true` on the lowest-ID model. Reconcile flag edits, membership changes, and deletion transactionally without overwriting newer admin selections; a Provider with no models reports missing configuration. Multiple flags are allowed. Disabled monitoring does not itself change flags (AC-003, AC-007).
- Monitor state is node-local: unknown, available, or unavailable, plus timestamps, consecutive outcomes, safe category, next check, and configuration/probe generation. Initially probe immediately. Proposed defaults: regular/recovery interval 3 minutes; after first failure, interval 30 seconds until 3 consecutive failures mark unavailable; then return to regular interval; 2 consecutive successes restore availability. Defaults are runtime-overridable. Schedule from completion to avoid overlap, add jitter, and cap concurrent probes across Providers. A monitored task and deadline keep coordination responsive; discard stale results using generation identity (AC-005, AC-006).
- `GENAI_HEALTH_CHECKS_ENABLED=false` disables initial, recurring and recovery probes on that node and bypasses observed-health gating, but preserves administrative disablement, pools and request fallback policy. Display disabled rather than healthy. On re-enable start unknown and probe immediately; environment changes normally take effect at restart. Retain `GENAI_ROUTING_PRIMARY_ONLY` as an independent bounded emergency path (AC-007, AC-021).

### 4.4 Alternatives Considered

- Atomic application reservations would provide immediate overflow but duplicate transport state and require synchronization and reclamation. Best-effort pool observation plus bounded checkout is sufficient for the accepted races.
- Reusing fast/slow pools or pooling by model would couple ServiceConfigs and backup. Tier-owned pools preserve the required failure and isolation boundaries.
- Request-driven breakers or using normal requests as recovery probes reintroduce long-stream false positives and traffic-dependent recovery. Independent synthetic probes avoid that coupling, while their limited representativeness remains an explicit risk.
- Hackney-only allocation cannot isolate Claude calls that use Req/Finch. Choose equivalent isolation and occupancy for the actual transport, or standardize supported adapters; if neither works, record the unresolved limitation and do not enable unsupported pool-only routing (AC-015).

Phase 1 transport evidence and the later-phase integration contract are recorded in `docs/exec-plans/current/features/genai-redesign/design/transport-evidence.md`. Installed Hackney in-place shrink can admit queued work above the reduced limit; use immediate pool replacement with temporary overlapping capacity instead.

## 5. Interfaces

- Context configuration operations validate Provider membership, distinct tiers, capacity, encrypted connection configuration and selected probe model. Saving or retiring configuration emits an after-commit reconciliation signal; each node also reconciles from persisted state at startup and after missed notifications.
- Define a small transport contract, implemented by each actual adapter transport: resolve/create a tier pool, inspect `{checked_out, capacity, queue_depth_or_unavailable}`, execute with that exact handle and finite checkout timeout, and reconcile/retire safely. Return explicit `busy`, `unavailable`, configuration and transport errors. This is an interface sketch, not a claim that current clients expose all operations (AC-008 through AC-011, AC-013 through AC-015).
- Extend completion dispatch and adapter callbacks so both `generate` and `stream` receive transport context, Provider connection configuration and deadlines. Preserve caller-facing response behavior and metadata where feasible; require explicit stream completion/error signals and track first exposed output before retry (AC-012, AC-016).
- Monitor API exposes read-only node-local eligibility and operational snapshot; only probe result handling mutates observed availability. A generation token binds result to current Provider credentials, model and configuration (AC-004 through AC-007).
- Administrative calls with ServiceConfig context use the relevant tier's production pool; without it use a named, explicitly sized administrative transport pool. Neither bypasses transport capacity (AC-017).

## 6. Data Model & Storage

- Add Provider records with encrypted credentials, connection and adapter fields, administrative state and probe policy. Replace model-owned credentials and provider enum usage with a Provider reference while preserving model identity and inference timeouts. Add `health_check` default false. Map secondary credential fields according to their actual adapter purpose (AC-001, AC-003).
- Add one persisted capacity for each configured ServiceConfig tier; validate positive usable values and defined semantics for missing tiers. Retire model `max_concurrent`, per-model breaker thresholds and global fast/slow controls after callers migrate. No separate application admission settings exist (AC-008, AC-021).
- Generate Ecto migrations normally, defining explicit `up/0` and `down/0`. Initial migration creates exactly one Provider named `OpenAI production`, moves credentials from the lowest-ID RegisteredModel with API keys, and links every existing RegisteredModel including those without keys. Preserve encrypted values and prevent their exposure. Audit resulting model/adapter/endpoint compatibility and invalid same-Provider backup configurations before health routing; administrators may subsequently create Providers and reassign models (AC-020).
- A single migrated Provider may not represent heterogeneous existing endpoint/adapter settings. Define a safe migration mapping and rollout precondition without silently discarding source configuration. Missing-key and rollback behavior must be decided and tested. Do not automatically split the mandated initial Provider into multiple records.

## 7. Consistency & Transactions

- Persist ServiceConfig selection and capacities atomically; validate membership against current Provider assignments. Publish reconciliation only after commit. Node-local state is eventually reconciled with the database, including startup/restart and missed events; do not assume PubSub alone is durable (AC-002, AC-013).
- Serialize probe designation with administrator edits, for example by locking the Provider row in a transaction and re-reading eligible models before setting the fallback flag. All mutations of flags and membership must participate in the same coordination; generation changes invalidate old probe results (AC-003, AC-006).
- A routing occupancy snapshot is intentionally approximate; it does not reserve a checkout. Configuration changes must not leak traffic to an obsolete endpoint, and retiring transport generations retain visibility of their active work. Resolve exact behavior for concurrent capacity updates and waiting checkouts through transport verification (AC-009, AC-011, AC-013).

## 8. Caching Strategy

Node-local monitor snapshots and pool state are runtime operational state, not a global source of truth. Persist configuration in PostgreSQL; reconcile node snapshots on change and restart. Do not cache occupancy in application counters or treat a snapshot as a reservation. Phase 3 publishes protected per-ServiceConfig execution snapshots for reads independent of slow reconciliation; health remains live and occupancy is never cached in application counters (AC-004, AC-008, AC-013).

## 9. Performance & Scalability Posture

Routing performs local health and occupancy reads before a bounded transport checkout. No zero-duration checkout is claimed to be atomic. Probe count scales with Providers and nodes; jitter schedules, cap concurrent probes, and use dedicated small transport capacity. Pool sizes are per node, and combined allocations can exceed upstream account quotas. The initial checkout timeout is 1,000 ms; no numeric throughput target is established (AC-005, AC-011, AC-014).

## 10. Failure Modes & Resilience

- Main full with no available secondary returns busy; backup is not overflow. Checkout timeout is local busy, never Provider-health evidence or a backup trigger (AC-009 through AC-011).
- Main outage selects eligible backup, which may itself be unavailable or full; return a bounded unavailable/busy error. Probe recovery continues independently while backup serves traffic (AC-005, AC-010).
- A monitor crash restarts unknown and schedules a probe; reject stale task results and distinguish invalid configuration from observed unavailability. Define the policy for stale previously available health before rollout (AC-006).
- Adapter stream inactivity, SSE error, truncation or enumeration exception must yield failure, not a successful partial result. The existing Anthropix hard-coded inactivity cutoff and filtered SSE errors are documented future work under the explicit Claude deferral; a model receive timeout alone would be insufficient (AC-016).
- Pool lifecycle and cleanup failures must surface to operators, and an unverified or unavailable transport must not silently bypass isolation (AC-013 through AC-016).

## 11. Observability

Emit routing reason and selection, busy/unavailable counts, Provider and selected model identifiers, checked-out occupancy and configured capacity by ServiceConfig tier, checkout wait and timeout, queue depth when available, and pool lifecycle/cleanup errors. Report probes, duration, health transitions, monitor failures, last success/check and next check, and safe failure categories. Track real-request outcomes, first-token time, stalls, duration, cancellation, interrupted streams, and backup attempts separately; none determines health. Integrate with existing telemetry/AppSignal conventions and avoid unbounded labels (AC-018, AC-019).

## 12. Security & Privacy

Use existing authorization for all Provider, model and ServiceConfig administration and test calls. Encrypt persisted credentials, restrict disclosure in changesets, logs, telemetry, UI and migration artifacts, and do not log prompts or raw provider payloads. Map provider errors to safe actionable categories. Credential changes invalidate in-flight probe generations and revalidate access without allowing stale results to restore health (AC-001, AC-018 through AC-020).

## 13. Testing Strategy

- ExUnit tests for validation, deterministic selection, flag reconciliation under concurrent edits, monitor state transitions and thresholds, no overlap, timeout/crash/restart, stale results, disabled checks and independent recovery (AC-001 through AC-007).
- Exercise actual installed transports, not only mocks: identify checked-out statistic; verify the limit bounds checked-out connections rather than idle retention; measure behavior when full; test timeout and cancellation removal of pending waiters, stream checkout ownership, completion/cancellation/`:kill` cleanup, and resize below occupancy including pending checkouts. Validate HTTP/1.1 semantics for the in-scope OpenAI adapter; defer Claude implementation and runtime verification as specified below, and require separate verification before future multiplexed support and isolate backup and separate ServiceConfigs (AC-008, AC-013 through AC-016).
- Force concurrent routing observations to show bounded queueing, primary-full secondary choice, both-full busy, and no failover or health mutation on contention. Test backup eligibility and a single eligible pre-output retry, no retry after response or tool fragments, and bounded total/checkout deadlines (AC-009 through AC-012).
- Verify per-node propagation, safe retiring pools across model/endpoint updates, admin calls with and without ServiceConfig, and LiveView permissions, labels and safe diagnostic states (AC-013, AC-017, AC-018).
- Test migration and explicit rollback with multiple models, missing keys and heterogeneous legacy connection data, then audit resulting configurations; test telemetry redaction and staged deployment behavior (AC-019 through AC-021). Use repository test-output hygiene and applicable security, performance and requirements reviews.

## 14. Backwards Compatibility

Preserve feature and section resolution, public completion behavior where feasible, and model-specific timeouts while adapting both sync and stream transport interfaces. Initial migration deliberately assigns all models to one Provider; preexisting backups require audit and administrative reconfiguration before new validation and health routing are enforced. Observe probes first, then enable routing through a controlled deployment; reconcile obsolete counters/breakers and remove the primary-only switch. Define rollback ordering for old application versions, credentials and fields before deployment; do not assume old nodes understand new schema or configuration (AC-020, AC-021).

## 15. Risks & Mitigations

- Installed transport may not satisfy active bounds, resize or kill cleanup: make empirical dependency-specific verification a release gate and resolve the transport choice before enabling routing.
- Per-node observations and configuration propagation can diverge: expose node-local state, reconcile from durable configuration and test missed events and restarts.
- A short probe is not evidence for every model, quota or long stream: retain request telemetry and treat model-specific classification as deferred; do not let ordinary requests mutate Provider availability.
- Single-Provider migration may conflate heterogeneous legacy connections: preserve source data until mapping and rollback are demonstrated, and block activation of invalid configurations.

## 16. Open Questions & Follow-ups

- Use the initial 1,000 ms checkout timeout and administrative capacity four per node from the Phase 1 transport contract. The initial total inference budget is 300,000 ms across both attempts; eligible failures are connection failures, pre-output inactivity, and HTTP 500/502/503/504. Generic 429, protocol/input/application errors and local pool failures do not trigger backup. Provider-specific classification remains deferred.
- Stale cutoff is two regular intervals plus probe deadline; stale/invalid configuration is locally ineligible rather than an observed outage. Structurally valid unknown health is initially eligible. Phase 4 supplies authorized probe-policy configuration and node-local diagnostics.
- Claude/Anthropic transport isolation and runtime verification are explicitly deferred. Leave its implementation unchanged and do not claim Hackney isolation for it. Future work must choose and verify its actual transport.
- Rollout and rollback use `docs/OPERATIONS.md`: additive single-Provider migration, explicit mapping/key/configuration audit, ingress-excluded canary observation, frozen mixed-version writers and tested atomic legacy connection preparation. Different-vendor enforcement remains deferred; distinct Provider records are mandatory for backup. The initial Provider is named "OpenAI production" and uses the lowest-ID keyed model.
- Do not accelerate probes based on real-request failures. Investigate the Anthropic OpenAI-compatible endpoint only as future work, subject to feature compatibility and vendor guidance.

Phase 3 implemented behavior, adapter boundaries, request deadlines, timing instrumentation limitations and deployment boundary are documented in `docs/exec-plans/current/features/genai-redesign/design/phase-3-execution.md`. Phase 2 implementation and its earlier observe-only compatibility decisions are documented in `docs/exec-plans/current/features/genai-redesign/design/phase-2-runtime.md`. The schema remains additive for rollback. OpenAI production and administrative execution now use managed transport; old counter/breaker services and controls are retired. Phase 4 implementation and verification are recorded in `docs/exec-plans/current/features/genai-redesign/execution/phase-4.md`; deployment-specific gates remain in `docs/OPERATIONS.md`.

## 17. References

- `docs/exec-plans/current/features/genai-redesign/informal.md` — investigation, detailed decisions, probe schedules and verification gate.
- `docs/exec-plans/current/features/genai-redesign/prd.md` and `docs/exec-plans/current/features/genai-redesign/requirements.yml` — scope and acceptance criteria.
- `lib/oli/gen_ai/router.ex`, `lib/oli/gen_ai/execution.ex`, `lib/oli/gen_ai/hackney_pool.ex`, `lib/oli/gen_ai/completions/`, `lib/oli_web/live/gen_ai/`, and `lib/oli/gen_ai/dialogue/server.ex` — existing execution and administration boundaries.
- `docs/design-docs/genai.md`, `docs/OPERATIONS.md`, `docs/TESTING.md`, `AGENTS.md`, and `mix.lock` — existing architecture and operational constraints.
