# Assessments Tile - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/intelligent_dashboard/assessment_tile/prd.md`
- FDD: `docs/exec-plans/current/epics/intelligent_dashboard/assessment_tile/fdd.md`

## Scope
Deliver `MER-5254` in reviewable increments that validate the tile architecture early, keep assessment shaping logic in non-UI projection layers, and defer final visual polish until the data/state contract is proven. The plan intentionally separates:

- concrete oracle consumption and assessment projection wiring
- LiveView tile state plus optional URL-backed disclosure state
- Figma-driven UI refinement for the expanded assessment surface
- email/review/scores actions and final integration hardening

This plan assumes adjacent intelligent-dashboard work may continue in parallel, so it follows the shared ownership and URL-param conventions already established by `student_support` and `dashboard_ui_composition.md`.

## Clarifications & Default Assumptions
- `PR 1` is an architecture-validation slice, not the final polished UI. Minimal but stable rendering is acceptable if it proves the grades/scope-resource data path and disclosure behavior.
- Darren Siegel's Jira comment is treated as authoritative: grades data should arrive already aggregated and display-ready, so this feature should not introduce a second stats-computation layer.
- The initial chart implementation should be server-rendered HEEx/CSS, not a JS chart runtime. A browser hook is a fallback only if `implement_ui` reveals a fidelity gap that cannot be closed cleanly without one.
- Tile-local URL params for this feature should use the namespaced shape `tile_assessments[expanded]` if persisted disclosure state is needed.
- Tile-local URL patches must reuse the current snapshot/projection and must not trigger scope-wide oracle reload.
- The email flow should reuse the `MER-5252-student-support-tile-P3` trigger/modal pattern rather than falling back to the older students-table modal.
- If `assessment_tile` becomes the second near-identical consumer of that draft-email modal, extraction to a dashboard-generic component is preferred over maintaining a second tile-specific clone.

## Phase 1: PR 1 - Projection, Dashboard Wiring, and Minimal Expandable Tile
- Goal: Prove the feature architecture end-to-end by replacing the legacy assessments projection, wiring the correct concrete-oracle inputs into the dashboard, and rendering a stable expandable tile without scope-wide refetch side effects.
- Tasks:
  - [ ] Replace the current legacy `Assessments` snapshot projection so it consumes `:oracle_instructor_grades` and `:oracle_instructor_scope_resources` instead of the placeholder section-analytics binding.
  - [ ] Introduce `Oli.InstructorDashboard.DataSnapshot.Projections.Assessments.Projector` to handle title/context enrichment, due-date ordering, completion-chip status derivation, histogram-bin normalization, and empty-state shaping.
  - [ ] Update dashboard payload assembly so `IntelligentDashboardTab`, the shell, and `ContentSection` pass `assessments_projection` and optional `assessments_tile_state` instead of only placeholder text/status.
  - [ ] Convert `AssessmentsTile` from a stateless placeholder into a `live_component` with minimal disclosure state and stable collapsed/expanded rendering.
  - [ ] Implement namespaced URL param parsing/application for `tile_assessments[...]` if disclosure state is made URL-backed in this story.
  - [ ] Add explicit guards so tile-local disclosure updates reuse the current snapshot/projection and do not invalidate scope-wide hydration.
  - [ ] Add targeted logging/telemetry for projection failures, missing title metadata, and unexpected tile-local state errors.
- Testing Tasks:
  - [ ] Add projector tests for sorting, title/context enrichment, completion-chip status mapping, histogram normalization, and no-assessment behavior.
  - [ ] Add component tests for collapsed rendering, disclosure toggling, populated state, and partial/empty states.
  - [ ] Add dashboard/LiveView coverage proving `tile_assessments[...]` patching, if adopted, rehydrates tile state without scope-wide reload.
  - Command(s): `mix test test/oli/instructor_dashboard test/oli_web/components/delivery/instructor_dashboard test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - Assessments tile data arrives through the intended snapshot/projection path.
  - The tile renders real assessment rows with stable disclosure behavior.
  - Tile-local state changes do not trigger scope-wide oracle reload.
  - The legacy section-analytics placeholder path is no longer the effective data source for this tile.
- Gate:
  - Architecture gate: confirm the grades + scope-resources contract is sufficient to drive the tile without adding a second aggregation layer or a JS chart runtime.
- Dependencies:
  - Depends on the concrete-oracles contracts for grades and scope resources being stable enough to provide schedule/title-friendly identifiers.
- Parallelizable Work:
  - Projector test authoring can run in parallel with tile `live_component` shell conversion.
  - Dashboard-tab URL param work can proceed in parallel with tile markup as long as the event contract is fixed early.

## Phase 2: PR 2 - UI Refinement, `implement_ui`, and Accessibility Hardening
- Goal: Refine the tile to match the intended UX more closely once the architecture is stable, using `implement_ui` to pin token/icon/component decisions and close design ambiguity before final polish.
- Tasks:
  - [ ] Run `implement_ui` against the Jira/Figma assessment tile source and capture token/icon/component/file-target decisions for the collapsed and expanded states.
  - [ ] Refine tile spacing, typography, status-chip styling, metrics layout, and histogram presentation to match the approved design direction.
  - [ ] Resolve ambiguous or missing design states identified in the PRD/FDD: empty, loading, error, hover/focus, and responsive behavior.
  - [ ] Add keyboard/focus/screen-reader affordances for row disclosure, action buttons, and histogram readability.
  - [ ] If `implement_ui` shows that HEEx/CSS cannot meet the chart fidelity requirement cleanly, introduce only the thinnest necessary browser hook while preserving the same projection/tile state boundaries.
- Testing Tasks:
  - [ ] Expand component/LiveView tests for disclosure accessibility semantics, focus behavior, and visual-state-driven class changes.
  - [ ] Add targeted tests for any hook/chart fallback only if a browser runtime is actually introduced.
  - [ ] Perform manual QA against the Jira-linked Figma node and attachment examples for good/bad completion status and expanded-state content.
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard test/oli_web/live/delivery/instructor_dashboard`
- Definition of Done:
  - `implement_ui` guidance has been incorporated into the tile implementation.
  - The collapsed and expanded tile states are intentionally designed and materially aligned with the design source.
  - Accessibility and responsive behavior are validated for supported states.
  - The chart-rendering choice is settled without reopening projection ownership or dashboard state boundaries.
