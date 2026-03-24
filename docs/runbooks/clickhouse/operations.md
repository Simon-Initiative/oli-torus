# OLAP Operations Runbook

## Overview

This document describes the production-oriented deployment shape for the Torus OLAP stack and summarizes the operational procedures required to reset, backfill, and restart the analytics pipeline. It focuses on deployed components, environment responsibilities, and workflows that are implemented in this repository.

The OLAP stack is built around three major concerns:

- Durable event storage in S3 as JSONL
- Continuous ingestion into ClickHouse through SQS and a Python Lambda ETL processor
- Historical and recovery-oriented ingest through the Torus bulk backfill workflow

## Production-Oriented Deployment Shape

### Core Components

The production-oriented OLAP deployment consists of the following components:

- Torus application services that emit xAPI events
- An S3 xAPI bucket that stores JSONL files as the system of record for analytics events
- S3 event notifications that publish object creation events
- An SQS queue that buffers ingest work for the ETL processor
- A Python-based Lambda ETL processor that reads JSONL objects from S3 and inserts records into ClickHouse
- A ClickHouse deployment that stores analytics data for querying and dashboards
- An operator-managed ClickHouse backup and restore process

### Functional Data Flow

The continuous ingestion path is:

`Torus -> S3 JSONL -> S3 Event Notification -> SQS -> Lambda ETL -> ClickHouse`

The historical and rebuild path is:

`S3 JSONL -> Torus Bulk Backfill -> ClickHouse Native S3 Reads -> ClickHouse`

For local development, Torus can bypass the S3 and Lambda path and upload directly to ClickHouse. That direct uploader is a development path, not the production ingestion topology.

### Environment Roles

The OLAP environments serve different purposes:

- Development supports local validation, schema iteration, and analytics UI development
- Staging or QA supports reset, restore, and end-to-end ingestion rehearsal
- Production stores the active analytics dataset and receives continuous ETL traffic

Staging is the preferred environment for validating restore behavior, reset procedures, and clean re-ingest workflows before repeating the same process in production.

## Configuration And Ownership Areas

### Torus application

Torus is responsible for:

- Emitting xAPI data to S3
- Providing the admin bulk backfill workflow
- Providing analytics-facing application features and dashboards

### AWS infrastructure

AWS infrastructure is responsible for:

- Persisting xAPI JSONL objects in S3
- Emitting S3 notifications
- Buffering work in SQS
- Running the Lambda ETL processor
- Managing the connectivity path between Lambda and ClickHouse

### ClickHouse infrastructure

ClickHouse infrastructure is responsible for:

- Storing raw analytics data
- Supporting dedupe-aware ingestion behavior
- Supporting backup and restore operations chosen by the operator
- Serving analytics queries

## Canonical References

Use these documents together:

- Lambda ETL deployment and AWS wiring: `cloud/xapi-etl-processor/README.md`
- ClickHouse read-only user for instructor custom analytics: `docs/runbooks/clickhouse/readonly-user.md`
- ClickHouse backup and restore procedure: `docs/runbooks/clickhouse/backup-restore.md`
- Backup automation assets: `devops/clickhouse-backup/clickhouse-backup.sh` and `devops/clickhouse-backup/systemd/`
- ClickHouse schema lifecycle commands: `mix clickhouse.migrate status|up|setup|reset|drop`
- Admin bulk ingest UI: `/admin/clickhouse/backfill`
- Admin health UI: `/admin/clickhouse`

Operational prerequisites:

- `clickhouse-olap` feature flag must be enabled for ClickHouse admin and analytics features.
- `clickhouse-olap-bulk-ingest` feature flag must be enabled for the admin backfill console.
- The ClickHouse database schema must exist and be current before backfills or ETL resume.

## Operational Procedures

### Reset procedure

Use the reset procedure when staging or production needs to be rebuilt from a known clean state after schema or ingestion changes.

Checklist:

- [ ] Confirm the target environment and whether it is staging or production
- [ ] Confirm that a usable ClickHouse backup exists before destructive work begins by following `docs/runbooks/clickhouse/backup-restore.md`
- [ ] Pause the Lambda ETL trigger so new queue work does not continue loading during the reset window
- [ ] Record the cutoff timestamp that separates historical backfill from resumed live ingestion
- [ ] Reset or rebuild the ClickHouse schema using the ClickHouse migration task
- [ ] Confirm that the environment is ready for a clean backfill run

Notes:

