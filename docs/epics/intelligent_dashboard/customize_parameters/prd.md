# Customize Student Support Parameters — PRD

## 1. Overview
Feature Name: Customize Student Support Parameters

Summary: Add a modal workflow that allows instructors to adjust student support classification parameters (inactivity and performance thresholds) and persist them at section scope. Saving parameters must immediately trigger Student Support tile reprojection using newly persisted values.

Links: `docs/epics/intelligent_dashboard/customize_parameters/informal.md`, `docs/epics/intelligent_dashboard/support_tile/prd.md`, `https://eliterate.atlassian.net/browse/MER-5256`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Student support classification rules are static and cannot be tailored by instructors.
  - Without persistence, different instructors could see inconsistent interpretations if settings were user-local.
  - Save/apply semantics require explicit coupling to tile reprojection to avoid stale charts/lists.
- Affected users/roles:
  - Instructors sharing a section dashboard.
- Why now:
  - Teams need section-level configurable support rules while preserving shared operational understanding across instructors.

## 3. Goals & Non-Goals
- Goals:
  - Provide configurable inactivity window and performance threshold controls.
  - Persist configuration at section level (shared across instructors).
  - Reproject Student Support outputs immediately after successful save.
  - Maintain clear cancel/escape/outside-click non-persistence behavior.
- Non-Goals:
  - Per-instructor parameter preferences.
  - Custom comparator editing beyond allowed numeric thresholds.
  - Reworking Student Support bucket taxonomy.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section dashboard context.
- Use Cases:
  - Instructor updates inactivity from 7 to 14 days and sees revised inactive counts.
  - Co-instructor opens dashboard later and sees same section-level parameter configuration.
  - Instructor adjusts thresholds, then cancels modal and keeps existing live state unchanged.

## 5. UX / UI Requirements
- Key Screens/States:
  - `Customize student support parameters` modal with `Inactivity` and `Group Ranges` sections.
  - Save/cancel flow with inline validation constraints.
- Navigation & Entry Points:
  - Entry from Student Support tile `Edit parameters` control.
- Accessibility:
  - Modal focus trap, keyboard operability for controls, proper labels/tooltips.
  - Numeric controls keyboard accessible and validation feedback announced.
- Internationalization:
  - Modal labels/messages externalized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/customize_parameters/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Section persistence writes are atomic and idempotent for repeated save submissions.
- Security & Privacy:
  - Only authorized instructors can read/write section parameter settings.
- Compliance:
  - Modal and controls satisfy WCAG 2.1 AA interaction requirements.
- Observability:
  - Minimal instrumentation: save success/failure counts and reprojection failure counts.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Add/extend section-scoped configuration persistence for student support parameters if not already present.
- Context Boundaries:
  - Non-UI service for parameter validation + persistence.
  - Student Support projection module consumes active settings.
  - UI modal remains tile-bound feature component.
- APIs / Contracts:
  - `get_support_parameters(section_id) -> defaults_or_persisted`
  - `save_support_parameters(section_id, params) -> {:ok, persisted} | {:error, reason}`
  - `reproject_support_data(section_id, scope, active_params)` invoked after successful save.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View/edit/save section support parameters | Section authorization required |
| Student | None | Not exposed |
| Admin | May manage in authorized admin context | Same section scoping |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Reuses existing instructor authorization flow.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Persisted setting changes must invalidate/refresh relevant support tile state to avoid stale counts.
- Multi-tenancy:
  - Settings and resulting projections scoped to section boundaries.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Parameter-save success rate.
  - Time from save to updated support visualization.
- Events:
  - `support_parameters.saved`
  - `support_parameters.save_failed`

## 13. Risks & Mitigations
- Conflicting instructor expectations -> section-level single source of truth with explicit persistence semantics.
- Invalid threshold combos causing undefined groups -> strict real-time constraints and validation tests.
- Reprojection lag causing trust issues -> immediate post-save refresh with visible feedback.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing support projection logic can accept parameter object without major refactor.
  - Inactivity options are fixed set for this iteration.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement section-level parameter persistence APIs.
- Build modal controls and validation.
- Wire save -> reprojection flow and error handling.
- Complete shared-instructor and accessibility QA.

## 16. QA Plan
- Automated:
  - Unit tests for parameter validation and overlap constraints.
  - Integration tests for section-level persistence visibility across multiple instructors.
  - Component/LiveView tests for save/cancel behaviors and rerender trigger.
- Manual:
  - Verify modal keyboard behavior and focus handling.
  - Verify save and failure states against expected tile updates.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