- Gate:
  - UX gate: product/design can confirm the tile is visually and behaviorally viable without reopening the Phase 1 architecture.
- Dependencies:
  - Depends on Phase 1 completing and proving the assessment projection/data path.
- Parallelizable Work:
  - `implement_ui` brief generation can run in parallel with accessibility refinements once the tile structure is stable.
  - Responsive polish and empty/error-state handling can proceed in parallel with non-chart visual cleanup.

## Phase 3: PR 3 - Email, Review Navigation, and Final Integration Hardening
- Goal: Complete the action side of the tile by wiring email/review/scores behavior on top of the validated architecture and polished UI.
- Tasks:
  - [ ] Wire `Email students not completed` to the grades-oracle helper and tile-owned draft-email modal flow.
  - [ ] Reuse the `MER-5252` trigger/modal split for draft email and decide whether to extract the modal to a dashboard-generic component during this phase or immediately after both consumers are stable.
  - [ ] Implement `Review questions` navigation using the confirmed scored-question route contract.
  - [ ] Implement `View Assessment Scores` navigation to the intended assessment-scores destination.
  - [ ] Add final hardening around modal open/close behavior, recipient lookup errors, navigation failures, and edge cases such as empty recipient lists.
- Testing Tasks:
  - [ ] Add component/LiveView tests proving the email action opens the modal with the correct recipients/context and closes cleanly.
  - [ ] Add tests proving review/scores actions navigate or fail gracefully with a user-visible error state.
  - [ ] Perform manual QA for email, review, and scores actions from representative assessments with and without recipient availability.
  - Command(s): `mix test test/oli_web/components/delivery/instructor_dashboard test/oli_web/live/delivery/instructor_dashboard test/oli/instructor_dashboard/oracles`
- Definition of Done:
  - Instructors can open the draft-email flow for students who have not completed an assessment.
  - Review and scores actions route to the correct downstream destinations or fail gracefully.
  - The tile is functionally complete for `MER-5254` without duplicating the older legacy email-modal pattern.
- Gate:
  - Feature-complete gate: instructors can inspect assessment data, open the email draft flow, and drill into downstream assessment views from the tile.
- Dependencies:
  - Depends on Phase 2 for stable UI structure and confirmed modal/component direction.
- Parallelizable Work:
  - Email modal extraction/generalization, if chosen, can proceed in parallel with review/scores navigation wiring once the recipient contract is fixed.
  - Oracle-helper tests can run in parallel with LiveView action wiring.

## Parallelization Notes
- The highest-risk work is front-loaded into Phase 1 so the team can confirm early that the concrete-oracle payload is sufficient and that no extra aggregation or chart runtime is needed.
- Adjacent dashboard-tile work can continue in parallel as long as shared changes to dashboard payload assembly, param parsing, and common email-flow primitives are coordinated carefully.
- Keep PR scope disciplined:
  - PR 1 proves data flow, projection ownership, and disclosure behavior
  - PR 2 proves final UI direction and accessibility
  - PR 3 proves action/handoff completeness
- Avoid bundling final visual polish or modal extraction decisions into PR 1; doing so would obscure whether architecture or UX detail is causing problems.

## Phase Gate Summary
- Gate A: Phase 1 proves that grades/scope-resource projection wiring and tile-local disclosure behavior work without scope-wide refetch or extra stats aggregation.
- Gate B: Phase 2 proves the tile can satisfy the intended UX, accessibility, and responsive expectations without destabilizing the architecture.
- Gate C: Phase 3 proves that email and navigation actions work correctly and complete the feature scope.
