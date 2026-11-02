# Audit Log Partitioned Storage

This runbook covers the partitioned `audit_log_events` table: the one-time migration from the flat 2025 table, rollback and roll-forward, partition maintenance, removing old partitions, and the append-only override.

Design: `docs/exec-plans/current/features/audit-log-expansion/design/pr-01-event-contracts-partitioned-storage.md`. Rehearsal and benchmark evidence: `docs/exec-plans/current/features/audit-log-expansion/evidence/pr-01-storage.md`.

## Key Constraints

- `audit_log_events` is partitioned by half-year on `inserted_at` (`audit_log_events_y2026h1` holds January to June 2026 UTC). There is no default partition: an insert outside every partition fails.
- Rows are append-only. A trigger rejects `UPDATE`, `DELETE`, and `TRUNCATE` unless the transaction ran `SET LOCAL oli.audit_log_allow_mutation = 'on'`.
- Migration `20261030155349_migrate_audit_log_events_to_partitioned` runs in one transaction and holds `ACCESS EXCLUSIVE` on the audit table from start to swap. Every read and write of `audit_log_events` waits for it (rehearsal: about 0.6s at production volume).
- An old application binary cannot write to the new table: its inserts violate the version 2 checks, and for section creation that rolls back the user's operation.

## Preflight

Run read-only, against production, before the deployment that contains the migration. Record the answers in the release ticket.

```sql
-- Volume and date range of both history sources.
SELECT count(*), min(inserted_at), max(inserted_at) FROM audit_log_events;
SELECT count(*), min(inserted_at), max(inserted_at) FROM settings_changes;

-- Rows the migration treats specially (counted in its summary, never failing it).
SELECT count(*) FILTER (WHERE user_id IS NOT NULL AND author_id IS NOT NULL) AS both_actors,
       count(*) FILTER (WHERE user_id IS NULL AND author_id IS NULL) AS no_actor
FROM audit_log_events;
SELECT details->>'resource_type', count(*) FROM audit_log_events GROUP BY 1;

-- Must be 0: the migration refuses details that are not a JSON object.
SELECT count(*) FROM audit_log_events
WHERE details IS NOT NULL AND jsonb_typeof(details) <> 'object';

-- Must be empty: a detached audit partition blocks the migration and its rollback.
SELECT relname FROM pg_class
WHERE relname ~ '^audit_log_events_y[0-9]{4}h[12]$' AND relkind = 'r' AND NOT relispartition;

-- Owner and grants. The migration copies only SELECT, INSERT, and REFERENCES to the new table,
-- re-issues grants as the migration role, and does not copy column grants.
SELECT pg_get_userbyid(relowner), relacl FROM pg_class WHERE relname = 'audit_log_events';
SELECT attname, attacl FROM pg_attribute
WHERE attrelid = 'audit_log_events'::regclass AND attacl IS NOT NULL;

-- Default privileges apply to every new partition and to the rollback archive.
SELECT pg_get_userbyid(defaclrole), defaclnamespace::regnamespace, defaclobjtype, defaclacl
FROM pg_default_acl;

-- Server and roles.
SELECT version();
SELECT rolname, rolconfig FROM pg_roles WHERE rolname IN (current_user /*, '<app role>' */);
SELECT has_schema_privilege('<app role>', 'public', 'CREATE');
SELECT pg_size_pretty(pg_total_relation_size('audit_log_events'));
```

Check the answers:

- The migration role should own `audit_log_events`; if it does not, the new table is owned by the migration role.
- Default privileges for the migration or maintenance role must not grant `UPDATE`, `DELETE`, `TRUNCATE`, or `SELECT` to other roles on new tables: they would reach every partition directly, bypassing the parent's grants, and the rollback archive. This is a release gate.
- `rolconfig` should not set a `statement_timeout` shorter than the rehearsed duration with margin.
- The monthly worker needs a role that has `CREATE` on the schema and owns `audit_log_events` (`ATTACH PARTITION` requires owning the parent). If the application role is not that role, the worker cannot add partitions. The migration provisions the current half-year plus four, so this is not urgent, but decide who runs `Oli.Auditing.Partitions.ensure_through/1` with that role before the horizon runs out. This is a release gate.
- `settings_changes` sets the oldest partition. With production data from 2024-07-29, three partitions before December 2025 are empty, which is harmless.

## Deployment

1. Stop every old application instance and Oban.
2. Run `bin/migrate` (`Oli.Release.migrate/0`). If any step fails, including reconciliation, nothing changes and the deployment stops. Keep the log line `audit_log_events migrated: ... copied=... by_type=... redacted=... ambiguous_actors=...`; it contains counts only.
3. Start the new application.
4. Smoke check: open `/admin/audit_log`, then from a remote console `Oli.Auditing.Partitions.status()` must return `{:ok, _}`.

