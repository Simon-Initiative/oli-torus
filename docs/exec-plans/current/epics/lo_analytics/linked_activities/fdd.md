# Linked Activities Details From Learning Objectives - Functional Design Document

## 1. Executive Summary
Complete the existing `RelatedActivitiesLive` page so instructors can inspect linked activity question analytics from a Learning Objective. The design keeps the existing route and authorization boundary, derives the activity set from cached section-resource relationships, and reuses the current instructor activity detail rendering instead of creating a second question-detail implementation.

The change has four cooperating pieces: an objective-family activity resolver, a page-context-aware activity insights service, a shared expandable activity table boundary, and the route-specific LiveView/container. The page remains read-only and additive: no schema changes, migrations, publication changes, or feature flag are required.

## 2. Requirements & Assumptions
The design satisfies FR-001 through FR-007 and AC-001 through AC-021 in `requirements.yml`. The detailed traceability records remain canonical there; this document explains the implementation contracts that realize them.

Key assumptions:

- `related_activities` has been populated by section post-processing and is the runtime source for direct objective links.
- A parent objective's effective descendants can be resolved by `SectionResourceDepot.objectives_with_effective_children/2` or equivalent depot-backed objective data.
- The user-visible design requires exactly `Question Stem`, `Attempts`, and `% Correct` columns on this route.
- One activity resource produces one row. If it occurs on multiple eligible pages, analytics are aggregated across occurrences and one canonical published revision is used for question presentation.
- All rows start collapsed; detail loading occurs only after an instructor selects a row.
- The current instructor dashboard permissions and section socket assigns are sufficient authorization inputs; no new permission is introduced.

Traceability mapping:

- Route and objective scope: AC-001, AC-002, AC-003.
- Shared details and page-context aggregation: AC-004, AC-005, AC-006, AC-020.
- Controls and table lifecycle: AC-007 through AC-010, AC-021.
- Empty, read-only, and authorized behavior: AC-011 through AC-013.
- Depot/performance/telemetry: AC-014, AC-015.
- Accessibility: AC-016 through AC-019.

## 3. Repository Context Summary
- `RelatedActivitiesLive` resolves objective-family activities through `Oli.Delivery.Sections.LinkedActivities`, owns URL parameter decoding, search, filtering, sorting, pagination, and route navigation, and delegates detail state to `ActivityInsightsState`.
- The former `RelatedActivitiesTableModel` shallow renderer has been retired. Linked rows use `OliWeb.Delivery.Pages.ActivitiesTableModel` in `:linked_activities` mode.
- `ActivitiesTableModel` renders the expansion control and delegates detail content to `render_assessment_details/2`. Its linked mode hides order and learning-objective columns while preserving the shared detail boundary.
- The shared expansion control now renders a meaningful accessible name, `aria-expanded`, and `aria-controls`, with server-side expansion state synchronized to the LiveView lifecycle.
- `Pages` currently owns `activity_summary_cache`, `loaded_activity_summaries`, `expanded_activity_ids`, adaptive-repair polling, and the calls that build summaries with `ActivityHelpers`.
- `ActivityHelpers.summarize_activity_performance/6` is page-scoped and produces the detail payload, including response summaries, answer distributions, correctness metrics, preview data, and activity-specific staged details.
- `SectionResourceDepot` provides `get_resources_by_ids/2`, `get_section_resource/2`, `graded_pages/2`, `practice_pages/2`, and effective objective traversal over cached section resources.
- Delivery uses published section resources and revisions. The page must not resolve mutable authoring revisions or inspect activity objective JSONB in the interaction path.

## 4. Implemented Design
### 4.1 Design options

Option A is to copy the selected-page branch from `Pages` into `RelatedActivitiesLive`. It is the smallest textual change, but it duplicates expansion state, adaptive repair behavior, and detail rendering, making future dashboard fixes diverge.

Option B is to make the existing `ActivitiesTableModel` and its state lifecycle reusable, with route-specific row preparation and table configuration. This is selected because it preserves the approved detail UI and limits new code to objective-scoped row discovery and cross-page aggregation.

Option C is to build a separate React analytics surface. It would add a new client contract and duplicate server-rendered dashboard behavior without a requirement for client-side routing or state; it is rejected.

### 4.2 Components and ownership

