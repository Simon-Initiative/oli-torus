# Instructor Expanded LO Visualization - Functional Design Document

## 1. Executive Summary

This FDD replaces the existing one-dimensional expanded Learning Objective (LO) visualization
(`DotDistributionChart` + `StudentProficiencyList`) with a two-dimensional Student Distribution
matrix and a group-based student table. The design keeps the existing expanded-row lifecycle owned
by `OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView` and keeps the existing
email-modal plumbing.

Two decisions changed after the first draft of this FDD, based on prior art found elsewhere in the
repository (section 3) and a deliberate engineering-risk-driven delivery sequence (section 13/plan.md):

1. The new matrix is a **pure HEEx/SVG component**, not a new React/Vega-Lite component. A materially
   similar 2D student-position matrix already exists in this codebase
   (`OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.StudentSupportParametersModal.matrix/1`)
   rendered as plain SVG with server-computed dot positions and no charting library, proving the
   approach works in this stack without React.
2. Group assignment and the widened linked-activity denominator ship first, in isolation, driving a
   chart-only PR with a no-op selection event; the student table and its selection/email behavior
   follow in two subsequent PRs. This validates the HEEx-chart bet in production before the rest of
   the feature is built on top of it.

## 2. Requirements & Assumptions

- Functional requirements: FR-001 through FR-011 in `requirements.yml` (matrix visualization,
  default state, group table display, group/guidance content, student selection & email, load more,
  group switching, closing, empty state, calculation integrity, keyboard accessibility). Full detail:
  `prd.md` sections 5-7.
- Non-functional requirements: WCAG 2.1.1 / 2.4.7 accessibility; zero new runtime JSONB scans for the
  linked-activity denominator; single source of truth for group assignment; no change to the existing
  Low/Medium/High proficiency chip presentation. Full detail: `prd.md` section 8.
- Assumptions (carried from `prd.md` section 14, restated here as design inputs):
  - The x-axis group split (Needs Support vs. Excelling) uses the student's continuous numeric
    proficiency score (`estimate.score`, 0.0-1.0) against a 50% threshold, not the Low/Medium/High
    *label* thresholds (Low <= 40%, Medium <= 80%, High > 80%) used for the display chip. Both
    thresholds are real and coexist: the label is presentational (already implemented in
    `OliWeb.Delivery.LearningObjectives.Proficiency`), the 50% split is the new group-membership rule.
  - `total_related_activities == 0` is treated as 0% activity completion, which places that student
    in Limited Activity.
  - Activity Completion is `activities_attempted_count / total_linked_activity_count`, the existing
    "attempted at least once" proxy from `Oli.Delivery.Metrics.student_activities_attempted_count/3`.
  - Boundary operators are inclusive on the "high" side: activity completion `>= 50%` is high
    activity; proficiency `>= 50%` is the Excelling side. Exactly-50% cases resolve deterministically
    this way pending confirmation (`prd.md` Open Questions).
  - A student with "Not enough data" proficiency (fewer than 3 first attempts) and high activity
    completion is provisionally classified as Needs Support (conservative default). Flagged again in
    section 16 as the single highest-uncertainty classification rule in this design.
  - The matrix has **exactly three** selectable/highlightable regions, not four. Visually the plot
    area is drawn with a dividing line at 50% proficiency and 50% activity completion, but the two
    lower quadrants (below the activity line, on either side of the proficiency line) are one merged
    Limited Activity hit-region spanning the full chart width, confirmed directly from the Figma
    layout geometry in `design/instructor_viz_ui_brief.md`. Selection state is therefore
    `nil | :needs_support | :excelling | :limited_activity`, never a fourth value.
  - The new table's checkbox column uses a native `<input type="checkbox">`, matching
    `StudentProficiencyTableModel`'s existing pattern, rather than the custom `role="checkbox"` button
    pattern used by `StudentSupportTile`. Native checkboxes are keyboard-operable with no extra ARIA
    work, which fits this ticket's accessibility requirements with the least new code. Revisit this
    only if a screenshot-level check of the Figma table header (the checkbox instance was marked
    `hidden="true"` in the metadata inspected for this work item) shows a custom visual that native
    checkboxes cannot express.

## 3. Repository Context Summary

