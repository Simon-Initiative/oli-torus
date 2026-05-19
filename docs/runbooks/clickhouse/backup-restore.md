# ClickHouse Backup And Restore

This runbook describes the high-level Torus OLAP backup and restore process using `clickhouse-backup`.

For exact command syntax, config keys, storage settings, retention policy settings, and version-specific behavior, use the upstream `clickhouse-backup` documentation:

- GitHub repository: https://github.com/Altinity/clickhouse-backup
- README: https://github.com/Altinity/clickhouse-backup/blob/master/README.md

## Scope

Use this runbook when you need to:

- Create a backup before destructive ClickHouse work
- Restore a ClickHouse dataset into staging for recovery validation
- Restore a production dataset after infrastructure loss or operator error

This runbook covers the ClickHouse OLAP dataset used by Torus, especially the database that contains `raw_events`.

Backups exist for operator convenience and faster recovery. They are not the only recovery path. If backups are unavailable or unusable, the ClickHouse analytics dataset can be rebuilt from the source-of-truth xAPI JSONL files stored in S3 via the Torus backfill workflows.

The repository includes the backup automation assets:

- `devops/clickhouse-backup/clickhouse-backup.sh`
- `devops/clickhouse-backup/systemd/clickhouse-backup.service`
- `devops/clickhouse-backup/systemd/clickhouse-backup.timer`

## Key Constraints

- `clickhouse-backup` must run on the same host, same Kubernetes pod, or a neighbor container with access to the same ClickHouse data directories as `clickhouse-server`.
- For data backups and restores, do not treat `clickhouse-backup` as a purely remote CLI.
- Keep the detailed storage and credential configuration in the tool's own config file and operational docs rather than duplicating them here.

## How The Tool Works

At a high level:

- Backup uses ClickHouse `FREEZE`-based part snapshots plus `clickhouse-backup` local metadata handling.
- Restore rehydrates the backup data back onto the ClickHouse node and attaches restored parts back into ClickHouse.
- Remote object storage workflows are handled by `clickhouse-backup` upload, download, and remote-create/restore commands.

Refer to the upstream docs for the exact storage backends and command semantics.

## Preconditions

- ClickHouse administrative access
- `clickhouse-backup` installed and configured on the ClickHouse host or pod
- Access to the configured remote backup storage
- The target ClickHouse database name
- Lambda ETL trigger access so live inserts can be paused during destructive work or restore

## High-Level Backup Process

The repo-provided automation implements this schedule:

- Daily backup timer at `00:00:00 UTC`
- Weekly full backup on Sundays
- Daily differential backup on other days, using the latest remote full backup when available
- Locking with `/var/lock/clickhouse-backup.lock` to prevent overlapping runs

The committed service unit expects the installed script to live at:

```text
/opt/scripts/clickhouse-backup.sh
```

The repo copy is the source artifact; operators are responsible for installing it to the path used by the systemd unit or adjusting the unit file for the target host.

1. Confirm the target environment and ClickHouse database.
2. If the backup precedes destructive work, pause the Lambda ETL trigger first so the dataset is stable during the operation.
3. Install the repo-owned script and systemd units onto the ClickHouse host.
4. Run `clickhouse-backup` on the ClickHouse host or pod.
5. Create a backup using the configured `clickhouse-backup` workflow.

Typical patterns:

- Create a local backup, then upload it to remote storage
- Use the tool's remote backup workflow directly, such as `create_remote`

The repo script specifically:

- Creates a full backup on Sundays
- Creates a diff backup on other days
- Falls back to a full backup if no remote full backup exists

6. Record the backup identifier, environment, timestamp, storage target, and operator.
7. Verify backup completion with `clickhouse-backup list`, `clickhouse-backup list remote`, or the equivalent remote listing command.
8. If ETL was paused only for the backup, re-enable the Lambda trigger and confirm queue drain.

## High-Level Restore Process

### Restore Into Staging

Use staging restore validation before relying on the same flow in production.

1. Pause the Lambda ETL trigger for the staging environment.
2. Confirm the target staging ClickHouse database and host.
3. If required for the recovery scenario, clear or rebuild the ClickHouse schema first.

For the repo-managed schema lifecycle, use:

```bash
mix clickhouse.migrate reset
```

4. Run `clickhouse-backup` on the staging ClickHouse host or pod.
5. Restore the selected backup using the configured workflow.

Typical patterns:

- Download a remote backup, then restore it
- Use the tool's remote restore workflow directly, such as `restore_remote`

6. If the restored data needs schema reconciliation, run:

```bash
mix clickhouse.migrate up
```

7. Validate the restored dataset.

Recommended checks:

- `raw_events` exists
- Row counts are plausible
- Recent timestamps match expectations
- `/admin/clickhouse` reports healthy status
- Representative analytics queries succeed

8. Re-enable the staging Lambda trigger only after validation is complete.

### Restore Into Production

1. Declare a maintenance window.
2. Pause the production Lambda ETL trigger so SQS retains new work during the restore.
3. Confirm the backup identifier, target environment, and restore host.
4. Run `clickhouse-backup` on the production ClickHouse host or pod.
5. Restore the selected backup using the same method validated in staging.
6. Run `mix clickhouse.migrate up` if schema reconciliation is needed after restore.
7. Validate ClickHouse health, row counts, representative analytics queries, and ETL connectivity.
8. Re-enable the Lambda trigger.
9. Confirm SQS backlog drains and fresh events appear in ClickHouse.

## Validation Checklist

- [ ] Backup artifact exists and is listed by `clickhouse-backup`
- [ ] Restore completed without ClickHouse errors
- [ ] `raw_events` table exists
- [ ] Row counts are plausible for the target environment
- [ ] Recent timestamps match expectations
- [ ] Admin ClickHouse health view loads
- [ ] Instructor analytics queries return expected data
- [ ] Lambda ETL can insert after restore

## Failure Notes

If restore validation fails:

- Leave the Lambda ETL trigger paused
- Preserve the failing backup identifier and restore logs
- Record the exact ClickHouse error
- Re-run validation in staging before attempting another production restore

## Related Documents

- `docs/runbooks/clickhouse/operations.md`
- `docs/runbooks/clickhouse/readonly-user.md`
- `devops/clickhouse-backup/clickhouse-backup.sh`
- `devops/clickhouse-backup/systemd/clickhouse-backup.service`
- `devops/clickhouse-backup/systemd/clickhouse-backup.timer`
- `cloud/xapi-etl-processor/README.md`