1. `Oli.Delivery.Sections.SectionResourceDepot` remains the source for objective section resources, effective children, direct `related_activities`, and eligible page resources.
2. `Oli.Delivery.Sections.LinkedActivities` resolves objective-family IDs and builds the activity-to-page context index. It replaces `Sections.get_activities_for_objective/2` and its retired private helpers.
3. `OliWeb.Delivery.ActivityInsightsState` provides the shared pure state projections used by `Pages` and `RelatedActivitiesLive`; the LiveViews retain their existing event and summary-loading boundaries.
4. Refactor `ActivitiesTableModel.new/2` to accept a small options map, for example `%{columns: :selected_page | :linked_activities}`, while retaining the existing default behavior for Scored Activities and Practice Activities. Linked mode hides order and learning-objective columns but retains the chevron, question, attempts, and score columns.
5. Make the shared expansion control accessible. `render_expanded/3` must receive each row's current expansion state, derived from `expanded_activity_ids`, and render `aria-expanded`, `aria-controls` pointing at the detail row id, and a meaningful accessible name for the icon-only control. The existing `JS.toggle` behavior is retained so the visual response stays immediate, but the server-side expansion state is the single source of truth for the ARIA attributes; the design must reconcile the two rather than leaving the client toggle authoritative. This satisfies AC-016 and AC-019 and applies to every consumer of the shared table model.
6. `RelatedActivitiesLive` remains responsible for route params, selected objective title, back path, filters, and assigning the linked rows/context into the shared boundary. It should not render or reconstruct question details.

### 4.3 Request and expansion flow

1. On mount, resolve the integer resource id against the current section. Redirect with the existing warning/error behavior if the objective is unavailable or unauthorized.
2. Resolve the selected objective and effective descendants from the section depot. Fetch all objective section resources in one batch and union their `related_activities` arrays with `Enum.uniq/1` or an equivalent stable set operation.
3. Build an index from each unique activity resource id to its containing eligible page revision/resource context. Restrict the index to visible, delivered pages available to the instructor and to the page classes supported by the existing summary path.
4. Resolve the published activity revision and row metadata for the unique IDs. Use aggregate row metrics from the same summary data path used for expanded details; do not preserve the old direct-only `Sections.get_activities_for_objective/2` behavior.
5. Decode URL params, apply text/attempt/score filters, sort, and paginate the rows. Reset `expanded_activity_ids` when the linked activity context changes; do not preload or auto-expand any row.
6. On `paged_table_selection_change`, toggle the selected resource id and request its summary only if it is not cached. The summary service groups the activity by containing page, calls `ActivityHelpers.summarize_activity_performance/6` per page group, and merges the result by activity resource id.
7. Render the shared detail row. A missing/zero-result summary uses the existing no-attempt question empty state; a transient request displays the existing loading state. Collapse removes visibility but retains cached data for re-expansion.

### 4.4 Page-context and aggregation contract

The resolver should return a structure equivalent to:

```elixir
%{
  activity_ids: [activity_id],
  activity_page_contexts: %{activity_id => [%{page_resource_id: id, page_revision: revision}]},
  canonical_page_context: %{activity_id => page_context},
  objective_ids: [objective_id]
}
```

Score fields travel in two different scales on purpose, and the boundary converts between them explicitly rather than relying on key fallbacks. `percent_correct` is a 0-100 percentage at the resolver boundary; linked rows expose `avg_score` as the 0-1 ratio consumed by `ActivitiesTableModel.render_avg_score_column/3`, which styles values below 0.40. `LinkedActivities.merge_summary_metrics/1` emits `avg_score` as a ratio, so callers must preserve that scale when normalizing rows.

The summary boundary receives unique activity IDs and page contexts. For each page context it calls the existing page-scoped helper with only the activity IDs present on that page, then merges resource summaries, response summaries, attempt totals, first-attempt correctness, eventual correctness, and answer distributions by activity ID. Counts are additive; correctness ratios are recomputed from merged numerators and denominators, not averaged as percentages.

The canonical page context is selected deterministically as the first eligible page in depot/display order. This is a decision, not an open item, so row identity and preview selection are stable across loads. The published activity revision is resolved once by resource id. If an activity has no eligible page context, keep the row with zero/empty metrics and render the established empty state rather than calling a page-scoped helper with an invalid page.

## 5. Interfaces
### 5.1 Objective-family resolver

