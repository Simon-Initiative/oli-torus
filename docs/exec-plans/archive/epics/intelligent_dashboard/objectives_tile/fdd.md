# Challenging Objectives Tile - Functional Design Document

## 1. Executive Summary
This design completes the `Challenging Objectives` tile as a normal Intelligent Dashboard consumer built on the existing snapshot/oracle stack instead of introducing any tile-local query path. The simplest adequate implementation is to finish the already-present tile lane pieces that are currently placeholders: add a real consumer binding for `challenging_objectives`, replace the placeholder `ChallengingObjectives` projection so it depends on objective-specific oracle data rather than the current progress proxy, shape a tile-focused hierarchy view model from oracle payloads plus `SectionResourceDepot`, and render that view model in the existing `challenging_objectives_tile.ex` component. The destination `Insights -> Learning Objectives` surface remains the deeper workflow and is not embedded inside the tile; instead, the tile emits deterministic deep links that preselect scope and initial expansion context on arrival. No schema or new runtime process is required. The main technical risks are hierarchy reconstruction, stale scope rendering during rapid filter changes, and mismatch between tile state and learning-objectives deep-link behavior; those are handled through snapshot-scoped projection data, LiveView token guards already established in the dashboard runtime, and an explicit URL/param contract for destination initialization.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` / `AC-001`: render the tile only when objectives exist for the selected scope and authorized instructor context.
  - `FR-002` / `AC-002`: show only low-proficiency objectives or sub-objectives at `<= 40%` for the current scope.
  - `FR-003` / `AC-003`: preserve curriculum ordering and show parent/child hierarchy correctly.
  - `FR-004` / `AC-004`: disclosure controls are keyboard-accessible and expose expanded state.
  - `FR-005` / `AC-005`: parent-objective clicks deep-link to `Insights -> Learning Objectives` with expanded context.
  - `FR-006` / `AC-006`: sub-objective clicks deep-link to the same destination with the relevant child visible in context.
  - `FR-007` / `AC-007`: `View Learning Objectives` opens the all-objectives view without forced expansion.
  - `FR-008` / `AC-008`, `AC-009`, `AC-010`: no-objectives, no-data, and no-low-proficiency states are distinct.
  - `FR-009` / `AC-011`: rapid scope changes never leave stale scope results rendered.
- Non-functional requirements:
  - Use existing dashboard oracle/snapshot/cache boundaries; no tile-local analytics query path.
  - Accessibility must satisfy WCAG 2.1 AA for row activation, disclosure controls, focus visibility, and semantic state.
  - Tile render should remain bounded to the current scope’s qualifying objective rows and reuse existing stale-result suppression in dashboard runtime.
  - Telemetry is included by default per `harness.yml`; feature flags and bespoke performance test gates are not required by default for this work item.
- Assumptions:
  - The low-proficiency threshold remains fixed at `<= 40%`.
  - Existing curriculum ordering in section resources is the source of truth for parent/objective ordering.
  - `ObjectivesProficiencyOracle` may return only low-performing objective records and not a fully assembled tree; `SectionResourceDepot` is therefore the approved source for hierarchy reconstruction.
  - The existing `Insights -> Learning Objectives` page can be extended to accept URL params for initial scope/card/expansion state without redesigning that page’s broader behavior.
  - When only a sub-objective qualifies as low proficiency, the parent objective remains visible as the expandable context row and nests the qualifying child beneath it.

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile.ex` already exists but is a placeholder-only HEEx component.
  - `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/content_section.ex` already composes the tile under the `Content` section.
  - `lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex` already decides tile eligibility with `has_objectives_tile?/2`, manages scope normalization, and participates in the session-scoped coordinator/snapshot flow.
  - `lib/oli/instructor_dashboard/oracles/objectives_proficiency.ex` and `lib/oli/instructor_dashboard/oracles/scope_resources.ex` already exist as concrete oracles.
  - `lib/oli/instructor_dashboard/data_snapshot/projections/challenging_objectives.ex` already exists but is currently wired incorrectly to `:oracle_instructor_progress` and returns a `progress_proxy`, so it is not aligned with this feature’s data contract.
  - `lib/oli/instructor_dashboard/oracle_bindings.ex` already maps the objective and scope-resource oracles but does not yet expose a `challenging_objectives` consumer profile.
  - `lib/oli_web/components/delivery/learning_objectives/learning_objectives.ex` already owns the richer instructor learning-objectives table, local row expansion state, and low-proficiency card concepts; it is the correct destination for drill-through, not the renderer for the dashboard tile itself.
  - `lib/oli/dashboard/snapshot/projections.ex` already supports capability-scoped projection derivation with ready/partial/unavailable statuses and telemetry.
