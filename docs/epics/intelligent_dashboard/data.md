# Intelligent Dashboard Data Design

Last updated: 2026-02-10

This document captures the data workstream design for `MER-5248` (global filter/scope) and `MER-5266` (CSV export), and defines the shared data backbone used by all tiles and AI features.

## Data Workstream Design (Draft v1)

### Design Goals

1. Data orchestration lives outside UI code in `Oli` namespace modules.
2. Execute the smallest feasible query set to produce a shared dashboard data snapshot.
3. Integrate with LiveView asynchronously so first render is fast, then tiles hydrate incrementally.
4. Cache computed results and avoid query churn when users toggle filters quickly.
5. Reuse the exact same computed snapshot for CSV zip export (transform-only path).
6. Handle rapid filter cycling without UI blocking or unbounded background query fan-out.

### Proposed Module Boundaries (Oli namespace)

Shared dashboard infrastructure (reusable across dashboard products):

- `Oli.Dashboard.Scope`
  - Canonical scope model and normalization.
  - Resolves `Entire Course`, `Unit`, `Module`, and any supported container IDs.

- `Oli.Dashboard.Oracle`
  - Behaviour defining a strict contract every data source/oracle implements.
  - Prevents ad-hoc one-off query additions in LiveView/tile code.

- `Oli.Dashboard.OracleRegistry`
  - Catalog of available oracles and their dependencies.
  - Maps tile IDs to required oracle subsets.

- `Oli.Dashboard.OracleRuntime`
  - Async oracle loader for a scope request.
  - Publishes incremental oracle completion events.
  - Enforces per-session bounded request policy (1 in-flight scope + 1 queued scope).

- `Oli.Dashboard.Snapshot.Assembler`
  - Composes normalized snapshots from completed oracle outputs.
  - Produces reusable data views for tile consumers.

- `Oli.Dashboard.Cache`
  - In-process cache manager used by dashboard LiveView processes.
  - Implements `InProcess` oracle cache with bounded capacity and TTL.
  - Handles read-through, coalescing, max-capacity enforcement, and eviction in-process.

- `Oli.Dashboard.RevisitCache`
  - Node-wide external cache process for short-lived revisit acceleration.
  - Stores only the currently viewed container for selected oracles, keyed per user.
  - Queried only during parameterized revisit flows.

- `Oli.Dashboard.LiveDataCoordinator`
  - UI-agnostic state machine for async loading policy:
  - one in-flight request
  - one queued request (replace-on-newest behavior)
  - stale result suppression via request tokens

Instructor dashboard composition (product-specific):

- `Oli.InstructorDashboard.DataSnapshot`
  - Public API for fetching instructor dashboard scoped data views.
  - Wires instructor oracle bindings into `Oli.Dashboard.*` runtime/cache/snapshot services.

- `Oli.InstructorDashboard.DataSnapshot.CsvExport`
  - Instructor dashboard-specific transform from assembled snapshot -> CSV files -> zip payload.
  - No direct analytics queries.

### Oracle Framework (Core Distinction)

Design rule: dashboard queries are organized around reusable domain oracles, not current tile-specific implementations.

Illustrative oracle capability slots (draft, non-binding in lane-1):
- `roster_capability_oracle`
  - Student identity and roster data (name, email, enrollment/activity anchors).
- `progress_capability_oracle`
  - Progress metrics across scoped containers and completion-threshold-aware aggregates.
- `proficiency_capability_oracle`
  - Objective proficiency metrics and low-proficiency indicators.
- `assessment_capability_oracle`
  - Assessment completion/performance/distribution summaries.
- `activity_capability_oracle` (optional split)
  - Last activity and inactivity support signals.
- `content_structure_capability_oracle`
  - Scoped hierarchy metadata used by filter navigation and labels.
- `ai_context_capability_oracle` (derived)
  - AI-ready context projection assembled from normalized oracle outputs (not by direct oracle-to-oracle calls).

Important: exact concrete instructor oracle keys/modules and final payload shapes are intentionally tile-driven and finalized in tile implementation stories. Lane-1 defines contracts, dependency model, and orchestration behavior.

