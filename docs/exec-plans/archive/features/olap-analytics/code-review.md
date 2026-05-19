## UI Review

- [x] Tabs Missing ARIA Roles/State

file: lib/oli_web/live/admin/clickhouse_backfill_live.ex
line: 482
Description: The tab buttons inside a role="tablist" lack role="tab", aria-selected, and aria-controls, so screen readers won’t announce active state or relationships to the tab panels.
Suggestion: Add role="tab" and aria-selected={@active_tab == :manual}/aria-selected={@active_tab == :inventory} plus aria-controls pointing to corresponding role="tabpanel" containers with matching id and aria-labelledby.

- [x] Table Headers Missing Scope

file: lib/oli_web/live/admin/clickhouse_backfill_live.ex
line: 601
Description: Column headers are missing scope="col", which makes header associations unreliable for screen readers in both tables.
Suggestion: Add scope="col" to each <th> in the tables.

- [x] Progress Bars Not Accessible

file: lib/oli_web/live/admin/clickhouse_backfill_live.ex
line: 652
Description: The visual progress bars have no semantic role or values, so assistive tech cannot interpret progress.
Suggestion: Add role="progressbar", aria-valuemin="0", aria-valuemax="100", and aria-valuenow={Float.round(progress_value, 1)} (or a hidden text alternative) on the progress element.

- [x] Live Status Updates Not Announced

file: lib/oli_web/live/admin/clickhouse_backfill_live.ex
line: 1084
Description: Status text updates for chunk logs are not in an aria-live region, so screen reader users won’t hear updates.
Suggestion: Add role="status" aria-live="polite" aria-atomic="true" to the status container.

- [x] External Link Missing Noopener

file: lib/oli_web/live/admin/clickhouse_backfill_live.ex
line: 961
Description: target="\_blank" without rel="noopener" allows the new page to access window.opener, enabling tab-nabbing.
Suggestion: Change to rel="noopener noreferrer".

## TypeScript Review

- [x] Resize observer never attaches when editor mounts later

file: assets/src/hooks/monaco_editor.tsx
line: 78
Description: The useEffect bails out if this.editor is not set; since the effect only depends on isResizable, it won’t rerun after editorDidMount sets this.editor, so the ResizeObserver may never attach and resizing won’t work.
Suggestion: Track the editor in React state/ref and include it in the effect deps, or move the observer setup into editorDidMount and tear it down in a cleanup stored on this.

- [x] Resize observer “debounce” queues unbounded timeouts

file: assets/src/hooks/monaco_editor.tsx
line: 82
Description: Each resize schedules a new setTimeout without canceling the previous one, so a drag-resize can queue many layout calls (jank) and timeouts can still fire after unmount.
Suggestion: Store the timeout id in a ref and clearTimeout before scheduling a new one and in the
cleanup; alternatively use requestAnimationFrame throttling.

## Requirements Review

- [x] No Tests For ClickHouse Query Error/Edge Paths

file: lib/oli/analytics/advanced_analytics.ex
line: 106
Description: The new ClickHouse query execution path adds error handling and formatting logic but no tests cover failure responses (ClickHouse down, non-200 responses, empty queries), leaving AC error-path verification unproven.
Suggestion: Add unit tests for execute_query/2 error branches and LiveView/Scenario tests that
assert UI behavior when ClickHouse is unavailable or returns errors.

## Performance Review

- [x] N+1 job lookups during recovery

file: lib/oli/analytics/backfill/inventory.ex
line: 1073
Description: job_active?/2 performs Repo.get/2 per batch while recover_inflight_batches/1 iterates all running/queued batches, resulting in N+1 database reads and extra latency when many batches are in flight.
Suggestion: Fetch job states in bulk (e.g., collect last_job_ids, Repo.all(from j in ObanJob, where: j.id in ^ids), build a map) or join on ObanJob in the initial query so each batch is checked without per-row queries.

- [x] Per-entry DB polling for interruption

file: lib/oli/analytics/backfill/inventory/batch_worker.ex
line: 1146
Description: check_for_interruption/1 calls Repo.get/2 and is invoked inside chunk and entry loops; for large inventories this results in many DB round trips and can dominate processing time.
Suggestion: Throttle interruption checks (e.g., once per page or every N chunks), or pass a refreshed batch once per page and only Repo.reload on a timer/backoff instead of per entry.

- [x] Extra batch reload per chunk

file: lib/oli/analytics/backfill/inventory/batch_worker.ex
line: 586
Description: apply_chunk_success/4 reloads the batch with Repo.get!/2 for every chunk, adding an extra DB read on the hot path and increasing latency under large backfills.
Suggestion: Avoid the reload by updating using the in-memory batch plus merged metadata, or use
Repo.update_all with inc/set to apply counters and metadata without a read; if a refresh is needed,
do it every N chunks.

## Security Review

- [x] Weak default credential in runtime config

