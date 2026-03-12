# Assessments Tile — PRD

## 1. Overview
Feature Name: Assessments Tile

Summary: Add a scoped Assessments tile that summarizes assessment completion and score distribution data to help instructors identify assessment-level performance patterns quickly. The tile uses aggregated oracle output and supports drill-through to assessment insights workflows.

Links: `docs/epics/intelligent_dashboard/assessment_tile/informal.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5254`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors lack a compact dashboard view of assessment status and score distributions within selected scope.
  - Assessment summaries require consistent aggregation definitions and metadata pairing (titles/schedule fields).
- Affected users/roles:
  - Instructors monitoring graded assessment outcomes.
- Why now:
  - Assessments are a core content section signal and dependency for support/outreach workflows.

## 3. Goals & Non-Goals
- Goals:
  - Render assessment summary and distribution data scoped to global filter.
  - Use aggregated oracle payloads without per-student raw rendering in tile.
  - Provide stable empty/conditional states when no graded pages are present.
- Non-Goals:
  - Recomputing grading stats in UI.
  - Building full assessment-detail pages.
  - Introducing new grading data sources beyond oracle/depot contracts.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section-scoped dashboard.
- Use Cases:
  - Instructor scans available/due/completion and score statistics for assessments in selected unit/module.
  - Instructor identifies outlier assessment distribution and navigates to deeper assessment insights.

## 5. UX / UI Requirements
- Key Screens/States:
  - Tile listing/summary for in-scope assessments with aggregate metrics.
  - Visual distribution representation from score bins.
  - Empty/hidden states for scopes without graded assessments.
- Navigation & Entry Points:
  - Tile-level navigation affordance to deeper assessment insights as defined in UI design.
- Accessibility:
  - Summary values and distribution visuals have non-visual equivalents/labels.
  - Interactive controls keyboard-operable with visible focus states.
- Internationalization:
  - Labels, date/time representations, and numeric formats localized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/assessment_tile/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Missing metadata for one assessment does not crash tile; row degrades gracefully.
- Security & Privacy:
  - Instructor-only section-scoped access; no unnecessary student-level PII in tile payload rendering.
- Compliance:
  - WCAG 2.1 AA non-visual labeling and keyboard interaction requirements for tile controls.
- Observability:
  - Minimal instrumentation: tile render failure count and missing-metadata warning count.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - Oracle consumption + projection in non-UI module.
  - UI module for rendering summaries/distributions.
- APIs / Contracts:
  - Input: grades oracle aggregate payload + content title metadata + selected scope.
  - Output: assessment tile view model list with stats and distribution entries.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View assessment summaries and interact with tile controls | Section-scoped |
| Student | None | Not exposed |
| Admin | Same in authorized contexts | Same access rules |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Uses existing instructor authorization pathway.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Relies on concrete oracle aggregated output; no direct data aggregation in LiveView UI.
- Multi-tenancy:
  - Assessment results strictly constrained by section and selected scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Assessment tile render success rate.
  - Scope-change freshness rate (no stale assessment rows).
- Events:
  - `assessment_tile.rendered`
  - `assessment_tile.scope_changed`

## 13. Risks & Mitigations
- Title/metadata mismatches -> use deterministic mapping with fallback labels and validation tests.
- Large assessment sets in broad scopes -> cap rendered rows/paging as needed by design and test for responsiveness.
- Confusion between empty and hidden behavior -> align with section composition rules and add explicit tests.

## 14. Open Questions & Assumptions
- Assumptions:
  - Aggregated grades oracle contract includes required statistical and schedule fields.
  - Section-composition logic determines whether empty tile is shown or omitted in broader dashboard context.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement assessment projection contract.
- Build tile rendering for summary + distribution.
- Integrate scope updates and conditional states.
- Complete QA and accessibility checks.

## 16. QA Plan
- Automated:
  - Unit tests for projection mapping from aggregate oracle payload.
  - Component tests for populated/empty/hidden states and scope update behavior.
- Manual:
  - Verify displayed stats against fixture data.
  - Verify keyboard and non-visual labeling expectations.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