- Unknowns to confirm:
  - Whether the tile should cap visible parent rows in the first release or always render the full qualifying list for the current scope.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Recommended modules and responsibilities:

| Module | Responsibility |
| --- | --- |
| `Oli.InstructorDashboard.OracleBindings` | Add a `challenging_objectives` consumer profile that requires `:oracle_instructor_objectives_proficiency` and `:oracle_instructor_scope_resources`. |
| `Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives` | Replace the current `progress_proxy` projection with a tile-specific projection that normalizes low-proficiency objective rows, distinguishes populated/no-data/empty states, and emits a tile view model. |
| `Oli.InstructorDashboard.DataSnapshot.Projections.Helpers` | Continue to provide generic projection helpers only; do not move hierarchy logic into shared helpers unless another tile needs it. |
| `OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab` | Consume projection status/data from the snapshot bundle and assign typed tile payload instead of placeholder text. |
| `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.ChallengingObjectivesTile` | Render the tile card, disclosure UI, empty/no-data states, and deterministic links into Learning Objectives. |
| `OliWeb.Delivery.InstructorDashboard.InstructorDashboardLive` + `OliWeb.Components.Delivery.LearningObjectives` | Accept initial deep-link params from the tile and hydrate the destination table with the intended scope/card/expanded row context. |

Design choice:
- Keep the tile as a small LiveView/HEEx component consuming prepared projection data.
- Do not embed the full `LearningObjectives` component inside the tile.
- Do not add a tile-specific oracle. The tile should consume existing concrete oracles and a corrected projection.

### 4.2 State & Data Flow
Consumer binding:
- Add a new consumer profile in `OracleBindings`:

```elixir
challenging_objectives: %{
  required_oracles: %{
    objectives_proficiency: :oracle_instructor_objectives_proficiency,
    scope_resources: :oracle_instructor_scope_resources
  },
  optional_oracles: %{}
}
```

Projection flow:
1. Intelligent Dashboard scope changes resolve through existing `IntelligentDashboardTab` logic.
2. Snapshot/runtime requests the `challenging_objectives` capability dependencies.
3. `ObjectivesProficiencyOracle` returns low-performing objective rows in scope.
4. `ScopeResourcesOracle` provides course/scope resource metadata for labels and alignment with current dashboard scope.
5. `ChallengingObjectives` projection:
   - inspects required oracle payloads
   - reconstructs parent/sub-objective relationships using `SectionResourceDepot`
   - orders rows by curriculum order
   - determines tile state:
     - `:populated`
     - `:no_data`
     - `:empty_low_proficiency`
   - builds navigation metadata for parent, child, and view-all actions
6. `IntelligentDashboardTab` assigns the typed projection into the shell payload.
7. `ChallengingObjectivesTile` renders the tile without performing any additional data fetch.

Recommended tile projection shape:

```elixir
%{
  capability: :challenging_objectives,
  state: :populated | :no_data | :empty_low_proficiency,
  scope: %{
    selector: "course" | "container:123",
    label: "Entire Course" | "Unit 2" | "Module 3"
  },
  rows: [
    %{
      objective_id: 101,
      title: "Quadratic functions",
      numbering: "2.3",
      proficiency_label: "Low",
      proficiency_pct: 34.0,
      has_children: true,
      children: [
        %{
          objective_id: 205,
          parent_objective_id: 101,
          title: "Solve by factoring",
          numbering: "2.3.1",
          proficiency_label: "Low",
          proficiency_pct: 28.0
        }
      ],
      link: %{type: :objective, params: %{objective_id: 101, filter_by: 55}}
    }
  ],
  view_all_link: %{params: %{filter_by: 55}}
}
```

The tile component owns only local disclosure state for visual expansion inside the tile. That state is ephemeral and reset when scope changes or the tile payload changes.

### 4.3 Lifecycle & Ownership
- Source of truth for objective metrics remains the snapshot/oracle result for the current request token and scope.
- Source of truth for tile render state remains the projection payload assigned by LiveView.
- Source of truth for in-tile expanded rows is component-local assign state only.
- Source of truth for post-click destination state remains URL params on `Insights -> Learning Objectives`, not cross-view in-memory state.
- When scope changes, the tile’s local disclosure state is reset against the new projection payload so stale expanded rows do not carry across scopes.

### 4.4 Alternatives Considered
- Reuse the full `LearningObjectives` component inside the tile.
  - Rejected because the destination view is substantially richer than the tile needs and would pull table/filter/paging complexity into a compact dashboard card.
