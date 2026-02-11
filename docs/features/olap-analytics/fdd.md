# OLAP Analytics (ClickHouse) - Functional Design Document

## 1. Executive Summary

The OLAP Analytics feature introduces a ClickHouse-backed analytics pipeline that stores unified xAPI events in a `raw_events` table and powers instructor analytics dashboards, including project-level analytics. Ingestion supports two paths: (1) S3 -> SQS -> Lambda ETL that converts JSONL to Parquet and inserts into ClickHouse, and (2) a dev-mode direct ClickHouse uploader for rapid iteration. Administrators gain an operational console to validate ClickHouse health, review operational metrics, and orchestrate bulk backfills. Two backfill modes are supported: direct S3 pattern ingestion (manual runs) and S3 Inventory manifest ingestion (batch-based runs with pause/resume/cancel). Inventory runs capture per-batch and per-chunk metrics that stream live to the UI. Instructors receive a new analytics tab with curated categories and custom SQL + Vega visualizations, all scoped to a single section. Project analytics reuse the same ClickHouse store but pivot queries on `project_id` and provide a dedicated LiveView dashboard. The design favors idempotent ingestion, clear run tracking, and low operational overhead using Oban workers and ClickHouse HTTP interfaces. Performance targets assume section-level query workloads and moderate backfill concurrency, with heavier project-level queries addressed via indexing and limits. Risks include data quality issues from inconsistent xAPI payloads and heavy custom queries; mitigations include dry-run mode, batch chunking, and UI guardrails.

## 2. Requirements & Assumptions

- Functional Requirements
  - Store xAPI events in a unified ClickHouse `raw_events` table.
  - Provide ClickHouse migration tooling and configuration in runtime/dev environments.
  - Ingest xAPI data via Lambda ETL and a dev-mode direct uploader.
  - Provide admin tools for health checks, sample queries, and backfill orchestration.
  - Provide instructor analytics with curated categories and custom analytics.
  - Provide project analytics with project-scoped queries and dashboards.
  - Add a ClickHouse index on `project_id` to support project-level query performance.
- Non-Functional Requirements
  - p50 query <= 2s and p95 <= 8s for section-level analytics under 1M events.
  - p50 query <= 2s and p95 <= 8s for project-level analytics under 5M events.
  - Backfill jobs must be retryable and resumable, with no partial run corruption.
  - Feature access must be scoped (admin for tooling, section-scoped for instructors).
- Explicit Assumptions
  - ClickHouse is provisioned and accessible via HTTP and native ports.
  - S3 inventory manifests are available and follow AWS inventory formats.
  - xAPI JSONL payloads are well-formed and contain required extensions.
  - Backfill runs are initiated manually by admins; ongoing data arrives via Lambda ETL.

## 3. Torus Context Summary

- Analytics pipeline uses `Oli.Analytics.Summary` to emit xAPI statement bundles.
- xAPI upload pipeline is configured via `:xapi_upload_pipeline` with pluggable uploader modules.
- Scoped feature flags are defined in `Oli.ScopedFeatureFlags.DefinedFeatures` and checked via `ScopedFeatureFlags.enabled?/2`.
- Oban queues already handle long-running background tasks; new queues are added for ClickHouse backfill and inventory workers.
- LiveView is used for admin tooling and instructor dashboard experiences.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

- **ClickHouse Storage**: `raw_events` table in ClickHouse stores unified event columns for all xAPI event types.
- **ClickHouse Migrations**: `Mix.Tasks.Clickhouse.Migrate` and `Oli.ClickHouse.Tasks` wrap `goose` to manage ClickHouse migrations.
- **xAPI Ingestion**:
  - **S3 Uploader** (`Oli.Analytics.XAPI.S3Uploader`): writes JSONL bundles to S3.
  - **Lambda ETL** (`cloud/xapi-etl-processor/lambda_function.py`): converts JSONL to Parquet and inserts into ClickHouse.
  - **Direct ClickHouse Uploader** (`Oli.Analytics.XAPI.ClickHouseUploader`): dev-mode parser and inserter using HTTP.
- **ClickHouse Analytics API** (`Oli.Analytics.ClickhouseAnalytics`): executes read-only analytics queries, health checks, query status/progress, and exposes health metadata and table metrics.
- **Manual Backfill**:
  - **Backfill Runs** (`Oli.Analytics.Backfill.BackfillRun`) stored in Postgres.
  - **Backfill Worker** (`Oli.Analytics.Backfill.Worker`) executes insert or dry-run queries using the ClickHouse `s3` table function.
