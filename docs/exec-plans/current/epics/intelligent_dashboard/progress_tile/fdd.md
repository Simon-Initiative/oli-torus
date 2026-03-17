# Progress Tile - Functional Design Document

## 1. Executive Summary
Implement `MER-5251` as a dashboard-local mixed LiveView feature that consumes oracle-backed snapshot data, derives a Progress-tile-specific projection, and renders the tile through a `Phoenix.LiveComponent` plus a thin browser hook for Vega-Lite charting. The simplest adequate design is to keep data access in existing dashboard oracle/runtime layers, keep threshold and schedule-aware derivation in a Progress tile projection module, and keep tile-local interaction state in the tile component rather than pushing it into the global dashboard shell or into the chart runtime.

This design aligns with the validated PRD, the Intelligent Dashboard UI composition baseline, and the oracle-first architecture established by the epic. It intentionally avoids introducing tile-specific analytics queries, a generic chart abstraction, or a new shared dashboard primitive.

Based on follow-up clarification from Jess Fortunato, the x-axis must render the direct children of the selected scope even when those children are structurally mixed. When a scope contains mixed direct-child resource types, the axis label should use generic copy such as `Course Content` rather than implying a single homogeneous child type.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` through `FR-014` from `requirements.yml` define the required tile behavior, including scoped rendering, threshold control, count/percentage toggle, schedule-aware overlays, pagination, empty states, and accessibility.
  - The tile must consume dashboard data through the oracle/snapshot path rather than querying directly from UI code.
  - The tile must navigate to `Insights > Content` via the existing instructor dashboard route contract.
- Non-functional requirements:
  - Accessibility and 200% zoom usability are first-class requirements.
  - Tile-local interactions must not produce stale chart state under rapid updates.
  - The design must stay consistent with LiveView ownership, existing token usage, and dashboard cache/runtime behavior.
- Assumptions:
  - The final concrete oracle pair for this tile is `Oli.InstructorDashboard.Oracles.ProgressBins` plus `Oli.InstructorDashboard.Oracles.ScopeResources`, replacing the prototype’s `Progress` and `Contents` oracles.
  - The dashboard runtime already owns scope resolution, cache lookups, and stale-result suppression; this feature consumes those guarantees rather than reimplementing them.
  - A dedicated progress chart hook under `assets/src/hooks/` is acceptable if the existing `VegaLiteRenderer` path alone is not sufficient for tile-local interaction and rerender behavior.

## 3. Repository Context Summary
- What we know:
  - The instructor dashboard shell and section composition already exist in:
    - `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`
    - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`
    - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/engagement_section.ex`
    - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
  - The prototype already demonstrates the intended layering for Progress tile:
    - `lib/oli/instructor_dashboard/prototype/tiles/progress.ex`
    - `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`
  - The concrete-oracle work defines the target data contracts:
    - `ProgressBinsOracle` for per-container progress histograms
    - `ScopeResourcesOracle` for direct-child labels and ordering
  - Dashboard architecture guidance already states that tiles consume prepared view models and that browser hooks should remain thin.
  - `assets/src/hooks/student_support_chart.ts` provides a working baseline for a thin Vega-Lite LiveView hook with mount/update/destroy handling.
- Unknowns to confirm:
  - The exact schedule marker payload shape and which upstream module provides it to the snapshot/projection layer.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
The Progress tile implementation should be split into four concrete responsibilities:

1. Dashboard runtime and snapshot layer
   - Resolve required oracle payloads for the current dashboard scope.
   - Provide the tile with oracle results and any schedule context already available in the scoped snapshot bundle.

2. Progress tile projection module
   - Consume `ProgressBinsOracle`, `ScopeResourcesOracle`, and schedule context.
   - Derive tile-ready data: chart series, threshold-aware counts, percent values, axis label metadata, per-item resource-type metadata, schedule marker metadata, pagination slices, and empty-state metadata.
   - Expose a stable tile view model that is UI-facing but renderer-agnostic.

3. Progress tile LiveComponent
   - Own tile-local interaction state: selected threshold, y-axis mode, pagination window, and focus/announcement strings.
   - Render title, CTA, controls, empty states, and a chart mount target.
   - Recompute the tile projection or projected slice when tile-local state changes, without triggering tile-level analytics access.

4. Browser hook / chart runtime
   - Receive a prepared Vega-Lite spec or equivalent chart payload from the LiveComponent.
   - Render, update, and teardown the chart.
   - Forward semantic events only if needed; do not own completion logic, threshold logic, or authoritative state.

### 4.2 State & Data Flow
Primary flow:

1. `IntelligentDashboardTab` resolves the current dashboard scope and requests the visible dashboard section data through the existing dashboard runtime path.
2. The dashboard runtime retrieves cached or freshly loaded oracle payloads for the current scope.
3. The snapshot/projection layer hands the Progress tile its required oracle payloads:
   - progress bins by direct child container
   - direct child scope resources and labels
   - schedule metadata if present upstream
4. The Progress tile projection module builds a view model:
   - resolves the direct children of the current scope in course order, without assuming they are all the same resource type
   - aligns progress bins to ordered child containers
   - computes threshold-aware completion counts
   - derives count and percentage values
   - derives the axis label copy, including generic fallback such as `Course Content` when mixed direct-child types are present
   - derives pagination windows and empty-state semantics
   - decorates schedule/no-schedule output
5. The Progress tile LiveComponent renders the controls and sends the chart payload/spec to the browser hook.
6. The browser hook mounts or updates Vega-Lite.
7. When the instructor changes threshold, y-axis mode, or pagination:
   - the LiveComponent updates tile-local state
   - the LiveComponent syncs the navigation-relevant subset of tile state into namespaced URL params
   - the component rebuilds the tile projection or slice from already available snapshot data
   - the hook rerenders from the updated payload
8. When the global dashboard scope changes:
   - the dashboard runtime fetches the new scope’s oracle data
   - the tile receives a new base projection context
   - tile-local state is reset or clamped as needed for the new scope

### 4.3 Lifecycle & Ownership
- Dashboard shell ownership:
  - owns section visibility and overall scope identity
  - passes snapshot-backed tile inputs into the engagement section
- Progress tile ownership:
  - should graduate from placeholder function component to `Phoenix.LiveComponent`
  - owns threshold/mode/pagination state while persisting the navigation-relevant subset in namespaced URL params following the dashboard UI composition guidance
- Projection ownership:
  - lives in backend Elixir modules under the instructor dashboard domain, adjacent to or replacing the current prototype projection logic
  - remains free of HEEx, JS, and DOM concerns
  - owns the decision about whether the current scope is homogeneous or mixed for axis-copy purposes
- Chart runtime ownership:
  - limited to browser rendering lifecycle
  - no independent data fetching, aggregation, or schedule derivation

### 4.4 Alternatives Considered
- Keep the tile as a simple HEEx function component with most state in `IntelligentDashboardTab`
  - Rejected because threshold, mode, and pagination are tile-local concerns and would unnecessarily couple tile behavior to the dashboard shell.
- Push threshold/count-percentage logic into the chart hook or Vega-Lite spec only
  - Rejected because it weakens testability, accessibility control, and boundary discipline. Those rules belong in Elixir-side tile state and projection logic.
- Query tile-specific progress data directly from the tile component or hook
  - Rejected because it violates the epic’s oracle-first architecture and would bypass cache/coordinator semantics.
- Introduce a shared cross-tile chart abstraction before implementing this tile
  - Rejected because the repo does not yet justify a shared primitive here, and doing so would add speculative complexity.

## 5. Interfaces
- Dashboard runtime to tile projection input
  - Inputs:
    - scope identity: `section_id`, `container_type`, `container_id`
    - `ProgressBinsOracle` payload
    - `ScopeResourcesOracle` payload
    - optional schedule payload block
  - Output:
    - a Progress tile base projection input struct or map
- Progress tile projection interface
  - Suggested module:
    - `Oli.InstructorDashboard.ProgressTile.Projection`
  - Suggested functions:
    - `build(base_input, opts) :: {:ok, projection} | {:error, reason}`
    - `reproject(projection_input, tile_state) :: projection`
  - Projection output should include:
    - `axis_label`
    - `class_size`
    - `completion_threshold`
    - `y_axis_mode`
    - ordered `series` with per-item resource type metadata
    - `page_window` or equivalent pagination metadata
    - `schedule_marker`
    - `empty_state`
    - localized labels/tooltips keys or resolved text
- LiveComponent interface
  - Suggested module:
    - `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ProgressTile`
  - Inputs:
    - base projection input or prebuilt projection
    - section slug / dashboard scope identifiers for navigation
    - params map for namespaced tile state hydration and patch generation
  - Events:
    - `progress_tile_threshold_changed`
    - `progress_tile_mode_changed`
    - `progress_tile_page_changed`
    - `progress_tile_view_details`
  - URL param guidance:
    - use namespaced params such as `tile_progress[threshold]`, `tile_progress[mode]`, and `tile_progress[page]`
    - tile-param changes must not trigger scope-wide oracle reloads when dashboard scope identity is unchanged
- Browser hook interface
  - Suggested hook:
    - `ProgressTileChart`
  - DOM data contract:
    - chart target element id
    - serialized chart spec or serialized chart data payload
    - render token or equivalent update discriminator

## 6. Data Model & Storage
- No schema or migration changes are required.
- Persistent storage remains unchanged; the feature reads from existing progress-related data through oracle modules.
- New in-memory structs/maps are expected:
  - Progress tile projection input
  - Progress tile projection output
  - LiveComponent tile state
- Schedule metadata must remain read-only and sourced from existing delivery/dashboard data rather than persisted by this feature.

## 7. Consistency & Transactions
- No new transaction boundary is introduced.
- Oracle reads must remain deterministic for identical scope inputs.
- LiveComponent state transitions should be idempotent and latest-input-wins within a single LiveView session.
- Scope changes and tile-local changes must remain separated:
  - scope changes can invalidate the whole tile input
  - tile-local changes must only recalculate from already loaded snapshot data

## 8. Caching Strategy
- Reuse the existing dashboard cache/runtime behavior; this feature does not add a tile-specific cache.
- Oracle payload caching remains the responsibility of the dashboard runtime layers already defined by the epic.
- The tile may memoize or retain its current tile-local projection in assigns during a LiveView session, but should not introduce an additional cross-request cache.
- Pagination should slice already projected series in memory; it should not request a new oracle load.

## 9. Performance & Scalability Posture
- The design keeps the most expensive work in oracle execution and snapshot hydration, where caching and runtime coordination already exist.
- The tile projection should operate on bounded aggregated data:
  - direct child containers for the scope, including mixed resource types when present
  - histogram bins per container
  - no raw per-page or per-student payload required for the main chart
- Threshold and count/percentage changes should reproject from in-memory aggregated data only.
- Avoid rebuilding the entire dashboard shell for tile-local interactions.
- Avoid speculative chart abstractions that add render indirection or duplicate serialization work.

## 10. Failure Modes & Resilience
- Missing oracle payload
  - Tile renders a deterministic unavailable or loading state instead of partial broken chrome.
- Missing or ambiguous schedule metadata
  - Tile falls back to no-schedule messaging and omits schedule visuals unless the upstream contract clearly marks schedule data as present.
- Invalid or unserializable chart spec
  - Browser hook logs a scoped warning, finalizes prior view, and leaves the tile chrome intact with a non-crashing fallback state.
- Rapid sequence of scope and tile-local updates
  - LiveView authoritative state plus hook render-token suppression prevents stale chart takeover.
- Long labels or many child containers
  - Projection and UI must preserve truncation + accessible disclosure and expose pagination rather than allowing unreadable overflow.

## 11. Observability
- Emit telemetry for tile render and interaction outcomes:
  - `progress_tile.rendered`
  - `progress_tile.threshold_changed`
  - `progress_tile.mode_changed`
  - `progress_tile.pagination_changed`
  - `progress_tile.view_details_clicked`
- Track failure points separately:
  - projection build failure
  - missing required payloads
  - chart render failure in hook/browser runtime
- Include scope metadata where already available through dashboard context, without adding new PII fields.
- Prefer structured logs or telemetry metadata that make it possible to separate oracle/runtime failures from tile rendering failures.

## 12. Security & Privacy
- The tile remains instructor-only and scoped to the current section.
- The chart shows aggregate completion information only; it must not expose raw student-level data.
- CTA navigation must continue to rely on existing instructor authorization gates.
- New telemetry must avoid student identifiers and other unnecessary PII.

## 13. Testing Strategy
- Elixir unit tests
  - projection tests for threshold handling, direct-child resolution in homogeneous and mixed scopes, axis-label fallback to `Course Content`, schedule/no-schedule behavior, pagination metadata, and empty states
  - tests should validate that `ProgressBinsOracle` and `ScopeResourcesOracle` payloads are consumed without UI-specific assumptions
- LiveView/component tests
  - tile renders title, CTA, class size, threshold control, toggle, and empty states
  - tile-local events update assigns and rerender expected payload/spec
  - accessibility assertions for labels, focusable controls, disabled pagination states, and `aria-live` messaging
- Browser/JS tests
  - targeted tests for the chart hook’s mount/update/destroy behavior and stale-render suppression
- Integration tests
  - dashboard shell + engagement section + Progress tile happy path with representative scoped payloads
- Manual verification
  - compare against Figma states for scheduled, unscheduled, modules, pages, paginated views, and mixed-child scopes using the approved generic axis label
  - verify 200% zoom, keyboard-only usage, tooltip disclosure, and long-label behavior

## 14. Backwards Compatibility
- No schema, migration, or external API compatibility risk is introduced.
- The feature replaces a current placeholder tile, so backward compatibility is mostly about preserving dashboard shell contracts rather than supporting an existing production tile behavior.
- Tile params should be URL-backed from the start for navigation continuity, and namespacing should follow the dashboard UI composition guidance instead of introducing flat query params.

## 15. Risks & Mitigations
- Overloading the LiveView shell with tile-local state: move Progress tile to a dedicated `LiveComponent` and keep threshold/mode/pagination there.
- Leaking projection logic into the browser hook: keep the hook limited to Vega-Lite render lifecycle and treat Elixir as the source of truth.
- Depending on schedule data that is not yet contractually stable: design the tile to degrade cleanly to no-schedule mode until the upstream schedule payload is confirmed.
- Chart accessibility regressions due to renderer defaults: implement accessible control wrappers and announcements in the LiveComponent rather than trusting Vega-Lite defaults.

## 16. Open Questions & Follow-ups
- Confirm the exact upstream schedule metadata contract and whether it enters the tile through snapshot assembly, a dedicated oracle field, or another already-existing dashboard projection layer.
- During implementation, verify whether the existing `OliWeb.Icons` set already contains a sufficiently matching Progress icon; if not, extend the canonical icon module rather than introducing a local SVG.

## 17. References
- `docs/exec-plans/current/epics/intelligent_dashboard/progress_tile/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/progress_tile/requirements.yml`
- `docs/exec-plans/current/epics/intelligent_dashboard/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/edd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/fdd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/README.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_oracles/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_coordinator/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_snapshot/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`
- `lib/oli/instructor_dashboard/prototype/tiles/progress.ex`
- `lib/oli/instructor_dashboard/prototype/tiles/progress/data.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
- `assets/src/hooks/student_support_chart.ts`