file: config/runtime.exs
line: 273
Description: Defaulting CLICKHOUSE_PASSWORD to "clickhouse" in runtime config means a production deployment can silently start with a known weak password, enabling unauthorized ClickHouse access if the env var is missing.
Suggestion: Remove the default and require System.fetch_env!("CLICKHOUSE_PASSWORD") (or set a secure secret via deployment config) so startup fails without an explicit secret.

- [x] Mass-assignment of server-controlled fields

file: lib/oli/analytics/backfill/backfill_run.ex
line: 63
Description: :initiated_by_id (and :status in the same cast list) are server-controlled fields; allowing them in cast/3 lets client-supplied params spoof the run initiator or status.
Suggestion: Remove :initiated_by_id (and :status if client-controlled) from cast/3, and set them explicitly in server logic (e.g., maybe_put_initiator/2 and controlled transitions).

- [x] Persisting secret credentials in metadata

file: lib/oli/analytics/backfill/inventory.ex
line: 1322
Description: Writing manifest_secret_access_key (and related session token) into run metadata persists AWS secrets in the DB, increasing exposure through admin UIs, logs, or backups.
Suggestion: Do not store secret values in metadata; keep them only in runtime config (or encrypt with a vault/field-level encryption) and store a reference or a boolean flag instead.

- [x] Unvalidated manifest host/scheme enables SSRF

file: lib/oli/analytics/backfill/inventory/batch_worker.ex
line: 1014
Description: The manifest host/scheme from run metadata is used to build the ClickHouse s3() URL without an allowlist, enabling requests to arbitrary hosts if a user can supply these fields (SSRF/data exfiltration).
Suggestion: Restrict host/scheme to a safe allowlist (e.g., \*.s3.amazonaws.com and https only), or ignore user-provided host/scheme and derive them from trusted config.

## Elixir Review

- [x] Chunk size override not parsed due to pipe precedence

file: lib/oli/analytics/backfill/inventory/batch_worker.ex
line: 824
Description: parse_positive_integer/2 is only applied to the literal 25, so any configured batch_chunk_size (string or float) bypasses parsing. This can propagate non-integer values into Enum.chunk_every/4 and crash at runtime.
Suggestion: Wrap the full expression before piping or compute configured first, then call parse_positive_integer(configured, 25).

- [x] Invalid run_id crashes orchestrator job instead of discarding

file: lib/oli/analytics/backfill/inventory/orchestrator_worker.ex
line: 31
Description: to_integer/1 raises on invalid input, causing the Oban job to error and retry indefinitely for malformed run_id values.
Suggestion: Replace to_integer/1 with a safe parse (e.g., Integer.parse/1) and return {:discard, "invalid run id"} when parsing fails.

- [x] Extra DB read inside per-chunk loop

file: lib/oli/analytics/backfill/inventory/batch_worker.ex
line: 586
Description: Repo.get!/2 runs for every processed chunk, adding an extra query per chunk and amplifying latency under large manifests. This violates the “no queries in loops” performance guideline.
Suggestion: Use the in-memory batch (or the updated_batch from Inventory.update_batch/2) to merge
metadata without reloading, or switch to Repo.update with a changeset built from the existing
struct.

## Plan

### Phase 1: Security fixes (blocker priority)

- [x] Create a new env called CLICKHOUSE_OLAP_ENABLED and only enable ClickHouse features if set to true.
- [x] Remove default ClickHouse password in runtime config; require explicit secret via env and fail
      fast if missing. Only require other CLICKHOUSE\_\* vars if CLICKHOUSE_OLAP_ENABLED=true.
- [x] Lock down mass-assignment: remove :initiated_by_id (and :status if server-controlled) from cast/3; set explicitly in server logic.
- [x] Stop persisting AWS secrets in metadata; store only a non-secret flag/reference, or move secrets to runtime config/secure store.
- [x] Add allowlist validation for manifest host/scheme (e.g., https + s3.amazonaws.com) or ignore user-provided host/scheme and derive from trusted config.

### Phase 2: Performance fixes (hot path)

- [x] Remove N+1 job lookups during recovery by bulk fetching Oban job states or joining in the initial query.
- [x] Throttle interruption checks to avoid per-entry DB polling (e.g., once per page or every N chunks).
- [x] Eliminate extra batch reload per chunk by using in-memory batch data or update_all with counters/metadata.

### Phase 3: Correctness/stability fixes (Elixir runtime)

- [x] Fix chunk size parsing precedence so configured batch_chunk_size is parsed before use.
- [x] Handle invalid run_id safely in orchestrator worker and discard malformed jobs instead of retrying indefinitely.

### Phase 4: UI accessibility and security polish

- [x] Add ARIA roles/state for tabs and link tabs to tabpanels with aria-controls/aria-labelledby.
- [x] Add scope="col" to all table headers.
- [x] Add semantic progressbar roles/values for progress bars.
- [x] Wrap live status updates in a polite aria-live region.
- [x] Add rel="noopener noreferrer" to external links with target="\_blank".
