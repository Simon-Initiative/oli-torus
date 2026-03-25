# Assessments Tile - Functional Design Document

## 1. Executive Summary
This feature delivers the `Assessments` tile for the Instructor Intelligent Dashboard by following the same layering pattern already established for `Student Support`: a non-UI snapshot projection for tile-ready data, a LiveView-owned tile surface for interaction state and navigation, and dashboard-tab orchestration for scope-aware URL/state coordination. Unlike `Student Support`, this tile does not need a browser-managed chart runtime for the initial implementation because Darren Siegel's Jira guidance says the grades payload should already arrive aggregated and the requested chart is a simple fixed-bin distribution with visible counts. The simplest adequate design is therefore: consume the concrete `GradesOracle` plus `ScopeResourcesOracle`, enrich only the assessment title/context metadata outside the UI, render the expandable rows in a `live_component`, and keep expansion/action state in LiveView without introducing React or Vega-Lite.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001`: render the Assessments tile for the selected scope when at least one graded page exists.
  - `FR-003`: pair aggregate assessment rows with human-readable titles and course-context labels from scope/resource metadata.
  - `FR-004`: show completion counts, score summary metrics, and histogram distribution per expanded assessment.
  - `FR-005`: consume oracle-provided distribution bins directly, without recomputing grade statistics in the UI.
  - `FR-006`: update tile contents correctly when the dashboard scope changes.
  - `FR-007`: hide or empty-state the tile consistently when no graded assessments exist in scope.
  - `FR-008`: keep enrichment and normalization outside HEEx so the tile renders prepared view data only.
- Non-functional requirements:
  - The tile must stay within the existing LiveView dashboard surface and preserve the dashboard's shared section/tile ownership model.
  - Expansion/collapse interactions must remain stable under rapid toggling.
  - Accessibility must satisfy WCAG 2.1 AA for disclosure controls, metric labeling, chart/list readability, and action affordances.
  - Observability is limited to targeted telemetry/logging around projection failures, tile rendering, and action/navigation failures.
- Assumptions:
  - Darren Siegel's comment on `MER-5254` is authoritative: the grades oracle payload is already aggregated and display-ready for schedule fields and score statistics, with no separate stats projection step required.
  - `Oli.InstructorDashboard.Oracles.Grades` and `Oli.InstructorDashboard.Oracles.ScopeResources` are the upstream contracts this tile should consume.
  - Assessment titles and course-context labels can be resolved from scope-resource metadata or `SectionResourceDepot`-aligned resource identifiers already exposed through the scope-resource contract.
  - Before final UI implementation, the local `implement_ui` skill will be run against the Jira/Figma source so token/icon/component mapping and unspecified visual states are made explicit.
  - The dashboard tile conventions captured in `dashboard_ui_composition.md` are normative for tile layering, state ownership, and section composition.