Oracle independence rule:
- Oracle implementations should not directly call or depend on other oracle implementations.
- Every oracle receives the same request context and resolves its own data independently.
- Cross-oracle composition happens only in orchestrator/assembler layers, not inside oracle modules.

Notional `OracleContext` struct:

```elixir
%Oli.Dashboard.OracleContext{
  dashboard_context_type: dashboard_context_type,
  dashboard_context_id: dashboard_context_id,
  user_id: user_id,
  container_id: container_id
}
```

Context notes:
- `dashboard_context_type`: context kind (for example `:section`, `:project`).
- `dashboard_context_id`: identifier for the selected dashboard context.
- `user_id`: current user executing the dashboard request (for auth/personalization/audit-sensitive behavior).
- `container_id`: selected scope container (course/unit/module/etc.).

Mapping note:
- For Instructor Dashboard, `dashboard_context_type = :section` and `dashboard_context_id = section_id`.
- Other dashboard products can map this to `:project` (or other context kinds) without changing oracle contracts.

Each oracle can expose:
- normalized data payload
- helper functions for common filtering/projections beyond global scope
- version/hash metadata for cache and invalidation decisions

Oracle behaviour (conceptual):
- `key/0`
- `load(%OracleContext{}, opts) :: {:ok, payload} | {:error, reason}`
- `project(payload, projection_opts) :: projection`
- `version/0`

### Tile Dependency Contract

Tiles declare required and optional oracle dependencies explicitly.

Illustrative examples (non-binding):
- Progress Tile requires: `progress_capability_oracle`; optional: `content_structure_capability_oracle`
- Student Support Tile requires: `roster_capability_oracle`, `progress_capability_oracle`, `proficiency_capability_oracle`; optional: `activity_capability_oracle`
- Summary Tile requires: `progress_capability_oracle`, `proficiency_capability_oracle`, `assessment_capability_oracle`

Render rules:
- Tile renders when all required oracles are ready.
- Tile may partially render when optional oracles are still loading.
- Tile never issues raw DB queries directly; it consumes oracle data/projections only.

### Canonical Snapshot Contract

The assembler returns a single scoped snapshot payload composed from oracle outputs:

- metadata block (course, section, scope, timestamp, timezone, thresholds)
- oracle payload map keyed by oracle name
- derived dashboard projection blocks for:
  - summary metrics
  - progress
  - student support
  - challenging objectives
  - assessments
  - AI context

This snapshot is the single source for:
- live tile rendering
- AI recommendation input shaping
- CSV export transformation

### Minimal Query Strategy

Design principle: query once per oracle domain and reuse broadly; do not query per tile.

Approach:
- Define a bounded query plan per oracle (stable query count, no N+1).
- Reuse shared intermediate relations/CTEs across oracles where appropriate.
- Build projections from oracle payloads in memory where feasible.
- Prefer set-based aggregate queries over iterative per-item queries.
- Avoid tile-level DB access entirely.

Implementation direction:
- OracleRuntime executes deterministic oracle load scheduling from the requested oracle set.
- Oracles may run with bounded intra-scope concurrency (small fixed pool) but always under one active scope request.
- Shared intermediate data may be reused by the assembler/projection layer after independent oracle loads complete.
- If needed, phase to precomputed summary tables/materialized support for large sections.

Governance guardrail:
- New tile features must map to existing oracles first.
- New queries are introduced by extending oracle contracts, not by adding tile-local query paths.

### LiveView Integration Pattern (Fast Mount + Incremental Hydration)

Initial mount:
- LiveView renders chrome immediately with placeholder/loading tile states.
- LiveView asks coordinator to load default scope request token.
- Coordinator resolves required oracle set for initially visible tiles.
- Coordinator first consults in-process cache state owned by the current LiveView.
- External revisit cache is not consulted on base mount with no container params.
- If cached oracle payloads/snapshot exist, hydrate immediately.
- Missing oracle payloads load in background; tiles hydrate as dependencies are satisfied.

Incremental behavior:
- Tiles subscribe to oracle-ready and projection-ready events.
- Example: if Progress tile depends only on `progress_capability_oracle`, it can render before `roster_capability_oracle` finishes.
- Example: a tile can render chart shell from one oracle and enrich details after second oracle is ready.
- UI remains interactive while data computation continues.
- Any stale task result is ignored via request token mismatch.

