# Challenging Objectives Tile - Product Requirements Document

## 1. Overview
Provide an instructor dashboard tile that highlights low-proficiency learning objectives and sub-objectives within the currently selected course-content scope. The tile should help instructors quickly spot weak content areas and transition into the existing `Insights -> Learning Objectives` experience with enough context to continue investigation.

## 2. Background & Problem Statement
Instructors can already inspect learning objectives in Torus, but they do not have a compact dashboard signal that surfaces the most concerning objectives for the currently selected scope. Without that summary, instructors must leave the dashboard and manually inspect broader views to determine which content areas need intervention.

This work item closes that gap by introducing a scope-aware `Challenging Objectives` tile that only appears when objectives exist, distinguishes between no-objective, no-data, and no-low-proficiency states, and supports navigation into the deeper objective-insights workflow.

## 3. Goals & Non-Goals
### Goals
- Surface learning objectives with low proficiency at or below the existing Torus threshold of `<= 40%`.
- Respect the global dashboard course-content filter so the tile always reflects the current scope.
- Present parent and sub-objective relationships clearly enough for instructors to scan hierarchy before drilling in.
- Navigate instructors into `Insights -> Learning Objectives` with context that matches the clicked objective, sub-objective, or view-all action.
- Reuse the dashboard oracle/data-contract architecture rather than adding tile-specific analytics queries.

### Non-Goals
- Changing the proficiency formula or the low-proficiency threshold.
- Adding new objective authoring, editing, or curriculum-ordering workflows.
- Redesigning the destination `Insights -> Learning Objectives` page beyond the minimum navigation contract needed for this tile.
- Introducing new schema, migrations, or standalone reporting endpoints for this tile.

## 4. Users & Use Cases
- Instructor: views the dashboard at course, unit, or module scope and immediately sees which objectives are underperforming in that scope.
- Instructor: expands a parent objective to inspect low-proficiency sub-objectives before deciding where students need support.
- Instructor: clicks an objective or sub-objective and lands in `Insights -> Learning Objectives` with the relevant context visible.
- Instructor: clicks `View Learning Objectives` to leave the tile and inspect the full objectives view for the selected section.

## 5. UX / UI Requirements
- The tile title is `Challenging Objectives`.
- The tile description communicates that the class is showing low proficiency (`<= 40%`) for the listed objectives.
- Objectives are shown in curriculum order using the same numbering expectations instructors already see elsewhere in Torus.
- Parent objectives with qualifying sub-objectives expose an expand/collapse control; objectives without children do not.
- Expand/collapse controls are keyboard operable, expose visible focus state, and communicate expanded/collapsed state programmatically.
- Objective and sub-objective rows are implemented as proper interactive elements, not click-only containers.
- When navigation is triggered from the tile, the destination should preserve enough context for the relevant objective state to be visible on arrival.
- If objectives exist but none are low proficiency for the selected scope, the tile shows a contextual informational message that names the active scope.
- If objectives exist in the selected scope but proficiency data is not yet available, the tile shows an informational no-data state instead of misleading low-proficiency results.
- If the course has no learning objectives at all, the tile is not rendered.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: interactive rows and disclosure controls satisfy WCAG 2.1 AA expectations for keyboard operation, focus visibility, semantic labeling, and state announcement.
- Reliability: rapid global scope changes must never leave the tile showing stale rows or mismatched scope labels.
- Security and privacy: data remains limited to authorized instructor/admin contexts for the current section and selected scope.
- Performance: this tile should consume existing dashboard oracle outputs and local projection logic rather than introduce direct analytics queries from LiveView or UI components.
- Observability: tile load, empty-state, navigation, and failure behavior should be measurable through repository-standard telemetry and AppSignal patterns.

## 9. Data, Interfaces & Dependencies
- Depends on the intelligent dashboard scope selection and hydration flow already defined for the instructor dashboard.
- Depends on the concrete dashboard oracles for objective proficiency and course-content titles/scope metadata.
- May use `SectionResourceDepot` to resolve parent-child objective relationships when the objective proficiency oracle payload alone does not provide hierarchy context.
- Requires a stable tile view-model contract that includes objective identifiers, titles, numbering/order, proficiency qualification, optional child rows, and navigation metadata.
- Requires a navigation contract into `Insights -> Learning Objectives` for:
  - a parent objective deep link with expanded row context
  - a sub-objective deep link with the relevant child visible in context
  - a view-all action with no forced row expansion
- No database schema changes or migrations are required.

## 10. Repository & Platform Considerations
- Keep domain/data shaping out of UI code and aligned with existing backend context boundaries in `lib/oli/` and LiveView rendering in `lib/oli_web/`.
- Preserve the intelligent dashboard rule that tiles consume oracle-backed projections instead of introducing tile-specific analytics query paths.
- Expect backend coverage in targeted ExUnit tests and LiveView/UI interaction coverage where rendering and navigation state need verification, consistent with [docs/TESTING.md](/Users/santiagosimoncelli/Documents/Projects/oli-torus/docs/TESTING.md).
- Follow normal repository review expectations, including security and performance review, because this work changes instructor-facing scoped data and interaction behavior.
- Link implementation and follow-up execution back to the repository’s Jira-based issue tracking flow for `MER-5253`.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Track tile render success/failure and distinguish between populated, empty, and no-data states.
- Track successful instructor drill-through arrival on objective rows, sub-objective rows, and `View Learning Objectives`.
- Track navigation failures or destination-state resolution failures so broken drill-through behavior is visible in production.
- Success signal: instructors can reach the deeper learning-objectives view from the dashboard with state that matches the scope and item they selected.

## 13. Risks & Mitigations
- Hierarchy reconstruction may drift from curriculum structure if oracle payloads are incomplete: mitigate by using depot-backed parent-child resolution and targeted tests for mixed parent/sub-objective cases.
- Scope changes may race with asynchronous tile hydration: mitigate by using the dashboard’s existing stale-result suppression and validating rapid scope switching behavior.
- Deep-link navigation may arrive without the intended expansion/highlight state: mitigate by defining explicit navigation params and verifying them in automated tests.
- Similar empty states can confuse instructors if no-objective, no-data, and no-low-proficiency cases are conflated: mitigate with distinct copy and separate rendering conditions.

## 14. Open Questions & Assumptions
### Open Questions
- Should the tile cap the number of visible parent objectives before requiring navigation to the full objectives page, or is the full qualifying list expected in the initial release?

### Assumptions
- The low-proficiency threshold remains fixed at `<= 40%` for this work item.
- Existing curriculum ordering and objective numbering rules are the source of truth for tile ordering.
- The destination `Insights -> Learning Objectives` surface can accept enough context to show the clicked objective or sub-objective meaningfully on arrival.
- No separate feature flag or migration strategy is required for this tile.
- When only a sub-objective is low proficiency, the tile still renders the parent objective as the expandable context row and nests the qualifying child beneath it.

## 15. QA Plan
- Automated validation:
  - Backend tests for scope-aware low-proficiency filtering and hierarchy shaping.
  - LiveView or component tests for disclosure rendering, keyboard behavior, and distinct conditional states.
  - Navigation tests that verify objective, sub-objective, and view-all actions pass the expected destination context.
  - Regression coverage for rapid scope changes so stale objective rows are not rendered.
- Manual validation:
  - Verify course, unit, and module scope behavior with datasets covering no objectives, no proficiency data, no low-proficiency objectives, and mixed parent/sub-objective results.
  - Verify keyboard-only expansion and activation flows.
  - Verify the destination page reflects the intended context after each tile action.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
