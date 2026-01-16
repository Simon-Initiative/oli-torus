# OLAP Analytics (ClickHouse) - PRD

## 1. Overview

Feature Name: OLAP Analytics (ClickHouse)

Summary: Provide a production-grade OLAP analytics pipeline that stores xAPI events in ClickHouse and powers instructor analytics dashboards. Administrators can backfill historical data from S3 (direct patterns or S3 Inventory manifests), monitor ingestion progress, and validate system health. Instructors gain analytics tabs with curated and custom visualizations for section-level and project-level insights.

## 2. Background & Problem Statement

Torus currently emits xAPI statements and supports raw analytics exports, but querying large datasets for insights is slow and operationally heavy. Instructors lack a modern, interactive analytics experience for course sections. Administrators have limited tooling to backfill or validate analytics data across large volumes of xAPI files stored in S3.

This feature introduces a ClickHouse-based OLAP layer to ingest, store, and query xAPI events at scale. It adds admin tooling for data ingestion and instructor-facing analytics dashboards that leverage the new data store. The work is needed to support higher-scale analytics, reduce reliance on batch exports, and enable near real-time insights for instructors.

## 3. Goals & Non-Goals

- Goals:
  - Store unified xAPI events in a ClickHouse `raw_events` table for fast OLAP queries.
  - Provide automated ingestion via S3 -> SQS -> Lambda ETL into ClickHouse, with a dev-mode direct uploader.
  - Allow administrators to run ClickHouse health checks, view operational health metrics, and schedule bulk backfills.
  - Support both direct S3-pattern backfills and S3 Inventory manifest driven backfills with pause/resume/cancel controls.
  - Provide an instructor analytics dashboard with curated categories (video, assessment, engagement, performance, cross-event) and custom SQL + Vega visualizations.
  - Add a project-level analytics dashboard scoped to `project_id`, with dedicated visualizations and query paths.
  - Gate access with feature flags and section-level rollouts.
- Non-Goals:
  - Replacing existing summary analytics pipeline or removing raw analytics exports.
  - Building a student-facing analytics experience.
  - Automatic xAPI data cleaning or semantic enrichment beyond the existing statement payloads.
  - A fully managed ClickHouse cluster provisioning workflow.
  - Cross-project or institution-wide analytics aggregation in this phase.
  - Automatic backfill scheduling for new sections; backfills are triggered manually by admins and ongoing data arrives via Lambda ETL.

## 4. Users & Use Cases

- Primary Users / Roles:
  - Torus Administrators (system-level) managing data ingestion and backfills.
  - Instructors viewing section analytics in the instructor dashboard.
  - Internal data/ops staff validating analytics coverage.
- Use Cases:
  - Admin verifies ClickHouse connectivity and reviews operational health metrics.
  - Admin schedules a backfill from a specific S3 pattern (dry run or insert) and monitors status, metrics, and errors.
  - Admin schedules an inventory-based backfill, pauses or resumes processing, and reviews per-chunk logs.
  - Instructor opens the analytics tab for a section and explores video engagement, assessment performance, and page engagement.
  - Instructor runs a custom SQL query against ClickHouse and supplies a Vega spec to visualize results.
  - Project author/admin opens a project analytics dashboard to view aggregated engagement and performance across the project.

## 5. UX / UI Requirements

- Key Screens/States:
  - Admin ClickHouse Analytics dashboard (health status and operational metrics).
  - Admin ClickHouse Backfill console (create run, list runs, view run metrics, pause/resume/cancel).
  - Inventory batch view with chunk logs (live streaming updates).
  - Instructor Dashboard -> Insights -> Analytics tab (category cards, charts, empty/error states).
  - Custom analytics view with SQL editor and Vega spec editor.
  - Project analytics LiveView dashboard with project-scoped filters and charts.
- Navigation & Entry Points:
  - Admin: `/admin/clickhouse` and `/admin/clickhouse/backfill` (visible only when feature enabled).
  - Instructor: `/sections/:slug/instructor_dashboard/insights/analytics` (section scoped).
  - Project: `/projects/:slug/analytics` (project scoped).
- Accessibility:
  - All controls are keyboard navigable; buttons and inputs have labels and clear focus states.
  - Data visualizations provide textual fallback (raw data panel) for screen readers.
- Internationalization:
  - UI strings are externalized and respect locale; date filters and formats use locale-aware rendering.
- Screenshots/Mocks:
  - _None provided (retroactive spec)._

## 6. Functional Requirements

