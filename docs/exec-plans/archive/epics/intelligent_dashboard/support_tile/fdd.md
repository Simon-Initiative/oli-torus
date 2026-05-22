# Student Support Tile - Functional Design Document

## 1. Executive Summary
This feature delivers the `Student Support` tile for the Instructor Intelligent Dashboard by combining a non-UI support projection with a LiveView-owned interactive tile surface. The tile consumes per-student progress/proficiency tuples plus enrolled-student identity and `last_interaction_at` data, derives deterministic support buckets and activity flags outside the UI, and renders an interactive donut/list experience inside the existing Phoenix LiveView dashboard. The selected architecture keeps domain logic out of HEEx and avoids introducing a React island for this tile: LiveView owns selection, filters, search, pagination, and email-entry state, while a narrow browser hook renders the Vega-Lite donut and forwards chart interactions back to LiveView. This is the simplest design that satisfies Darren Siegel's Jira guidance, preserves the dashboard's existing HEEx/LiveView composition, and keeps future `MER-5255` and `MER-5256` extensions on stable boundaries.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001`: render the Student Support tile with donut chart and legend from projected support-category data.
  - `FR-002`: compute support-bucket assignments in non-UI projection code from progress/proficiency and student info oracle inputs.
  - `FR-004`: prefer `struggling` as the default selected bucket, but fall back to the first non-empty bucket in priority order; selecting a donut segment or legend item updates both the highlighted segment and the student list.
  - `FR-005`: support search, `20`-row initial page, `Load more`, and no-scroll-reset pagination behavior.
  - `FR-006`: derive active/inactive status in projection space from `last_interaction_at` using the fixed 7-day rule for this ticket.
  - `FR-007`: support visible-row selection plus master selection and enable `Email` only when selection is non-empty.
  - `FR-009`: render the no-activity informational state instead of the donut/list when there is no student activity.
- Non-functional requirements:
  - UI state must remain synchronized across donut, legend, and student list under rapid interaction.
  - The tile must remain within the existing LiveView dashboard surface rather than introducing a separate React-owned runtime for tile state.
  - Accessibility must satisfy WCAG 2.1 AA for keyboard operation, focus behavior, accessible labels, and chart/list interaction announcements.
  - Observability is limited to targeted telemetry for projection failure and email-open action, plus explicit logging for visualization load failure.
- Assumptions:
  - Darren Siegel's comment on `MER-5252` is authoritative: the tile uses 2D progress/proficiency plus roster-oracle inputs, uses Vega-Lite for the chart, keeps inactivity derivation in projection space, and decomposes chart from list rendering.
  - Concrete upstream oracle work provides `ProgressProficiencyOracle` and `StudentInfoOracle` payloads as defined in the concrete-oracles feature pack.
  - The current placeholder `:oracle_instructor_support` binding will be replaced or expanded as support-tile implementation lands; this FDD defines the feature boundary, not the upstream oracle migration plan.
  - Before UI implementation starts, the local `implement_ui` skill will be run against the three Jira-linked Figma states so token/icon/component mapping is explicit.
  - The shared dashboard tile conventions in `dashboard_ui_composition.md` are normative for URL-state namespacing, tile-local state ownership, and LiveComponent layering.

## 3. Repository Context Summary
- What we know:
  - The dashboard shell is LiveView/HEEx-based. [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex) composes the summary region plus `engagement`/`content` sections.
  - The Student Support tile already has a placeholder HEEx component at [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex).
  - Dashboard layout state already persists per enrollment through [`lib/oli/instructor_dashboard.ex`](../../../../../../lib/oli/instructor_dashboard.ex) and [`lib/oli/instructor_dashboard/instructor_dashboard_state.ex`](../../../../../../lib/oli/instructor_dashboard/instructor_dashboard_state.ex). This tile should reuse that LiveView/dashboard ownership model rather than create a parallel client state store.
  - The current snapshot projection for student support at [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex) is only a thin pass-through of support-oracle payloads and does not yet implement the bucket/list interaction contract required by `MER-5252`.
  - The concrete-oracles docs define the upstream payloads we need: `ProgressProficiencyOracle` returns per-student `{student_id, progress_pct, proficiency_pct}` tuples, and `StudentInfoOracle` returns identity fields plus `last_interaction_at`.
  - The frontend already supports LiveView hooks via [`assets/src/hooks/index.ts`](../../../../../../assets/src/hooks/index.ts), and the repo already uses Vega-Lite in Elixir plus browser-side rendering elsewhere.
  - React-based Vega rendering exists in [`assets/src/components/misc/VegaLiteRenderer.tsx`](../../../../../../assets/src/components/misc/VegaLiteRenderer.tsx), but this tile does not need React ownership; a dedicated LiveView hook is simpler and aligns with the current dashboard surface.
  - [`docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`](../dashboard_ui_composition.md) now defines the cross-tile contract for projection vs tile vs hook responsibilities, namespaced tile URL params, and the rule that tile-local URL patches must not trigger scope-wide refetch.
- Unknowns to confirm:
  - Exact tooltip and screen-reader announcement copy for donut hover/selection and inactivity-filter explanation after `implement_ui` runs.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport`
  - Becomes the non-UI feature projection entrypoint for this tile.
  - Consumes upstream oracle payloads for progress/proficiency and student info.
  - Produces a tile-ready projected model with deterministic bucket summaries, per-bucket student rows, and activity status metadata.