- **Inventory Backfill**:
  - **Inventory Runs/Batches** (`Oli.Analytics.Backfill.InventoryRun`, `InventoryBatch`) store manifest metadata, status, and metrics.
  - **Orchestrator Worker** reads S3 inventory manifest and enqueues batch jobs.
  - **Batch Worker** processes batches in chunks and records chunk logs.
- **Chunk Log Streaming Observability**:
  - **InventoryChunkLog** records per-chunk metrics in Postgres.
  - **ClickhouseChunkLogsChannel** streams logs to admin UI.
  - **ChunkLogsViewer Hook** renders logs with infinite scroll and live mode.
- **Instructor Analytics**:
  - **InstructorDashboardLive** loads section analytics state and data.
  - **SectionAnalytics Component** builds queries and VegaLite specs for charts.
- **Project Analytics**:
  - **ProjectAnalyticsLive** (name TBD) provides project-scoped charts and filters.
  - **ProjectAnalytics Component** (name TBD) issues `project_id` scoped queries and renders VegaLite charts.

### 4.2 State & Message Flow

1. xAPI statement bundles are produced by summary pipeline.
2. Upload pipeline writes JSONL to S3 (default) or directly to ClickHouse (dev/per-instance configuration).
3. Lambda ETL consumes SQS events, converts JSONL to Parquet, and inserts into ClickHouse `raw_events`.
4. Admin schedules a backfill run (manual S3 pattern or inventory run); a Postgres run record is created and an Oban job enqueued.
5. Backfill workers issue ClickHouse `INSERT ... SELECT` queries using the `s3(...)` table function.
6. Inventory batch workers chunk through manifest entries, ingest chunks, and persist chunk log metrics.
7. Chunk log updates are broadcast over PubSub and streamed to connected admin clients.
8. Instructor analytics tab queries ClickHouse for section data and renders charts or custom visualizations.
9. Project analytics dashboard queries ClickHouse for project data and renders project-scoped charts.

### 4.3 Supervision & Lifecycle

- Oban queues:
  - `:clickhouse_backfill` for manual backfills.
  - `:clickhouse_inventory` for manifest orchestration.
  - `:clickhouse_inventory_batches` for batch ingestion.
- Workers are retried (max_attempts) and use unique constraints to prevent duplicate processing.
- Manual runs and inventory runs update status transitions with timestamps.
- Chunk logs are appended with upsert semantics and can be paged or streamed.

### 4.4 Alternatives Considered

- Using a single Postgres data store for analytics was rejected due to scale limitations.
- A fully managed streaming platform (e.g., Kafka) was not selected for initial scope; S3 + Lambda is simpler to operate.
- Only supporting S3 pattern backfills was insufficient for large historical datasets; inventory-based backfills provide scale.

## 5. Interfaces

### 5.1 HTTP/JSON APIs

- ClickHouse HTTP interface used for queries and inserts.
- Lambda inserts use `INSERT ... FORMAT Parquet` with optional settings.

### 5.2 LiveView

- Admin:
  - `/admin/clickhouse` -> `OliWeb.Admin.ClickHouseAnalyticsView` (health status + operational metrics)
  - `/admin/clickhouse/backfill` -> `OliWeb.Admin.ClickhouseBackfillLive`
- Instructor:
  - `/sections/:slug/instructor_dashboard/insights/analytics` -> instructor dashboard analytics tab
- Project:
  - `/projects/:slug/analytics` -> project analytics dashboard
- Channel:
  - `clickhouse_chunk_logs:*` -> live chunk log streaming

### 5.3 Processes

- Oban workers for backfill orchestration and ingestion.
- PubSub broadcasts for chunk log updates and backfill state updates.

## 6. Data Model & Storage

### 6.1 Ecto Schemas

- `clickhouse_backfill_runs`
  - target_table, s3_pattern, format, status, options, clickhouse_settings, dry_run
  - metrics: rows/bytes read and written, duration, error
- `clickhouse_inventory_runs`
  - inventory_date, inventory_prefix, manifest details, status, counters, metrics
- `clickhouse_inventory_batches`
  - run_id, sequence, parquet_key, status, metrics, attempts, timestamps
- `clickhouse_inventory_chunk_logs`
  - batch_id, chunk_index, metrics
