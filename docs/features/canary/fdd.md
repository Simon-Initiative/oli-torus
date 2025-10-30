**Executive Summary**
The canary rollout layer extends Torus’s scoped feature flag system to move select features through controlled stages—internal-only, 5%, 50%, and full availability—while retaining project/section scoping and honoring publisher opt-outs. Rollout state metadata, deterministic cohorting, and publisher-level exemptions ensure safety and contractual compliance. Internal actors, tagged via a new `is_internal` flag on authors/users, are the first cohort before percentages open to general users. Cohort decisions are sticky by hashing actor identifiers and are cached with Cachex for performance and cross-request consistency. Publisher-level overrides take precedence over rollout stages, preserving opt-out agreements or allowing accelerated inclusion. Operations benefit from fast rollback (set stage to `off`), full audit coverage, and telemetry for adoption and error tracking. The design remains horizontally scalable: decisions are mostly cache hits, Repo lookups are indexed, and no hot GenServers are introduced. Telemetry and logging integrate with AppSignal to maintain observability. Key risks include hash version drift, cache invalidation bugs, and LiveView complexity, all mitigated through documented hashing contracts, PubSub-driven cache busting plus TTLs, and integration tests.

**Requirements & Assumptions**
Functional Requirements
- FR1: Features marked as `:canary` must progress through `off → internal_only → five_percent → fifty_percent → full`.
- FR2: Scoped enablement persists—only resources with entries in `scoped_feature_flag_states` are evaluated for canary access.
- FR3: Internal actors (`is_internal = true`) gain access in `internal_only` and later stages
- FR4: Non-internal users participate in sticky 5%/50% cohorts based on deterministic hashing of `{feature, actor_type, actor_id}`.
- FR5: Publisher exemptions (`deny`, `force_enable`) override stage outcomes after scope evaluation but before cohort logic.
- FR6: Admin UI must manage stage transitions, show inheritance/global fallback, and edit publisher exemptions with audit coverage.
- FR7: Expose combined decision logic via `ScopedFeatureFlags.can_access?/3-4` supporting diagnostics and cache bypass.

Non-Functional Requirements
- NFR1: Decision latency P95 ≤ 5 ms local node, ≤ 15 ms cross-node.
- NFR2: Max one Repo query per table (`scoped_feature_flag_states`, `scoped_feature_rollouts`, `scoped_feature_exemptions`) on cache miss.
- NFR3: Support ≥ 500 decisions/sec/node without Repo pool exhaustion (pool size 20).
- NFR4: Cohort cache hit rate ≥ 95%.
- NFR5: Instrumentation failures must not break access decisions; degrade gracefully.

Explicit Assumptions
- A1: Percentage stages are fixed at 5% and 50%; custom percentages out of scope (drives enum design).
- A2: Callers pass fully loaded project/section structs with `publisher_id`; otherwise `can_access?/3` fetches publisher via Repo.
- A3: Publisher relationships remain authoritative for opt-outs; institution-level overrides not required.
- A4: Cachex already supervised in Torus runtime; new caches attach to existing supervisor.
- A5: Single Erlang cluster per deployment; per-node caches acceptable with PubSub invalidation. False assumptions imply additional schema or infra work.

**Torus Context Summary**
- `Oli.ScopedFeatureFlags` handles feature definitions, enable/disable flows, and auditing; LiveView component in `OliWeb.Components.ScopedFeatureFlagsComponent` presents toggles.
- `scoped_feature_flag_states` stores resource-specific flags (presence = enabled).
- Publishers live under `Oli.Inventories`; projects/sections reference them.
- Guides stress immutable publications, tenant boundaries, and audit compliance; scoped feature doc clarifies compile-time safety and state storage.
- Repo operations funnel through `Oli.Repo`; telemetry via :telemetry/AppSignal available.
- No existing canary support; new rollouts/exemptions extend this context.

**Proposed Design**

*Component Roles & Interactions*
- Extend `Oli.ScopedFeatureFlags` with decision API, rollout setters, cache invalidation, and telemetry hooks.
- New `Oli.ScopedFeatureFlags.Rollouts` module encapsulates persistence for rollout stages/exemptions.
- Ecto schemas: `ScopedFeatureRollout`, `ScopedFeatureExemption`.
- LiveView enhancements surface canary controls and exemption management.
- Author and user admin screens expose a system-admin-only `is_internal` checkbox, persisting the flag through existing account contexts with auditing.
- Cachex tables store stage resolutions and cohort results.
- Phoenix PubSub topic (`"feature_rollouts"`) broadcasts invalidation events.