- What we know:
  - `OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView`
    (`lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`) owns expanded-row
    lifecycle: it loads data synchronously or asynchronously in `handle_initial_update/2`, forwards
    async results through `send/2` + `update/2`'s `loaded_data` branch, and currently tracks
    `selected_proficiency_level` plus `handle_event("show_students_list", ...)` /
    `handle_event("hide_students_list", ...)`.
  - The current per-student dataset is built by `retrieve_students_data/1` (joins account data) and
    `add_missing_students_to_proficiency_data/4` (adds missing enrolled students, attaches
    `activities_attempted_count` / `total_related_activities` from a **single-objective**
    `SectionResourceDepot.get_section_resource/2` read).
  - `Oli.Delivery.Metrics.student_proficiency_for_objective/2` returns `%{id, proficiency,
    proficiency_range}` per student using `Oli.Analytics.Summary.Proficiency.estimates_for_objectives/3`
    under the hood; the numeric `estimate.score` and the categorical `estimate.label`
    (`:low | :medium | :high`, mapped to strings by a private `estimate_label/1`) are both already
    available at this layer.
  - `Oli.Delivery.Metrics.student_activities_attempted_count/3` is already a pure aggregate query
    (`COUNT(DISTINCT resource_id) ... GROUP BY user_id`) filtered by section, student id list, a
    caller-supplied `related_activity_ids` list, `project_id == -1`, activity resource type, and
    `num_attempts > 0`. It already returns only `%{student_id => count}`.
  - `SectionResourceDepot.objectives_with_effective_children_for(section_id, resource_ids)`
    (`lib/oli/delivery/sections/section_resource_depot.ex:209`) is an existing **bounded** lookup that
    returns the requested objective section-resources with `children` normalized to objective
    *resource ids* (not internal section-resource ids), without hydrating every objective in the
    course.
  - `SectionResourceDepot.get_resources_by_ids(section_id, resource_ids)`
    (`section_resource_depot.ex:141`) is the existing batched cache read already used by
    `ExpandedObjectiveView.get_sub_objectives_data/3` for sub-objective activity counts; it never
    touches the database once the section depot is initialized.
  - `OliWeb.Delivery.LearningObjectives.Proficiency.chip/1`
    (`lib/oli_web/components/delivery/learning_objectives/proficiency.ex`) already renders the
    Low/Medium/High/Not-enough-data chip with tokens confirmed to match the Figma variable defs
    pulled for this ticket. Reused as-is for the new table's Proficiency column.
  - **New finding, changes the chart's technology choice**: a materially similar 2D student-position
    matrix already exists at
    `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_parameters_modal.ex`
    (function component `matrix/1`, around line 320). It renders an `<svg viewBox="...">` with
    server-computed region `<rect>`s, region `<text>` labels, and `<circle :for={point <-
    @student_points} ...><title>{point.label}</title></circle>` dots positioned by
    `progress_pct`/`proficiency_pct` (computed server-side by `matrix_x/1`/`matrix_y/1` in the sibling
    `StudentSupportTile` module) — **no charting library, no React**. Dark-mode is handled with
    Tailwind `dark:` classes directly on SVG elements (no JS dark-mode detection). Sizing is handled by
    the SVG's `viewBox` attribute (no JS resize/visibility observer needed for the base rendering).
    The one JS hook this component uses (`StudentSupportParametersMatrix`) exists only to support
    *dragging* the threshold boundaries — a capability this ticket does not need, since MER-5814 only
    requires click/keyboard *selection* of a fixed region, not moving a boundary.
  - **New finding, changes what "table reuse" means**: `StudentSupportTile`
    (`.../tiles/student_support_tile.ex`, MER-5252) renders a bucket-detail panel with strong
    structural overlap to what this ticket needs beside the chart: a header (title + count +
    description), a search/filter row, a select-all + `EmailButton` row, a scrollable student list with
    per-row checkboxes, an empty-state message, and a "Load N more" affordance. However, it is **not**
    built on `OliWeb.Common.SortableTable` (it is a hand-rolled scrollable `div` list with no sortable
    columns), and its columns/filters (search, Active/Inactive, "View Profile") differ from what this
    ticket needs (sortable Proficiency/Activity Completion columns, a proficiency sub-filter, no
    profile link). The columns and overall table markup are therefore **not** a drop-in reuse
    candidate. What *is* a genuine, currently-triplicated reuse candidate is the **selection-state
    logic**: `StudentProficiencyList`, `StudentSupportTile`, and this ticket's planned table all
    independently implement the same `MapSet`-based row-toggle, select-all-toggle, and
    selected-emails-derivation logic. This FDD extracts that logic once (section 4.1) rather than
    writing a fourth copy.
  - `OliWeb.Components.Delivery.Students.EmailButton` (already used by both `StudentProficiencyList`
    and `StudentSupportTile`) renders through `OliWeb.Components.DesignTokens.Primitives.Button`, the
    one existing `design_tokens/` primitive in this codebase, so the new table's Email button requires
    no new component work.
