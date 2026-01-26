# Backpressure-Aware GenAI Routing & Circuit Breakers — FDD

## 1. Executive Summary
This design adds a centralized routing and health layer for GenAI calls so Torus can shed load, route to backups, and avoid hackney pool stalls during peak usage. It targets both synchronous and streaming workloads by applying admission control and circuit breaking before provider calls are issued. Each ServiceConfig will own its routing policy parameters, editable directly in the existing ServiceConfig admin view, preserving current admin workflows. Routing decisions and outcomes are instrumented with telemetry for AppSignal dashboards and operational tuning. The design uses OTP patterns with supervised processes and ETS-based counters to keep routing decisions under 5ms p95. Breaker state is maintained per RegisteredModel in-memory, with fast reads for routing and bounded update overhead. The approach is intentionally local-node first (per-node counters and breakers) with clear extension points for multi-node coordination later. Risks center on correct threshold calibration and the difference between single-node and clustered behavior; both are mitigated with conservative defaults, observability, and staged ServiceConfig rollouts (no feature flag in this phase). Overall, the design keeps existing provider adapters intact and focuses on a minimal, targeted UI extension plus backend runtime components.

## 2. Requirements & Assumptions
### Functional Requirements
- Central router computes a RoutingPlan from resolved ServiceConfig and live signals (FR-001).
- Admission control with ETS counters for active requests/streams (FR-002).
- Circuit breakers per RegisteredModel with closed/open/half_open (FR-003).
- Request-type-aware thresholds (streaming vs non-streaming) (FR-004).
- Fast rejection if capacity exceeded or both models unhealthy (FR-005).
- Telemetry for routing decisions, reasons, queue/wait, and outcomes (FR-006).
- Preserve FeatureConfig and section override resolution (FR-007).
- Each ServiceConfig owns editable routing parameters (no shared policies) (FR-008).
- Read-only health indicators in ServiceConfig UI (FR-011).
- ServiceConfig editor extended for routing parameters (FR-012).
- Operational introspection for breaker/counter state (FR-009).

### Non-Functional Requirements
- Router decision p95 < 5ms, p50 < 2ms at 2k concurrent requests.
- Rejected requests respond within 200ms end-to-end.
- Streaming requests must not starve the hackney pool.
- No PII in telemetry/logs; tenant isolation preserved.
- Rollout controlled via staged ServiceConfig updates with straightforward rollback by restoring prior values.

### Explicit Assumptions
- Routing policy parameters will be stored directly on `completions_service_configs` (no shared policy table). Impact: admin UI and migrations touch existing ServiceConfig flows; avoids separate CRUD surface.
- In-memory breaker and counters are per node initially. Impact: in clustered deployments, breakers may diverge; we will instrument and document the behavior.
- ServiceConfig UI edits are limited to admins and mirror existing GenAI admin patterns. Impact: no new UI page or navigation.
- PRD section 11 includes stale migration notes; FDD supersedes schema details. Impact: update PRD in a follow-up if desired.

## 3. Torus Context Summary
From `guides/design/genai.md`, GenAI routing currently flows through `Oli.GenAI.Completions` (generate/stream) with provider implementations for OpenAI-compatible and Claude. `RegisteredModel` and `ServiceConfig` form the static routing config; `GenAI.FeatureConfig` associates features and section overrides. Streaming dialogue is handled by `Oli.GenAI.Dialogue.Server` (GenServer) and uses fallback to backup model on error. A dedicated hackney pool is started via `Oli.GenAI.HackneyPool` in `Oli.Application`. Admin GenAI UIs exist as LiveViews, including `OliWeb.GenAI.ServiceConfigsView`, which edits ServiceConfig name/primary/backup models and already follows established admin patterns. Feature flags are available via `Oli.ScopedFeatureFlags` with audited changes and per-section/project scope, but this feature does not add a new flag. Deployment supports clustering (per design docs), so node-local state must be considered and documented for multi-node behavior.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- **Oli.GenAI.Completions (existing)**: Retained as the provider dispatch layer (generate/stream) for a specific `RegisteredModel`. It remains the integration point with provider adapters and is not deleted. The router/execution layer sits above it and decides which model to call.
- **Oli.GenAI.Router**: Pure decision module that produces a `RoutingPlan` from request context + ServiceConfig policy + live signals (counters + breaker state). It does not call external providers.
- **Oli.GenAI.AdmissionControl**: ETS-backed counters for active requests and streams. Provides O(1) increments/decrements and `admit?/2` checks.
- **Oli.GenAI.BreakerSupervisor / BreakerRegistry / Breaker**: Dynamic supervisor + per-model GenServer that maintains rolling health, emits breaker state changes, and writes a snapshot into ETS for fast reads.
- **Oli.GenAI.Execution** (new helper): Wraps provider calls, applies RoutingPlan, updates counters, emits telemetry, handles fallback and backoff. It delegates actual model calls to `Oli.GenAI.Completions`.
- **Admin UI Extension**: `OliWeb.GenAI.ServiceConfigsView` adds fields for routing parameters and read-only health indicators (breaker state + counters).