- `Oli.InstructorDashboard.DataSnapshot.Projections.StudentSupport.Projector`
  - New projection-focused module responsible for support-bucket assignment, inactivity derivation, student-row shaping, summary counts, and deterministic ordering.
  - This is where the business rules live; HEEx and hooks must not recompute them.
- `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportTile`
  - Should be implemented as a `live_component` once real interaction state lands.
  - Renders the tile chrome, legend/buttons, filter/search controls, student list, selection controls, and email action affordance.
  - Receives projected payload plus tile-local interaction state.
- `assets/src/hooks/student_support_chart.ts`
  - New thin LiveView hook that mounts Vega-Lite via `vega-embed` on a DOM node.
  - Accepts server-generated spec JSON from HEEx data attributes.
  - Forwards donut interactions back to LiveView via `pushEvent`.
  - Does not own filtering, search, paging, or selection state.
  - In Phase 1, this hook drives a deliberately minimal chart used to validate runtime viability and state synchronization before visual refinement.
- `OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab`
  - Owns scope-wide dashboard routing, snapshot/oracle hydration, and distribution of tile param slices.
  - Must distinguish scope-affecting param changes from tile-local param changes so support-tile URL patches do not trigger scope-wide refetch.
- `OliWeb.Components.Delivery.Students.EmailButton` and existing email modal flow
  - Remain the downstream entrypoint for opening the draft-email workflow. The support tile only hands off selected recipients/context.

Design decision:
- Use Vega-Lite through a LiveView hook, not through a React component.
- Rationale:
  - the dashboard is already a LiveView surface
  - chart interaction requirements are narrow
  - LiveView must remain the owner of the tile state anyway
  - a hook avoids introducing a React island just to render one visualization

### 4.2 State & Data Flow
Projection input contract:
- `progress_proficiency_rows`: `[%{student_id, progress_pct, proficiency_pct}]`
- `student_info_rows`: `[%{student_id, email, given_name, family_name, last_interaction_at}]`
- optional projection params for this ticket:
  - `inactivity_days: 7`

Projection output contract:

```elixir
%{
  buckets: [
    %{
      id: "struggling",
      label: "Struggling",
      count: 12,
      pct: 0.24,
      students: [
        %{
          student_id: 1,
          display_name: "Ada Lovelace",
          email: "ada@example.edu",
          progress_pct: 33.0,
          proficiency_pct: 0.42,
          activity_status: :inactive,
          last_interaction_at: ~U[2026-03-01 12:00:00Z]
        }
      ]
    }
  ],
  totals: %{
    total_students: 50,
    active_students: 43,
    inactive_students: 7
  },
  default_bucket_id: "struggling",
  has_activity_data?: true
}
```

Bucket precedence:
1. `struggling`
2. `on_track`
3. `excelling`
4. `not_enough_information`

