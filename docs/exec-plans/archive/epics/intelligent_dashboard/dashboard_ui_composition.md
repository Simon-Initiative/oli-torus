# Intelligent Dashboard: Files and Responsibilities

## Scope

This document defines the implementation structure for the Instructor Intelligent Dashboard UI in `Insights > Dashboard`, including component composition, file placement, layer ownership boundaries, and shared state-management conventions for dashboard tiles. It covers the summary region and section grouping (`Engagement`, `Content`), tile composition (`Summary`, `Progress`, `Student Support`, `Challenging Objectives`, `Assessments`), and the expected separation between LiveView shell, dashboard-tab orchestration, reusable section chrome, tile modules, non-UI projections, and tile-local browser hooks.

## Purpose

This document is the implementation reference for this PR (dashboard UI composition and ownership baseline) and for the follow-on Intelligent Dashboard delivery PRs tied to:

- `MER-5246` (Insights > Learning Dashboard)
- `MER-5248` (Global Filter Navigation)
- `MER-5258` (Section grouping/reorder/collapse chrome)
- `MER-5259` (Tile expand/resize behavior)
- `MER-5249` (Summary tile + recommendation surface)
- `MER-5250` (Recommendation feedback/regeneration UI)
- `MER-5251` (Progress tile)
- `MER-5252` (Student Support tile)
- `MER-5253` (Challenging Objectives tile)
- `MER-5254` (Assessments tile)
- `MER-5255` and `MER-5256` (Student Support extensions)

It exists to keep file placement, layer boundaries, and component ownership consistent across those PRs.

## Non-Goals

This document does not replace or redefine product requirements, data contracts, or execution planning from epic PRD/FDD/plan artifacts. It does not specify oracle internals, cache policy internals, or backend query logic. It is not a visual design spec, and it does not mandate final UI styling details beyond structural/component boundaries.

## Overview

Define a clear file layout and ownership model for `Insights > Dashboard` (Instructor Intelligent Dashboard), aligned with the planned summary/sections and tiles:

- Top summary region: `Summary` (positioned between scope selector and section groups)
- Sections (tile groups): `Engagement`, `Content`
- Tiles: `Summary`, `Progress`, `Student Support`, `Challenging Objectives`, `Assessments`

This document describes:

- Which files already exist
- What each file/module is responsible for
- How section components compose with reusable section chrome
- How dashboard and tile state should be split across URL params, LiveView assigns, projections, and hooks

## Architectural Boundaries

### LiveView shell (`InstructorDashboardLive`)

`InstructorDashboardLive` remains the Phoenix entry point and owns:

- `mount/3`, `handle_params/3`, `handle_event/3`, `handle_info/2`
- URL/canonicalization and tab navigation (`overview`, `insights`, `discussions`)
- Delegation to dashboard-specific orchestration for `Insights > Dashboard`

### Dashboard orchestration (`IntelligentDashboardTab`)

`IntelligentDashboardTab` owns dashboard-tab-specific orchestration:

- Scope resolution/validation/persistence
- Session-local initialization for in-process store
- LiveView-side runtime integration through `Oli.Dashboard.LiveDataCoordinator`
- Consumption of snapshot/projection contracts for tile-ready dashboard hydration

Important runtime ownership note:

- `InProcessStore` is session-local and initialized by dashboard-tab flow.
- `RevisitCache` is global app-supervised and consumed by name; it is not initialized by LiveView/dashboard helpers.

### UI composition (summary + sections + tiles)

The dashboard UI composes a top summary region plus section-based tiles.

- `Summary` is rendered as a top-level region below the scope selector.
- A reusable section wrapper is used for all dashboard sections.
- Section modules decide which tiles appear and in what order.
- Tile modules render card-level UX and tile-local interactions.
- Tile-specific business rules stay in non-UI projection modules and are passed into tiles as prepared view models.

## Shared Tile Contract

All dashboard tiles should follow the same architectural split so multiple developers can work in parallel without diverging on state ownership or business-logic placement.

### Non-UI projection modules

Projection modules own:

- classification and aggregation rules
- derivation from oracle payloads
- deterministic counts, statuses, and summary values
- chart/list base datasets that are meaningful business outputs

Projection modules must not depend on HEEx, browser hooks, or tile-local DOM state.

### Tile live components

Tiles should be implemented as `Phoenix.LiveComponent`s beneath the dashboard shell when they need local interaction state.

Tile live components own:

- tile-local interaction state
- rendering of the projected view model
- UI-only derivation such as selected subset, local paging window, search within the projected set, and control enablement
- dispatch of navigation and action events

Tile live components must not recompute business classification logic that belongs in projections.

### Browser hooks

Browser hooks are allowed when a tile needs DOM-managed behavior such as:

- chart rendering runtimes
- drag/drop interactions
- browser-only measurements or resize handling

Hooks should remain thin:

- render or wire the browser capability
- forward semantic events back to LiveView
- avoid owning business logic or authoritative tile state

### Dashboard shell

The dashboard shell remains the coordinator for:

- scope-wide snapshot/oracle hydration
- section layout composition
- routing/global param parsing
- distributing prepared data into section and tile components

## File Map

## Existing Files

