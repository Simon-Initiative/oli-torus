# OLAP Analytics (ClickHouse) - Delivery Plan

Scope and guardrails reference the approved PRD (`docs/features/olap-analytics/prd.md`) and FDD (`docs/features/olap-analytics/fdd.md`). The plan reflects the implementation delivered on the `olap-investigation` branch and marks completed work.

- Scope Summary: Build a ClickHouse-backed OLAP analytics pipeline, admin backfill tooling (manual and inventory-based), and an instructor analytics dashboard with curated and custom queries, plus project-level analytics dashboards scoped to `project_id`.
- Non-Functional Guardrails: p50 analytics query <= 2s and p95 <= 8s for section-level queries under 1M events and project-level queries under 5M events; backfills are retryable and resumable; admin and instructor access is gated and audited.

## Clarifications & Default Assumptions

- ClickHouse is provisioned and reachable via HTTP and native ports.
- xAPI JSONL objects are stored in S3 with consistent schemas.
- Inventory manifests follow AWS S3 Inventory conventions and are readable via configured credentials.

## Phase 1: ClickHouse Schema and Runtime Configuration

- Goal: Establish ClickHouse storage, migrations, and local dev configuration.
- Tasks
  - [x] Add ClickHouse `raw_events` migration and indexes in `priv/clickhouse/migrations`.
  - [x] Add ClickHouse migration tooling (`mix clickhouse.migrate`) and runtime tasks.
  - [x] Add ClickHouse config defaults in `config/runtime.exs` and `config/dev.exs`.
  - [x] Add Docker Compose ClickHouse service and dev users file.
- Definition of Done: ClickHouse can be created, migrated, and queried locally via mix tasks and docker compose.

## Phase 2: xAPI Ingestion Pipeline

- Goal: Support ingestion into ClickHouse via S3 -> Lambda ETL and dev-mode direct uploader.
- Tasks
  - [x] Add Lambda ETL package (`cloud/xapi-etl-processor`) for JSONL -> Parquet -> ClickHouse.
  - [x] Add ClickHouse direct uploader for dev/testing (`Oli.Analytics.XAPI.ClickHouseUploader`).
  - [x] Wire uploader selection via `XAPI_ETL_MODE` in runtime config.
  - [x] Document Lambda packaging and deployment steps in README.
- Definition of Done: JSONL xAPI bundles can reach ClickHouse through ETL or direct uploader.

## Phase 3: ClickHouse Analytics API and Admin Health Console

- Goal: Provide ClickHouse health checks and operational metrics in admin UI.
- Tasks
  - [x] Implement `Oli.Analytics.ClickhouseAnalytics` (health check, sample queries, query execution, status/progress).
  - [x] Implement health checks and operational metrics.
  - [x] Add admin dashboard LiveView `/admin/clickhouse` with health check and operational metrics.
  - [x] Gate admin analytics access behind global `clickhouse-olap` feature flag.
  - [x] Gate admin bulk ingest access behind `clickhouse-olap-bulk-ingest` feature flag.
- Definition of Done: Admins can validate ClickHouse health and review operational metrics from the UI without executing arbitrary queries.

## Phase 4: Manual Backfill Runs (S3 Pattern)

- Goal: Enable admins to backfill xAPI data from S3 patterns with dry-run support.
- Tasks
  - [x] Add `clickhouse_backfill_runs` schema and migration.
  - [x] Implement `Oli.Analytics.Backfill` context for scheduling and status transitions.
  - [x] Implement backfill query builder and Oban worker execution.
  - [x] Add admin UI controls for scheduling and monitoring manual backfills.
- Definition of Done: Admins can schedule backfills and track metrics/errors per run.

## Phase 5: Inventory-Based Backfills and Chunk Logs