- The repo-defined schema reset path is `mix clickhouse.migrate reset` for local and operator-managed environments.
- In production, only use destructive reset commands after a backup has been created and verified.
- Pausing the ETL trigger means disabling the Lambda event source mapping or otherwise preventing SQS-driven Lambda consumption.

### Backfill procedure

Use the backfill procedure to rebuild historical analytics data from S3 after a reset or to load older data that is not yet present in ClickHouse.

Checklist:

- [ ] Choose the supported backfill mode:
  - Manual S3-pattern run
  - Inventory-manifest run
- [ ] Determine the datetime boundary for historical ingest
- [ ] Open `/admin/clickhouse/backfill` and verify both ClickHouse feature gates are enabled
- [ ] Use the Torus bulk backfill workflow to select the S3 pattern or inventory manifest to ingest
- [ ] Run the ClickHouse-native ingest path for the selected files or manifests
- [ ] Monitor ClickHouse ingest progress, query health, and duplicate behavior during the run
- [ ] Validate row counts and representative query results after the backfill completes
- [ ] Resume live ETL only after backfill validation is complete

### Restart procedure

Use the restart procedure after reset and backfill work is complete.

Checklist:

- [ ] Confirm that the historical backfill is complete up to the recorded cutoff timestamp
- [ ] Confirm that ClickHouse is healthy and queryable from `/admin/clickhouse`
- [ ] Re-enable the Lambda ETL trigger
- [ ] Confirm that new SQS messages are being drained successfully
- [ ] Validate that fresh xAPI events are arriving in ClickHouse after restart
- [ ] Monitor for ingest failures, duplicate spikes, or schema mismatch errors immediately after reactivation

### ClickHouse maintenance procedure

Use this procedure when the ClickHouse server must be taken down or restarted for maintenance.

Checklist:

- [ ] Confirm the maintenance window and target ClickHouse environment
- [ ] Pause the Lambda ETL trigger before taking ClickHouse down so new work remains buffered in SQS
- [ ] Confirm that SQS messages are accumulating normally and are not being consumed during the maintenance window
- [ ] Perform the required ClickHouse server shutdown, restart, upgrade, or other maintenance work
- [ ] Wait for ClickHouse to come back up fully and verify that the server is healthy
- [ ] Confirm that ClickHouse is reachable from the ETL path and can accept inserts again
- [ ] Confirm that the ClickHouse schema is still current; if needed, run `mix clickhouse.migrate status` or `mix clickhouse.migrate up`
- [ ] Re-enable the Lambda ETL trigger after ClickHouse health and insert reachability have been confirmed
- [ ] Confirm that queued SQS messages are being drained successfully after ETL resumes
- [ ] Monitor the resumed pipeline for connection failures, retry spikes, or insert errors until the queue returns to normal

### Restore validation procedure

Use the restore validation procedure in staging to confirm that the backup and recovery path is operational.

Checklist:

- [ ] Select a recent backup artifact using `docs/runbooks/clickhouse/backup-restore.md`
- [ ] Restore the backup into the staging ClickHouse environment
- [ ] Validate schema objects, table presence, and representative row counts
- [ ] Run representative analytics queries to confirm the restored dataset is usable
- [ ] Record any restore gaps, timing issues, or manual recovery steps that need to be incorporated into the runbook

## Operational Constraints And Considerations

### Pipeline coordination

Reset and backfill work must be coordinated with the live Lambda ETL path. The cutoff timestamp is the key control point that separates historical reload work from resumed live ingest.

### Duplicate handling

The system tolerates some overlap between live ETL and backfill through dedupe-aware ClickHouse storage behavior. Even so, overlap windows should be controlled tightly to reduce cleanup and validation work.

### Recovery source of truth

S3 remains the authoritative historical source for rebuilds. ClickHouse is the analytical serving store, not the system of record for the original xAPI event payloads.

### Backup posture

This repository documents the backup and restore procedure, but does not provision backup infrastructure for operators. Restore validation should be repeated whenever the recovery process materially changes.

## Documentation Alignment

This document should stay aligned with:

- `cloud/xapi-etl-processor/README.md`
- `docs/runbooks/clickhouse/readonly-user.md`
- `docs/runbooks/clickhouse/backup-restore.md`
- Any environment-specific deployment documentation for staging and production infrastructure

## Summary

The production-oriented OLAP deployment is centered on S3 as the durable event source, Lambda and SQS for continuous ingestion, ClickHouse for analytics storage, and the Torus bulk backfill workflow for historical rebuilds. The operational emphasis is on disciplined reset and reload workflows, restore validation, and keeping this runbook aligned with the ETL, schema, and backup procedures documented in the repository.