- Build a new tile-specific objective query path in LiveView.
  - Rejected because it violates the established dashboard oracle/snapshot boundary.
- Add a dedicated hierarchy oracle for parent-child objective trees.
  - Rejected for this slice because `SectionResourceDepot` already has the hierarchy information and the ticket guidance explicitly permits depot-based reconstruction.
- Keep the existing `progress_proxy` projection temporarily and implement only placeholder UI polish.
  - Rejected because it would preserve the wrong dependency contract and force later rework in both projection and UI layers.

## 5. Interfaces
- LiveView/snapshot interface:
  - `IntelligentDashboardTab` should stop passing `objectives_status` debug text as the tile’s primary data contract and instead pass the `:challenging_objectives` projection payload plus projection status.
- Consumer/oracle interface:
  - `Oli.InstructorDashboard.OracleBindings.binding_for(:challenging_objectives)` returns the dependency profile above.
- Tile component interface:
  - `ChallengingObjectivesTile.tile(assigns)` should accept:
    - `projection`
    - `projection_status`
    - `section_slug`
    - `target` only if server-pushed events are needed; otherwise links remain plain navigational anchors
- Navigation contract to `Insights -> Learning Objectives`:
  - Recommended URL params:
    - `filter_by`
    - `selected_card_value`
    - `objective_id` (optional)
    - `subobjective_id` (optional)
  - Parent objective link:
    - `selected_card_value=low_proficiency_outcomes`
    - `objective_id=<parent_id>`
    - optional `filter_by=<scope_container_id>`
  - Sub-objective link:
    - `selected_card_value=low_proficiency_skills`
    - `objective_id=<parent_id>`
    - `subobjective_id=<child_id>`
    - optional `filter_by=<scope_container_id>`
  - View-all link:
    - omit `objective_id` and `subobjective_id`
    - preserve `filter_by` when the dashboard scope is a concrete container
- Destination initialization contract:
  - `InstructorDashboardLive` / `LearningObjectives` should read those params during update/param handling and seed `expanded_objectives` deterministically before first render.

## 6. Data Model & Storage
- No new Ecto schema or migration is required.
- Existing read-only inputs:
  - `ObjectivesProficiencyOracle` payload
  - `ScopeResourcesOracle` payload
  - `SectionResourceDepot` section-resource hierarchy
  - existing dashboard scope selector and navigator state
- No persistence is needed for tile disclosure state or drill-through state beyond URL params.

## 7. Consistency & Transactions
- This feature is read-only for dashboard data and does not require transaction boundaries.
- Consistency guarantee comes from snapshot-scoped projection derivation: all tile rows for a render are derived from a single snapshot bundle for a single request token/scope.
- Deep-link state should be derived only from URL params at destination render time; the tile must not rely on hidden server session state between dashboard and learning-objectives views.

## 8. Caching Strategy
- Reuse existing dashboard snapshot/oracle caching only.
- No tile-specific cache key or browser-local persistence is required.
- Projection derivation must remain deterministic so cached oracle payloads produce stable tile rows for identical scope inputs.
- Because the tile can reconstruct hierarchy from `SectionResourceDepot`, only oracle payloads need cache participation; depot access remains in-memory per existing section runtime behavior.

## 9. Performance & Scalability Posture
- This tile should remain lightweight relative to the full learning-objectives view:
  - it renders only low-proficiency rows for the active scope
  - it avoids table/pagination/filter orchestration in-card
  - it does not trigger additional server round trips after projection assignment
- Potential hotspots:
  - repeated depot hierarchy traversal for large objective sets
  - unnecessary reshaping on every LiveView diff
- Mitigations:
  - perform hierarchy shaping once in the projection layer, not in the HEEx template
  - keep rendered payload bounded to qualifying rows rather than the full objective catalog
  - reset disclosure state only when projection identity changes, not on unrelated LiveView updates

## 10. Failure Modes & Resilience
- Missing required objective oracle payload:
  - projection becomes `:unavailable` and tile shows a non-breaking unavailable state rather than stale or misleading data.
- Scope-resource metadata unavailable:
  - tile falls back to a safe generic scope label (`Entire Course` or current selector) and logs projection failure if the missing data prevents a valid payload.
- Objective hierarchy mismatch between oracle payload and depot:
  - tile renders whichever qualifying rows can be resolved and logs a warning for missing parent/child mappings.
- Rapid scope changes:
  - existing coordinator/token guards suppress stale UI application; tile-local disclosure state is reset on new payload.