*State & Message Flow*
1. `can_access?/3` ensures feature defined and scope enabled via existing `enabled?/2`.
2. Determine publisher (preload or Repo lookup). Check exemption table; `deny` returns false immediately.
3. Resolve rollout stage by checking project, section, then global rollout entries; results cached.
4. Apply `force_enable` (true unless stage `off`).
5. Evaluate stage: internal-only uses `actor.is_internal`; percentage stages use cached deterministic hash; full grants access unless `deny`.
6. Emit telemetry with stage, result, cache hit. Cache entries TTL-managed.

*Supervision & Lifecycle*
- No new supervisors; rely on existing Cachex supervisor for two caches (`:feature_flag_stage`, `:feature_flag_cohorts`).
- Repo transactions wrap stage/exemption mutations with audit on success.
- PubSub broadcasts triggered post-commit to invalidate caches; receiving LiveViews refresh assigns.

*Alternatives Considered*
- Third-party flag service (LaunchDarkly/Flagsmith) rejected: added latency, weaker tenant scoping.
- Inline JSON metadata on `scoped_feature_flag_states` rejected: mixes scoped-only and canary semantics, complicates migrations.
- Random database sampling rejected: non-deterministic per request, weak stickiness guarantees.
- Dedicated GenServer per feature rejected: stateful bottleneck, higher ops burden.

**Interfaces**

*HTTP/JSON APIs*
- No new public REST endpoints. Potential future read-only admin API noted but not in scope.

*LiveView*
- Update `ScopedFeatureFlagsComponent` events:
  - `"set_rollout"`: validates stage transitions and persists via Rollouts context.
  - `"toggle_exemption"`: toggles publisher effect; requires admin authorization.
- Assigns: `:current_stage`, `:inherited_stage`, `:publisher_status`, `:stage_history`.
- Subscribe to `"feature_rollouts"` topic; handle `{:invalidate, feature}` by refreshing relevant assigns.
- Update account detail LiveViews/pages to render a system-admin-only `is_internal` checkbox, wiring `handle_event/3` callbacks through existing account contexts to persist the flag and emit audit events.

*Processes*
- Cachex tables (per node). Keys: stage cache `{feature, scope_type, scope_id}`, cohort cache `{feature, actor_type, actor_id}`.
- No bespoke GenServers; rely on PubSub for invalidation fan-out.

**Data Model & Storage**
- `ScopedFeatureRollout` (`scoped_feature_rollouts`):
  - Fields: `feature_name` (string, indexed), `scope_type` (enum `:global|:project|:section`), `scope_id` (nullable), `stage` (enum `:off|:internal_only|:five_percent|:fifty_percent|:full`), `rollout_percentage` (int generated), `updated_by_id`, timestamps.
  - Unique index `(feature_name, scope_type, scope_id)`; partial unique for `scope_type = 'global' AND scope_id IS NULL`.
- `ScopedFeatureExemption` (`scoped_feature_exemptions`):
  - Fields: `feature_name`, `publisher_id` (FK), `effect` enum (`:deny|:force_enable`), `note`, `updated_by_id`, timestamps.
  - Unique index `(feature_name, publisher_id)`.
- Extend `authors` and `users` schemas with `is_internal` boolean default false, not null; create partial index on true values for admin queries (`CREATE INDEX CONCURRENTLY ON ... (id) WHERE is_internal`).
- Migration strategy: additive columns with defaults, concurrent indexes, wrap stage/exemption tables in single migration; add Ecto enum types.
- Preload publishers when loading projects/sections to avoid per-request lookup.

**Consistency & Transactions**
- Stage/exemption mutations use `Repo.transaction/1`; audit captured within same transaction to avoid divergence.
- `can_access?/3` read-only; idempotent.
- Cache invalidation triggered only after successful commit; on failure nothing emitted.
- Deterministic hashing ensures consistency; document hash version constant to prevent accidental cohort reshuffle.

**Caching Strategy**
- `:feature_flag_stage` Cachex cache: TTL 5 minutes, write-through on miss, keyed by `{feature, scope_type, scope_id}`.
- `:feature_flag_cohorts` Cachex cache: TTL 30 minutes, stores boolean result with metadata (`stage`, `hash_version`); keys `{feature, actor_type, actor_id}`.
- Invalidate caches via PubSub broadcast `{:invalidate, feature, scope_type, scope_id}` on stage/exemption change; each node deletes matching keys.
- Cache misses fall back to Repo lookups; caches sized to cap at ~200 k entries per node (≈20 MB).
- No PII in cache keys/data.