- Unknowns to confirm (do not block design, but block final boundary-value implementation): the
  exact-50% inclusivity rule, the "Not enough data + high activity" classification, whether
  `total_related_activities == 0` should be visually distinguished from a normal Limited Activity
  entry, and the checkbox visual pattern noted in section 2. Tracked in section 16.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- **`Oli.Delivery.Metrics.StudentDistributionGroup`** (new, `lib/oli/delivery/metrics/student_distribution_group.ex`):
  a pure, side-effect-free module owning the group-assignment rule. Public API:
  - `group_for(proficiency_score :: float, activity_completion :: float) :: :needs_support | :excelling | :limited_activity`
  - `assign(students :: [map()]) :: [map()]` — takes the enriched per-student list (each entry already
    carrying `proficiency`, `activities_attempted_count`, `total_related_activities`) and returns the
    same list with an added `:activity_completion` float and `:distribution_group` atom per student.

  Placed in `lib/oli/` (not `lib/oli_web/`) because it is a domain classification rule, not a
  presentation concern, consistent with `docs/BACKEND.md`'s boundary guidance. (AC-012, AC-013,
  AC-014, AC-019, AC-031)

- **`ExpandedObjectiveView`** (modified): keeps owning expanded-row lifecycle and async loading.
  Changes:
  - Replace the single-objective `related_activities` lookup in
    `add_missing_students_to_proficiency_data/4` with a new private
    `linked_activity_ids_for_objective/2` that unions parent + sub-objective activity ids (section 4.2).
  - After building the enriched per-student list, call `StudentDistributionGroup.assign/1` once, so the
    resulting `student_proficiency` assign already carries `activity_completion` and
    `distribution_group` for every enrolled student.
  - Replace `selected_proficiency_level` with `selected_student_group` (`nil | :needs_support |
    :excelling | :limited_activity`).
  - Replace `handle_event("show_students_list", %{"proficiency_level" => level}, socket)` /
    `"hide_students_list"` with `handle_event("select_student_group", %{"group" => group}, socket)` /
    `handle_event("deselect_student_group", _params, socket)`. `select_student_group` toggles: if the
    incoming group matches the currently selected group, it deselects. (AC-006, AC-007, AC-008,
    AC-009, AC-024, AC-025, AC-026, AC-027, AC-028)

- **`StudentDistributionMatrix`** (new, **pure HEEx/SVG**,
  `lib/oli_web/components/delivery/learning_objectives/student_distribution_matrix.ex`, a stateless
  `Phoenix.Component` — not a `LiveComponent`, since it owns no state of its own): supersedes
  `DotDistributionChart.tsx` for this surface. Follows the pattern proven by
  `StudentSupportParametersModal.matrix/1` (section 3): an `<svg viewBox="...">` with three region
  `<rect>`s (Needs Support, Excelling, and one full-width Limited Activity region below the 50%
  activity line), one `<circle>` per student positioned by `proficiency`/`activity_completion`, and
  Tailwind `dark:` classes for theming. Each region is a real interactive target: `phx-click`
  (`phx-target={@myself}` bubbling to `ExpandedObjectiveView`, since this component is rendered inline
  inside it) pushing `"select_student_group"` with the region's group key, plus `tabindex="0"`,
  `role="button"`, `aria-pressed`, `aria-label`, and a `phx-keydown` binding that treats `Enter` and
  `Space` the same as a click (LiveView keydown bindings work on any focusable element, not only
  `<button>`). No JS hook is required for rendering, selection, or theming; a hook is only a candidate
  later if a richer hover tooltip than a native SVG `<title>` is requested (not a current
  requirement — see section 16). (AC-001, AC-002, AC-003, AC-004, AC-005, AC-034, AC-036)