Implemented boundary:

```elixir
resolve_linked_activity_context(section_id, objective_id) ::
  {:ok, %{objective_ids: [integer()], activity_ids: [integer()], page_contexts: map()}}
  | {:error, :objective_not_found | :section_resource_unavailable}
```

The resolver must use depot reads and batch lookup. It must preserve stable ordering for display/context selection while ensuring `activity_ids` are unique. It must never infer links by scanning revision JSONB during a LiveView event.

### 5.2 Shared activity insights boundary

Proposed assigns/data contract:

```elixir
%{
  section: section,
  students: students,
  activity_types_map: activity_types_map,
  rows: linked_rows,
  summary_contexts: page_contexts,
  table_mode: :linked_activities,
  expanded_activity_ids: MapSet.t(),
  activity_summary_cache: %{activity_id => summary},
  loaded_activity_summaries: %{activity_id => summary}
}
```

The boundary exposes the same LiveView events already used by `ActivitiesTableModel`: `paged_table_selection_change`, sorting, page changes, and limit changes. Route-specific filter events stay in `RelatedActivitiesLive`; the shared boundary receives the resulting rows and params.

### 5.3 Table model contract

`ActivitiesTableModel.new(rows, opts \ [])` keeps the current default selected-page columns. With `columns: :linked_activities`, it returns the chevron, question stem/title, attempts, and `% Correct` columns only, with `data.expandable_rows: true` and the target needed by the selection JS. Existing callers must not change behavior.

The model must also expose the set of expanded row ids to the chevron renderer so `render_expanded/3` can emit `aria-expanded` for each row. Passing expansion state through the table model, rather than reading it from the client toggle, is what makes the accessible state correct for all consumers.

The row contract must support both current selected-page rows (`title`, `content`, `total_attempts`, `avg_score`, `learning_objectives`, `order`) and linked rows. A normalization function should map linked metrics to the existing names rather than making render functions understand two unrelated shapes.

### 5.4 URL and filter contract

Preserve existing params and use the current helpers: `text_search`, `selected_attempts_ids`, `avg_score_percentage`, `avg_score_selector`, `sort_by`, `sort_order`, `offset`, `limit`, and encoded `back_params`. Accepted sort atoms are `:question_stem`, `:attempts`, and `:percent_correct`; internal mapping may use `:title`, `:total_attempts`, and `:avg_score` after normalization. Filter changes push patches with offset reset to zero. Clear All Filters removes activity filters and restores the default sort/page state while retaining back-navigation state.

## 6. Data Model & Storage
No new tables, columns, migrations, or persisted records are required.

Runtime data sources:

- `SectionResource.related_activities`: direct objective-to-activity IDs, read through `SectionResourceDepot`.
- Objective hierarchy and section resources: depot-backed records for the current published section.
- Page revisions/activity references: existing delivered page data used to map activities to page contexts.
- Activity revisions: published delivery revisions resolved by resource ID for title/content/preview.
- `ResourceSummary` and response summaries: existing analytics data accessed through `ActivityHelpers` and `Oli.Analytics.Summary`.

The LiveView socket may hold transient maps for rows, page contexts, expanded IDs, and summaries. These assigns are request/session-local and must not be written back to activity, attempt, response, or summary storage.

## 7. Consistency & Transactions
The page is read-only and requires no transaction. Each render observes the current published section and analytics snapshot available when the relevant depot/summary calls execute; analytics may change between initial row load and expansion, so expanded details should be treated as a current snapshot rather than a permanently consistent report.

The activity ID set and page-context index should be computed as one logical load operation. If a page context becomes unavailable, skip that context and preserve the unique row with an empty/error-safe summary. Do not partially write derived relationships or repair `related_activities` from this page.

## 8. Caching Strategy
Use existing `SectionResourceDepot` caching for section resources, objective hierarchy, pages, and `related_activities`. Do not add a second cache layer for relationship data.

Use the existing per-LiveView `activity_summary_cache` and `loaded_activity_summaries` lifecycle. Cache keys are activity resource IDs; cache invalidation occurs when the objective/section context changes or the LiveView is remounted. Adaptive summary repair polling remains shared and must be scoped to the linked page's loaded summaries.

Summary calls are lazy. Initial navigation loads row metadata and aggregate row values needed for filtering/sorting, but does not call detail rendering for every activity. Re-expanding a cached row must not issue another summary request unless the existing adaptive-repair flow marks it stale.