- Goal: Support large historical backfills via S3 Inventory manifests and stream progress.
- Tasks
  - [x] Add inventory run, batch, and chunk log schemas + migrations.
  - [x] Implement inventory orchestrator and batch worker with pause/resume/cancel support.
  - [x] Persist per-chunk metrics and broadcast updates via PubSub.
  - [x] Add Phoenix channel `clickhouse_chunk_logs:*` for live chunk log streaming.
  - [x] Add ChunkLogsViewer hook for infinite scrolling and live updates.
  - [x] Add admin UI for inventory runs, batches, and chunk logs.
- Definition of Done: Inventory backfills can be scheduled, monitored, paused/resumed, and debugged via chunk logs.

## Phase 6: Instructor Analytics Dashboard

- Goal: Provide a section-scoped analytics experience backed by ClickHouse.
- Tasks
  - [x] Add instructor analytics tab and route wiring in Instructor Dashboard.
  - [x] Implement SectionAnalytics component with category queries and VegaLite chart specs.
  - [x] Add engagement filters (date range, max pages) and title enrichment.
- [x] Add custom analytics editors (SQL + Vega) with Monaco integration.
- [x] Configure a dedicated ClickHouse read-only user for custom analytics queries.
- [x] Enforce server-side SQL validation: allow only SELECT and require section_id/project_id predicate or CTE filter.
- [x] Gate access with `instructor_dashboard_analytics` scoped feature flag.
- Definition of Done: Instructors can view analytics for enabled sections and run custom queries.

## Phase 7: Project-Level Analytics Dashboard

- Goal: Add project-scoped analytics using `project_id` with dedicated visualizations and performance guardrails.
- Tasks
  - [ ] Add ClickHouse index on `project_id` in `raw_events` migration and verify it in ClickHouse.
  - [ ] Define project-scoped analytics queries (engagement, performance, activity attempts) and VegaLite specs.
  - [ ] Implement project analytics LiveView (route, layout, loading/error states).
  - [ ] Add custom analytics controls scoped to `project_id` (SQL editor + Vega spec).
  - [ ] Add project-level feature flag `project_dashboard_analytics` and wire access checks.
  - [ ] Add telemetry for project analytics query execution and load state.
- Definition of Done: Project analytics dashboard loads for enabled projects with acceptable query performance and clear empty/error states.

## Phase 8: Tests and QA

- Goal: Validate backfills, analytics queries, and UI behavior.
- Tasks
  - [x] Add unit tests for backfill query builder and run transitions.
  - [x] Add integration tests for inventory backfills and ClickHouse analytics functions.
  - [x] Add LiveView tests for admin backfill UI and instructor analytics tab.
  - [ ] Add LiveView tests for project analytics dashboard and feature gating.
  - [ ] Add query tests for project analytics datasets and `project_id` index usage.
  - [x] Validate ClickHouse stub usage for tests.
- Definition of Done: New test suites pass and cover core success/failure paths.

## Phase 9: Ops, Rollout, and Observability

- Goal: Make rollout safe and operations-ready.
- Tasks
  - [x] Document Lambda ETL packaging and AWS setup steps.
  - [ ] Add AppSignal dashboards/alerts for backfill duration, failure rates, and query latency.
  - [ ] Wire `ScopedFeatureFlags` staged rollout (internal_only -> five_percent -> fifty_percent -> full) for instructor analytics access.
  - [ ] Wire staged rollout for `project_dashboard_analytics` (internal_only -> five_percent -> fifty_percent -> full).
  - [ ] Publish admin runbook for backfill operations and troubleshooting.
- Definition of Done: Rollout staged, metrics visible, and operational playbooks published.

## Phase Gate Summary

- Gate A (post Phase 2): ClickHouse schema and ingestion pipeline operational.
- Gate B (post Phase 5): Backfill tooling complete and stable.
- Gate C (post Phase 6): Instructor analytics ready behind feature flags.
- Gate D (post Phase 7): Project analytics ready behind feature flags.
- Gate E (post Phase 9): Operational readiness and rollout complete.