## Rollback And Roll-Forward

Rollback archives the full history in `audit_log_events_rollback_archive` and rebuilds the 2025 table with the original 16 event types.

1. Stop the new application and drain or pause Oban.
2. Confirm the detached-partition query in Preflight returns nothing. Drop or reattach any table it lists first.
3. Run `bin/oli eval 'Oli.Release.rollback(Oli.Repo, 20261030155349)'`. Ecto rolls back down to and including the given version, so pass this migration's own version.
4. Start the old application.

While rolled back:

- The archive holds names and emails from event snapshots and has no append-only guard. Do not modify it; only the table owner can read it.
- Events of new types are only in the archive; the old UI cannot show them.

Roll-forward is a normal deployment of the new version. The migration restores the archive first, copies only the legacy rows written after the rollback, reconciles, and drops the archive. If a legacy row was deleted or edited during the rollback window, reconciliation fails and nothing changes; restore that row before retrying.

## Partition Maintenance

- `Oli.Auditing.PartitionMaintenanceWorker` runs monthly in both Oban configurations and calls `Partitions.ensure_through/1` for two years ahead.
- `Partitions.status/0` returns `:warning` when fewer than three future half-years exist, and `:error` when the current half-year has no partition.
- A missing partition makes inserts fail with `partition_missing`; each failure logs one line with the event type, interval, and correlation ID, and emits `[:oli, :auditing, :append, :error]`.
- `ensure_through/1` creates each partition as a standalone table and attaches it with `ATTACH PARTITION`, which takes only `SHARE UPDATE EXCLUSIVE` on the parent, so reads and inserts continue while it runs. Avoid `CREATE TABLE ... PARTITION OF` for manual provisioning: it needs `ACCESS EXCLUSIVE`, and behind a long query every insert queues for up to the lock timeout.
- `ATTACH PARTITION` still conflicts with `VACUUM`, `ANALYZE`, `CREATE INDEX`, and `DETACH ... CONCURRENTLY` on the parent. If one of them holds the parent for more than five seconds, `ensure_through/1` returns a provisioning error; Oban retries the job up to three times and it runs again the next month. Avoid scheduling parent maintenance at 08:00 UTC on the 1st.
- Autovacuum never analyzes the partitioned parent. Run `ANALYZE audit_log_events` after a bulk change such as removing a partition, and periodically as history grows, because queries that cannot prune (such as the admin list) plan with the parent's statistics.

## Removing The Oldest Partition

There is no retention automation. Removing history destroys audit records permanently, so it needs the same review and approval as the append-only override, and a retention decision that allows it. To remove history, run outside a transaction, for example in `psql`:

```sql
ALTER TABLE audit_log_events DETACH PARTITION audit_log_events_y2025h2 CONCURRENTLY;
-- Export the detached table here if the history must be kept elsewhere (see below).
DROP TABLE audit_log_events_y2025h2;
ANALYZE audit_log_events;
```

- Exports contain names and emails from event snapshots. Store them only in encrypted, access-controlled storage with a defined retention period, never on workstations or in tickets.
- `DETACH ... CONCURRENTLY` does not block reads or writes of newer partitions, but it waits for every transaction that started before it. If it is interrupted, finish it with `ALTER TABLE audit_log_events DETACH PARTITION <name> FINALIZE`.
- `Oli.Auditing.Partitions.detach/1` uses a plain `DETACH`, which needs `ACCESS EXCLUSIVE` on the parent: behind a long query, every read and write would queue behind it. It gives up after a five-second lock timeout; prefer the SQL above in production.
- Do not leave a detached partition undropped: it blocks the migration's rollback and roll-forward, and `ensure_through/1` cannot recreate a partition with that name.

## Append-Only Override

Only a documented procedure, reviewed like a migration, may change audit rows. It must:

- run inside an explicit transaction and use `SET LOCAL oli.audit_log_allow_mutation = 'on'`, never a session-level `SET`, so the override ends with the transaction;
- never run from application code paths.

Every role can set `oli.audit_log_allow_mutation`, even at session level; the guard prevents accidents, not deliberate changes. What protects the rows is privileges and ownership: keep `UPDATE`, `DELETE`, and `TRUNCATE` on the parent and its partitions off application and reporting roles (the migration does not copy them), and remember that the table owner can also disable triggers or detach and drop partitions. Record which role owns the audit tables.