## 9. Performance & Scalability Posture
- Objective relationships: one depot batch lookup for the selected objective plus effective descendants, followed by in-memory union/de-duplication.
- Page context: use depot page lists and existing resource helpers; avoid one query per activity. If page revision resolution cannot be fully depot-backed, batch-resolve the necessary published revisions.
- Detail summaries: group IDs by page and invoke the existing helper once per page group. Do not call `summarize_activity_performance/6` once per row.
- Filtering/sorting/pagination: operate on the bounded linked row set in memory, matching current LiveView behavior. Keep pagination after filtering and sorting so total counts and offsets remain correct.
- Analytics: retain aggregate-only summary queries and avoid loading raw response records into the LiveView beyond the existing detail payload contract.
- Instrument linked-load and summary-load duration, row/group counts, cache outcomes, and failures to detect regressions in AppSignal/telemetry.

## 10. Failure Modes & Resilience
- Missing objective or section resource: use the existing error flash and redirect to Learning Objectives.
- Empty relationship arrays: render the no-linked-activities page state.
- Search/filter produces no rows: render the filtered-empty state without losing the active params.
- Missing activity revision: retain a stable fallback title and empty detail state; do not crash rendering.
- Missing page context: exclude the context from summary calls, retain the unique activity row, and show no analytics available.
- Summary query/helper failure: log bounded context, keep the row/table usable, and render a recoverable empty/error state. Do not mutate source analytics.
- Stale adaptive summary: reuse the existing refresh/poll mechanism and replace only the affected cached summary.
- Invalid query params: use existing `Params` defaults and allow-listed atoms; never convert arbitrary input into an atom.

## 11. Observability
Emit or reuse telemetry around two operations:

- `linked_activities.load`: section/objective scope outcome, objective count, unique activity count, page-context count, duration, and error class.
- `linked_activities.summary_load`: activity/page-group count, cache hit/miss, summary count, duration, outcome, and error class.

Telemetry metadata must exclude student email, raw response content, activity authored content, and unrestricted query parameters. Logger messages should use section/objective/resource identifiers only where existing operational policy permits and should remain bounded. AppSignal should surface elevated errors or latency without requiring a new provider.

## 12. Security & Privacy
- Retain the existing route authorization and instructor section enrollment checks before resolving objective/activity data.
- Resolve every objective, page, activity revision, and analytics summary through the current section/publication scope. Never accept a resource ID from another section merely because it appears in a query or relationship array.
- Use the enrolled instructor dashboard student set when building summaries, matching `Pages` behavior; do not broaden to arbitrary section users.
- Preserve aggregate presentation and do not introduce raw response or PII fields into the linked row contract or telemetry.
- Keep input handling allow-listed for sort atoms, selectors, and numeric pagination values.

## 13. Testing Strategy
### Unit tests

- Test the objective-family resolver with direct links, parent-plus-child links, child-only links, duplicate IDs, unrelated IDs, stable ordering, and empty relationships.
- Migrate, do not delete, the existing `get_activities_for_objective/2` coverage in `test/oli/delivery/sections_test.exs`. The eight tests in that describe block already exercise an objective with one activity, an objective with multiple activities, mixed graded and practice pages, a sub-objective, a non-existent objective, an activity with no question stem, zero-attempt activities, and attempts/percent-correct accuracy. Re-point them at the new resolver and extend the sub-objective case so a parent objective also includes its children's activities, per AC-002.
- Test page-context indexing for activities on one page, multiple pages, missing pages, and unsupported/hidden pages.
- Test summary merge math: additive attempt/correct counts and recomputed ratios, including zero denominators.
- Test table normalization and column modes: linked mode has exactly the required columns; default mode remains unchanged.

### LiveView tests

Extend `test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs` for AC-001 through AC-013 and AC-020 through AC-021: navigation/back params, objective scopes, de-duplication, unrelated exclusion, all filters, clear, sorting, pagination, empty states, collapsed initial state, expansion/collapse/re-expansion, and read-only database snapshots.

Add assertions that expansion uses the shared detail labels/content and that page-context grouping handles activities placed on multiple pages. Add authorization tests for unauthenticated, non-enrolled, and cross-section resource cases.

### Accessibility and manual verification