- **`StudentSelection`** (new, shared, `lib/oli/utils/student_selection.ex` or
  `lib/oli_web/components/delivery/students/student_selection.ex` — final placement decided at
  implementation time based on whether any non-web caller emerges; default to the web-components
  location since today's three callers are all LiveView/LiveComponent-side): a small pure module
  extracted from the duplicated logic in `StudentProficiencyList` and `StudentSupportTile`. Public API:
  - `toggle(selected_ids :: [id], id) :: [id]`
  - `toggle_all(all_ids :: [id], selected_ids :: [id]) :: [id]`
  - `selected_emails(students :: [map()], selected_ids :: [id]) :: String.t()`

  `StudentProficiencyList` (being replaced by `StudentDistributionTable` in this ticket) does not need
  to be migrated to this module — it is deleted, not refactored. `StudentSupportTile` (a live,
  unrelated MER-5252 feature) **is** migrated to call this module as part of this ticket's PR3, purely
  to remove the third duplicate; its existing test suite
  (`test/.../student_support_tile_test.exs`, exact path to confirm at implementation time) must
  continue to pass unmodified in behavior. (Supports AC-020, AC-021; see section 15 for the
  cross-feature-touch risk this introduces.)

- **`StudentDistributionTable`** (new LiveComponent,
  `lib/oli_web/components/delivery/learning_objectives/student_distribution_table.ex`, superseding
  `StudentProficiencyList`): renders beside the chart when `selected_student_group != nil`.
  Responsibilities:
  - Filters the already-computed `student_proficiency` list by `distribution_group ==
    selected_student_group` — never recomputes grouping.
  - Renders the header block: group title, count, guidance copy, and suggested action, sourced from a
    static content map, plus the close ("X") control firing `deselect_student_group` on the parent.
  - Renders the proficiency sub-filter (`filter_by_proficiency` event), same four options in all three
    groups for implementation simplicity (section 16 tracks confirming the Figma dropdown's actual
    option list).
  - Reuses `OliWeb.Delivery.LearningObjectives.Proficiency.chip/1` for the Proficiency column.
  - Reuses `OliWeb.Components.Delivery.Students.EmailButton` and the existing
    `email_modal_payload`/`DraftEmailModal` forwarding pattern, calling the new `StudentSelection`
    module instead of reimplementing toggle/select-all/email-derivation.
  - Owns Load More as a `visible_count` assign + `Enum.take/2` slice over the already-loaded,
    already-filtered list (no server pagination). (AC-010, AC-011, AC-015, AC-016, AC-017, AC-018,
    AC-020, AC-021, AC-022, AC-023, AC-029, AC-030, AC-033, AC-035, AC-036)

- **`StudentDistributionTableModel`** (new, superseding `StudentProficiencyTableModel`): same
  `SortableTableModel` pattern, columns: selection (native `<input type="checkbox">`, per section 2),
  student name, proficiency (via `Proficiency.chip/1`), activity completion — with the group-specific
  default `sort_by_spec` chosen when the table mounts for a given group (AC-015, AC-016, AC-017).

### 4.2 State & Data Flow

1. Row expands -> `ExpandedObjectiveView.handle_initial_update/2` (unchanged trigger).
2. `linked_activity_ids_for_objective/2` (new):
   ```elixir
   def linked_activity_ids_for_objective(section_id, objective_id) do
     case SectionResourceDepot.objectives_with_effective_children_for(section_id, [objective_id]) do
       [%{children: child_ids}] ->
         child_ids = List.wrap(child_ids)
         SectionResourceDepot.get_resources_by_ids(section_id, [objective_id | child_ids])
         |> Enum.flat_map(&(&1.related_activities || []))
         |> Enum.uniq()

       [] ->
         []
     end
   end
   ```
   Zero new database queries: both Depot calls hit the already-initialized ETS-backed cache.
3. `retrieve_students_data/1` and the missing-students backfill stay as-is.
4. `StudentDistributionGroup.assign/1` runs once over the combined list, producing
   `activity_completion` and `distribution_group` per student in-memory.
5. The resulting list is assigned as `student_proficiency` and flows to both
   `StudentDistributionMatrix` (rendered inline, computing region counts/positions from the flat
   per-student list) and, once selected, to `StudentDistributionTable` (filtered slice).
6. Selecting a region: the SVG region's `phx-click`/`phx-keydown` fires `select_student_group` directly
   on `ExpandedObjectiveView` (no client-side event bridge needed, unlike the React/`pushEventTo`
   design this supersedes) -> `selected_student_group` updates -> LiveView re-renders, mounting
   `StudentDistributionTable` with the filtered slice once it exists (PR2 onward; PR1 ships this event
   as a no-op beyond setting the assign, per the delivery sequence in `plan.md`).
7. Load More: `StudentDistributionTable` keeps a `visible_count` assign over its already-filtered,
   already-sorted list; `handle_event("load_more", ...)` increments it — a single `Enum.take/2`, no new
   query.
8. Closing (via "X" or re-clicking the selected region): `deselect_student_group` sets
   `selected_student_group` back to `nil`; `StudentDistributionTable` unmounts; the chart re-renders
   with no highlighted region. No student data is touched by this transition (AC-028).

### 4.3 Lifecycle & Ownership

- `ExpandedObjectiveView` remains the sole owner of `selected_student_group` and the enriched
  `student_proficiency` list.
- `StudentDistributionMatrix` is a stateless function component — it renders from assigns passed to it
  on every parent render and owns no process/state of its own, which is only possible because it is
  HEEx rather than a separately-mounted React application; this removes an entire class of lifecycle
  concerns (LiveReact mount timing, visibility/resize observers) that the React alternative would have
  needed.
- `StudentDistributionGroup` and `StudentSelection` are both stateless modules.
- `StudentDistributionTable`'s `visible_count` and any local sort-state are the only new
  per-LiveComponent state.

### 4.4 Alternatives Considered

- **Chart technology: HEEx/SVG vs. a new React component.** The original draft of this FDD proposed a
  new React component mirroring `DotDistributionChart`'s Vega-Lite + React/SVG hybrid, per
  `informal.md`'s Jira-comment-sourced recommendation to keep that pattern. That recommendation was
  reasoned from the *current* component's specific complexity: per-dot tooltips, dynamic collapsing of
  6+ same-proficiency students into one grouped "tower" dot, and JS-driven dark-mode/resize handling.
  None of those requirements carry over cleanly to this ticket: the ticket has no tooltip acceptance
  criterion, the Figma mocks show one dot per student with no collapsing behavior, dark-mode is
  achievable with Tailwind `dark:` classes with no JS, and an SVG `viewBox` scales without a resize
  observer. `StudentSupportParametersModal.matrix/1` (section 3) is a working, shipped proof that this
  stack renders an equivalent 2D student-position matrix without a charting library. Given no
  requirement here forces React, HEEx/SVG is simpler (fewer moving parts, no LiveReact registration, no
  event-bridge indirection) and is the chosen approach. If a future requirement needs true rich
  per-dot hover tooltips or very dense-crowd dot collapsing, that would be a reason to revisit — tracked
  as an open question, not a current blocker.
- **Table reuse: one shared component vs. extracted subcomponents.** Considered building one shared
  "student list panel" component used by both `StudentSupportTile` and this ticket's table. Rejected:
  `StudentSupportTile` is a hand-rolled list with search/Active-Inactive filtering and a "View Profile"
  link, while this ticket needs `SortableTable`-based sortable columns and a proficiency sub-filter —
  forcing one shared component would mean threading divergent column/filter/action configuration
  through it, which is more complexity than the duplication it would remove. Only the selection-state
  logic (`StudentSelection`, section 4.1) is extracted, because that piece is byte-for-byte duplicated
  business logic across three call sites today, not merely visually similar UI.
- **Load More via server pagination**: rejected for the reasons in the original draft — the expanded
  row already loads the entire enrolled roster into memory for the chart, so there is no query-cost
  reduction to gain from a new paged-query contract.
- **Group-assignment placement**: `lib/oli/` over `lib/oli_web/`, per `docs/BACKEND.md`'s domain-rule
  boundary guidance, unchanged from the original draft.

## 5. Interfaces

- LiveView event `select_student_group` — payload `%{"group" => "needs_support" | "excelling" |
  "limited_activity"}`, fired by `StudentDistributionMatrix`'s region `phx-click`/`phx-keydown`
  bindings, handled by `ExpandedObjectiveView`.
- LiveView event `deselect_student_group` — no payload, fired by re-clicking the selected region
  (chart) or the table's close control (once it exists).
- LiveView event `load_more` (scoped to `StudentDistributionTable`'s `@myself` target) — no payload.
- LiveView event `filter_by_proficiency` (scoped to `StudentDistributionTable`) — payload
  `%{"proficiency" => "not_enough_info" | "low" | "medium" | "high" | "all"}`.
- `StudentDistributionMatrix` component attrs (HEEx, not a network/JSON contract):
  ```
  attr :students, :list, required: true
  # each entry: %{id, proficiency, proficiency_range, activity_completion, distribution_group}
  attr :selected_group, :atom, default: nil  # nil | :needs_support | :excelling | :limited_activity
  attr :myself, :any, required: true          # phx-target for the parent LiveComponent
  attr :unique_id, :string, required: true
  ```
  `distribution_group` and `activity_completion` are always pre-computed by
  `StudentDistributionGroup.assign/1` before reaching this component — it never re-derives group
  membership, satisfying the "single source of truth" NFR by construction (there is no second
  implementation of the rule on the client, because there is no client-side code at all).
- `Oli.Delivery.Metrics.StudentDistributionGroup.group_for/2` and `.assign/1` — internal Elixir API.
- `StudentSelection.toggle/2`, `.toggle_all/2`, `.selected_emails/2` — internal Elixir API, consumed by
  `StudentDistributionTable` and (post-PR3 migration) `StudentSupportTile`.
- `SectionResourceDepot.objectives_with_effective_children_for/2` and `.get_resources_by_ids/2` —
  existing internal APIs, no signature changes required.

## 6. Data Model & Storage

No schema or migration changes. `section_resources.related_activities` (`bigint[]`) is read, not
written. `distribution_group` and `activity_completion` are computed in-memory per request/expansion
and are not persisted.

## 7. Consistency & Transactions

No new transactional boundaries. All reads are through `SectionResourceDepot` (cache) and read-only
`Ecto.Repo` queries. Group assignment is pure in-memory computation over data already fetched in one
expanded-row load, so the chart and table can never observe different snapshots within one expansion.

## 8. Caching Strategy

Continues to rely on `SectionResourceDepot`'s existing ETS-backed cache; no new cache is introduced.
The widened `linked_activity_ids_for_objective/2` call trades one single-objective Depot read for two
Depot reads, both still zero-database-query once the section depot is initialized.

## 9. Performance & Scalability Posture

- No new N+1 risk: the per-student activity numerator remains one aggregate `GROUP BY user_id` query
  regardless of how many linked activity ids are passed in.
- Load More is a pure in-memory `Enum.take/2` slice.
- `StudentDistributionGroup.assign/1` is O(n) over the enrolled student list, matching existing O(n)
  work already done elsewhere in the same loader.
- Removing the React/Vega-Lite rendering path for this surface (replaced by server-rendered SVG) is a
  net reduction in client-side JS work per row expansion, not a regression.
- No new NFR test budget is defined for this ticket; `harness.yml`'s `performance_requirements`
  capability defaults to excluded. Telemetry (section 11) is the chosen observability lever instead.

## 10. Failure Modes & Resilience

- `SectionResourceDepot.objectives_with_effective_children_for/2` returning `[]` for the requested
  objective is handled by `linked_activity_ids_for_objective/2` returning `[]`, which flows into
  `total_related_activities == 0` for every student — the existing zero-denominator path, not a new
  failure mode.
- Async load failures (`Task.start/1` crashing) are already unhandled by the current implementation in
  the same way; this ticket does not change that failure posture.
- If `estimate.score` is `nil` for a student who nonetheless has an `estimate.label`, the group
  assignment function must treat that student the same as "Not enough data" rather than raising on a
  nil comparison.
- A `phx-keydown` binding on a non-`<button>` SVG element only fires while that element has DOM focus;
  the region must have `tabindex="0"` for keyboard users to reach it at all — a straightforward but
  easy-to-forget requirement, called out explicitly here so it is not lost during implementation.

## 11. Observability

Per `harness.yml`, telemetry defaults to included:

- Emit a telemetry event on `select_student_group`/`deselect_student_group`, tagged with `section_id`,
  `objective_id`, and `group`.
- Emit a telemetry event on Email-from-group and Load More usage (once those exist, PR3), same tags
  plus `selected_count` for email.
- Instrument `linked_activity_ids_for_objective/2` and the `student_activities_attempted_count/3` call
  with existing Ecto/Phoenix telemetry so a regression relative to the current single-objective lookup
  is visible in AppSignal.

## 12. Security & Privacy

No new access-control surface: this feature reads the same section-scoped, instructor-authorized data
already exposed by the current expanded view, through the same LiveView authorization boundary as
today. No new PII is exposed. Email sending continues through the existing `EmailButton` /
`DraftEmailModal` path, unchanged.

## 13. Testing Strategy

Per `docs/TESTING.md`: ExUnit for pure/local logic, `Phoenix.LiveViewTest` for LiveView state
transitions. No Jest coverage is needed for the chart (it is HEEx, not a React component); no
`Oli.Scenarios` coverage is warranted (this is a LiveView rendering/event-handling feature).

Delivery is sequenced as three PRs (`plan.md` phases 1-3), each independently mergeable to `master`
under this team's release-cut model (`master` does not imply production until a release is cut, so
partial functionality landing on `master` between PRs is acceptable as long as all three land before
the next release):

- **PR1 (chart only, table not yet built)**: replaces `DotDistributionChart` with
  `StudentDistributionMatrix`; `select_student_group`/`deselect_student_group` update
  `selected_student_group` and nothing else renders differently yet. Verifies:
  - AC-001, AC-002, AC-003, AC-004, AC-005: chart rendering, dot placement, per-group counts.
  - AC-006: default state, no highlight.
  - AC-024, AC-027: region-level switching and re-click-to-deselect (chart-only; no table to close yet).
  - AC-031: selection does not mutate proficiency/activity data (trivial to verify now, worth locking
    in early as a regression guard).
  - AC-032: grouping recalculates from updated fixture data without a page reload.
  - AC-034, AC-036: keyboard-selectable regions with visible focus indicators (chart-level; table
    controls are verified in PR3).
  - ExUnit, `StudentDistributionGroupTest`: AC-012, AC-013, AC-014, AC-019 (boundary and
    exactly-one-group tests), plus the `total_related_activities == 0` and nil-`proficiency` cases from
    section 10.
  - ExUnit, denominator-widening tests: correctness of the parent+sub-objective union.
- **PR2 (table added, read-only)**: `StudentDistributionTable` renders beside the chart when a group is
  selected, no selection checkboxes or Email button yet. Verifies:
  - AC-007: table is absent until a group is selected (now meaningfully testable).
  - AC-008, AC-009, AC-010, AC-011: table position, persistent highlight, header content, filtered rows.
  - AC-015, AC-016, AC-017, AC-018: per-group guidance copy, default sort, proficiency filter.
  - AC-025, AC-026, AC-028: switching groups updates the table without closing first, the table's "X"
    closes it, and no data is mutated by closing.
  - AC-029, AC-030: empty-group rendering.
- **PR3 (selection, email, shared-selection extraction)**: adds the checkbox column, select-all,
  `EmailButton` wiring, and migrates `StudentSupportTile` onto the new `StudentSelection` module.
  Verifies:
  - AC-020, AC-021: row/select-all checkboxes and the Email button acting on the current selection.
  - AC-022, AC-023, AC-033: Load More append behavior.
  - AC-035: every table control (checkboxes, Email, Load More, filter, Close) is keyboard-operable.
  - AC-036 (final pass): focus-visible styling across every control introduced across all three PRs.
  - Regression: `StudentSupportTile`'s existing test suite still passes unmodified after migrating it
    onto `StudentSelection`.

## 14. Backwards Compatibility

- This is a full replacement of the current expanded visualization behind no feature flag, sequenced
  as three PRs landing on `master` ahead of the next release cut rather than shipped as one large
  change.
- `DotDistributionChart.tsx` and its `registerApplication` line in `assets/src/apps/Components.tsx` are
  deleted in PR1 (not deprecated), since the HEEx replacement ships in the same PR.
- `StudentProficiencyList`/`StudentProficiencyTableModel` are deleted in PR2 (not deprecated), since
  the replacement table ships in that PR.
- Existing tests referencing `selected_proficiency_level`,
  `show_students_list`/`hide_students_list`, and `StudentProficiencyList`/`StudentProficiencyTableModel`
  must be migrated to the new event names and modules in the same PR that removes what they tested.
- `StudentSupportTile`'s public behavior must not change when it is migrated onto `StudentSelection` in
  PR3 — this is a pure internal refactor of a live, unrelated feature (MER-5252), and should be called
  out explicitly in that PR's description so reviewers scope their review accordingly.

## 15. Risks & Mitigations

- Risk: the widened linked-activity denominator changes `total_related_activities` for every
  top-level objective that has sub-objectives. Mitigation: this is an intentional, PRD-approved
  correction (Requirement 1 in `informal.md`), called out in the PR1 description so reviewers don't
  mistake it for an unrelated behavior change.
- Risk: `StudentSelection` extraction in PR3 touches `StudentSupportTile`, a file this ticket does not
  otherwise own. Mitigation: keep that migration mechanical (call the new module instead of inline
  `MapSet` logic, no behavior change), run `StudentSupportTile`'s existing tests unmodified, and flag
  the cross-feature touch explicitly for review (ideally with input from whoever last worked MER-5252).
- Risk: reusing the same four-option proficiency filter UI across all three groups when only Limited
  Activity strictly needs all four options could confuse instructors. Mitigation: flagged in section 16
  for design confirmation against the Figma dropdown's actual option list.
- Risk: choosing native checkboxes over `StudentSupportTile`'s custom `role="checkbox"` pattern could
  turn out to mismatch the approved Figma visual (the checkbox instance was marked hidden in the
  inspected frames). Mitigation: this is a low-cost decision to reverse in PR3 if a screenshot-level
  check contradicts it; it does not block PR1 or PR2.
- Risk (carried from `prd.md`): shipping the wrong Activity Completion definition. Mitigation:
  unchanged — flagged explicitly rather than silently assumed correct.

## 16. Open Questions & Follow-ups

Carried forward from `prd.md` (not re-litigated here) plus follow-ups from this revision:

- All open questions listed in `prd.md` section 14 remain open: the final Activity Completion
  definition, the "Not enough data" + high-activity classification (this FDD's working default: Needs
  Support), the `total_related_activities == 0` handling, exact-50% boundary inclusivity, dot-collapsing
  behavior at high density, the per-group badge icon question, and responsive-layout scope.
- Confirm the actual option list rendered by the Figma "Drop-down filter" component in each group's
  header before implementing `filter_by_proficiency`.
- Confirm the checkbox visual in the Figma table header (currently marked hidden in the inspected
  frame metadata) before finalizing whether native `<input type="checkbox">` is visually sufficient, or
  whether a custom-styled checkbox is required.
- If a future requirement needs rich per-dot hover tooltips beyond a native SVG `<title>`, or
  collapsing of many same-value dots into one grouped marker, that would be the trigger to revisit the
  HEEx-vs-React decision in section 4.4 for this specific surface — not a reason to preemptively add
  either capability now.

## 17. References

- `prd.md` (this work item)
- `informal.md` (this work item) — original technical investigation, Jira comment context from Darren
  Siegel and Jess Fortunato
- `design/instructor_viz_ui_brief.md` (this work item) — Figma-derived UI brief
- `plan.md` (this work item) — three-PR delivery sequence
- `requirements.yml` (this work item) — FR-001..FR-011, AC-001..AC-036
- `lib/oli_web/components/delivery/learning_objectives/expanded_objective_view.ex`
- `lib/oli_web/components/delivery/learning_objectives/student_proficiency_list.ex`
- `lib/oli_web/components/delivery/learning_objectives/student_proficiency_table_model.ex`
- `lib/oli_web/components/delivery/learning_objectives/proficiency.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_parameters_modal.ex`
- `lib/oli/delivery/metrics.ex`
- `lib/oli/delivery/sections/section_resource_depot.ex`
- `lib/oli_web/components/delivery/students/email_button.ex`
- `assets/src/components/misc/DotDistributionChart.tsx`
- `assets/src/apps/Components.tsx`
- `docs/BACKEND.md`, `docs/FRONTEND.md`, `docs/TESTING.md`, `docs/DESIGN.md`, `docs/OPERATIONS.md`
