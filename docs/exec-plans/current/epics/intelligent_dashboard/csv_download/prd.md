# Intelligent Dashboard CSV Download — PRD

## 1. Overview
Feature Name: Intelligent Dashboard CSV Download

Summary: Add instructor-initiated export of current dashboard data as a ZIP bundle of CSV files, providing both accessibility-alternative data access and offline analysis utility. Export output must match the dashboard’s current scope and active tile parameter state at download time.

Links: `docs/epics/intelligent_dashboard/csv_download/informal.md`, `docs/epics/intelligent_dashboard/summary_tile/prd.md`, `docs/epics/intelligent_dashboard/support_tile/prd.md`, `https://eliterate.atlassian.net/browse/MER-5266`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Instructors cannot easily export dashboard data for external review or accessibility-driven non-visual consumption.
  - A centralized export approach risks diverging from tile-specific projection logic.
  - Scope and parameter fidelity can be lost if export does not bind to current UI state.
- Affected users/roles:
  - Instructors requiring CSV output for analysis/accessibility.
- Why now:
  - Accessibility requirements and instructor workflows require downloadable non-visual equivalents.

## 3. Goals & Non-Goals
- Goals:
  - Provide `Download dashboard data (CSV)` action that returns ZIP of applicable CSV files.
  - Ensure exported data reflects current scope and active parameter settings.
  - Use tile-driven dataset-provider contract for export assembly.
  - Implement synchronous in-memory CSV/ZIP generation for this iteration.
- Non-Goals:
  - Async long-running export job pipeline in v1.
  - Exporting data outside current dashboard scope.
  - Placeholder files for unavailable datasets.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Instructor in section dashboard context.
- Use Cases:
  - Instructor filtered to Module 1 exports CSVs containing only Module 1-relevant values.
  - Instructor with customized support/progress settings exports data that matches those settings.
  - Instructor uses CSV bundle as accessible alternative to visual dashboard elements.

## 5. UX / UI Requirements
- Key Screens/States:
  - Download button in dashboard UI.
  - Loading/disabled state while synchronous export assembles.
  - Browser download trigger for ZIP file.
- Navigation & Entry Points:
  - Entry via dashboard-level download button.
- Accessibility:
  - Button keyboard-accessible with descriptive label.
  - Loading state communicated to assistive technologies.
- Internationalization:
  - Button and status text externalized.
- Screenshots/Mocks:
  - Refer to Jira/Figma assets linked from `docs/epics/intelligent_dashboard/csv_download/informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: No load or performance testing requirements for this phase.
- Reliability:
  - Export failures return clear error feedback and do not produce corrupt partial downloads.
- Security & Privacy:
  - Export accessible only to authorized instructors.
  - CSV contents include only section-scoped permitted data.
- Compliance:
  - Feature satisfies text-based alternative requirement for dashboard visualizations (WCAG-aligned intent).
- Observability:
  - Minimal instrumentation: export success/failure count and duration metric.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - None.
- Context Boundaries:
  - Tile dataset-provider interfaces (tile/domain boundary).
  - Non-UI services: `CSVRenderer`, `ZipAssembler`.
  - LiveView orchestration for button event and download response.
- APIs / Contracts:
  - `tile_export_datasets(tile_state) -> [%{file_name: String.t(), rows: list(map), columns: [String.t()] | nil}]`
  - `render_csv(dataset) -> {:ok, binary} | {:error, reason}`
  - `build_zip(csv_files, zip_name) -> {:ok, binary} | {:error, reason}`
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Instructor | Trigger dashboard CSV ZIP download | Section-scoped authorization |
| Student | None | Not exposed |
| Admin | Allowed in authorized contexts | Same scoping rules |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - Existing instructor-role authorization applies.
- GenAI (if applicable):
  - N/A.
- External services:
  - None.
- Caching/Perf:
  - Reuse already available tile/oracle state where possible; avoid new heavy queries during export.
- Multi-tenancy:
  - Export payload constrained to current section and selected scope.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this feature

## 12. Analytics & Success Metrics
- KPIs:
  - Export success rate.
  - Median export generation time.
- Events:
  - `dashboard_export.started`
  - `dashboard_export.completed`
  - `dashboard_export.failed`

## 13. Risks & Mitigations
- Scope/settings mismatch risk -> bind export inputs directly to live UI state snapshot at click time.
- Format drift between tile UI and CSV output -> tile-owned dataset providers using same projected state source.
- Synchronous latency spikes -> loading feedback now; explicit criteria for later async migration if thresholds exceeded.

## 14. Open Questions & Assumptions
- Assumptions:
  - Dashboard data volumes are bounded enough for synchronous in-memory generation in v1.
  - Required CSV schema details in ticket remain authoritative for initial output columns.
- Open Questions:
  - Should failed exports emit user-visible retry affordance in same interaction surface or global banner only?

## 15. Timeline & Milestones (Draft)
- Implement tile export contract and dataset providers.
- Implement CSV renderer and ZIP assembler services.
- Wire LiveView synchronous orchestration + download response.
- Complete accessibility and export correctness QA.

## 16. QA Plan
- Automated:
  - Unit tests for CSV rendering and zip assembly.
  - Contract tests for tile dataset-provider outputs.
  - Integration tests validating scope/settings fidelity in exported values.
- Manual:
  - Validate downloaded ZIP content and filenames.
  - Accessibility checks for button and loading state announcements.
- Performance Verification: Not required for this phase.

## 17. Definition of Done
- [ ] All FRs mapped to ACs
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Rollout/rollback posture documented (or explicitly not required)