Default-bucket selection rule:
- select `struggling` when it is non-empty
- otherwise select the first non-empty bucket using the same priority order above
- if all buckets are empty, render the feature's no-data state instead of a selected bucket

Activity-status derivation:
- `inactive` means no activity in the last 7 days, computed from `last_interaction_at`.
- This derivation is projection-owned and is emitted as a field on each student row plus aggregated counts for the currently selected bucket.

Tile-local interaction state:

```elixir
%{
  selected_bucket_id: "struggling",
  selected_activity_filter: :all,
  search_term: "",
  visible_count: 20,
  selected_student_ids: MapSet.new()
}
```

URL-owned tile params:

```elixir
%{
  "tile_support" => %{
    "bucket" => "struggling",
    "filter" => "inactive",
    "page" => "2",
    "q" => "ada"
  }
}
```

Derived render flow:
1. Dashboard runtime loads upstream oracle payloads into snapshot.
2. Student-support projection merges progress/proficiency with student info and computes support buckets plus inactivity.
3. Dashboard coordination assigns projected tile data plus parsed `tile_support[...]` params to the Student Support tile component.
4. The Student Support tile component derives the currently visible list from:
   - selected bucket
   - selected activity filter
   - search term
   - visible row count
5. HEEx renders:
   - chart spec JSON for the hook
   - legend/filter/search/list/selection controls
6. Hook mounts donut chart and forwards clicks back to LiveView.
7. Tile-local interaction updates issue `push_patch` with namespaced `tile_support[...]` params.
8. The dashboard reapplies only the support-tile local state to the already-loaded projection and re-renders list plus chart selected-state spec without reloading scope-wide oracle data.

Recommended event contract:
- `"student_support_bucket_selected"` with `%{"bucket_id" => bucket_id}`
- `"student_support_activity_filter_selected"` with `%{"filter" => "all" | "active" | "inactive"}`
- `"student_support_search_changed"` with `%{"value" => term}`
- `"student_support_load_more"` with `%{}`
- `"student_support_row_toggled"` with `%{"student_id" => id}`
- `"student_support_visible_toggled"` with `%{"checked" => boolean}`
- `"student_support_email_opened"` with `%{}`

### 4.3 Lifecycle & Ownership
- Upstream oracle loading and cache participation remain owned by the dashboard runtime and snapshot layers.
- Support-bucket and activity-status business logic are owned by the projection layer.
- URL-owned support-tile navigation state (`bucket`, `filter`, `page`, `q`) is parsed at dashboard level and applied to the tile-local interaction state using the shared dashboard tile contract.
- The tile `live_component` owns only tile-local interaction/rendering concerns and must not recompute support classification or inactivity derivation.
- The chart hook owns only browser-local visualization lifecycle:
  - mount
  - destroy/rebuild on spec changes
  - click listener registration
  - resize handling
- No support-tile interaction state is persisted to DB in this story.
- Section layout persistence already exists and remains orthogonal to tile interaction state.
- Future tickets:
  - `MER-5255` should extend the rendered student-row surface for profile-hover behavior without changing projection ownership.
  - `MER-5256` should extend projection inputs/configuration for custom thresholds and inactivity window without moving the rules into UI.

### 4.4 Alternatives Considered
- Use `Components.VegaLiteRenderer` React component inside the LiveView tile.
  - Rejected because it introduces a React island where the surrounding surface is already HEEx/LiveView. The tile still needs LiveView-owned state, so React adds complexity without solving a real problem.
- Render the donut entirely in HEEx/SVG without Vega-Lite.
  - Rejected because the ticket explicitly calls for Vega-Lite and because the interactive selection/hover behavior would need custom charting logic that is more expensive than using the chosen viz runtime.
- Push all tile state into client JS.
  - Rejected because search, selection, email entrypoint context, and future parameter-driven reprojection belong in the existing LiveView/dashboard control flow.
- Compute active/inactive and support buckets in HEEx or the hook.
  - Rejected because Darren's ticket guidance explicitly places this logic in non-UI projection space.

## 5. Interfaces
- Snapshot/projection interface:
  - `StudentSupport.derive(snapshot, opts) -> {:ok, projection} | {:partial, projection, reason} | {:error, reason}`
