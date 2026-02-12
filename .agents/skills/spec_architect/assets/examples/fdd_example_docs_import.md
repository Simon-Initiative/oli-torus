# Google Docs Page Import — Functional Design Document

## 1. Executive Summary
The Google Docs Page Import feature lets Torus administrators convert a Google Doc (shared via Markdown export) into a new curriculum page without leaving the curriculum editor. A guarded “Import from Google Docs” action validates a FILE_ID, downloads the Markdown export, parses it into Torus page JSON, and materialises CustomElements and media according to Torus conventions. The pipeline uses an AST-driven Markdown parser with targeted handlers for tables, lists, and inline marks, while YouTube and MCQ CustomElements are upgraded into Torus media blocks and `oli_multiple_choice` activities. Embedded base64 images are decoded, deduplicated via hashing, uploaded to the Torus media library, and substituted into the resulting page. Import work executes inside `Oli.TaskSupervisor` tasks to protect LiveView responsiveness, and telemetry spans capture latency and failure metrics. SSRF risk is controlled by host allowlisting, and audit events log who imported what. Key risks include Markdown schema drift, media ingestion failures, and MCQ validation errors; each is mitigated through structured warnings, fallbacks, and monitoring.

## 2. Requirements & Assumptions
- **Functional Requirements**
  - Admin-only import control in the curriculum editor (FR-001).
  - Server-side FILE_ID validation and Markdown export URL construction (`format=md`) with resilient error handling (FR-002, FR-003).
  - Page creation via existing project/container pathways using converted Torus JSON (FR-004, FR-005).
  - CustomElement detection for YouTube and MCQ with warnings for unsupported constructs (FR-006, FR-007, FR-009).
  - Base64 image extraction, media upload, and content substitution (FR-008).
  - Warning logging, metadata persistence, and telemetry emission (FR-009–FR-011).
- **Non-Functional Requirements**
  - p50 import latency ≤ 6 s, p95 ≤ 12 s for Markdown ≤ 3 MB; hard fail at 10 MB download payload.
  - ≤ 1 % error rate across rolling 30 days; retries on transient 5xx only.
  - Admin-only access, tenant-aware scoping, and WCAG-compliant UI.
- **Explicit Assumptions**
  - Docs are publicly accessible or shared via service account; no per-user OAuth flow is required.
  - Curriculum editor assigns include the target container and project context.
  - Media library quotas are sufficient and existing APIs support synchronous uploads; image dedupe is hash-based.

## 3. Torus Context Summary
- **What We Know**
  - Curriculum authoring is delivered via `OliWeb.Workspaces.CourseAuthor.CurriculumLive`, which already interacts with `Oli.Authoring.Editing.ContainerEditor` for page management.
  - `Oli.Authoring.Course` and `Oli.Authoring.Editing.PageEditor` handle resource creation and locking semantics.
  - `Oli.Resources.PageContent` offers traversal utilities for Torus JSON, and activity creation flows live in `Oli.Authoring.Editing.ActivityEditor`.
  - `Oli.Auditing` captures admin activity logs; `Oli.TaskSupervisor` is available for supervised async work.
  - Media assets are handled via the existing media library contexts used throughout authoring.
- **What We Don’t Know / Need to Confirm**
  - Expected behaviour when the same image appears across imports (assume dedupe by hash but confirm with product).
  - Any tenant-specific CDN constraints that affect media upload destinations.
  - Preferred telemetry naming conventions for the new metrics (coordinate with observability team).

## 4. Proposed Design