1. `lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex`
2. `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`
3. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`
4. `lib/oli_web/components/delivery/instructor_dashboard/dashboard_section_chrome.ex`
5. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/engagement_section.ex`
6. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/content_section.ex`
7. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex`
8. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
9. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`
10. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile.ex`
11. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex`
12. `assets/src/hooks/dashboard_section_chrome.ts`

## Planned Follow-on Files

These files are expected as feature work lands, but may not exist yet for every tile:

1. tile-specific hook files under `assets/src/hooks/` when a tile needs browser-managed behavior
2. tile-specific non-UI projection helpers under the dashboard snapshot/projection layer when a tile's view model needs feature-owned derivation beyond raw oracle passthrough

## Responsibility Breakdown

## `shell.ex` (existing)

- Dashboard shell composition
- High-level placement of summary region and section components
- Passes summary/section/tile view-model inputs into section and tile components

## `dashboard_section_chrome.ex`

Reusable section-level UI chrome (dashboard-generic):

- Section header rendering
- Expand/collapse control
- Reorder handle/callback integration
- Base section layout container and accessibility semantics

It is intentionally tile-agnostic and does not contain tile-specific eligibility rules.

Placement note:

- This file should live at the `instructor_dashboard` root, not under `intelligent_dashboard`.
- Rationale: the chrome is reusable across instructor dashboard surfaces, while `intelligent_dashboard` should contain only product-specific shell, tile-group, and tile modules.

## `tile_groups/engagement_section.ex`

Section-specific composition for `Engagement`:

- Uses `dashboard_section_chrome` as wrapper
- Renders tiles in this section:
  - `progress_tile`
  - `student_support_tile`
- Applies engagement-section-specific ordering/visibility rules

## `tile_groups/content_section.ex`

Section-specific composition for `Content`:

- Uses `dashboard_section_chrome` as wrapper
- Renders tiles in this section:
  - `challenging_objectives_tile`
  - `assessments_tile`
- Applies content-section-specific ordering/visibility rules

## Tile files under `tiles/`

Each tile file owns tile-level rendering and interaction behavior:

- `summary_tile.ex`
  - Summary metrics + recommendation presentation
  - Recommendation interaction hooks (regen/feedback UI integration points)
- `progress_tile.ex`
  - Threshold/mode/pagination interactions
  - Scope-aware chart rendering contract consumption
- `student_support_tile.ex`
  - Donut/legend/list synchronization
  - Bucket/filter/search/paging/selection behavior
- `challenging_objectives_tile.ex`
  - Objective hierarchy list/disclosure behavior
  - Deep-link navigation actions to Learning Objectives
- `assessments_tile.ex`
  - Assessment summaries/distribution rendering
  - Scope-aware empty/hidden/populated states

All tile modules consume prepared view models/contracts and must not introduce direct analytics query paths.

Recommended implementation note:

- tiles may remain function components while they are simple placeholders
- once a tile has meaningful local interaction state, it should graduate to a `live_component` rather than pushing all local state into `IntelligentDashboardTab`

## Composition Contract (Explicit)

`Summary` is composed as a standalone top region, then section groups are composed below it:

- `shell` -> `summary_tile` (standalone top region)

`engagement_section` and `content_section` both compose the same reusable wrapper:

- `engagement_section` -> `dashboard_section_chrome` + engagement tiles
- `content_section` -> `dashboard_section_chrome` + content tiles

This is required so section behavior (collapse/reorder/accessibility chrome) is consistent and reusable, while tile selection/ordering remains section-specific.

## State and Persistence Rules

### URL-owned state (survives reload/back/share)

- View/tab/scope params
- Tile interaction params that define navigation state (for example selected support bucket/filter/page)

Global rule:

- changing URL params that affect only tile-local interaction state must not refetch scope-wide oracle data or rebuild the whole dashboard snapshot
- changing URL params that affect dashboard scope identity may refetch/rebuild upstream data

### URL parameter namespacing

To avoid flat query-param sprawl, tile params should be namespaced by tile slug.

Preferred format:

- `dashboard_scope=course|container:123`
- `tile_support[bucket]=struggling`
- `tile_support[filter]=inactive`
- `tile_support[page]=2`
- `tile_support[q]=ada`

Apply the same pattern for other tiles:

- `tile_progress[...]`
- `tile_assessments[...]`
- `tile_objectives[...]`

Rules:

- only state that matters for back/forward/share should go in the URL
- hover, tooltip, temporary checkbox state, and other ephemeral UI details should not go in the URL
- tile param changes should be parsed and applied by the relevant tile/dashboard coordination code without invalidating unrelated tiles

### Persisted preference state (DB-backed)

- Section order/collapse preferences for dashboard layout
- Optional persisted defaults where explicitly required

### Ephemeral UI state

- Hover/tooltips/transient focus-only details
- Local visual state not required to survive navigation

## Param-Handling Contract

When `handle_params/3` receives a patch inside the same dashboard LiveView, implementation should distinguish:

- scope-affecting param changes:
  - may invalidate snapshot/oracle/projection data for the current dashboard scope
- tile-local param changes:
  - should only update the relevant tile's local interaction state and derived visible subset
  - should not trigger full dashboard data reload

Recommended ownership split:

- `InstructorDashboardLive`
  - route mount and top-level patch flow
- `IntelligentDashboardTab`
  - parse global dashboard params and dispatch tile param slices
- dashboard shell / tile live components
  - apply tile-local URL state to the already prepared projection for that tile

This is important for `back`/`forward` behavior: a user should be able to navigate from a tile-driven filtered state into a detail page and back without losing that filter state, while also avoiding unnecessary scope-wide refetch.

## LiveComponent Nesting

The intended component hierarchy is valid and supported:

- `LiveView`
- dashboard `live_component`
- tile `live_component`
- tile-internal hook when needed

This nesting does not conflict with the requirement that tiles consume prepared projection data, as long as:

- business logic remains in non-UI projection layers
- tile live components own only tile-local interaction and rendering concerns
- hooks remain thin and browser-focused