- Internal projection helper interface:
  - `Projector.build(progress_rows, student_info_rows, opts) -> projection_map`
- LiveView assign interface:
  - `:student_support_projection`
  - `:student_support_selected_bucket_id`
  - `:student_support_activity_filter`
  - `:student_support_search_term`
  - `:student_support_visible_count`
  - `:student_support_selected_student_ids`
- URL param interface:
  - `tile_support[bucket]`
  - `tile_support[filter]`
  - `tile_support[page]`
  - `tile_support[q]`
- LiveView event interface:
  - `"student_support_bucket_selected"`
  - `"student_support_activity_filter_selected"`
  - `"student_support_search_changed"`
  - `"student_support_load_more"`
  - `"student_support_row_toggled"`
  - `"student_support_visible_toggled"`
  - `"student_support_email_opened"`
- Hook DOM contract:
  - host element includes:
    - `data-spec`
    - `data-selected-bucket-id`
    - stable DOM id
  - hook emits only semantic selection events to LiveView, not raw Vega internals
- Email handoff interface:
  - selected rows map to recipient identities already present in projection/student rows
  - tile opens the downstream email flow with selected recipients and support-tile initiation context

## 6. Data Model & Storage
- Ecto schemas and migrations:
  - No new database schema is required for `MER-5252`.
  - Existing `instructor_dashboard_states` persistence is unrelated to support-tile URL state and should not be extended for this story.
- Storage posture:
  - The tile is read-only with respect to dashboard data.
  - Restorable tile-navigation state lives in namespaced URL params, not in DB.
  - Non-restorable ephemeral interaction state remains in LiveView assigns/component state only.
- Input data sources:
  - upstream dashboard snapshot oracle payloads
  - no direct tile-specific DB queries from HEEx/hooks

## 7. Consistency & Transactions
- No multi-row transaction boundary is required for the tile itself.
- Support projection must be deterministic for identical upstream inputs.
- Tile-local URL patches must only rederive support-tile visible state from the already-loaded projection and must not invalidate unrelated tile data.
- If the chart hook fails to mount or re-render, LiveView list interactions still function; the chart surface shows a recoverable fallback message instead of breaking the whole tile.

## 8. Caching Strategy
- The tile does not introduce a new cache.
- It relies on the existing dashboard runtime cache/oracle/snapshot layers.
- Projection output should be derived from the snapshot already loaded for the current scope and should not bypass runtime cache boundaries.
- Hook-local chart rendering must not cache data separately from LiveView assigns.
- URL patches for `tile_support[...]` must reuse the current projection/snapshot rather than trigger refetch through cache/coordinator paths.

## 9. Performance & Scalability Posture
- The main tile-level hotspot is large-roster list filtering after projection.
- Recommended posture:
  - compute support buckets once per projection refresh
  - keep per-bucket student arrays in projection output
  - apply activity filter and search in LiveView over the selected bucket only
  - append pagination by `visible_count` rather than re-querying data
- Roster sizes for instructor dashboards are expected to be manageable for in-memory LiveView filtering after upstream snapshot hydration.
- No dedicated performance benchmark is required for this story, but test coverage should guard against obvious stale-state or duplicate-row regressions.

## 10. Failure Modes & Resilience
- Upstream oracle missing/unavailable:
  - projection returns `:partial` or `:error`
  - tile renders a recoverable loading/unavailable state, not malformed chart/list data
- No activity data:
  - tile renders the specified informational empty state
  - chart/list are omitted
- Hook render failure:
  - log warning
  - render fallback message in the chart area
  - keep legend/list/email controls functional when possible
- Invalid bucket event from browser:
  - ignore event if bucket id is unknown
  - keep previous selected bucket
- Search/load-more/select race under rapid interaction:
  - LiveView remains source of truth; list is rederived from current assigns each render
- Future upstream contract drift:
  - add projection tests that fail fast if expected oracle fields disappear or change semantics

## 11. Observability
- Reuse existing dashboard logging patterns and add targeted tile instrumentation:
  - `support_tile.bucket_selected`
  - `support_tile.email_opened`
