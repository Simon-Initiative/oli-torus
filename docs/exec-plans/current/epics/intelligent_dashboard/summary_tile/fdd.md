# Summary Tile - Functional Design Document

## 1. Executive Summary
This feature delivers the `Summary` region for the Instructor Intelligent Dashboard by replacing the current placeholder projection and placeholder HEEx card with a projection-owned summary view model plus a LiveView-owned interactive tile surface. The simplest adequate design is: keep all summary business logic in a new summary projector under `Oli.InstructorDashboard.DataSnapshot.Projections.Summary`, treat Darren Siegel's four oracle slots as optional upstream dependencies so the region can render incrementally, and render the result through a `live_component` that owns only recommendation-control interaction state. This keeps domain and aggregation rules out of HEEx, matches the existing dashboard composition model in `shell.ex` and `IntelligentDashboardTab`, and gives `MER-5249` a stable boundary with `MER-5305` without forcing recommendation-generation details into the UI layer.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` / `AC-001`: render the Summary region directly below the global content filter.
  - `FR-002` / `AC-002`: support four optional upstream data sources and render incrementally when only a subset is available.
  - `FR-003` / `AC-003`: show only applicable metric cards and let remaining cards expand responsively.
  - `FR-004` / `AC-004`: provide accessible metric-definition tooltips on hover and keyboard focus.
  - `FR-005` / `AC-005`: render recommendation content with thinking and beginning-course fallback states.
  - `FR-006` / `AC-006`: disable regenerate while a regeneration request is in flight and re-enable it on completion or failure.
  - `FR-007` / `AC-007`: update summary metrics and recommendation on scope changes without browser refresh.
  - `FR-008` / `AC-008`: render thumbs up, thumbs down, and regenerate controls and route them through the defined feedback/regeneration contracts.
  - `FR-009` / `AC-009`: keep tile data shaping in non-UI projection code, with UI components consuming prepared output only.
- Non-functional requirements:
  - The tile must remain inside the existing LiveView dashboard shell and preserve the dashboard's shared composition model.
  - Partial oracle failure must degrade only the affected subcomponent and must not collapse the whole summary region.
  - Accessibility must satisfy WCAG 2.1 AA for tooltip association, visible focus, keyboard operation, and programmatic recommendation labeling.
  - Recommendation failures must preserve the last good recommendation while exposing deterministic UI state.
  - Observability should stay minimal and focused on projection failures and recommendation control outcomes.
- Assumptions:
  - Darren Siegel's Jira comment is authoritative for technical scope and overrides the earlier ticket note that feedback-related behavior is excluded.
  - `MER-5305` provides a recommendation oracle or equivalent contract that can be consumed by the summary projection without requiring UI-specific provider logic.
  - Existing concrete-oracle module names in `OracleBindings` are authoritative for progress/proficiency/objectives/grades inputs.
  - Before final UI implementation starts, the local `implement_ui` skill will be run against the Jira/Figma sources so token, icon, and unresolved visual-state decisions are made explicit.
  - The dashboard layering contract in `dashboard_ui_composition.md` is normative for summary placement, state ownership, and URL param behavior.