### 4.2 State & Message Flow
1. A feature resolves ServiceConfig via existing FeatureConfig + section override logic.
2. Caller invokes `Oli.GenAI.Execution.generate/stream` (new) with `request_ctx` (feature, section_id, request_type, actor_id, service_config_id).
3. Router reads ETS counters and breaker snapshot; produces a `RoutingPlan` (selected model, fallback list, reason, timeouts, admission decision).
4. AdmissionControl increments counters (global and per-service-config) if admitted.
5. Execution issues provider call via `Oli.GenAI.Completions.generate/stream` (existing adapters), using the hackney pool.
6. On completion, Execution decrements counters and reports outcome to breaker process (success/error/timeout/429/latency).
7. If primary fails and fallback is allowed, Execution consults RoutingPlan fallback and repeats once.
8. Telemetry events emitted on decision, admission, provider outcome, and breaker state changes.

### 4.3 Supervision & Lifecycle
- Add a new supervised subtree in `Oli.Application`:
  - `{Registry, keys: :unique, name: Oli.GenAI.BreakerRegistry}`
  - `Oli.GenAI.BreakerSupervisor` (DynamicSupervisor)
  - `Oli.GenAI.AdmissionControl` (GenServer that owns ETS tables and provides init/cleanup)
- `Oli.GenAI.Breaker` processes are started on demand per `registered_model_id` and terminated if idle beyond TTL.
- ETS tables are owned by `Oli.GenAI.AdmissionControl` and recreated on restart; router falls back to static routing if ETS is unavailable.

### 4.4 Alternatives Considered
- **Use a third-party circuit breaker library (e.g., fuse)**: quicker to implement but less control over metrics, multi-signal thresholds, and per-model customization.
- **Global GenServer for all breakers**: simpler but a single bottleneck under high concurrency.
- **Distributed counters via Redis**: cross-node consistency but higher latency and operational cost; deferred for later phase.

## 5. Interfaces
### 5.1 HTTP/JSON APIs
- None planned for public use. Optional internal admin/debug endpoint can be added later for breaker/counter introspection.

### 5.2 LiveView
- `OliWeb.GenAI.ServiceConfigsView`:
  - Add fields for routing policy parameters to the existing form.
  - Add read-only health display (breaker state, recent error/429/latency snapshot, active request/stream counts).
  - Reuse existing `phx-submit="save"` and `toggle_editing` flows; validate policy fields in the ServiceConfig changeset.

### 5.3 Processes
- `Oli.GenAI.AdmissionControl`
  - `init/1`: create ETS tables (counters, health snapshots).
  - `increment/2`, `decrement/2`: use `:ets.update_counter` for atomic changes.
  - `read/1`: return counters for routing and UI.
- `Oli.GenAI.Breaker` (per RegisteredModel)
  - `handle_cast({:report, outcome})`: update rolling window buckets and state.
  - `handle_call(:status, ...)`: return breaker state.
  - Writes snapshot to ETS for router/UI reads.

## 6. Data Model & Storage
### 6.1 Ecto Schemas
Add routing policy fields to `completions_service_configs` (exact naming may vary):
- `routing_soft_limit` (integer, >= 0)
- `routing_hard_limit` (integer, >= 0)
- `routing_stream_soft_limit` (integer, >= 0)
- `routing_stream_hard_limit` (integer, >= 0)
- `routing_breaker_error_rate_threshold` (numeric or float, 0.0..1.0)
- `routing_breaker_429_threshold` (numeric or float, 0.0..1.0)
- `routing_breaker_latency_p95_ms` (integer, >= 0)
- `routing_open_cooldown_ms` (integer, >= 0)
- `routing_half_open_probe_count` (integer, >= 0)
- `routing_timeout_ms` (integer, >= 0)
- `routing_connect_timeout_ms` (integer, >= 0)

Migration plan (online-safe):
1. Add nullable columns with defaults in a first migration.
2. Backfill existing ServiceConfig rows with conservative defaults.
3. Add NOT NULL + CHECK constraints in a second migration.

Constraints:
- `routing_soft_limit <= routing_hard_limit`
- `routing_stream_soft_limit <= routing_stream_hard_limit`
- Thresholds within range 0.0..1.0.

### 6.2 Query Performance
- ServiceConfig list queries already preload models; added columns do not change query shape.
- Admin UI should avoid per-row joins by using existing `Oli.GenAI.service_configs/0` query.
- Any health indicators read from ETS; no DB reads per refresh.

