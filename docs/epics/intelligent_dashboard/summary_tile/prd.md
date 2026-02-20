# Summary Tile — PRD

## 1. Overview
Feature Name: Summary Tile

Summary: Add a top-of-dashboard summary section that shows scoped key metrics and an AI recommendation to help instructors quickly decide where to focus. The section must update with global scope changes, handle partial data availability gracefully, and support recommendation feedback/regeneration interactions without page refresh.

Links: `docs/epics/intelligent_dashboard/summary_tile/informal.md`, `docs/epics/intelligent_dashboard/prd.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5249`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors lack a consolidated, scoped summary that combines core metrics and recommendation guidance in one place.
  - Existing recommendation interactions are not integrated into the summary layout contract for this story.
  - Partial-data states can produce inconsistent UI if metric tiles are treated as all-or-nothing.
- Affected users/roles:
  - Instructors in section-scoped Learning Dashboard contexts.
- Why now:
  - Summary is the anchor surface for the Intelligent Dashboard and dependency point for recommendation feedback/regeneration workflows.

## 3. Goals & Non-Goals
- Goals:
  - Render a summary section directly below the global filter with metric tiles and AI recommendation.
  - Support incremental rendering from optional oracle inputs.
  - Ensure scoped updates on filter changes and robust loading/empty states.
  - Provide recommendation controls integration points (thumbs + regenerate) with disabled-in-flight behavior.
- Non-Goals:
  - Implementing recommendation infrastructure internals (covered by `ai_infra`).
  - Implementing separate feedback modal feature behavior outside this tile's integration boundary.
  - Redesigning global filter behavior.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor role in a section context viewing Learning Dashboard.
- Use Cases:
  - Instructor changes scope to Unit/Module and immediately sees scoped summary metrics and recommendation.
  - Instructor sees only available metrics when objectives or assessments are absent.
  - Instructor requests recommendation regeneration and gets a thinking state until response returns.

## 5. UX / UI Requirements
- Key Screens/States:
  - Summary section below global content filter.
  - Metric tile states: loading, populated, hidden-when-not-applicable.
  - AI recommendation states: loading/thinking, populated, beginning-course message.
- Navigation & Entry Points:
  - Entry is passive on dashboard load and global-scope changes.
- Accessibility:
  - Tooltips accessible via hover and keyboard focus with proper ARIA associations.
  - AI recommendation label and icon programmatically associated with recommendation content.
  - All controls keyboard-operable with visible focus indicators.
- Internationalization:
  - User-visible strings externalized for localization.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/summary_tile/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Partial oracle failures degrade only affected subcomponents; entire summary does not crash.
  - Regenerate failure preserves previous recommendation.
- Security & Privacy:
  - Instructor-only access via existing dashboard authorization.
  - Recommendation content/logging must avoid raw student PII.
- Compliance:
  - WCAG 2.1 AA tooltip and keyboard requirements are satisfied.
- Observability:
  - Minimal instrumentation: error counters for summary render failures and recommendation regenerate failures.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - `Oli.InstructorDashboard.*` non-UI projection modules for summary metrics.
  - LiveView/UI layer consumes projection output and recommendation contracts.
- APIs / Contracts:
  - Inputs: selected dashboard scope and optional oracle payloads.
  - Outputs: metric card view models + recommendation view model.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View summary metrics and recommendation, trigger regen/feedback controls | Scoped to section access |
| Student | None | Instructor dashboard only |
| Admin | Same as instructor for authorized sections | Must meet section access rules |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Uses existing instructor-role dashboard authorization.
- GenAI (if applicable):
  - Consumes recommendation output from `ai_infra`; no model/provider coupling in UI.
- External services:
  - None directly from this feature.
- Caching/Perf:
  - Must cooperate with existing dashboard oracle/caching paths and avoid ad-hoc queries in UI.
- Multi-tenancy:
  - All data strictly section-scoped under selected container scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - % of dashboard views with successful summary render.
  - Recommendation regenerate success rate.
- Events:
  - `summary_tile.regenerate_clicked`
  - `summary_tile.regenerate_failed`

## 13. Risks & Mitigations
- Optional-oracle race conditions -> enforce stable loading state composition and deterministic re-render order.
- Over-coupling summary UI to recommendation internals -> integrate via explicit recommendation contract view model only.
- Layout regressions with hidden metrics -> add responsive snapshot tests and manual visual QA against Figma.

## 14. Open Questions & Assumptions
- Assumptions:
  - Exact concrete oracle module names are sourced from `concrete_oracles` artifacts.
  - Thumbs controls in this tile are integration hooks; full workflow details are specified in `feedback_ui` and `ai_infra`.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Define summary projections and view models.
- Implement summary UI states and responsive layout rules.
- Integrate recommendation controls and regenerate state handling.
- Complete accessibility and regression QA.

## 16. QA Plan
- Automated:
  - Unit tests for summary projection modules.
  - LiveView/component tests for loading/partial/empty/populated states.
  - Interaction tests for regenerate disabled-in-flight behavior.
- Manual:
  - Verify scope change updates across course/unit/module.
  - Verify hidden-metric responsive layout and tooltip accessibility.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
