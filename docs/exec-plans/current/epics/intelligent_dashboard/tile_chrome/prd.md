# Dashboard Tile Chrome (Section Grouping/Reorder) — PRD

## 1. Overview
Feature Name: Dashboard Tile Chrome

Summary: Implement reusable dashboard section chrome that supports section grouping, collapse/expand, and drag-reordering while keeping dashboard-specific tile eligibility logic outside the reusable module. Instructor Dashboard consumes this reusable chrome and persists section layout preferences at section scope.

Links: `docs/epics/intelligent_dashboard/tile_chrome/informal.md`, `docs/epics/intelligent_dashboard/prd.md`, `https://eliterate.atlassian.net/browse/MER-5258`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Dashboard needs reorganizable, collapsible section containers but current behavior is tightly tied to instructor implementation details.
  - Layout changes require persistence and deterministic reload behavior.
  - Conditional section visibility depends on tile eligibility rules that should remain dashboard-specific.
- Affected users/roles:
  - Instructors customizing dashboard layout.
  - Engineering teams reusing chrome for future dashboards.
- Why now:
  - Engagement/Content section UX depends on this foundation and upcoming dashboards can reuse it.

## 3. Goals & Non-Goals
- Goals:
  - Provide reusable, tile-agnostic section chrome component set.
  - Support collapse/expand and reorder with callback contract to host dashboard.
  - Persist section order/expansion state at section scope.
  - Apply instructor-dashboard-specific tile eligibility before rendering chrome.
- Non-Goals:
  - Cross-section tile dragging.
  - Per-user layout persistence.
  - Embedding instructor-specific tile logic into shared chrome module.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in Learning Dashboard.
- Use Cases:
  - Instructor collapses Content section and sees same state after refresh.
  - Instructor drags Engagement below Content and sees persisted order across sessions.
  - Course with no objectives and no graded assessments hides entire Content section.

## 5. UX / UI Requirements
- Key Screens/States:
  - Section header with title, caret, drag handle.
  - Expanded and collapsed section states.
  - Drag hover/placeholder/drop visual feedback per design.
  - Single-tile full-width section rendering.
- Navigation & Entry Points:
  - Entry on dashboard load; interactions are inline.
- Accessibility:
  - Caret/drag controls keyboard-reachable and semantically labeled.
  - Non-rendered sections leave no hidden focusable controls.
  - Focus order remains logical after show/hide/reorder changes.
- Internationalization:
  - Section labels and tooltips externalized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/tile_chrome/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Persisted layout state restores deterministically on reload/navigation.
- Security & Privacy:
  - Layout preference writes authorized for section instructors only.
- Compliance:
  - WCAG 2.1 AA keyboard/focus/semantic requirements for section controls.
- Observability:
  - Minimal instrumentation: layout-save failure count and restore failure count.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Add/extend section-level layout preference storage if not already present.
- Context Boundaries:
  - Shared UI chrome module (dashboard-generic).
  - Instructor dashboard composition and eligibility logic module.
  - Section-preference persistence service.
- APIs / Contracts:
  - `on_section_order_changed(new_order)` callback.
  - `on_section_expansion_changed(section_id, expanded?)` callback.
  - `save_layout_preferences(section_id, %{order, expansion})`.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Reorder/collapse sections and persist layout | Section-scoped |
| Student | None | Instructor dashboard only |
| Admin | May manage in authorized contexts | Same section constraints |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Uses existing instructor authorization controls.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Layout persistence should be lightweight and avoid interfering with tile data loads.
- Multi-tenancy:
  - Preferences are section-scoped and isolated across sections/institutions.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Layout persistence success rate.
  - Reorder/collapse interaction usage rate.
- Events:
  - `dashboard_layout.section_reordered`
  - `dashboard_layout.section_toggled`

## 13. Risks & Mitigations
- Shared component overfitting instructor use case -> keep API generic and child-content agnostic.
- Hidden-focus accessibility bugs when sections omitted -> explicit keyboard/focus regression tests.
- Layout drift across instructors -> section-level persistence as single source of truth.

## 14. Open Questions & Assumptions
- Assumptions:
  - Current dashboard has two top-level sections (Engagement, Content) but chrome supports extensible section lists.
  - Eligibility checks can be computed before render from existing oracle/depot signals.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Build shared chrome components and callback contracts.
- Implement instructor composition and eligibility integration.
- Add section-level persistence save/restore.
- Complete accessibility and interaction QA.

## 16. QA Plan
- Automated:
  - Component tests for collapse/reorder behavior and callback emissions.
  - Integration tests for section-level persistence and restore across sessions/users.
  - Tests for zero-tile omission and single-tile full-width behavior.
- Manual:
  - Drag/drop visual conformance checks against design.
  - Keyboard/focus traversal verification for all control states.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
