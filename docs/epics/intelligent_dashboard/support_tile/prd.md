# Student Support Tile — PRD

## 1. Overview
Feature Name: Student Support Tile

Summary: Build a Student Support tile that groups students by progress/proficiency-derived support categories and enables instructor action through filtering, list management, and email initiation. The feature combines donut visualization and student list interactions backed by non-UI projection logic.

Links: `docs/epics/intelligent_dashboard/support_tile/informal.md`, `docs/epics/intelligent_dashboard/concrete_oracles/prd.md`, `https://eliterate.atlassian.net/browse/MER-5252`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors do not have a compact grouped view of students who are struggling/on-track/excelling.
  - Activity status and bucketed segmentation require coordinated data projection and UI state.
  - Selection-to-email workflow requires predictable list/filter semantics.
- Affected users/roles:
  - Instructors monitoring student progress in section context.
- Why now:
  - Student support actionability is central to the intelligent dashboard experience.

## 3. Goals & Non-Goals
- Goals:
  - Render support categories with interactive donut/legend filtering.
  - Provide searchable, paged student list tied to selected category.
  - Support active/inactive filtering and multi-select for email launch.
  - Keep bucketing and inactivity logic in non-UI projection modules.
- Non-Goals:
  - Customizable support thresholds/inactivity definitions (covered by separate feature).
  - Full email composition/send workflow implementation.
  - Student profile-hover implementation details from separate story.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section dashboard.
- Use Cases:
  - Instructor starts in struggling bucket, identifies inactive students, and selects recipients for outreach.
  - Instructor switches to other categories and loads more students while maintaining scroll context.
  - Instructor uses search to find a student within selected bucket.

## 5. UX / UI Requirements
- Key Screens/States:
  - Donut chart and legend for support categories.
  - Student list with search, active/inactive filters, selection checkboxes.
  - Empty/no-activity informational state.
- Navigation & Entry Points:
  - `View Student Overview` navigates to `Overview -> Students`.
  - `Email` opens email modal with selected recipients.
- Accessibility:
  - Donut segments and legend controls keyboard-operable.
  - Filter controls and checkboxes expose accessible labels/states.
  - Load-more interactions preserve focus/scroll expectations.
- Internationalization:
  - Labels, bucket descriptions, and empty-state messaging externalized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/support_tile/informal.md`.

## 6. Functional Requirements
| ID | Description | Priority | Owner |
|---|---|---|---|
| FR-001 | Render Student Support tile with donut chart and bucket legend using projected support-category data. | P0 | UI |
| FR-002 | Compute bucket assignments (struggling/on-track/excelling/not-enough-information) in non-UI projection code from progress-proficiency and student info oracles. | P0 | Data |
| FR-003 | Ensure each student belongs to exactly one support bucket or not-enough-information category per deterministic rule ordering. | P0 | Data |
| FR-004 | Default selected bucket is `struggling`; selecting legend item or donut segment updates highlighted segment and student list. | P0 | UI |
| FR-005 | Student list supports search, 20-item initial page, `Load more` pagination, and no-scroll-reset behavior on load more. | P0 | UI |
| FR-006 | Active/inactive filtering uses projection-level inactivity derivation from `last_interaction_at` (7-day rule for this feature). | P0 | Data/UI |
| FR-007 | Row and master selection checkboxes support selecting visible students only; `Email` action enables only when selection is non-empty. | P0 | UI |
| FR-008 | Clicking `Email` opens email modal with selected recipients pre-populated. | P1 | UI |
| FR-009 | If no student activity exists, tile shows informational no-data state instead of donut/list. | P0 | UI |

## 7. Acceptance Criteria
- AC-001 (FR-001) — Given tile loads with support projection data, when rendered, then donut and legend display bucket percentages/counts.
- AC-002 (FR-002, FR-003) — Given student progress/proficiency inputs, when projection executes, then each student is assigned to exactly one valid category using deterministic rule precedence.
- AC-003 (FR-004) — Given default load, when tile first renders, then struggling bucket is selected and list shows struggling students.
- AC-004 (FR-004) — Given instructor clicks donut segment or legend item, when selection changes, then list updates to corresponding category and segment highlight matches.
- AC-005 (FR-005) — Given >20 students in selected list, when instructor clicks `Load more`, then next page appends without duplicate rows or scroll reset.
- AC-006 (FR-006) — Given 7-day inactivity rule, when active/inactive filter toggles, then list updates and counts match projection-derived inactivity flags.
- AC-007 (FR-007, FR-008) — Given selection changes, when no rows selected then Email is disabled; when rows selected and Email clicked then modal opens with those recipients.
- AC-008 (FR-009) — Given no activity data exists, when tile renders, then informational state appears and donut/list are not shown.

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Rapid bucket/filter/search toggling never produces stale or cross-category list rows.
- Security & Privacy:
  - Student list visibility restricted to authorized instructor contexts.
  - PII shown only as needed for instructor workflow.
- Compliance:
  - WCAG 2.1 AA keyboard and screen-reader compatibility for chart/list controls.
- Observability:
  - Minimal instrumentation: projection failure count and email-open action count.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - Non-UI support projection module(s).
  - UI component tree for donut, legend, list, and selection controls.
- APIs / Contracts:
  - Input contracts: progress-proficiency tuples, student roster info with `last_interaction_at`, selected bucket/filter/search/pagination state.
  - Output contracts: bucket summary metrics and paged student rows with inactivity flags.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | View/filter/select students and open email modal | Section-scoped access |
| Student | None | Not available in student view |
| Admin | Allowed in authorized contexts | Same section scoping applies |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Instructor-role access only.
- GenAI (if applicable):
  - Integrates with email modal entrypoint only; no direct AI generation in this tile.
- External services:
  - None directly.
- Caching/Perf:
  - Tile consumes oracle outputs and internal projection; no ad-hoc direct queries in UI.
- Multi-tenancy:
  - All rows and metrics limited to current section and scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Student support tile render success rate.
  - Instructor interaction rate with bucket filters and email-open action.
- Events:
  - `support_tile.bucket_selected`
  - `support_tile.email_opened`

## 13. Risks & Mitigations
- Complex category logic drift -> centralize projection rules and add exhaustive unit tests for boundary conditions.
- UI state desync between donut and list -> single source-of-truth selected bucket state.
- Large rosters impacting list responsiveness -> incremental paging and scoped filtering with efficient projection structures.

## 14. Open Questions & Assumptions
- Assumptions:
  - Inactivity is fixed at 7 days in this feature and becomes configurable in `customize_parameters`.
  - Vega-Lite is acceptable for donut interaction requirements in this story.
- Open Questions:
  - None.

## 15. Timeline & Milestones (Draft)
- Implement support projection and deterministic bucketing.
- Implement donut + legend interactions.
- Implement list search/filter/pagination/selection.
- Integrate email modal launch and complete QA.

## 16. QA Plan
- Automated:
  - Unit tests for bucket/inactivity projection rules.
  - Component tests for donut-legend-list interaction sync.
  - Tests for load-more behavior, selection constraints, and email button enablement.
- Manual:
  - Validate no-data state and default struggling selection.
  - Validate keyboard navigation across chart/list controls.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