## 3. Repository Context Summary
- What we know:
  - The dashboard shell is already LiveView/HEEx-based and composes section groups from [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/shell.ex).
  - The `ContentSection` group already owns `ChallengingObjectivesTile` and `AssessmentsTile` placement in [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/content_section.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tile_groups/content_section.ex).
  - The current Assessments tile is only a placeholder function component in [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex).
  - `StudentSupportTile` is the best local reference for architecture and file organization: projection in [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex), projector in [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support/projector.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support/projector.ex), tile `live_component` in [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex), hook in [`assets/src/hooks/student_support_chart.ts`](../../../../../../assets/src/hooks/student_support_chart.ts), and tests split by layer.
  - The open PR branch `MER-5252-student-support-tile-P3` also establishes the most relevant email-flow reference: `EmailButton` remains a thin trigger, while the dashboard tile owns a richer draft-email modal specialized for tile-managed recipients rather than the older generic students-table modal.
  - `IntelligentDashboardTab` already parses and normalizes namespaced tile URL params for `Student Support` and is the correct owner for future tile-specific params and scope-aware rehydration behavior in [`lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`](../../../../../../lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex).
  - `OracleBindings` already exposes the concrete oracles this tile should consume: `:oracle_instructor_grades` and `:oracle_instructor_scope_resources` in [`lib/oli/instructor_dashboard/oracle_bindings.ex`](../../../../../../lib/oli/instructor_dashboard/oracle_bindings.ex).
  - The current `Assessments` snapshot projection still points at a legacy section-analytics placeholder in [`lib/oli/instructor_dashboard/data_snapshot/projections/assessments.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/assessments.ex) and will need to be realigned to the concrete oracle contracts for this feature.
- Unknowns to confirm:
  - Whether the initial implementation should allow multiple rows open simultaneously or enforce single-row expansion. The design language suggests per-row disclosure, but the ticket does not require multi-open behavior.
  - The exact route helper and parameter contract for `Review questions`, since the PRD references the scored-page question view but the final navigation target should be confirmed during implementation.
  - Whether `assessment_tile` should consume a newly extracted dashboard-generic draft-email modal immediately, or first reuse the `MER-5252` student-support modal pattern and extract only once both tile implementations are stable.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- `Oli.InstructorDashboard.DataSnapshot.Projections.Assessments`
  - Becomes the non-UI feature projection entrypoint for this tile.
  - Stops consuming legacy section-analytics placeholder data.
  - Requires `:oracle_instructor_grades` and `:oracle_instructor_scope_resources`.
- `Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector`
  - New projector-focused module responsible for:
    - sorting assessments by due date, then available date, then stable scope order
    - pairing oracle grade rows with resource titles/context labels
    - shaping completion chip status metadata
    - normalizing histogram bins into a deterministic render order
    - preparing empty-state flags and action identifiers
  - Must not recompute score statistics or histogram counts from lower-level raw data.
- `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.Tiles.AssessmentsTile`
  - Should be converted from a stateless placeholder to a `live_component`.
  - Owns only tile-local interaction/render concerns:
    - which assessment row is expanded
    - action dispatch for review/email/view-scores
    - disclosure accessibility state
  - Receives prepared projection data plus optional tile state.
- Draft email modal component
  - Reuse the `MER-5252` tile-owned modal pattern rather than falling back to the older students-table `EmailModal`.
  - Preferred direction: keep `EmailButton` as a thin trigger and feed a tile-owned draft-email modal with resolved recipient rows, subject/body defaults, and tile-local close/send handling.
  - If `assessment_tile` becomes the second near-identical consumer, extract the modal to a dashboard-generic home with neutral naming such as `DraftEmailModal` rather than creating a second tile-specific clone.
- `OliWeb.Components.Delivery.InstructorDashboard.IntelligentDashboard.TileGroups.ContentSection`
  - Should mirror the `EngagementSection` pattern by passing projection data and tile state into the live component rather than only a placeholder status string.
- `OliWeb.Delivery.InstructorDashboard.IntelligentDashboardTab`
  - Owns namespaced assessment-tile param parsing and path generation if URL-backed expansion state is adopted.
  - Owns routing/action handoff for dashboard-wide navigation and must avoid scope-wide re-fetch on tile-local expansion changes.
- Existing email/navigation integrations
  - `OliWeb.Components.Delivery.Students.EmailButton` should remain reusable as the trigger surface.
  - `GradesOracle.students_without_attempt_emails/2` is the expected backend entrypoint for no-attempt email recipients.
  - Existing section/instructor dashboard routing remains the owner of navigation to assessment scores and scored-question review pages.

Design decision:
- Follow the `Student Support` repository split, but do not create a JS chart hook in Phase 1.
- Rationale:
  - the chart is a fixed bar distribution, not a highly interactive visualization
  - counts are already aggregated in oracle output
  - avoiding a hook keeps the first implementation simpler and easier to test in LiveView
  - if `implement_ui` later reveals a visual requirement that cannot be met cleanly in HEEx/CSS, a thin hook can still be introduced without changing projection boundaries

### 4.2 State & Data Flow
Projection input contract:
- `grades_payload`: `%{grades: [%{page_id, minimum, median, mean, maximum, standard_deviation, histogram, available_at, due_at, completed_count, total_students, review_resource_id?}]}`
- `scope_resources_payload`: `%{course_title, items: [%{resource_id, resource_type_id, title, numbering_level?, numbering_index?, parent_title?}]}`
- optional feature opts:
  - `completion_threshold_pct: 50`

Projection output contract:

```elixir
%{
  rows: [
    %{
      assessment_id: 123,
      title: "Quiz 1",
      context_label: "Unit 2 · Module 1",
      available_at: ~U[2026-03-01 12:00:00Z],
      due_at: ~U[2026-03-05 12:00:00Z],
      completion: %{
        completed_count: 18,
        total_students: 30,
        ratio: 0.6,
        label: "18 of 30 students completed",
        status: :good
      },
      metrics: %{
        minimum: 42.0,
        median: 76.0,
        mean: 74.5,
        maximum: 98.0,
        standard_deviation: 11.2,
        mean_status: :below_threshold
      },
      histogram_bins: [
        %{range: "0-10", count: 0},
        %{range: "10-20", count: 1}
      ],
      actions: %{
        email_assessment_id: 123,
        review_assessment_id: 123,
        scores_path_hint: :assessment_scores
      }
    }
  ],
  total_rows: 8,
  has_assessments?: true
}
```

Tile-local interaction state:

```elixir
%{
  expanded_assessment_id: 123 | nil
}
```

Recommended URL-owned tile params:

```elixir
%{
  "tile_assessments" => %{
    "expanded" => "123"
  }
}
```

Derived render flow:
1. Dashboard runtime hydrates the snapshot with `GradesOracle` and `ScopeResourcesOracle`.
2. The assessments projection resolves titles/context labels, sorts rows, and emits tile-ready disclosure rows.
3. `IntelligentDashboardTab` parses optional `tile_assessments[...]` params and assigns `assessments_tile_state`.
4. `ContentSection` passes `assessments_projection` and `assessments_tile_state` into `AssessmentsTile`.
5. `AssessmentsTile` renders:
   - collapsed row list
   - a single expanded row at a time by default
   - completion chip, summary metrics, distribution bars, and action buttons
6. Clicking a disclosure control issues a tile-local patch or event update that changes only `expanded_assessment_id`.
7. Clicking `Email students not completed` triggers recipient lookup through the grades oracle helper and opens the tile-owned draft-email modal flow using the same trigger/modal split proven in `MER-5252-student-support-tile-P3`.
8. Clicking `Review questions` or `View Assessment Scores` routes through existing instructor dashboard destinations without changing projection ownership.

Recommended event contract:
- `"assessments_row_toggled"` with `%{"assessment_id" => id}`
- `"assessments_email_requested"` with `%{"assessment_id" => id}`
- `"assessments_review_requested"` with `%{"assessment_id" => id}`
- `"assessments_scores_requested"` with `%{"assessment_id" => id}`

### 4.3 Lifecycle & Ownership
- Upstream oracle loading and caching remain owned by the dashboard runtime and snapshot layers.
- Assessment ordering, title/context enrichment, chip-status derivation, and histogram normalization are owned by the assessments projection/projector layer.
- The tile `live_component` owns only disclosure state and action wiring.
- Dashboard-level URL parsing/patching owns any persisted tile-local expansion state.
- No database persistence is introduced for tile-local expansion state.
- No React island or browser-only state is required for the initial bar chart implementation.
- Future follow-on work can add richer chart rendering or multi-expand behavior without changing the projection boundary.

### 4.4 Alternatives Considered
- Keep `AssessmentsTile` as a stateless function component.
  - Rejected because expansion state and action orchestration will quickly become awkward and inconsistent with the `Student Support` pattern already in the repo.
- Introduce a Vega-Lite or React chart runtime immediately.
  - Rejected because the requirements only call for a fixed histogram with visible counts; a JS chart runtime adds complexity without clear benefit in v1.
- Read `SectionResourceDepot` directly from the HEEx component.
  - Rejected because title/context enrichment belongs in non-UI preparation or oracle-aligned boundaries, not in rendering code.
- Recompute histogram or summary stats in the tile from lower-level rows.
  - Rejected because Darren's guidance and the concrete-oracles contract explicitly say grades data should already arrive aggregated.

## 5. Interfaces
- Snapshot/projection interface:
  - `Assessments.derive(snapshot, opts) -> {:ok, projection} | {:partial, projection, reason} | {:error, reason}`
- Internal projector interface:
  - `Projector.build(grades_rows, scope_resource_items, opts) -> projection_map`
- LiveView assign interface:
  - `:assessments_projection`
  - `:assessments_tile_state`
- URL param interface:
  - `tile_assessments[expanded]`
- Oracle/helper interfaces:
  - `GradesOracle` tile data payload for aggregate assessment rows
  - `GradesOracle.students_without_attempt_emails(section_id, assessment_id) -> {:ok, [email]} | {:error, reason}`
  - `ScopeResourcesOracle` payload for title/context lookup
  - `EmailButton` trigger component with `email_handler_id`-based modal open/close messaging
  - Draft-email modal interface accepting resolved recipient rows plus contextual default subject/body values

## 6. Data Model & Storage
- No schema changes or migrations are required.
- No tile-specific persistence is required.
- The only data-shape changes are in in-memory snapshot/projection structures and LiveView assigns.
- Existing oracle payloads remain the source of truth; the assessments projector only reshapes them for render readiness.

## 7. Consistency & Transactions
- There is no multi-step transactional write path in the main tile render flow.
- Email-recipient lookup must be based on a single oracle/helper read for the chosen assessment so the UI cannot drift between disclosure state and recipient resolution.
- Navigation actions should use assessment identifiers already present in the projection to avoid mismatches between rendered rows and downstream targets.

## 8. Caching Strategy
- The tile should participate in the existing dashboard cache/snapshot lifecycle through `IntelligentDashboardTab` and the oracle runtime.
- No tile-local cache is needed.
- Tile-local expansion changes must reuse the current snapshot/projection and avoid re-fetching grades data.

## 9. Performance & Scalability Posture
- The tile intentionally depends on aggregate grades payloads rather than per-student raw grade rows, which keeps the render model bounded even for larger sections.
- Histogram rendering should use a fixed 10-bin loop and simple HEEx/CSS primitives.
- Sorting and title enrichment are O(n log n) over the number of graded pages in scope, which is acceptable for the expected dashboard surface.
- Large-scope rendering risk should be mitigated by deterministic ordering and, if needed later, a rendered-row cap or paged disclosure list. The FDD does not require that cap up front.

## 10. Failure Modes & Resilience
- Missing title metadata for an assessment:
  - render a fallback label and log projection warning data; do not crash the tile.
- Missing or malformed histogram bins:
  - render metrics without the chart and expose a clear empty/partial chart state.
- No graded assessments in scope:
  - hide the tile or render the agreed empty state consistently with dashboard composition rules.
- Email-recipient lookup failure:
  - keep the instructor on the dashboard and surface an actionable error rather than navigating away.
- Divergence between student-support and assessment email UX:
  - reuse the same draft-email modal pattern and shared component where possible instead of letting two tile-local implementations drift.
- Review-navigation failure:
  - surface an error flash/state instead of leaving the user in an undefined state.

## 11. Observability
- Add targeted logging/telemetry for:
  - assessment projection failures
  - missing title/context metadata
  - email-recipient lookup failures
  - review-question navigation failures
- Keep telemetry minimal and aligned with the PRD:
  - `assessment_tile.rendered`
  - `assessment_tile.scope_changed`
- If tile-local URL state is introduced, log/debug only when invalid `tile_assessments` params are dropped.

## 12. Security & Privacy
- The tile remains instructor-only and section-scoped under existing instructor dashboard auth.
- The displayed tile data is aggregate and should avoid exposing unnecessary student-level PII.
- The only student-specific operation in scope is the email-recipient lookup for learners who have not completed the selected assessment; that helper must continue filtering to enrolled learners only.
- No new roles, permissions, or cross-institution access paths are introduced.

## 13. Testing Strategy
- Projection tests:
  - add `test/oli/instructor_dashboard/data_snapshot/projections/assessments_projector_test.exs` covering:
    - sorting by due date / available date fallback
    - title/context enrichment
    - completion chip status mapping
    - histogram-bin normalization
    - empty-state behavior
- Component tests:
  - add `test/oli_web/components/delivery/instructor_dashboard/assessments_tile_test.exs` covering:
    - collapsed rendering
    - disclosure toggling
    - metrics/chart rendering from prepared rows
    - empty/partial states
    - button enablement and stable behavior under rapid toggling
    - email modal open/close behavior using the shared trigger/modal contract
- LiveView/dashboard-tab tests:
  - add or extend tests around `IntelligentDashboardTab` if `tile_assessments[...]` params are adopted, proving tile-local patching does not trigger scope-wide re-fetch.
- Manual verification:
  - compare rendered rows against the Jira/Figma design source for default and status-chip states
  - verify keyboard disclosure behavior and action focus order
  - verify email/review/scores actions from representative assessments

## 14. Backwards Compatibility
- This feature replaces only the current placeholder behavior for the assessments tile.
- No external API, schema, or route compatibility break is expected.
- Legacy section-analytics placeholder dependencies in the assessments projection should be removed cleanly rather than left as dual-path behavior.

## 15. Risks & Mitigations
- Oracle contract drift from concrete-oracles expectations: bind the projection directly to `GradesOracle` and `ScopeResourcesOracle` and cover payload-shape assumptions with projector tests.
- UI boundary drift into HEEx helpers: keep ordering, label enrichment, and chip-status derivation in a dedicated projector module.
- Hidden complexity in email/review actions: isolate those actions behind explicit events/helper interfaces so the tile component stays focused on rendering and disclosure state.
- Modal duplication between dashboard tiles: prefer reuse of the `MER-5252` draft-email modal pattern and extract to a neutral dashboard component if both tiles need the same recipient/subject/body workflow.
- Figma ambiguity around unspecified states: require `implement_ui` before final polish and treat missing states as explicit follow-ups instead of guessing in code.

## 16. Open Questions & Follow-ups
- Confirm whether the final UX wants single-row expansion or multi-row expansion.
- Confirm the exact scored-question review path and parameter shape for `Review questions`.
- Decide whether to rename/extract the `MER-5252` draft-email modal to a dashboard-generic component during this story or in an immediate follow-up once both tile consumers are in place.
- Follow-up: update `IntelligentDashboardTab` dashboard payload assembly so it assigns `assessments_projection` alongside the current placeholder `assessments_text`.

## 17. References
- [`docs/exec-plans/current/epics/intelligent_dashboard/assessment_tile/prd.md`](./prd.md)
- [`docs/exec-plans/current/epics/intelligent_dashboard/assessment_tile/requirements.yml`](./requirements.yml)
- [`docs/exec-plans/current/epics/intelligent_dashboard/support_tile/fdd.md`](../support_tile/fdd.md)
- [`docs/exec-plans/current/epics/intelligent_dashboard/dashboard_ui_composition.md`](../dashboard_ui_composition.md)
- [`lib/oli/instructor_dashboard/data_snapshot/projections/assessments.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/assessments.ex)
- [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/assessments_tile.ex)
- [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support.ex)
- [`lib/oli/instructor_dashboard/data_snapshot/projections/student_support/projector.ex`](../../../../../../lib/oli/instructor_dashboard/data_snapshot/projections/student_support/projector.ex)
- [`lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex`](../../../../../../lib/oli_web/components/delivery/instructor_dashboard/intelligent_dashboard/tiles/student_support_tile.ex)
- [`lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex`](../../../../../../lib/oli_web/live/delivery/instructor_dashboard/intelligent_dashboard_tab.ex)
