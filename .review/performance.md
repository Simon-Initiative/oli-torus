# Performance Review Checklist

> Use this file during PR review to quickly spot latency, throughput, and memory risks. Prefer small, surgical suggestions with file/line references.

---

## 1) Industry-agnostic Best Practices

### Data access & storage
- [ ] **Avoid N+1**: batch, join, or preload related data.
- [ ] **No queries in loops**: move query out of `map/each` and operate on sets.
- [ ] **Return only needed fields**: select projections, not `SELECT *`.
- [ ] **Indexes exist for hot filters/joins**; verify with an `EXPLAIN` (look for seq scans).
- [ ] **Bulk ops**: use batch insert/update/delete primitives instead of per-row operations.
- [ ] **Streaming for large sets**: iterate without loading entire results into memory.
- [ ] **Precompute/aggregate** heavy analytics into summary tables when latency matters.
- [ ] **Background the heavy work**: async job/queue for expensive, non-interactive tasks.
- [ ] **Cache wisely**: read-through cache for hot keys; define TTL + invalidation strategy.

### API/I/O & delivery
- [ ] **Bounded concurrency & backpressure** for fan-out calls; never unbounded task spawns.
- [ ] **Reuse HTTP clients & connections** (keep-alive, pooling); set timeouts + retries w/ jitter.
- [ ] **Stream responses** (server-side) for large payloads; compress over the wire.
- [ ] **HTTP caching**: ETag/Last-Modified/Cache-Control on static & cacheable dynamic content.

### Algorithmic complexity & data structures
- [ ] **Check hotspots** for accidental `O(n^2)` (nested scans, repeated sorts).
- [ ] **Use appropriate structures** (hash maps/sets, tries, heaps) for lookups and scheduling.

### Memory & GC
- [ ] **Avoid building giant intermediate lists/strings**; prefer iterators/streaming/concat buffers.
- [ ] **Release references** to large buffers promptly; avoid retaining whole results when not needed.

### Concurrency correctness
- [ ] **Do not block main/reactive loops** with CPU or I/O.
- [ ] **Idempotent jobs** + dedupe keys to tolerate retries.
- [ ] **Time-box work** with deadlines/cancellations; surface partial results where possible.

### Observability & safeguards
- [ ] **Metrics**: latency histograms (p50/p95/p99), throughput, queue length, error rate.
- [ ] **Tracing** around DB, HTTP, cache, and render paths.
- [ ] **Log level discipline**: no noisy debug logs in hot loops; structured fields for filtering.

---

## 2) Elixir / Phoenix / Ecto

### BEAM & processes
- [ ] **Never block a GenServer** with long DB/HTTP/CPU work. Offload via `Task`/`Task.Supervisor` or a worker process; keep `handle_call`/`handle_cast` fast.
- [ ] **Bounded parallelism**: prefer `Task.async_stream(enumerable, fun, max_concurrency: N, timeout: :infinity)` for fan-out with backpressure. Use `on_timeout: :kill_task` if appropriate.
- [ ] **ETS for hot reads**: use `:ets` with `read_concurrency: true` (and `write_concurrency` if needed). Keep entries compact; define eviction/TTL strategy.
- [ ] **Use `:persistent_term` only for read-mostly constants** (updates are expensive).
- [ ] **Use iodata** for building responses (`iodata()` / `IO.iodata_to_binary`) to avoid string copies.

### Ecto & Repo
- [ ] **No queries in `Enum.*` loops** — consolidate into a set operation or use a single query.
- [ ] **Preload associations** required by templates/controllers to prevent N+1.
- [ ] **Select only needed fields** with `select:`; avoid loading entire structs in hot paths.
- [ ] **Batch operations**: prefer `Repo.insert_all/3` / `update_all/3` for bulk writes.
- [ ] **Stream big reads**: `Repo.stream/2` within a `Repo.transaction/1`.
- [ ] **Analyze queries**: run `Ecto.Adapters.SQL.explain/4` or DB `EXPLAIN ANALYZE` for slow paths.
- [ ] **Tune Repo pools**: `pool_size`, `timeout`, `queue_target` aligned with concurrency and DB capacity.
- [ ] **Indexes** shipped with migrations for frequent filters/joins; unique indexes for natural keys.

### Phoenix / LiveView
- [ ] **Initial load uses async assigns**: `assign_async` for network/DB-bound data to reduce TTFB.
- [ ] **Minimal assigns**: store only fields needed to render; avoid putting whole big structs into `socket.assigns`.
- [ ] **Stream large collections**: use LiveView **streams** to avoid memory ballooning; do not `Enum.filter` a stream—re-fetch and `stream(..., reset: true)`.
- [ ] **Chunk/stream large downloads**: `send_chunked/2` instead of building giant binaries.
- [ ] **Move expensive work out of `mount/3`**; defer to `handle_params`/async assigns.

### Libraries & patterns
- [ ] **HTTP**: use `Req` client reuse; set timeouts/retries/backoff; cap concurrency for fan-out calls.
- [ ] **Pipelines**: prefer `with` for `{ :ok, _ }` chains to keep happy-path fast and readable.

---

## 3) Torus-specific (Project Standards)

> Pulled from Torus guidelines; enforce these verbatim.

### Queries & data shape
- [ ] **Prefer a single, custom query** when feasible instead of a series of reused query calls.
- [ ] **Break overly complex queries into multiple simpler ones** *when a single query becomes unreadable or planner-hostile*.
- [ ] **Absolutely no DB queries inside `Enum.map` or any loop**.
- [ ] **Use aggregated tables** (`ResourceSummary`, `ResponseSummary`) for reporting/analytics instead of scanning `ActivityAttempt`/`PartAttempt`.

### Caching & delivery
- [ ] **Delivery code MUST use `SectionResourceDepot`** cache for page titles, course hierarchy, schedules, page details, etc., instead of running resolver/section resource queries directly.
- [ ] **LiveViews optimize TTFB with async assigns** (`assign_async`).
- [ ] **LiveViews store only what is needed to render** in assigns; avoid dumping large structs.

### LiveView collections (memory safety)
- [ ] **Use LiveView streams for collections** (append, reset, prepend, delete) to avoid memory ballooning.
- [ ] **When filtering/pruning**, **re-fetch and `stream(..., reset: true)`** — do not try to `Enum.filter` a stream.
- [ ] **Track counts separately** (streams aren’t enumerable) and implement empty states via markup, not by counting the stream.

---

## Reviewer Red Flags (paste these as actionable comments)

- “Move query out of loop and fetch in one set operation.”
- “Use `preload` on X to remove N+1 in Y (template/controller uses it).”
- “Large list assigned to socket; convert to LiveView stream.”
- “Delivery path bypasses `SectionResourceDepot`; switch to cache.”
- “Replace multiple small queries with one tailored query (show proposed Ecto).”
- “Switch to `Task.async_stream` with `max_concurrency` for bounded fan-out.”
- “Return `select:` only the fields used by the view to reduce payload/CPU.”
- “Add index on (`field_a`, `field_b`) used by frequent filter/join; attach `EXPLAIN` before/after.”

---

## Verification Steps (fast)
- [ ] Run slow path with tracing/telemetry; capture DB/HTTP spans.
- [ ] `EXPLAIN` hottest queries (drop screenshot/snippet into PR).
- [ ] Compare TTFB before/after for LiveView route (browser devtools).
- [ ] Assert no queries are executed inside enumerations (grep + code scan).
- [ ] Ensure Repo pool & timeouts are sane for new fan-out work.