- Add server-side warning logs for:
  - projection failure
  - chart spec generation failure
  - unknown browser bucket/filter payloads
- If practical during implementation, include metadata:
  - `section_id`
  - `container_id`
  - `bucket_id`
  - `selected_count`

## 12. Security & Privacy
- The tile inherits existing instructor-dashboard authorization; it is not available to learners.
- Student identity exposure is limited to the fields already provided by `StudentInfoOracle` and required for instructor workflow.
- No new persistent copy of student support data is created.
- Browser-visible payloads should avoid including unnecessary fields beyond what the tile and email handoff need.
- All interactions remain section-scoped within the existing LiveView session.

## 13. Testing Strategy
- Unit tests:
  - projection bucketing precedence and exclusivity
  - inactivity derivation from `last_interaction_at`
  - `not_enough_information` handling for missing/insufficient proficiency data
  - deterministic counts and student-row shaping
- LiveView tests:
  - default `struggling` selection on first render
  - bucket selection changes visible list
  - active/inactive filter changes visible list and counts
  - search filters within selected bucket only
  - `Load more` appends rows without resetting list state
  - row/master selection semantics
  - `Email` enable/disable behavior
  - no-data state rendering
- Hook-focused browser tests:
  - minimal JS test coverage for hook event forwarding if the repo already supports targeted hook tests
  - otherwise validate the hook through LiveView integration plus manual QA
- Manual QA:
  - compare default, hover, and no-inactive states against the three Jira-linked Figma sources
  - keyboard walkthrough for legend, filters, search, list, selection, and email button
  - validate fallback default selection when `struggling` is empty but another bucket is populated
  - validate donut click updates list and highlight state consistently
  - validate chart fallback behavior when hook/render fails in dev

## 14. Backwards Compatibility
- No schema migration or external API compatibility concern is introduced.
- The tile is additive within the existing dashboard section composition.
- The design preserves forward compatibility for `MER-5255` and `MER-5256` by keeping tile rules in projection space and tile state in LiveView.

## 15. Risks & Mitigations
- Risk: projection logic drifts from future parameter customization.
  - Mitigation: centralize support classification and inactivity derivation in a dedicated projector module that later accepts configurable params.
- Risk: chart/list state desynchronizes.
  - Mitigation: keep LiveView as the single source of truth for selected bucket and derive both list and selected-chart spec from that state.
- Risk: React island creeps into a HEEx dashboard.
  - Mitigation: standardize on a LiveView hook for Vega-Lite and document that React is not part of this tile design.
- Risk: tile-local URL patches accidentally trigger scope-wide data reload and rerender churn.
  - Mitigation: follow the shared dashboard tile param contract and treat `tile_support[...]` changes as local-state reapplication only.
- Risk: Vega-Lite may not support the full interaction or visual-control requirements of the final tile without excessive complexity.
  - Mitigation: treat the chart renderer as replaceable from the start; use the first implementation slice to validate minimum required behavior (segment selection, URL patch sync, list sync, and state rehydration), and if Vega-Lite proves insufficient, replace only the renderer/hook layer while preserving projection, URL, and tile-state contracts.
- Risk: Figma-driven details get approximated during implementation.
  - Mitigation: require `implement_ui` design brief before coding and use it to pin tokens, icon sourcing, and state-specific styling.

## 16. Open Questions & Follow-ups
- Follow-up: align the current placeholder `support_summary` oracle binding with the concrete support/projection contract when implementation begins.

## 17. References
- [`docs/exec-plans/current/epics/intelligent_dashboard/support_tile/prd.md`](./prd.md)
- [`docs/exec-plans/current/epics/intelligent_dashboard/support_tile/requirements.yml`](./requirements.yml)
- [`docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`](../dashboard_ui_composition.md)
- [`docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/fdd.md`](../concrete_oracles/fdd.md)
- [`docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/README.md`](../concrete_oracles/README.md)
- [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex)
- [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex)
- [`lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`](../../../../../../lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex)
- Jira `MER-5252` plus Darren Siegel comment accessed on 2026-03-13
- Figma nodes:
  - `500:25180`
  - `1074:26453`
