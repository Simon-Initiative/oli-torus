# Assessments Tile — PRD

## 1. Overview
Feature Name: Assessments Tile

Summary: Add a scoped Assessments tile that summarizes assessment completion and score distribution data to help instructors identify assessment-level performance patterns quickly. The tile consumes display-ready aggregated grades-oracle output, pairs it with assessment-title metadata, and supports drill-through to assessment insights workflows.

Links: `docs/epics/intelligent_dashboard/assessment_tile/informal.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5254`, `https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=895-8349&t=EfwdptDGcPWmCVAN-1`

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
  - Completion-status chip variants aligned with the Jira-linked "good status" and "bad status" examples.
- Navigation & Entry Points:
  - Tile-level navigation affordance to deeper assessment insights as defined in UI design.
- Accessibility:
  - Summary values and distribution visuals have non-visual equivalents/labels.
  - Interactive controls keyboard-operable with visible focus states.
- Internationalization:
  - Labels, date/time representations, and numeric formats localized.
- Screenshots/Mocks:
  - `Component / Assessments Tile`: `https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=895-8349&t=EfwdptDGcPWmCVAN-1`
  - Jira attachments also include the "good status" and "bad status" chip examples referenced in `MER-5254`.
  - Before implementation, run the local `implement_ui` skill against the Jira/Figma sources to map these states onto Torus tokens, icons, reusable components, and target files.
  - `implement_ui` should explicitly confirm missing or ambiguous empty, loading, error, hover/focus, and responsive states before coding.

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
  - Grades oracle payload is expected to arrive already aggregated and display-ready for completion, schedule, score metrics, and score-distribution values.
  - Non-UI enrichment may pair the grades-oracle payload with content-oracle or `SectionResourceDepot` title metadata where needed for display labels.
  - UI module renders summaries/distributions and must not re-aggregate score statistics client-side.
- APIs / Contracts:
  - Input: grades oracle aggregate payload + content title metadata + selected scope.
  - Output: assessment tile render contract that uses oracle-provided stats directly, with only minimal enrichment/formatting needed for titles and presentation.
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
- Figma-state drift or underspecified interaction states -> require `implement_ui` design brief before coding to pin token/icon/component mappings and surface missing-state decisions early.

## 14. Open Questions & Assumptions
- Assumptions:
  - Darren Siegel's Jira comment is authoritative for this feature's technical constraints: grades-oracle payload should already include `available_at`, `due`, and aggregated assessment statistics needed for display, with no separate stats projection required.
  - Aggregated grades oracle contract includes required statistical and schedule fields.
  - Assessment titles may require pairing oracle results with content-oracle data or direct `SectionResourceDepot` reads.
  - Section-composition logic determines whether empty tile is shown or omitted in broader dashboard context.
- Open Questions:
  - The ticket design source currently shows the primary component state plus status-chip variants, but does not fully specify empty, loading, error, hover/focus, or responsive behavior. `implement_ui` should either map these from existing Torus patterns or flag them for product/design approval.

## 15. Timeline & Milestones (Draft)
- Implement assessment render contract and title-enrichment path without re-aggregating oracle stats.
- Produce design-mapping brief with `implement_ui` using the Jira/Figma sources before UI implementation begins.
- Build tile rendering for summary + distribution.
- Integrate scope updates and conditional states.
- Complete QA and accessibility checks.

## 16. QA Plan
- Automated:
  - Unit tests for projection mapping from aggregate oracle payload.
  - Component tests for populated/empty/hidden states and scope update behavior.
- Manual:
  - Verify displayed stats against fixture data.
  - Validate implemented visual states against the Jira-linked Figma node and attachment examples for good/bad completion status.
  - Verify keyboard and non-visual labeling expectations.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
