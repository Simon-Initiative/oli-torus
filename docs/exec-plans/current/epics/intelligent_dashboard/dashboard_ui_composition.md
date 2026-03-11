# Intelligent Dashboard: Files and Responsibilities

## Scope

This document defines the implementation structure for the Instructor Intelligent Dashboard UI in `Insights > Dashboard`, including component composition, file placement, and layer ownership boundaries. It covers the summary region and section grouping (`Engagement`, `Content`), tile composition (`Summary`, `Progress`, `Student Support`, `Challenging Objectives`, `Assessments`), and the expected separation between LiveView shell, dashboard-tab orchestration, reusable section chrome, and tile modules.

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
- Which files will be created as placeholders in the first pass
- What each file/module is responsible for
- How section components compose with reusable section chrome

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

## File Map

## Existing Files

1. `lib/oli_web/live/delivery/instructor_dashboard/instructor_dashboard_live.ex`
2. `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`
3. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`

## New Files (Placeholders in first implementation pass)

### Reusable section wrapper

1. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/dashboard_section_chrome.ex`

### Section components (tile groups)

1. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/engagement_section.ex`
2. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/content_section.ex`

### Tile components

1. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex`
2. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/progress_tile.ex`
3. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`
4. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile.ex`
5. `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex`

## Responsibility Breakdown

## `shell.ex` (existing)

- Dashboard shell composition
- High-level placement of summary region and section components
- Passes summary/section/tile view-model inputs into section and tile components

## `dashboard_section_chrome.ex` (new)

Reusable section-level UI chrome (dashboard-generic):

- Section header rendering
- Expand/collapse control
- Reorder handle/callback integration
- Base section layout container and accessibility semantics

It is intentionally tile-agnostic and does not contain tile-specific eligibility rules.

## `tile_groups/engagement_section.ex` (new)

Section-specific composition for `Engagement`:

- Uses `dashboard_section_chrome` as wrapper
- Renders tiles in this section:
  - `progress_tile`
  - `student_support_tile`
- Applies engagement-section-specific ordering/visibility rules

## `tile_groups/content_section.ex` (new)

Section-specific composition for `Content`:

- Uses `dashboard_section_chrome` as wrapper
- Renders tiles in this section:
  - `challenging_objectives_tile`
  - `assessments_tile`
- Applies content-section-specific ordering/visibility rules

## Tile files under `tiles/` (new)

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

### Persisted preference state (DB-backed)

- Section order/collapse preferences for dashboard layout
- Optional persisted defaults where explicitly required

### Ephemeral UI state

- Hover/tooltips/transient focus-only details
- Local visual state not required to survive navigation

## First-Pass Placeholder Expectation

In the first implementation pass, the new files above can be created as placeholders with:

- `@moduledoc` describing the responsibility contract
- Minimal public API surface expected by composition
- Explicit TODO markers for runtime integration and tests

No tile business logic or full interaction implementation is required in that placeholder pass.