## 3. Repository Context Summary
- What we know:
  - The dashboard shell already places the summary region above section groups in [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex).
  - The current summary tile UI is only a placeholder function component in [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex).
  - A summary projection already exists in [`lib/oli/instructor_dashboard/data_snapshot/projections/summary.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/summary.ex), but it still depends on legacy placeholder oracles (`:oracle_instructor_progress`, `:oracle_instructor_engagement`, `:oracle_instructor_support`) and does not shape real summary metrics or recommendation state.
  - `IntelligentDashboardTab` already owns scope resolution, bundle/projection hydration, and tile-local state parsing for other dashboard tiles in [`lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`](../../../../../../lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex).
  - The concrete lane-1 projection pattern is already established by `Progress`, `StudentSupport`, and `Assessments`, each with a projection module plus a dedicated `Projector` helper in `lib/oli/instructor_dashboard/data_snapshot/projections/`.
  - Existing oracle module names relevant to this tile are registered in [`lib/oli/instructor_dashboard/oracle_bindings.ex`](../../../../../../lib/oli/instructor_dashboard/oracle_bindings.ex): `Oli.InstructorDashboard.Oracles.ProgressProficiency`, `Oli.InstructorDashboard.Oracles.Grades`, `Oli.InstructorDashboard.Oracles.ObjectivesProficiency`, and `Oli.InstructorDashboard.Oracles.ScopeResources`.
  - `IntelligentDashboardTab.build_dashboard_payload/2` currently exposes `progress_projection`, `student_support_projection`, `objectives_projection`, and `assessments_projection`, but not `summary_projection`; this will need to change when the summary stops being a hardcoded placeholder.
- Unknowns to confirm:
  - The exact recommendation-oracle binding key and payload shape once `MER-5305` lands.
  - Whether thumbs-up/down should be disabled after the first successful submission for a recommendation instance in `MER-5249`, or only wired/rendered here with the stronger duplicate-submission rules owned by `MER-5250`.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.DataSnapshot.Projections.Summary`
  - Replace the current placeholder dependency list with the actual summary dependencies.
  - Treat all four summary inputs as optional so the region can render incrementally instead of failing hard when one oracle is missing.
  - Emit a tile-ready summary projection and status metadata rather than raw oracle payload maps.
- `Oli.InstructorDashboard.DataSnapshot.Projections.Summary.Projector`
  - New projector-focused module that owns:
    - metric applicability decisions
    - average metric derivation and formatting
    - recommendation fallback/thinking/render state derivation
    - card ordering and layout metadata
    - tooltip copy keys / recommendation accessibility labels
  - Must not perform provider-specific recommendation generation or direct DB access.
- `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.SummaryTile`
  - Convert from a stateless placeholder to a `live_component`.
  - Own only tile-local interaction concerns:
    - regenerate-in-flight UI state
    - local sentiment submission lock state if needed before server response
    - dispatch of thumbs/regenerate events
  - Consume prepared projection data and projection status from the dashboard shell.
- `OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab`
  - Own summary-tile assign hydration the same way it already owns support/progress/assessments assigns.
  - Route summary tile events to the recommendation contract layer exposed by `MER-5305`.
  - Preserve scope-wide snapshot reuse when tile-local recommendation interactions occur.
- `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Shell`
  - Stop rendering `SummaryTile.tile status="Loading summary placeholders"`.
  - Pass `summary_projection`, `summary_projection_status`, and `summary_tile_state` into the `SummaryTile` live component.

Design decision:
- Use a projection + live component split, not a richer JS/React island.
- Rationale:
  - the summary surface needs only standard LiveView interaction, not browser-managed visualization
  - the repo already prefers projection-owned business logic with LiveComponent-owned UI state for dashboard tiles
  - introducing React would add complexity without solving a real requirement

Conceptual oracle-slot mapping:
- Darren's slot names are treated as conceptual slots, while this FDD binds them to current repo contracts:
  - `progress` slot -> `:oracle_instructor_progress_proficiency`
    - used to compute `Average Student Progress` as the average of `progress_pct` across enrolled learners in scope
  - `proficiency_progress` slot -> `:oracle_instructor_objectives_proficiency`
    - used to compute `Average Class Proficiency` across objectives in scope
  - `assessment` slot -> `:oracle_instructor_grades`
    - used to compute `Average Assessment Score` as the average of page means for graded assessments in scope
  - `recommendation` slot -> assumed recommendation oracle key from `MER-5305`
- `:oracle_instructor_scope_resources` is treated as optional enrichment support, not as one of Darren's four conceptual slots.

### 4.2 State & Data Flow
Projection input contract:
- optional `progress_proficiency_rows`: `[%{student_id, progress_pct, proficiency_pct}]`
- optional `objectives_proficiency_payload`: `%{objective_rows: [%{objective_id, title, proficiency_distribution}], objective_resources: list()}`
- optional `grades_payload`: `%{grades: [%{page_id, mean, minimum, median, maximum, standard_deviation, histogram, available_at, due_at}]}`
- optional `recommendation_payload`: contract defined by `MER-5305`
- optional `scope_resources_payload`: `%{course_title, items: [...]}` for future contextual copy enrichment if needed

Projection output contract:

```elixir
%{
  cards: [
    %{
      id: :average_student_progress,
      label: "Average Student Progress",
      value_text: "72%",
      value_number: 72.0,
      tooltip_key: :average_student_progress,
      status: :ready
    },
    %{
      id: :average_class_proficiency,
      label: "Average Class Proficiency",
      value_text: "81%",
      value_number: 81.0,
      tooltip_key: :average_class_proficiency,
      status: :ready
    }
  ],
  recommendation: %{
    status: :ready | :thinking | :beginning_course | :unavailable,
    recommendation_id: "rec_123" | nil,
    label: "AI Recommendation",
    body: "Focus on Module 2 before Quiz 1.",
    aria_label: "AI Recommendation: Focus on Module 2 before Quiz 1.",
    can_regenerate?: true,
    can_submit_sentiment?: true
  },
  layout: %{
    visible_card_count: 2,
    card_grid_class: "grid-cols-2"
  },
  available_slots: [:progress, :recommendation],
  missing_slots: [:assessment, :proficiency_progress]
}
```

Tile-local interaction state:

```elixir
%{
  regenerate_in_flight?: false,
  submitted_sentiment: :up | :down | nil,
  last_recommendation_id: "rec_123" | nil
}
```

Derived render flow:
1. Dashboard runtime assembles the snapshot and projection bundle for the selected scope.
2. `Summary.derive/2` reads available oracle payloads without requiring all four summary slots.
3. `Summary.Projector.build/2` computes visible metric cards, recommendation state, layout metadata, and tooltip/recommendation labels.
4. `IntelligentDashboardTab` places `summary_projection` and `summary_projection_status` into the dashboard payload and initializes `summary_tile_state`.
5. `Shell` renders the summary `live_component` with the prepared projection and tile state.
6. `SummaryTile` renders:
   - only visible metric cards
   - recommendation block in `thinking`, `ready`, `beginning_course`, or `unavailable` state
   - thumbs/regenerate controls when recommendation contract allows them
7. Clicking regenerate issues a LiveView event, sets `regenerate_in_flight?` true locally, and disables the regenerate control until the response resolves.
8. When the recommendation contract returns a new result or failure, `IntelligentDashboardTab` updates `summary_projection` and `summary_tile_state` without reloading the page or rebuilding unrelated tile-local UI state.

Recommended event contract:
- `"summary_recommendation_regenerate_requested"` with `%{"recommendation_id" => id}`
- `"summary_recommendation_sentiment_submitted"` with `%{"recommendation_id" => id, "sentiment" => "up" | "down"}`

### 4.3 Lifecycle & Ownership
- Upstream oracle loading, cache participation, and scope identity remain owned by the dashboard runtime and snapshot layers.
- Metric derivation, recommendation-state shaping, and card applicability rules are owned by the summary projection/projector layer.
- The summary `live_component` owns only transient interaction state required to keep controls responsive between LiveView round trips.
- `IntelligentDashboardTab` owns event handling, integration with recommendation contracts, and propagation of updated summary projection/state into the shell.
- No DB persistence is introduced for summary tile local state.
- No browser hook is required for the initial implementation.

### 4.4 Alternatives Considered
- Keep the current placeholder summary projection and compute values directly in HEEx.
  - Rejected because it violates the explicit `FR-009` boundary and would repeat the exact anti-pattern the other dashboard FDDs avoid.
- Make one or more summary oracles required.
  - Rejected because Darren's technical direction explicitly says the four summary inputs are optional and should render incrementally.
- Reuse `ProgressBins` for average student progress.
  - Rejected because `ProgressBins` is optimized for per-container histograms, not a single scoped course/unit/module average. `ProgressProficiency` already carries per-student scoped `progress_pct`, which makes the summary average simpler and more direct.
- Push recommendation interaction state entirely into `IntelligentDashboardTab`.
  - Rejected because regenerate button disablement and optimistic control lock state are tile-local UI concerns that fit better in a `live_component`.

## 5. Interfaces
- Projection interface:
  - `Summary.derive(snapshot, opts) -> {:ok, projection} | {:partial, projection, reason} | {:error, reason}`
- Internal projector interface:
  - `Projector.build(available_oracles, opts) -> projection_map`
- LiveView assign interface:
  - `:summary_projection`
  - `:summary_projection_status`
  - `:summary_tile_state`
- LiveView event interface:
  - `"summary_recommendation_regenerate_requested"`
  - `"summary_recommendation_sentiment_submitted"`
- Recommendation contract interface from `MER-5305`:
  - implicit load via snapshot/oracle result
  - regenerate entrypoint returning a replacement recommendation contract
  - sentiment submission entrypoint keyed by recommendation id

## 6. Data Model & Storage
- No schema changes or migrations are required for `MER-5249`.
- No new dashboard-state persistence is required for summary UI interaction state.
- The only new data shapes are:
  - summary projection payload emitted in-memory from `Summary.Projector`
  - tile-local summary state in LiveView assigns/component state
- Any persistent rate-limit or recommendation artifact storage remains owned by `MER-5305`, not this ticket.

## 7. Consistency & Transactions
- There is no multi-write transaction in the metric-render path.
- Recommendation regeneration and sentiment submission are single-action UI flows that delegate consistency guarantees to the `MER-5305` service boundary.
- Summary projection derivation must be deterministic for identical upstream oracle inputs.
- Scope changes must replace summary projection content atomically at the LiveView assign level so cards and recommendation never represent different scopes in the same render.

## 8. Caching Strategy
- The summary tile should participate in the existing dashboard snapshot/oracle cache lifecycle.
- It should not introduce a separate tile-local cache.
- Regenerate requests must rely on `MER-5305` cache invalidation/update semantics so the summary tile does not show stale recommendation content on rerender or revisit.
- Tile-local sentiment/regenerate UI state must reuse the current projection and not trigger a full page reload.

## 9. Performance & Scalability Posture
- Summary metric derivation is intentionally bounded:
  - progress average is a reduction over already scoped `ProgressProficiency` rows
  - assessment average is a reduction over already aggregated `Grades` rows
  - proficiency average is a reduction over objective-level results in scope
- The tile renders at most three metric cards plus one recommendation panel, so DOM complexity is low.
- The design avoids extra DB queries from HEEx or event handlers.
- No dedicated performance benchmark is required for this story, but the implementation should continue to rely on snapshot/oracle contracts instead of ad hoc fetches.

## 10. Failure Modes & Resilience
- Missing summary metric input:
  - hide only the affected card and expand remaining cards; do not fail the region.
- Missing recommendation input:
  - render the non-breaking recommendation unavailable or thinking state rather than collapsing the whole tile.
- Recommendation regeneration failure:
  - preserve the previous recommendation, clear the in-flight flag, and render an actionable error state.
- Duplicate thumbs submission or stale recommendation id:
  - server response wins; keep UI consistent with the contract result rather than trying to enforce idempotency in HEEx alone.
- Projection derivation failure:
  - return an explicit projection failure status and render a bounded fallback state in the summary tile instead of crashing the dashboard shell.

## 11. Observability
- Reuse the existing projection telemetry emitted by `Oli.Dashboard.Snapshot.Projections`.
- Add targeted telemetry/logging for:
  - summary projection failure or partial derivation
  - recommendation regenerate requested / completed / failed
  - sentiment submission completed / failed
- Suggested event names:
  - `summary_tile.regenerate_clicked`
  - `summary_tile.regenerate_failed`
  - `summary_tile.sentiment_submitted`
- Logging should avoid raw recommendation prompt context or student-identifying details.

## 12. Security & Privacy
- The summary tile remains instructor-only and section-scoped under existing dashboard authorization.
- Metric cards show aggregate values only and must not expose student-level PII.
- Recommendation content and telemetry must follow the privacy posture established by `MER-5305`; this tile must not log raw student-identifying context or provider payloads.
- No new roles, permissions, or cross-institution access paths are introduced.

## 13. Testing Strategy
- Projection tests:
  - `AC-002`: partial oracle availability yields a valid partial summary projection with only available subcomponents rendered.
  - `AC-003`: objective- or assessment-free scopes hide the corresponding cards and emit the expected layout metadata.
  - `AC-005`: no-activity recommendation input produces the beginning-course fallback state.
  - `AC-009`: summary aggregation/formatting logic lives in projector modules, not in the tile component.
- LiveView/component tests:
  - `AC-001`: summary tile renders directly below the scope navigator in the shell.
  - `AC-004`: tooltip triggers are focusable and expose accessible association attributes.
  - `AC-006`: regenerate disables while request is in flight and re-enables after completion/failure.
  - `AC-007`: scope changes update summary values and recommendation without a full page reload.
  - `AC-008`: thumbs/regenerate controls dispatch the expected LiveView events and maintain consistent visible state.
- Manual validation:
  - compare light, dark, and thinking states against the Jira-linked Figma references
  - verify screen-reader announcement wording for recommendation content
  - verify keyboard-only access to tooltips and controls

## 14. Backwards Compatibility
- The dashboard route, scope selector, and section-group composition remain unchanged.
- Existing placeholder summary behavior is replaced in place; no external API contract is removed for other surfaces.
- The design is compatible with the current dashboard shell and does not require migrating persisted dashboard state.

## 15. Risks & Mitigations
- Recommendation oracle contract drift from `MER-5305`: keep the summary projection bound to a normalized recommendation view model and update only the adapter layer if the backend contract changes.
- Ambiguity in class-proficiency source could cause late implementation churn: this FDD selects `ObjectivesProficiency` as the canonical v1 input and records that choice explicitly.
- UI-control semantics could overlap with `MER-5250`: keep this ticket limited to rendering and dispatching thumbs/regenerate controls, while richer additional-feedback workflow remains outside scope.
- Existing placeholder projection dependencies could accidentally keep stale legacy behavior alive: replace the dependency list in `Summary` rather than layering new logic on top of the old placeholder contract.

## 16. Open Questions & Follow-ups
- Confirm the exact recommendation oracle key and payload shape once `MER-5305` merges so the summary projection can bind to a concrete module/key name.
- Confirm whether recommendation sentiment controls should lock after first submission in `MER-5249` or simply reflect backend response state and leave stricter duplicate-prevention UX to `MER-5250`.
- Follow-up implementation should decide whether summary tile strings and tooltip copy live in an existing dashboard copy module or are first introduced locally and later centralized.

## 17. References
- [prd.md](./prd.md)
- [requirements.yml](./requirements.yml)
- [informal.md](./informal.md)
- [dashboard_ui_composition.md](../dashboard_ui_composition.md)
- [summary.ex](/Users/santiagosimoncelli/Documents/Projects/oli-torus/lib/oli/instructor_dashboard/data_snapshot/projections/summary.ex)
- [summary_tile.ex](/Users/santiagosimoncelli/Documents/Projects/oli-torus/lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/summary_tile.ex)
- [shell.ex](/Users/santiagosimoncelli/Documents/Projects/oli-torus/lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex)
- [intelligent_dashboard_tab.ex](/Users/santiagosimoncelli/Documents/Projects/oli-torus/lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex)
- [oracle_bindings.ex](/Users/santiagosimoncelli/Documents/Projects/oli-torus/lib/oli/instructor_dashboard/oracle_bindings.ex)