Dashboard re-entry behavior:
- A user can navigate away (for drill-down) and return with a warm path for the previously viewed container.
- On revisit with explicit container params, LiveView may consult the node-wide per-user revisit cache.
- Revisit cache is only for short-lived back-navigation acceleration, not a primary runtime cache.

### Rapid Filter Cycling Control Policy

Required policy (adopted):
- At most 1 in-flight scope build at any time per dashboard session.
- At most 1 queued scope build.
- If new scope arrives while queue occupied, queued scope is replaced by latest scope.

State machine sketch:
- `idle` -> start request `S1` (`in_flight=S1`, `queued=nil`)
- user selects `S2` while `S1` running -> `queued=S2`
- user selects `S3` while `S1` running and `queued=S2` -> replace queue `queued=S3`
- `S1` completes -> if `queued` exists, start queued and clear queue
- only apply results if result token equals current expected token

Benefits:
- bounded backend work under extreme filter thrashing
- latest-intent behavior for the user
- no UI blocking

Optional enhancement after baseline:
- short debounce (for example 100-200ms) before queue replacement commits
- cooperative cancellation if query/task cancellation is safe in this path

### Cache Strategy

Cache level:
- `InProcess` cache (LiveView-local):
  - primary runtime cache for the active interaction window inside one LiveView process.
  - stores a collection of oracle payloads per container.
- `Revisit` cache (node-wide external process):
  - short-lived cache for return navigation only.
  - stores a collection of selected oracle payloads for one container, for one specific user.

Cache scope model:
- Container is the generic scope unit (`Entire Course`, `Unit`, `Module`, etc.).
- InProcess oracle entries are stored at `(dashboard_context_id, container_id_or_scope, oracle_key)` within a single LiveView process.
- Revisit cache entries are stored at `(user_id, dashboard_context_id, container_id_or_scope, oracle_key)`.
- Revisit cache is node-wide but intentionally narrow in scope and TTL.

Granularity and completeness model:
- Cache is oracle-granular, not container-blob-granular.
- A container cache can be:
  - `incomplete`: only a subset of required oracles are cached
  - `complete`: all required oracles for that container are cached
- Oracle results are written to cache immediately upon completion, even if other required oracles are still pending.
- Cache writes do not wait for a full "container complete" barrier.
- Late oracle completion must still populate cache for its original `(section, container, oracle)` key, even if the user has already navigated to another container.
- On returning to a container, coordinator resolves only missing required oracles:
  - cached required oracles are read immediately
  - missing required oracles continue/trigger load
  - once late oracle is cached, subsequent return gets full cache hit
- This guarantees the scenario:
  - container A gets 3/4 oracles cached
  - user moves to container B
  - A's 4th oracle finishes later
  - user returns to A and receives cache hits for all 4 oracles

Cache key shape (example):
- InProcess oracle payload key:
- `{:dashboard_oracle, oracle_key, dashboard_context_id, container_type, container_id_or_nil, oracle_version, data_version}`
- Revisit oracle payload key:
- `{:dashboard_revisit_oracle, user_id, dashboard_context_id, container_type, container_id_or_nil, oracle_key, oracle_version, data_version}`

Capacity and eviction (InProcess cache):
- Capacity is not a single fixed count for all sections.
- Max cached containers is tiered by section enrollment size.
- Capacity is measured by number of containers cached, not total oracle entries.
- A single container may contain multiple oracle payloads (typically 3-5), but still counts as one container toward the limit.
- Required env vars (all configurable):
  - `INSTRUCTOR_DASHBOARD_CACHE_SMALL_SECTION_MAX_ENROLLMENTS` (default: `50`)
  - `INSTRUCTOR_DASHBOARD_CACHE_NORMAL_SECTION_MAX_ENROLLMENTS` (default: `500`)
  - `INSTRUCTOR_DASHBOARD_CACHE_SMALL_SECTION_MAX_CONTAINERS` (default: `12`)
  - `INSTRUCTOR_DASHBOARD_CACHE_NORMAL_SECTION_MAX_CONTAINERS` (default: `8`)
  - `INSTRUCTOR_DASHBOARD_CACHE_LARGE_SECTION_MAX_CONTAINERS` (default: `3`)