Use LiveView-rendered HTML assertions for `aria-expanded`, accessible names, semantic headings, and focus-preserving hooks where deterministic. Manually verify keyboard operation and visible focus for search, multi-select, score selector, reset, sortable headers, pagination, and row chevrons at supported viewport sizes.

### Required gates

- `mix test test/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live_test.exs` plus new focused unit targets.
- `mix format --check-formatted` or the repository’s equivalent formatting gate.
- Harness requirements and FDD validators.
- Security, performance, Elixir/Phoenix, UI/accessibility, and requirements code reviews before merge.

## 14. Backwards Compatibility
The existing URL remains unchanged. Existing Learning Objectives navigation and back parameters remain valid. Scored Activities, Practice Activities, and Surveys continue using the default `ActivitiesTableModel` mode and existing `Pages` behavior.

`Sections.get_activities_for_objective/2` has no consumers outside the page being rewritten, so retiring it does not affect Scored Activities, Practice Activities, Surveys, or any other route. The accessibility changes to the shared expansion control are additive attributes on an existing button and apply to every consumer of `ActivitiesTableModel`, so the existing Scored and Practice Activities tests must run alongside the new linked-activities tests.

Existing activity, section-resource, publication, attempt, response, and analytics records are read without migration. Sections with stale or empty `related_activities` data degrade to the documented empty state; post-processing/backfill remains outside this work item.

## 15. Risks & Mitigations
- Cross-page summary semantics may disagree with page-specific ordinal/preview behavior: use the deterministic canonical page context defined in 4.4 and merge aggregate metrics by numerators/denominators; add multi-page tests.
- If an activity's rendered preview differs by containing page, the canonical page choice decides what the instructor sees while the metrics stay aggregated across occurrences. Surface this during implementation review if any activity type is found to render page-dependent content.
- Shared table refactor may regress existing dashboard columns or events: preserve default options and run existing Pages tests alongside linked-activities tests.
- Activity details may issue N+1 summary calls: enforce page grouping and instrument group/query counts.
- Related arrays may be stale: treat them as the established section source of truth and surface empty/error-safe states; do not repair synchronously.
- Expanded details may expose more data than the shallow page: reuse `ActivityHelpers` and existing instructor authorization/privacy behavior rather than adding new payload fields.
- Product may later choose occurrence-level rows: isolate aggregation in the summary boundary so row semantics can change without rewriting route/filter/table code.

## 16. Open Questions & Follow-ups
- Manual authenticated browser verification remains pending for layout, responsive behavior, keyboard focus, and Figma comparison.
- The implemented default is one aggregate row per activity resource across eligible page occurrences. A future occurrence-level product decision would require revising AC-006 and the row contract.
- Telemetry uses bounded linked-activity events implemented by the resolver and LiveView summary path; any future namespace change is outside this work item.

## 17. References
- `docs/exec-plans/current/epics/lo_analytics/linked_activities/prd.md`
- `docs/exec-plans/current/epics/lo_analytics/linked_activities/requirements.yml`
- `docs/exec-plans/current/epics/lo_analytics/linked_activities/informal.md`
- `lib/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live.ex`
- `lib/oli_web/components/delivery/activity_insights_state.ex`
- `lib/oli_web/components/delivery/pages/activities_table_model.ex`
- `lib/oli_web/components/delivery/pages/pages.ex`
- `lib/oli_web/components/delivery/activity_helpers.ex`
- `lib/oli/delivery/sections/section_resource_depot.ex`

## Decision Log

### 2026-09-05 - Reconcile Implemented Architecture
- Change: Updated the design from proposed component names and stale route behavior to the actual `LinkedActivities`, `ActivityInsightsState`, and shared `ActivitiesTableModel` boundaries.
- Reason: Phases 1-6 completed the implementation with a retired shallow model and a shared state projection rather than the originally tentative `ActivityInsightsTable` component.
- Evidence: `lib/oli/delivery/sections/linked_activities.ex`, `lib/oli_web/components/delivery/activity_insights_state.ex`, `lib/oli_web/live/delivery/instructor_dashboard/learning_objectives/related_activities_live.ex`, and phase execution records.
- Impact: Interface ownership and file references now match the repository; manual browser QA remains an explicit follow-up.
- `docs/design-docs/publication-model.md`
- `docs/design-docs/high-level.md`
