# Challenging Objectives Tile — PRD

## 1. Overview
Feature Name: Challenging Objectives Tile

Summary: Provide a scoped tile that surfaces low-proficiency learning objectives (and sub-objectives) so instructors can quickly identify content areas needing intervention. The tile supports hierarchical display, conditional rendering, and deep-link navigation into Insights -> Learning Objectives.

Links: `docs/epics/intelligent_dashboard/objectives_tile/informal.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5253`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors need a quick indicator of low-performing objectives within the selected scope.
  - Objective hierarchy display and expansion behavior are not captured in dashboard tile requirements.
  - Empty states for no objectives vs no low-proficiency objectives must be explicit and distinct.
- Affected users/roles:
  - Instructors reviewing objective mastery trends.
- Why now:
  - Objective-specific insight is a key dashboard pillar and direct bridge to deeper Insights workflows.

## 3. Goals & Non-Goals
- Goals:
  - Display low-proficiency objectives (<=40%) for selected scope.
  - Support parent/sub-objective expandable hierarchy where applicable.
  - Provide deterministic navigation to Insights -> Learning Objectives with contextual selection.
- Non-Goals:
  - Redefining proficiency thresholds in this story.
  - Implementing objective authoring/editing workflows.
  - Building unrelated Insights page functionality beyond navigation contract.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section context.
- Use Cases:
  - Instructor sees top challenging objectives in selected module and drills into detailed Insights view.
  - Instructor expands an objective to inspect sub-objectives before deciding intervention focus.

## 5. UX / UI Requirements
- Key Screens/States:
  - Tile list of challenging objectives with optional expandable sub-objectives.
  - Empty state when no low-proficiency objectives in scope.
  - Conditional hidden state when no objectives exist in course/scope.
- Navigation & Entry Points:
  - Objective row click navigates to `Insights -> Learning Objectives` with objective row expanded.
  - Sub-objective click navigates with corresponding sub-objective visible/highlighted.
  - `View Learning Objectives` navigates to all-objectives default view.
- Accessibility:
  - Expand/collapse controls keyboard-operable and state-announced.
  - Focus order and visible indicators preserved across expand/collapse and navigation actions.
- Internationalization:
  - Labels/messages externalized; scope/container names localization-safe.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/objectives_tile/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Navigation failures show explicit non-breaking error state.
- Security & Privacy:
  - Instructor-only access; objective data scoped to section and selected container.
- Compliance:
  - WCAG 2.1 AA for disclosure controls and keyboard navigation.
- Observability:
  - Minimal instrumentation: navigation failure count and objective-data load failure count.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - Objective projection/filtering in non-UI module.
  - UI component renders hierarchy and navigation actions.
- APIs / Contracts:
  - Inputs: scope, objective proficiency data, objective hierarchy/title metadata.
  - Outputs: ordered list view model with optional child rows and navigation metadata.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View challenging objectives and navigate to insights | Section-scoped |
| Student | None | Instructor dashboard only |
| Admin | Same actions in authorized contexts | Same access controls |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Existing instructor role gating.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Consume oracle-driven objective payloads; avoid direct UI-level queries.
- Multi-tenancy:
  - Objective rows and navigation context constrained by section scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Challenging objectives tile render success rate.
  - Click-through rate to Insights -> Learning Objectives.
- Events:
  - `objectives_tile.objective_clicked`
  - `objectives_tile.view_all_clicked`

## 13. Risks & Mitigations
- Hierarchy data inconsistencies -> use depot-backed hierarchy resolution with defensive empty-child handling.
- Overly noisy low-proficiency list in large scopes -> maintain deterministic ordering and truncation/scroll strategy in UI.
- Navigation-context mismatch -> include explicit objective identifiers in navigation params and test deep-link behavior.

## 14. Open Questions & Assumptions
- Assumptions:
  - Low-proficiency threshold is fixed at <=40% for this feature.
  - Objective hierarchy metadata is available via oracle/depot composition.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement objective projection/filtering by threshold and scope.
- Implement hierarchy UI with disclosure behavior.
- Implement Insights navigation contracts and empty states.
- Complete accessibility and navigation QA.

## 16. QA Plan
- Automated:
  - Unit tests for low-proficiency filtering and hierarchy shaping.
  - Component tests for disclosure interactions and conditional states.
  - Navigation tests for objective/sub-objective/view-all actions.
- Manual:
  - Verify behavior across scopes with/without objectives.
  - Verify keyboard and screen-reader semantics for disclosure controls.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