## 7. Consistency & Transactions
- ServiceConfig updates (including routing policy fields) remain single-row updates; use existing `ServiceConfig.changeset/2` with validations.
- Routing execution uses in-memory counters; counters are eventually consistent across nodes.
- Breaker state updates are idempotent per outcome event and tolerant of duplicate reports.

## 8. Caching Strategy
- ETS table `:genai_counters` for active request/stream counts (keyed by `{:service_config, id}` and optionally `{:service_config, id, section_id}`).
- ETS table `:genai_breaker_snapshots` for fast read of breaker state and recent metrics.
- TTL-based cleanup for per-section counters to prevent unbounded growth.

## 9. Performance and Scalability Plan
### 9.1 Budgets
- Router decision: p50 < 2ms, p95 < 5ms.
- ETS memory: cap at ~50k keys (bounded by active sections and models).
- Repo pool: unchanged; no new DB round trips on request path.

### 9.2 Load Tests
- None

### 9.3 Hotspots & Mitigations
- Hotspot: breaker GenServer mailbox under high error volume → mitigate with bucketed metrics and `cast` updates.
- Hotspot: ETS contention → use `read_concurrency` and `write_concurrency` options.
- Hotspot: LiveView refresh on health indicators → throttle refresh interval (e.g., 5–10s) and only read ETS.

## 10. Failure Modes & Resilience
- Provider 429/5xx/timeouts → breaker opens, routes to backup; telemetry records reason.
- Both models unhealthy → fast failure with standard error message; no pool wait.
- Router/ETS unavailable → fall back to static Primary/Backup routing.
- Node restart → counters/breakers reset; defaults still protect pool via hard limits and open cooldown on next signals.

## 11. Observability
Telemetry events (examples):
- `[:oli, :genai, :router, :decision]` measurements: `%{duration_ms}` metadata: `%{service_config_id, registered_model_id, reason, request_type, section_id}`
- `[:oli, :genai, :router, :admission]` measurements: `%{admitted: 0|1}` metadata: `%{hard_limit, soft_limit, counts}`
- `[:oli, :genai, :provider, :stop]` measurements: `%{duration_ms}` metadata: `%{provider, model, outcome, http_status}`
- `[:oli, :genai, :breaker, :state_change]` measurements: `%{state}` metadata: `%{registered_model_id, reason}`

AppSignal dashboards: routing decisions by reason, rejection counts, breaker open counts, per-model latency p95.

## 12. Security & Privacy
- Admin-only access to ServiceConfig editing and routing policy fields.
- Health indicators are read-only and exclude any PII.
- Telemetry metadata uses internal IDs only; no user content or prompts.

## 13. Testing Strategy
- Unit tests for router policies (threshold boundaries, streaming vs non-streaming).
- Property tests for breaker state transitions and windowed metrics.
- LiveView tests for ServiceConfig form validation and persistence.
- Concurrency tests for ETS counters (increment/decrement correctness under load).
- Failure injection tests for provider 429/timeouts to verify breaker open and fallback.

## 15. Risks & Mitigations
- Multi-node divergence of breaker state → document behavior; consider future distributed coordination (PubSub or external store).
- Miscalibrated thresholds → ship conservative defaults and expose metrics for tuning.
- UI complexity creep → keep edits in existing ServiceConfig view; no new admin navigation.

## 16. Open Questions & Follow-ups
- Should breaker state be coordinated across nodes, and if so via PubSub or external store?
- What default policy values are acceptable for streaming vs non-streaming requests?
- Should counters be strictly per ServiceConfig or also per section for fairness?
- Do we need per-user rate limiting in this phase?
- Should we add a lightweight admin debug endpoint for breaker/counter inspection?

## 17. References
- Supervision Principles · https://www.erlang.org/doc/design_principles/sup_princ.html · Accessed 2026-01-23
- Overview of Design Principles · https://www.erlang.org/doc/design_principles/des_princ.html · Accessed 2026-01-23
- Supervisor (Elixir v1.19) · https://hexdocs.pm/elixir/Supervisor.html · Accessed 2026-01-23
- GenServer (Elixir v1.19) · https://hexdocs.pm/elixir/GenServer.html · Accessed 2026-01-23
- Registry (Elixir v1.19) · https://hexdocs.pm/elixir/Registry.html · Accessed 2026-01-23
- ets (Erlang) · https://www.erlang.org/doc/man/ets.html · Accessed 2026-01-23
- counters (Erlang) · https://www.erlang.org/doc/man/counters.html · Accessed 2026-01-23
- Telemetry (Elixir) · https://hexdocs.pm/telemetry/readme.html · Accessed 2026-01-23
- Phoenix Telemetry · https://hexdocs.pm/phoenix/telemetry.html · Accessed 2026-01-23