**Performance and Scalability Plan**
Budgets
- P50 < 1 ms, P95 < 5 ms, P99 < 10 ms per decision.
- Repo QPS from decisions < 50/s/node with 95% cache hit; Repo pool size remains 20 (default).
- Cache memory < 50 MB per node; monitor via Cachex stats.

Hotspots & Mitigations
- Cohort hashing CPU: minimal; ensure compiled constants.
- Cache invalidation fan-out: limit PubSub payload and frequency (batch consecutive updates).
- LiveView rerenders: preload necessary data, avoid repeated Repo calls; use `temporary_assigns`.
- Potential N+1 on admin list: use Repo preload for publishers/features when listing.

**Failure Modes & Resilience**
- Repo unavailable: return `false` (fail closed) and log warning; telemetry increments `decision_repo_error`.
- Cachex failure: bypass cache and recompute; if repeated, emit alert but keep serving.
- PubSub down: rely on TTL expiration; log warning.
- Stage change conflict: raise user-friendly error; LiveView refreshes latest state.
- Hash version drift: treat change as migration; require release note and explicit cohort impact communication plan.

**Observability**
- Telemetry `[:torus, :feature_flag, :decision]` with measurements `%{duration: native_time}` and metadata `%{feature, stage, scope_type, scope_id, publisher_id, actor_type, result, cache_hit, hash_version}`.
- Telemetry `[:torus, :feature_flag, :rollout_stage_changed]` with metadata `%{feature, scope_type, scope_id, from_stage, to_stage, actor_id}`.
- AppSignal counters for decisions, errors, cache hit rate; alerts on error rate >1% or cache hit <80%.
- Structured logs on stage/exemption updates at info level with audit correlation (`audit_event_id`).
- Consider OpenTelemetry tracing around `can_access?/3` for high-value features (sampling 10%).

**Security & Privacy**
- Authorization: restrict rollout/exemption mutations and `is_internal` toggle to system admins; verify via `Oli.Accounts` roles before executing.
- Multi-tenancy: ensure scope/publisher combos align with tenant; guard queries with tenant filters where applicable.
- `is_internal` flag managed via system-admin-only checkbox; each change triggers an audit event capturing actor and note.
- No additional PII stored; caches avoid emails/names.
- Audit capture remains mandatory for stage/exemption updates with actor details and notes.

**Testing Strategy**
- Unit tests covering all stage transitions, coercing `is_internal`, `deny`/`force_enable`, cache hit/miss behavior.
- Property tests verifying cohort stickiness and boundary conditions (5% hash threshold).
- Integration tests for LiveView component to verify UI state, PubSub invalidation, and permission checks.
- Migration tests: up/down ensures no data loss, validates defaults.
- Failure injection: simulate Repo outage using Mox to ensure fail-closed pathway works.
- Telemetry tests capturing emitted events via `:telemetry.attach_many`.

**Risks & Mitigations**
- R1: Hash algorithm change reshuffles cohorts → Document `@cohort_hash_version`; require explicit migration and product approval before change.
- R2: Cache invalidation missing leads to stale access decisions → Use PubSub invalidation plus short TTL; add health check verifying stage change propagation.
- R3: Admin misconfiguration (e.g., skipping stage) → UI enforces sequential progression; confirm dialogs for demotions.
- R4: Database bloat from rollout tables → monitor size; scheduled cleanup for deprecated features.
- R5: Publisher exemption conflicts with business rules → require note entry; add weekly report of exemptions for review.

**Open Questions & Follow-ups**
- Q1: Should `force_enable` override `off` stage or only apply when stage ≥ internal_only? (recommend: respect `off`; product decision pending).
- Q2: Do we need scheduled stage promotions (`starts_at`)? Schema can support; confirm MVP priority.
- Q3: Should adoption telemetry roll up to dashboard (e.g., Prometheus)? Need stakeholder sign-off.
- Q4: Are there external cohorts (institutions) needing exemptions? If yes, extend schema.
- Q5: What is acceptable delay for cache invalidation across nodes? Need SRE agreement.

**References**
- Cachex: Advanced Caching for Elixir · https://hexdocs.pm/cachex/readme.html · Accessed 2025-10-30
- Ecto.Enum — Ecto v3.11.2 · https://hexdocs.pm/ecto/Ecto.Enum.html · Accessed 2025-10-30
- Phoenix PubSub · https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html · Accessed 2025-10-30
- Telemetry for Elixir · https://hexdocs.pm/telemetry/readme.html · Accessed 2025-10-30
- AppSignal for Phoenix · https://docs.appsignal.com/elixir/index.html · Accessed 2025-10-30
