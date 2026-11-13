# PR-01 Storage Evidence

Work item: `docs/exec-plans/current/features/audit-log-expansion`, phase 1 (MER-6111). Design: `design/pr-01-event-contracts-partitioned-storage.md`. Operating procedure: `docs/runbooks/audit-log/partitioned-storage.md`.

All measurements below come from disposable databases on a developer machine (PostgreSQL 14.19, Homebrew, `wal_level=replica`, Apple silicon, local SSD), created and dropped by the scripts. They show relative behavior and orders of magnitude, not production latencies. PR-01 cannot deploy alone; it waits in the integration branch until every coverage PR passes.

## Reproduce

```bash
# Migration rehearsal: production volume, then the 10x growth scenario.
MIX_ENV=test mix run --no-start test/support/audit_log_migration_rehearsal.exs
AUDIT_REHEARSAL_ROWS=62690 MIX_ENV=test mix run --no-start test/support/audit_log_migration_rehearsal.exs

# Partition benchmark: one disposable database at a time, refuses to start below 15 GiB free.
AUDIT_BENCHMARK_ROWS=1000000,440000 MIX_ENV=test mix run --no-start test/support/audit_log_partition_benchmark.exs
AUDIT_BENCHMARK_ROWS=10000000 MIX_ENV=test mix run --no-start test/support/audit_log_partition_benchmark.exs
```

## Migration Rehearsal

Synthetic legacy table with production row count (6,269 rows, 2025-12-10 to 2026-10-29), average `details` of 448 bytes, plus 10 edge rows: user, author, neither, and both actor IDs; nested secret keys; half-year boundary timestamps; a non-account `resource_id`; `NULL` details; a `settings_changes` row from 2024. 44 checks pass.

| Step | 6,269 rows | 62,690 rows (10x) |
| --- | --- | --- |
| `up/0` | 0.61s, 12 MB WAL | 6.04s, 107 MB WAL |
| `down/0` | 0.20s, 11 MB WAL | 1.90s, 108 MB WAL |
| Roll-forward | 0.46s | 4.49s |
| Roll-forward after new-type events | 0.43s | 3.52s |

- Every step stays far below the 60-second plan B threshold (design section 4.7), so the single-transaction migration stands.
- A concurrent read of `audit_log_events` waits for the whole step: 0.58s for `up/0` at production volume, 5.8s at 10x. The migration holds `ACCESS EXCLUSIVE` from start to swap. The deployment already stops the application first.
- **Refusals:**
  - A reconciliation mismatch (a legacy row deleted after rollback while the archive holds it) aborts with `migrated_rows_without_legacy_row`, and the legacy table and archive stay unchanged.
  - Non-object `details` stop `up/0` naming only the row ID.
  - A detached partition stops `down/0` naming the table.
- **Grants:** a reporting role keeps `SELECT` through `up/0` and `down/0`. Its `UPDATE` does not reach the append-only table.
- **Local development database** (2,867 real rows):
  - migrate, rollback, and migrate again;
  - row count and checksum identical at every step.

## Partition Benchmark

Synthetic version 2 rows over five years in time order. The mix mirrors the main families:
- 40% student exceptions;
- 10% manual grades;
- 20% section events;
- 20% project events;
- 10% system-provisioned accounts.

The admin list joins 20,000 users, 2,000 authors, 3,000 projects, and 10,000 sections.

**Volumes.** Production on 2026-10-29 wrote about 600 central events per month. Moving all assessment-setting history in would bring it to about 200,000 rows per year. Over five years:
- 1M rows is that rate;
- 10M rows is ten times it;
- 440,000 rows is about the size of the `settings_changes` history that PR-05 brings into this table.

These are scenarios, not measurements.

**Layouts.** The six-month layout is the migration's own: half-years from five years back through four future half-years. The annual layout uses the same parent, indexes, and checks, with yearly bounds.

**Conditions:**
- `VACUUM (ANALYZE)` runs after loading.
- Reads come from a single client on a warm cache, with custom plans. Each read is the median of 5 runs after one warm-up, with per-node timing off.
- The 10M run was made with the machine otherwise idle (load average about 3). Earlier runs overlapped other desktop load; numbers from those runs that differed are not used.