- ClickHouse `raw_events` table (ReplacingMergeTree)
  - unified event columns and metadata (event_hash, source_file, source_line)

### 6.2 Query Performance

- Indexes on `raw_events.section_id`, `raw_events.project_id`, `raw_events.event_type`, and `raw_events.user_id` support common analytics queries.
- Section analytics queries are bounded by section_id, time filters, and limit clauses.
- Project analytics queries are bounded by project_id, time filters, and limit clauses.
- Custom SQL queries should include section_id or project_id predicates; UI encourages scoped queries.

## 7. Consistency & Transactions

- Backfill scheduling uses `Ecto.Multi` to persist run records and enqueue Oban jobs atomically.
- Inventory run/batch updates are persisted with explicit status transitions to avoid partial states.
- Chunk logs use upsert semantics keyed by batch_id + chunk_index.

## 8. Caching Strategy

- No new caching layers introduced for ClickHouse data.
- SectionResourceDepot is reused for mapping page titles in engagement analytics.

## 9. Performance and Scalability Plan

### 9.1 Budgets

- Section analytics query p50 <= 2s, p95 <= 8s (1M events).
- Project analytics query p50 <= 2s, p95 <= 8s (5M events).
- Inventory batch chunk size defaults to 25 and is configurable.
- Max simultaneous inventory batches default to 1 and is configurable.

### 9.2 Load Tests

- Simulate section analytics queries for 1M events and validate latency.
- Simulate project analytics queries for 5M events and validate latency.
- Run inventory backfill on a manifest with 100+ files and validate batch processing throughput.

### 9.3 Hotspots & Mitigations

- Heavy custom SQL queries -> enforce timeout and optional row limits.
- Backfill throughput -> configure batch chunk size and concurrency limits.
- Large manifests -> paginate manifest reads and process in batches.

## 10. Failure Modes & Resilience

- ClickHouse unavailable -> surface errors in admin UI and mark runs failed.
- S3 credentials invalid -> backfill runs fail with descriptive errors.
- Lambda insert failures -> SQS retries and DLQ for persistent failures.
- Custom analytics query errors -> surface error message without crashing LiveView.
- Backfill/job failure -> allow retry from the last completed batch/chunk so processing resumes without redoing completed work.

## 11. Observability

- Backfill runs store metrics (rows/bytes/duration) and errors in Postgres.
- ClickHouse query execution time captured in `ClickhouseAnalytics.execute_query/3` responses.
- Inventory chunk logs stream progress and error details to UI.
- Logs are emitted for ingestion and query failures.

## 12. Security & Privacy

- ClickHouse analytics access (including admin analytics dashboard and section analytics) is gated by `clickhouse-olap`.
- ClickHouse bulk ingest/backfill tooling is gated by `clickhouse-olap-bulk-ingest`.
- Instructor analytics requires section-scoped feature enablement.
- Project analytics will require project-scoped feature enablement.
- Queries are scoped by section_id or project_id to prevent data leakage.
- Custom SQL read-only enforcement:
  - Use a dedicated ClickHouse user configured with `readonly=1` and no DDL/DML privileges.
  - Apply per-user limits (e.g., `max_execution_time`, `max_result_rows`, `max_rows_to_read`, `max_bytes_to_read`, `max_memory_usage`) to bound query impact.
  - Server-side SQL validation allows only a single SELECT statement and rejects any query containing INSERT/UPDATE/DELETE/ALTER/CREATE/DROP (including nested subqueries).
  - Validation requires a `WHERE section_id = ?` or `WHERE project_id = ?` predicate, or an equivalent CTE that filters by those fields before results are returned.
- xAPI identifiers (user email/ID) are treated as PII and should not be logged.

## 13. Testing Strategy

- Unit tests for backfill query builder, run transitions, and inventory processing.
- Integration tests for backfill workers and analytics queries.
- LiveView tests for admin backfill UI, instructor analytics tab, and project analytics dashboard.
- JS hook tests for chunk logs viewer (manual QA or integration).

## 15. Risks & Mitigations

- Data skew from partial backfills -> expose run status and allow reruns.
- ClickHouse schema drift -> manage via explicit migrations and versioned SQL.
- Performance regressions from custom analytics -> enforce query timeouts and size limits.

## 16. Open Questions & Follow-ups

- What is the retention policy for `raw_events` and inventory logs?