### 4.1 Component Roles & Interactions
- **UI Layer (`CurriculumLive`)**: Renders the admin-only “Import from Google Docs” button, modal, and job state. Dispatches `"import_google_doc"` events and shows success/error/warning feedback.
- **Importer Orchestrator (`Oli.GoogleDocs.Import`)**: Top-level function orchestrating validation, download, Markdown parsing, CustomElement handling, media ingestion, activity creation, and page persistence.
- **HTTP Client (`Oli.GoogleDocs.Client`)**: Wraps `Oli.HTTP.http().get/3`, enforces `docs.google.com` host, uses dedicated hackney pool (`:google_docs_import`), enforces a 10 MB limit, and retries once on transient 5xx.
- **Markdown Parser (`Oli.GoogleDocs.MarkdownParser`)**: Converts the Markdown export into an internal AST, normalises headings/paragraphs/lists, and routes tables to CustomElement handlers; inline spans map to Torus marks.
- **Custom Element Handlers (`Oli.GoogleDocs.CustomElements`)**: Detects sentinel tables (`CustomElement` header). Generates YouTube blocks or MCQ specs; falls back to table representation with warnings when unsupported.
- **MCQ Activity Builder (`Oli.GoogleDocs.McqBuilder`)**: Validates MCQ data, creates `oli_multiple_choice` activities via `ActivityEditor.create/9`, and returns activity-reference blocks.
- **Media Pipeline (`Oli.GoogleDocs.MediaIngestor`)**: Extracts base64 image payloads, computes SHA256 hashes, checks for existing assets, uploads binaries when necessary, and returns Torus asset URLs alongside warnings for failures.
- **Persistence Layer**: Invokes `ContainerEditor.add_new/4` with populated content and metadata; commits inside a Repo transaction to ensure all-or-nothing semantics for page creation and activity linkage.

### 4.2 State & Message Flow
1. LiveView validates FILE_ID and launches a supervised task via `Task.Supervisor.async_nolink`.
2. Importer fetches Markdown; on invalid status or size limit breach it raises an error message for the LiveView.
3. Markdown parser emits a structured result with block list, CustomElement specs, embedded media payloads, document title, and warnings.
4. Media ingestor processes base64 images (dedupe -> upload -> produce URLs); unresolved uploads append warnings.
5. Activities are created sequentially for MCQ specs; references are inserted into the block list.
6. Repo transaction creates the page revision with the final Torus JSON (`%{"version" => "0.1.0", "model" => [...]}`) and attaches it to the project container.
7. Task sends `{:import_completed, ref, {:ok, revision, warnings}}` or `{:import_completed, ref, {:error, reason, warnings}}` to the LiveView.
8. LiveView clears busy state, refreshes the hierarchy, flashes messages, and navigates to the new page on success.

### 4.3 Supervision & Lifecycle
- Import tasks run under `Oli.TaskSupervisor` with `temporary` restart strategy; failure does not restart automatically.
- Hackney pool size (default 5) limits concurrent downloads; LiveView additionally restricts concurrent imports to prevent backpressure issues.
- Media ingestion is synchronous inside the task to keep state isolated; long-running uploads (>5 s) trigger warnings but do not block other tasks.

### 4.4 Alternatives Considered
- **Oban background jobs** were rejected to keep UX synchronous and avoid additional operational overhead.
- **YAML-based TorusDoc import** would require lossy Markdown conversion; direct Markdown parsing is more faithful.
- **Deferred media ingestion** could reduce import latency but risks broken references; we chose eager ingestion with fallbacks for reliability.

## 5. Interfaces

### 5.1 HTTP/JSON APIs
- Outbound request: `GET https://docs.google.com/document/d/<FILE_ID>/export?format=md`.
- Response handling: accept `text/markdown`; treat 3xx/4xx/5xx as errors with user-friendly messaging; enforce 10 MB maximum and stop reading once exceeded.
- No new public APIs; internal media upload uses existing authoring media contexts.

### 5.2 LiveView
- Events: `show_google_doc_import`, `validate_google_doc_import`, `import_google_doc`.
- Assigns touched: `:import_changeset`, `:import_job`, `:warnings`, `:recently_created_slug`.
- LiveView receives `{:import_completed, ref, result}` messages; reuse existing container broadcast subscriptions for hierarchy refresh.

### 5.3 Processes
- Import task: supervised task with monitor reference; handles success/exception reporting.
- Hackney pool: `:hackney_pool.child_spec(:google_docs_import, size: pool_size)` initialised during application start.
- No persistent GenServers introduced; media ingestion uses existing synchronous helpers.

## 6. Data Model & Storage

### 6.1 Ecto Schemas
- No new tables required; page revisions leverage existing `Oli.Resources.Revision` schema.
- Media uploads use existing media library schema (`media_items`, etc.) with SHA256 hash stored in metadata for dedupe.
- Audit entries recorded through `Oli.Auditing` with file_id hash and warning counts.

### 6.2 Query Performance
- Additional queries beyond baseline: `Course.get_project_by_slug/1`, `AuthoringResolver.from_resource_id/2`, media lookup by hash, and `ChangeTracker.track_revision/3`.
- No new indexes anticipated; ensure media lookup uses existing hash index (add if missing).