| ID     | Description                                                                                                          | Priority | Owner              |
| ------ | -------------------------------------------------------------------------------------------------------------------- | -------- | ------------------ |
| FR-001 | Create and maintain a ClickHouse `raw_events` table that stores unified xAPI event data.                             | P0       | Analytics Platform |
| FR-002 | Provide ClickHouse migration tooling and environment configuration (dev + runtime).                                  | P0       | Platform           |
| FR-003 | Ingest xAPI JSONL objects to ClickHouse via S3 -> SQS -> Lambda ETL, with a direct ClickHouse uploader for dev mode. | P0       | Analytics Platform |
| FR-004 | Provide an admin UI for ClickHouse health checks and operational metrics.                                             | P0       | Admin UX           |
| FR-005 | Provide manual backfill runs from S3 patterns with dry-run and insert modes, including run status and metrics.       | P0       | Analytics Platform |
| FR-006 | Provide inventory-based backfills driven by S3 Inventory manifests, with batch scheduling and concurrency controls.  | P0       | Analytics Platform |
| FR-007 | Record per-run and per-batch metrics, and expose per-chunk log streaming for inventory backfills.                    | P1       | Analytics Platform |
| FR-008 | Expose instructor analytics dashboard categories backed by ClickHouse queries and Vega visualizations.               | P0       | Delivery UX        |
| FR-009 | Support custom analytics: read-only SQL editor + Vega spec input, rendering custom charts on demand with enforced read-only validation and scope filters. | P1       | Delivery UX        |
| FR-010 | Gate admin tooling behind a global feature flag and instructor analytics behind a section-scoped feature flag.       | P0       | Platform           |
| FR-011 | Provide analytics load state messaging (not loaded, loading, error) for sections without ClickHouse data.            | P1       | Delivery UX        |
| FR-012 | Add project-level analytics dashboard backed by ClickHouse queries scoped to `project_id`.                           | P1       | Authoring UX       |
| FR-013 | Add ClickHouse index on `project_id` to support project-level queries.                                                | P1       | Analytics Platform |

## 7. Acceptance Criteria

- AC-001 (FR-001, FR-002) Given ClickHouse is configured, when migrations run, then `raw_events` exists with required columns and indexes.
- AC-002 (FR-003) Given xAPI JSONL files are uploaded to S3, when the Lambda ETL runs, then ClickHouse receives Parquet inserts with valid rows.
- AC-003 (FR-004) Given an admin accesses `/admin/clickhouse`, when they run a health check, then the UI displays success or error feedback.
- AC-004 (FR-005) Given a valid S3 pattern, when an admin schedules a backfill, then a run is created, queued, and completion metrics are captured.
- AC-005 (FR-006, FR-007) Given an S3 inventory manifest, when a backfill run is scheduled, then batches are created, processed, and chunk logs stream to the UI.
- AC-006 (FR-008) Given a section with ClickHouse data and the feature enabled, when an instructor opens analytics, then charts render for at least one category.
- AC-007 (FR-009) Given a read-only custom SQL query and Vega spec, when submitted, then results are visualized or a descriptive validation error is shown; any non-SELECT or unscoped query is rejected.
- AC-008 (FR-010, FR-011) Given feature flags are disabled or data is missing, then the UI blocks access or shows a not-loaded message.
- AC-009 (FR-012, FR-013) Given a project with ClickHouse data, when a user opens the project analytics dashboard, then charts load using `project_id` scoped queries and complete within performance targets.

## 8. Non-Functional Requirements

- Performance & Scale: analytics category queries should return in p50 <= 2s and p95 <= 8s for sections with up to 1M events; project-level queries should meet the same targets for up to 5M events; custom queries should enforce timeouts and reasonable row limits.
- Reliability: backfill jobs should retry on transient failures, record errors, and avoid partial state corruption. Inventory batches must be idempotent and restartable.
- Security & Privacy: only authenticated admins can access backfill tooling; instructor analytics must be scoped to the current section. Custom SQL is read-only via DB user restrictions plus server-side validation that only allows SELECT and requires `section_id` or `project_id` scope predicates. xAPI user identifiers are treated as PII and must not be logged in plaintext.
- Compliance: audit backfill actions and feature flag changes; maintain WCAG AA and data retention policies.
- Observability: track ClickHouse query execution time, backfill duration, rows/bytes ingested, and error rates. Surface metrics in admin UI and logs.

## 9. Data Model & APIs

- Ecto Schemas & Migrations:
  - `clickhouse_backfill_runs` for manual S3 backfills.
  - `clickhouse_inventory_runs`, `clickhouse_inventory_batches`, `clickhouse_inventory_chunk_logs` for inventory-driven backfills.
  - ClickHouse migration `raw_events` table (ReplacingMergeTree) with indexes on `section_id`, `project_id`, `event_type`, `user_id`.