- Tiering rule:
  - enrollments `< small_threshold` -> small container max
  - enrollments `< normal_threshold` -> normal container max
  - enrollments `>= normal_threshold` -> large container max
- Eviction is container-scoped:
  - when a container is evicted, all oracle entries for `(dashboard_context_id, container)` are evicted together.
- Eviction policy is least-recently-used (LRU), based on last access timestamp.

TTL policy:
- In-process cache TTL:
  - `INSTRUCTOR_DASHBOARD_INPROCESS_CACHE_TTL_MINUTES` (default: `15`)
- Node-wide revisit cache TTL:
  - `INSTRUCTOR_DASHBOARD_REVISIT_CACHE_TTL_MINUTES` (default: `5`)
- Do not rely on complex per-oracle invalidation in this phase.
- TTL is the primary freshness control plus optional manual/emergency flush hooks.

Revisit cache behavior (strict):
- Revisit cache stores only currently viewed container payloads for one specific user.
- The exact oracle subset is defined by instructor capability bindings from tile implementations.
- Initial candidate subset (non-binding) includes:
  - `progress_capability_oracle`
  - `proficiency_capability_oracle`
  - `roster_capability_oracle`
  - `assessment_capability_oracle`
- Revisit cache is checked only when LiveView is entered with explicit container params (for example, return via browser history).
- Revisit cache is not checked during a base dashboard mount that does not preselect a specific container.

Policy:
- read-through cache via `Oli.InstructorDashboard.DataSnapshot.get_or_build/…`
- per-oracle request coalescing: concurrent misses for same oracle key share one build
- normal lookup order: `InProcess` -> build/load
- on eligible revisit flow: `InProcess` -> `Revisit` -> build/load
- cache write policy: write per-oracle completion as soon as each oracle resolves
- stale-write guard: oracle write is accepted only if the result matches current section/container/oracle/version identity
- optional coarse invalidation hooks (for emergency/manual flush) may exist, but are not required for normal freshness behavior

Expected effects:
- fast back-and-forth between recently viewed modules/units
- reduced repeated heavy query execution
- bounded in-process memory usage by enrollment-tiered container limits
- fast drill-down-and-return behavior via short-lived node-wide per-user revisit cache
- deterministic response times after warm-up

### CSV Export Reuse Path (`MER-5266`)

CSV generation pipeline:
1. Resolve current scope.
2. Fetch snapshot via same `Oli.InstructorDashboard.DataSnapshot` API (prefer cache hit).
3. Transform snapshot blocks into CSV row sets.
4. Zip files and stream download.

Constraint:
- CSV export should not execute independent analytics queries when snapshot is available.
- Any fallback query path (if ever needed) should still call the same builder contract.

### Performance and Reliability Guardrails

- Enforce bounded concurrency per dashboard session (1 active + 1 queued).
- Instrument:
  - cache hit rate by scope type
  - in-process cache entry count and container eviction rate
  - revisit cache hit rate
  - snapshot build duration percentiles
  - queue replacement count
  - stale result discard count
  - CSV generation latency
- Add hard timeout and safe fallback state for snapshot builds.
- Keep UI responsive with explicit loading/partial/failed states per tile.

### Delivery Breakdown for This Workstream

Phase A: foundation
- Scope model + oracle behaviour + oracle registry.
- Snapshot contract + cache wrapper.
- Coordinator state machine and tokenized async handling.

Phase B: shared builder
- Implement tile-driven oracle bindings/sets and bounded query plans.
- Implement assembler from oracle outputs to snapshot/projections.
- Validate data parity against existing views for core metrics.

Phase C: LiveView integration
- Fast mount + dependency-aware incremental tile hydration + filter-thrash policy.

Phase D: CSV transform
- Snapshot-to-CSV adapters and zip assembly.

Phase E: hardening
- Load/perf tests for rapid filter cycling across large courses.
- Cache tuning and invalidation tuning.