- Deep-link parameter mismatch:
  - destination page falls back to its normal default view rather than crashing or leaving the user in an undefined state.

## 11. Observability
- Rely on existing projection telemetry in `Oli.Dashboard.Snapshot.Projections` for:
  - capability key `:challenging_objectives`
  - ready/partial/unavailable/failed status
  - derivation duration
- Add destination-arrival telemetry for tile-driven drill-through:
  - `[:oli, :instructor_dashboard, :challenging_objectives, :navigation]`
  - metadata distinguishes `objective`, `subobjective`, and `view_all`
- Log warnings for:
  - missing depot rows for oracle-returned objective ids
  - invalid deep-link params that cannot be resolved at destination

## 12. Security & Privacy
- The tile remains instructor/admin only through the existing instructor dashboard authorization path.
- All objective data is scoped to the current section and selected dashboard scope.
- No new PII exposure is introduced; tile content is objective metadata plus aggregated proficiency state only.
- Drill-through links remain internal section-scoped routes and should not expose data outside the authorized section context.

## 13. Testing Strategy
- ExUnit unit tests:
  - `Oli.InstructorDashboard.DataSnapshot.Projections.ChallengingObjectives`
    - requires the correct oracle keys
    - distinguishes populated / no-data / empty-low-proficiency states
    - reconstructs hierarchy in curriculum order
    - handles unresolved parent/child rows defensively
  - `Oli.InstructorDashboard.OracleBindings`
    - validates the new `challenging_objectives` consumer profile
- LiveView/component tests:
  - `challenging_objectives_tile.ex`
    - populated rendering
    - disclosure control presence/absence
    - keyboard-operable expand/collapse behavior
    - correct links for objective, sub-objective, and view-all actions
  - `InstructorDashboardLive` / `LearningObjectives`
    - destination deep-link params seed the intended initial expansion/filter/card state
    - invalid params degrade safely to default behavior
- Integration/regression tests:
  - targeted Intelligent Dashboard LiveView test for rapid scope changes proving only latest-scope rows render (`AC-011`)
  - targeted flow proving no-objective, no-data, and no-low-proficiency states remain distinct (`AC-008`, `AC-009`, `AC-010`)
- Manual validation:
  - verify desktop and keyboard-only behavior against Figma/Jira intent
  - verify drill-through arrives on the expected Learning Objectives context for both parent and child links

## 14. Backwards Compatibility
- No database or external API compatibility concerns.
- Existing dashboard placeholder behavior will be replaced, but route structure remains within the current instructor dashboard URLs.
- Learning Objectives destination changes must remain additive: if new deep-link params are absent, the page should keep its current behavior unchanged.

## 15. Risks & Mitigations
- Risk: the existing projection module remains partially wired to placeholder progress data.
  - Mitigation: explicitly replace its required-oracle set and payload shape in the same slice as tile implementation.
- Risk: hierarchy reconstruction produces duplicated or misleading parent rows.
  - Mitigation: derive parent/child view models from depot resource identity once, add ordering/dedup tests, and log unresolved mappings.
- Risk: deep-link UX diverges from tile selection semantics.
  - Mitigation: use an explicit URL contract and verify it in LiveView tests, not manual assumptions.
- Risk: a large scope yields too many low-proficiency rows for a compact tile.
  - Mitigation: confirm product expectation on row-cap behavior before implementation; keep this as an explicit follow-up if unresolved.

## 16. Open Questions & Follow-ups
- Product decision needed: should the tile show the full qualifying list or cap visible parent rows with overflow deferred to `View Learning Objectives`?
- Follow-up implementation note: once the tile consumes typed projection data, remove the prototype-only `objectives_text` placeholder handling from `IntelligentDashboardTab` and `Shell`.

## 17. References
- `docs/exec-plans/current/epics/intelligent_dashboard/objectives_tile/prd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/objectives_tile/requirements.yml`
- `docs/exec-plans/current/epics/intelligent_dashboard/concrete_oracles/fdd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_oracles/fdd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/data_snapshot/fdd.md`
- `docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`
- `lib/oli/instructor_dashboard/oracle_bindings.ex`
- `lib/oli/instructor_dashboard/data_snapshot/projections/challenging_objectives.ex`
- `lib/oli/instructor_dashboard/oracles/objectives_proficiency.ex`
- `lib/oli/instructor_dashboard/oracles/scope_resources.ex`
- `lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/challenging_objectives_tile.ex`
- `lib/oli_web/components/delivery/learning_objectives/learning_objectives.ex`
