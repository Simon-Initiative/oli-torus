# Progress Tile — PRD

## 1. Overview
Feature Name: Progress Tile

Summary: Deliver a scope-aware progress visualization tile that helps instructors see completion trends across course hierarchy levels. The tile supports completion-threshold adjustment, schedule-aware overlays, pagination, and count/percentage view toggles with accessible interactions.

Links: `docs/epics/intelligent_dashboard/progress_tile/informal.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5251`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors lack a compact, hierarchy-aware chart of completion progress scoped to current filter.
  - Completion interpretation varies by page rules; threshold-based completion needs explicit instructor control.
  - Schedule-awareness and large-axis handling (pagination/truncation) require dedicated UI logic.
- Affected users/roles:
  - Instructors using Learning Dashboard for intervention planning.
- Why now:
  - Progress visibility is a foundational engagement signal in the dashboard and feeds related workflows.

## 3. Goals & Non-Goals
- Goals:
  - Render Progress tile for selected scope with chart-driven completion insights.
  - Support threshold, count/percentage toggle, and scope-level reprojection.
  - Render schedule indicators only when schedule exists.
  - Keep non-UI projection logic isolated for testability.
- Non-Goals:
  - Building full Insights > Content destination page.
  - Changing global filter semantics.
  - Implementing cross-tile shared charting abstractions beyond this tile’s needs.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section context.
- Use Cases:
  - Instructor checks completion by unit/module/page for the selected scope.
  - Instructor raises completion threshold to tighten “complete” definition and sees immediate reprojection.
  - Instructor toggles between count and percentage without page refresh.

## 5. UX / UI Requirements
- Key Screens/States:
  - Tile body with class size, threshold control, chart, toggle, pagination controls.
  - Empty states for zero class size and no activity.
  - Schedule-aware variant with dotted position indicator and tooltip.
- Navigation & Entry Points:
  - `View Progress Details` button navigates to `Insights > Content`.
- Accessibility:
  - Bar values/labels programmatically associated.
  - Tooltips accessible on hover and keyboard focus.
  - Toggle and pagination controls keyboard operable with announced state changes.
- Internationalization:
  - Externalize labels/tooltips/messages and support localized number formatting.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/progress_tile/informal.md`.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Render Progress tile scoped to current global filter (course/unit/module/container level). | P0 | UI |
| FR-002 | Use concrete progress and content-title oracle data to build a non-UI projection model consumed by the chart component. | P0 | Data/UI |
| FR-003 | Provide `Completion Threshold` control with selectable values 10%-100%, and reproject chart data on selection changes. | P0 | UI |
| FR-004 | Render chart axis granularity based on selected scope level (course->units, unit->modules, module->children). | P0 | UI |
| FR-005 | Provide y-axis mode toggle between student count and class percentage without full page reload. | P0 | UI |
| FR-006 | If schedule exists, render schedule position indicator and schedule-aware visual treatment; if no schedule, omit these visuals entirely. | P1 | UI |
| FR-007 | Provide horizontal pagination controls when axis items exceed available width, preserving chart state and accessibility semantics. | P1 | UI |
| FR-008 | Handle empty/edge states for no activity and zero class size with explicit explanatory messaging. | P0 | UI |
| FR-009 | Keep UI rendering and interaction state isolated from projection logic to maximize unit-test coverage. | P0 | UI/Data |

## 7. Acceptance Criteria
- AC-001 (FR-001) — Given an instructor opens dashboard, when Progress tile loads, then it reflects currently selected global scope.
- AC-002 (FR-002, FR-009) — Given progress oracle payloads, when projection runs, then chart-ready data is produced by non-UI module and UI consumes projected output only.
- AC-003 (FR-003) — Given instructor selects a new completion threshold, when selection changes, then chart reprojects and rerenders using the new threshold.
- AC-004 (FR-004) — Given scope is Entire Course/Unit/Module, when chart renders, then x-axis items correspond to direct children of that scope.
- AC-005 (FR-005) — Given instructor toggles count/percentage mode, when toggle changes, then y-axis values and bar tooltips update without page refresh.
- AC-006 (FR-006) — Given schedule exists/does not exist, when tile renders, then schedule indicators appear only for scheduled contexts.
- AC-007 (FR-007) — Given too many x-axis items for viewport width, when tile renders, then pagination controls appear and navigate sets without stale labels.
- AC-008 (FR-008) — Given no activity or class size zero, when tile renders, then explanatory empty state appears and misleading chart is not shown.

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Rapid filter/toggle/threshold changes do not produce stale chart state.
- Security & Privacy:
  - Instructor-only access; tile shows aggregate data only.
- Compliance:
  - WCAG 2.1 AA keyboard/screen-reader requirements for chart controls and tooltips.
- Observability:
  - Minimal instrumentation: projection failure count, empty-state render count.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - Non-UI projection modules under instructor dashboard domain.
  - UI chart component (Vega-Lite) consumes projection model.
- APIs / Contracts:
  - Inputs: scope, completion threshold, y-axis mode, progress oracle payloads, content title payloads, optional schedule context.
  - Output: ordered chart model containing label, completion value(s), schedule marker metadata, pagination metadata.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View and interact with progress tile controls | Section-scoped |
| Student | None | Instructor dashboard only |
| Admin | View for authorized section contexts | Same access constraints |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Leverages existing instructor role gates.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Uses oracle-driven data; no direct analytics queries in UI.
- Multi-tenancy:
  - All scope and values constrained to current section.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Progress tile render success rate.
  - Interaction completion rate for threshold and y-axis toggle.
- Events:
  - `progress_tile.threshold_changed`
  - `progress_tile.mode_toggled`

## 13. Risks & Mitigations
- Chart complexity across hierarchy levels -> use a single projection contract with deterministic scope-level mapping.
- Schedule overlay clutter -> conditional rendering and tooltip-only details reduce visual overload.
- Regression under rapid interactions -> add state-consistency tests with rapid event sequences.

## 14. Open Questions & Assumptions
- Assumptions:
  - Schedule presence and current position marker are available from existing schedule context data.
  - Vega-Lite can satisfy required interactions and accessibility wrappers for this tile.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement non-UI projection model and tests.
- Build UI controls + chart rendering.
- Add schedule-aware and pagination behavior.
- Finish accessibility and regression QA.

## 16. QA Plan
- Automated:
  - Unit tests for projection by scope/threshold/mode.
  - LiveView/component tests for controls, empty states, pagination, and schedule variants.
- Manual:
  - Verify hierarchy adaptation across course/unit/module.
  - Verify keyboard operation and tooltip/readout behavior.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