### Size and writes

| Layout | Rows | Partitions | Table | Indexes | Single insert median / p95 | 1,000-row insert median / p95 |
| --- | --- | --- | --- | --- | --- | --- |
| six-month | 440k | 15 | 146 MB | 224 MB | 0.40 / 0.60 ms | 19.1 / 22.8 ms |
| annual | 440k | 8 | 146 MB | 213 MB | 0.41 / 0.68 ms | 21.6 / 33.6 ms |
| six-month | 1M | 15 | 331 MB | 492 MB | 0.45 / 0.71 ms | 23.4 / 26.0 ms |
| annual | 1M | 8 | 331 MB | 450 MB | 0.49 / 0.74 ms | 21.6 / 26.5 ms |
| six-month | 10M | 15 | 3,309 MB | 4,075 MB | 0.54 / 0.73 ms | 42.6 / 120.8 ms |
| annual | 10M | 8 | 3,308 MB | 4,073 MB | 0.79 / 0.97 ms | 114.5 / 175.1 ms |

Single inserts stay below 1 ms in both layouts at every volume. Inserts always go to the current partition, whose size depends on the yearly rate, not on history. The 1,000-row batch numbers at 10M vary run to run (the previous 10M run, which overlapped autovacuum, had the opposite order), so they show no layout effect.

### First-page reads at 10M rows

| Query | Execution, six-month / annual | Planning, six-month / annual | Partitions executed, six-month / annual |
| --- | --- | --- | --- |
| All history, newest 25 | 0.04 / 0.02 ms | 0.38 / 0.17 ms | 5 of 15 / 3 of 8 |
| Last 30 days | 0.02 / 0.01 ms | 0.47 / 0.27 ms | 5 of 15 / 3 of 8 |
| One type in one quarter | 0.02 / 0.01 ms | 0.22 / 0.22 ms | 1 of 15 / 1 of 8 |
| One section, all history | 0.03 / 0.02 ms | 1.32 / 0.72 ms | 5 of 15 / 3 of 8 |
| One learner, all history | 0.04 / 0.03 ms | 1.30 / 0.73 ms | 15 of 15 / 8 of 8 |

- **Execution:** indexed first-page reads stay below a tenth of a millisecond at every volume. Date bounds prune to the partitions in range, and ordered `LIMIT` reads stop after the newest partitions.
- **Planning:** planning time grows with the partition count. It is about twice as high with 15 partitions as with 8, but stays below 1.5 ms.
- **Not measured:**
  - generic plans, which lock every partition;
  - concurrency against the lock manager.

  Those costs also grow with the partition count. At 15 to 20 partitions, they are a reason to avoid monthly partitions, not six-month ones.

### Admin list (current `Oli.Auditing.browse_events_query/3`)

Median execution, with the range of the 5 runs:

| Query | 440k six-month | 440k annual | 1M six-month | 1M annual | 10M six-month | 10M annual |
| --- | --- | --- | --- | --- | --- | --- |
| Default page | 0.50 s (0.43-0.73) | 1.46 s (0.72-2.28) | 1.23 s (1.18-1.27) | 1.45 s (1.31-1.78) | 39.5 s (38.1-47.4) | 37.7 s (36.1-44.2) |
| Text search | 1.83 s (1.75-1.91) | 1.98 s (1.90-2.20) | 4.00 s (3.98-4.03) | 4.55 s (4.02-5.68) | 65.9 s (65.2-67.5) | 62.7 s (61.7-68.6) |
| One event type | 0.17 s (0.17-0.33) | 0.17 s (0.16-0.21) | 0.35 s (0.33-0.38) | 0.46 s (0.38-0.55) | 29.6 s (28.7-31.9) | 30.5 s (29.0-30.6) |