## 7. Consistency & Transactions
- Repo transaction wraps page creation and activity references; rollback cleans up partial state on failure.
- Media uploads occur before the transaction; failures trigger warnings and revert to external URLs if necessary.
- ETS guard prevents duplicate concurrent imports of the same FILE_ID (hash key).

## 8. Caching Strategy
- ETS table (`:google_docs_import_guard`) tracks in-flight FILE_ID hashes; cleared on task completion.
- Optional ETS cache of media hash → asset_id during an import burst to avoid repeated DB lookups.
- SectionResourceDepot remains unchanged; imported content joins working copy like other pages.

## 9. Performance and Scalability Plan

### 9.1 Budgets
- p50 ≤ 6 s, p95 ≤ 12 s per import (≤ 3 MB Markdown).
- Hard cap 10 MB download; limit AST nodes to 50 000 to avoid excessive CPU.
- Media payload budget: ≤ 5 MB combined base64; warn and skip beyond that.
- Repo pool (default 10) and hackney pool (default 5) sufficient for expected ≤ 20 imports/hour.

### 9.2 Hotspots & Mitigations
- Markdown parsing CPU spikes → stream AST, short-circuit unsupported patterns.
- Media upload bottlenecks → sequential uploads with timeout; optional resizing or rejection for >5 MB images.
- MCQ fan-out → sequential creation; warn and fallback if limit exceeded.
- Large tables → cap rows/columns, warn, and fall back to plain table.

## 10. Failure Modes & Resilience
- Network failures → retry once with jitter; surface descriptive LiveView error.
- Unauthorized or missing doc → user-friendly error and audit entry.
- Markdown parse errors → fallback plain-text import with warning.
- Media upload failure → fallback to original data URL or external link, warn user, continue import.
- Task crash → LiveView receives `:DOWN`, resets state, shows error notification.
- Graceful shutdown → incomplete tasks emit failure; no partial page created.

## 11. Observability
- Telemetry span `[:oli, :google_docs_import]` with measurements (`duration_ms`, `download_bytes`, `media_bytes`) and metadata (project_id, author_id, file_id_hash, warning_count).
- Increment counters for media uploads (`uploaded_media_count`, `media_upload_failures`).
- Structured logs at info level for success and warn level for partial success/failures.
- AppSignal dashboard tracking duration percentiles and error ratio; alert when error rate > 1 % or p95 > 12 s over 15 min.
- Audit capture includes FILE_ID hash, import duration bracket, and warning summary.

## 12. Security & Privacy
- Admin role check enforced both client-side and server-side.
- Tenant isolation inherited from curriculum context; ensure page attaches only to current project.
- Host allowlist prevents SSRF; FILE_ID sanitized before URL interpolation.
- Store FILE_ID only as SHA256 hash outside task memory; redact Markdown content from logs.
- Strip EXIF metadata before media upload to avoid leaking sensitive information.
- Rate limiting implicit via UI; monitor telemetry for abuse.

## 13. Testing Strategy
- **Unit Tests**: FILE_ID validation; Markdown parser element coverage; CustomElement conversions; media ingestion (base64 decode, hash dedupe, upload success/failure); warning aggregation.
- **Integration Tests**: Import success with mixed content; invalid FILE_ID; doc with MCQ + YouTube; media failure fallback; audit + telemetry assertions.
- **LiveView Tests**: Button visibility (admin vs non-admin); modal validation; success and error flows; warning render.
- **Manual QA**: Keyboard-only and screen-reader passes for modal; large doc (8 MB) performance; media-heavy doc to validate uploads; regression check for existing curriculum functions.

## 15. Risks & Mitigations
- Markdown schema drift → maintain fixture suite and emit warnings for unknown patterns.
- Media ingestion failure → retry uploads, fallback to external reference, and alert via telemetry.
- MCQ validation errors → pre-validate keys, warn, and render table fallback rather than failing entire import.
- Latency spikes → enforce size limits, sequentialise heavy steps, and monitor with telemetry.
- Storage growth from duplicate images → hash dedupe, add monitoring on media usage.

## 16. Open Questions & Follow-ups
- Confirm policy for reusing existing media assets across imports (hash dedupe vs always-new).
- Determine naming conventions/owners for AppSignal dashboards and alerts.
- Assess need for background clean-up of orphaned media if import ultimately fails.