- Context Boundaries:
  - `Oli.Analytics.ClickhouseAnalytics` for query execution and health checks.
  - `Oli.Analytics.Backfill` for run lifecycle and scheduling.
  - `Oli.Analytics.Backfill.Inventory` for inventory batch orchestration.
  - `Oli.Analytics.XAPI` pipeline modules for ingestion (S3/Lambda or direct ClickHouse).
- APIs / Contracts:
  - Admin LiveViews: `OliWeb.Admin.ClickHouseAnalyticsView`, `OliWeb.Admin.ClickhouseBackfillLive`.
  - Channel: `clickhouse_chunk_logs:*` for live chunk log streaming.
  - Instructor analytics component: `OliWeb.Components.Delivery.InstructorDashboard.SectionAnalytics`.
  - Project analytics LiveView: `OliWeb.ProjectAnalyticsLive` (name TBD).
- Permissions Matrix:

| Role       | Run Backfill | View Admin Analytics | View Instructor Analytics | Run Custom SQL       |
| ---------- | ------------ | -------------------- | ------------------------- | -------------------- |
| Admin      | Yes          | Yes                  | Yes (if enabled)          | Yes                  |
| Instructor | No           | No                   | Yes (section-scoped)      | Yes (section-scoped) |
| Author     | No           | No                   | No                        | No                   |
| Student    | No           | No                   | No                        | No                   |
| Project Admin | No        | No                   | Yes (project-scoped)         | Yes (project-scoped)         |

## 10. Integrations & Platform Considerations

- LTI 1.3: Instructor analytics is scoped to the section resolved from LTI context.
- AWS: S3 stores xAPI JSONL; SQS triggers Lambda; Lambda inserts into ClickHouse.
- ClickHouse: HTTP interface for inserts and queries; native port for migration tooling.
- Caching/Perf: SectionResourceDepot used for page title mapping in engagement analytics; no additional caching layer introduced.
- Multi-Tenancy: Analytics queries filter by `section_id` or `project_id` and use scoped feature gating.

## 11. Feature Flagging, Rollout & Migration

- Flagging:
  - Global: `clickhouse-olap` (system feature flag) gates ClickHouse analytics across the system, including admin dashboards and section analytics access.
  - Global: `clickhouse-olap-bulk-ingest` gates admin ClickHouse bulk ingest/backfill tooling.
  - Scoped: `instructor_dashboard_analytics` gates instructor analytics per section.
  - Scoped: `project_dashboard_analytics` gates project analytics per project.
- Rollout Plan (scoped flag stages):
  - `internal_only`: enable for internal test sections only; verify query correctness and load state behavior.
  - `five_percent`: enable for a randomized 5% of sections; watch query latency and error rates.
  - `fifty_percent`: expand to 50% of sections; monitor ClickHouse load and backfill backlog.
  - `full`: enable for all sections once KPIs are stable.
  - Rollback: disable scoped rollout and/or global `clickhouse-olap`/`clickhouse-olap-bulk-ingest` to hide analytics or bulk ingest tooling.
- Data Migrations:
  - Postgres migrations create backfill tracking tables.
  - ClickHouse migrations create `raw_events`.
- Backfills:
  - Manual S3-pattern backfills and inventory-driven backfills are the primary data migration paths.

## 12. Analytics & Success Metrics

- North Star / KPIs:
  - % of active sections with ClickHouse analytics loaded.
  - % of active projects with project-level analytics enabled.
  - p95 analytics query latency within target thresholds.
  - Backfill completion rate and mean time to completion.
- Event Spec (internal):
  - `clickhouse.backfill.run.started` / `completed` / `failed` with run_id, rows, bytes.
  - `clickhouse.analytics.query.executed` with query_type, duration_ms, section_id.

## 13. Risks & Mitigations

- ClickHouse performance degradation under heavy backfill load -> throttle batch concurrency and size via config.
- Project-level analytics queries may be heavier -> add `project_id` index and enforce query limits.
- Data quality issues from malformed JSONL -> per-batch error tracking, dry run mode, and resumable batches.
- Instructor queries timing out -> enforce query limits and show descriptive errors.
- Security risk from custom SQL -> restrict access to instructors, enforce read-only, and scope queries to section_id or project_id.

## 14. Open Questions & Assumptions

- Assumptions:
  - ClickHouse is available and managed separately from Torus core services.
  - xAPI JSONL files are consistently structured and accessible via S3 credentials.
  - Backfill runs are initiated manually by admins; ongoing data arrives via Lambda ETL.
- Open Questions:
  - What are the long-term retention policies for `raw_events` in ClickHouse?
  - What are the required roles/permissions for project-level analytics (author vs admin vs instructor)?