- **Why it is slow:** this confirms the risk deferred in review round 3. `count(*) OVER()`, the left joins, and the OR'ed joined-name `to_tsvector` force every matching row to be read: 492,000 blocks at 10M. The cost grows faster than the row count once the working set leaves memory: 1.2 s at 1M becomes 39 s at 10M.
- **Layout:** it makes no consistent difference. The ranges overlap, except where a run overlapped other load.
- **At today's volume:** about 6,000 rows, so the list stays fast.
- **At the volume PR-05 brings** (measured at 440,000 rows): the default page takes about 0.5 s and text search about 1.8 s. The UI and search PR (PR-07) must replace the window count and the joined-name search before then, for example with an estimated or capped count, keyset pagination, and a `search_text`-only match using the GIN index.

### Six-month versus annual (AC-075)

At 440,000, 1M, and 10M rows:
- the layouts execute writes, indexed reads, and the admin list at the same cost, within run-to-run variation;
- six-month partitions double planning time, which stays below 1.5 ms;
- neither one is a bottleneck: the admin query shape is.

Six-month partitions keep the cost of more objects small: 15 against 8 here, about 20 against 10 over ten years. In return they halve the unit of retention and removal, and each partition stays at about half a year of rows.

Keep the six-month layout. Monthly partitions, with roughly six times more partitions, are not justified by these numbers.

### Removing the oldest partition (AC-078)

`ALTER TABLE ... DETACH PARTITION ... CONCURRENTLY`, then `DROP TABLE`, with another connection inserting throughout:

| Rows | Removed partition | Detach | Drop | Longest concurrent insert |
| --- | --- | --- | --- | --- |
| 1M | `y2021h2`, 32,437 rows | 17 ms | 14 ms | 12 ms |
| 10M | `y2021h2`, 324,321 rows | 202 ms | 602 ms | 141 ms |

- Newer partitions keep their row counts. The total equals the previous total minus the removed rows plus the concurrent inserts.
- Writers continue throughout. At 10M the longest insert wait was 141 ms, while the drop removed about 300 MB of table and indexes.
- No retention automation ships.

### Provisioning a partition behind a long read

A report-style transaction holds the parent for 2 seconds while a new partition is created and another connection keeps inserting. Both methods run like `Partitions.ensure_through/1`: one transaction with a five-second lock timeout and the truncate trigger.

| Rows | Method | Provisioning time | Longest insert wait |
| --- | --- | --- | --- |
| 1M | `CREATE TABLE ... PARTITION OF` | 1,769 ms | 1,763 ms |
| 1M | `CREATE TABLE ... (LIKE ...)` + `ATTACH PARTITION` | 79 ms | 21 ms |
| 10M | `CREATE TABLE ... PARTITION OF` | 2,035 ms | 2,033 ms |
| 10M | `CREATE TABLE ... (LIKE ...)` + `ATTACH PARTITION` | 41 ms | 25 ms |

- `CREATE ... PARTITION OF` needs `ACCESS EXCLUSIVE` on the parent. It waits for the long read, and every insert queues behind it, for as long as the read lasts, up to the lock timeout.
- `ATTACH PARTITION` needs only `SHARE UPDATE EXCLUSIVE`, so inserts are not blocked. The new table is empty, so validating the attach costs nothing.

**Decision:** `Oli.Auditing.Partitions.ensure_through/1` now creates the table with `LIKE` and attaches it. The migration keeps `PARTITION OF`, because it already holds `ACCESS EXCLUSIVE` for the whole transaction.

`test/oli/auditing/partitions_test.exs` covers two things:
- an attached partition matches one created by the migration: columns, defaults, constraints, index definitions, triggers, and bounds;
- `ensure_through/1` succeeds while another session reads the table. With `PARTITION OF`, that test fails with `partition_missing`.

## Open Items

- Admin list query shape: PR-07 must fix it before history volume grows (measured above).
- Admin text search: `to_tsquery` raises on malformed input (pre-existing); PR-07 chooses a safe parser together with the new search semantics. Both items are recorded in `plan.md` Phase 7.
- Operations inputs before release (runbook Preflight):
  - PostgreSQL version;
  - whether the application role has `CREATE` on the schema, and who runs partition maintenance otherwise;
  - owner and ACL of `audit_log_events`;
  - any role-level `statement_timeout`;
  - how `bin/migrate` is ordered relative to stopping old instances.
