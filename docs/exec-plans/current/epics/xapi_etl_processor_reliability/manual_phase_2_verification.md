# Phase 2 Manual Verification Checklist

Work item: `docs/exec-plans/current/epics/xapi_etl_processor_reliability`

Purpose:

- complete the remaining Phase 2 testing task:
  - manually exercise representative low-volume and forced-failure runs to confirm logs make the dominant stage explicit
- verify that the Lambda's stage-level observability is operationally useful in realistic runs, not just in unit tests

This checklist is written for a human operator to execute in sequence.

## Success Criteria

This verification is complete when all of the following are true:

- a low-volume successful run shows the expected stage progression in logs
- a forced ClickHouse failure run shows the last successful stage before failure
- a no-progress run shows that work was prepared but not inserted because the Lambda refused unsafe work
- for each run, the dominant stage is identifiable from the logs without reading application code

## Prerequisites

Before starting, confirm:

- the latest Lambda code for `cloud/xapi-etl-processor` is deployed
- the Lambda is configured with the current runtime baseline or a close equivalent
- you can access:
  - the Lambda function configuration
  - CloudWatch logs for the function
  - the SQS queue feeding the function
  - a safe test path in S3 for JSONL input files
- you have a way to temporarily force a ClickHouse insert failure in a non-production-safe environment

Recommended baseline during verification:

- SQS batch size: `50`
- batching window: `60s`
- max concurrency: `2`
- Lambda memory: `1024 MB`
- Lambda timeout: `60s`

Record the exact values used:

- Lambda name: `xapi-etl-processor-dev`
- SQS queue: `clickhouse-etl-events-dev`
- S3 bucket: `torus-xapi-dev`
- ClickHouse host: `clickhouse-staging.oli.cmu.edu`
- ClickHouse database: `oli_analytics_dev`
- Date/time of verification: `27MAR2026`

## Log Fields To Look For

The Lambda should emit structured INFO logs with `ETL stage ...` payloads.

During the checks below, look for these stage names:

- `invocation_start`
- `message_prepared`
- `sub_batch_flush_start`
- `sub_batch_concatenated`
- `sub_batch_serialized`
- `sub_batch_committed`
- `sub_batch_failed`
- `sub_batch_no_progress`
- `invocation_complete`

Important fields to confirm when present:

- `stage`
- `flush_reason`
- `row_count`
- `message_count`
- `object_count`
- `payload_bytes`
- `duration_ms`
- `remaining_time_ms`
- `insert_token`
- `outcome`
- `error`

## Scenario 1: Low-Volume Successful Run

Goal:

- prove that a normal low-volume success path emits enough stage information to understand the full flow

### Setup

- Prepare `1-3` small JSONL files in the test S3 prefix.
- Ensure the files are valid and should produce rows after transformation.
- Keep the total row count small enough that one invocation should complete comfortably.

Checklist:

- [x] Test JSONL files prepared in S3
- [x] SQS messages emitted or otherwise enqueued for those files
- [x] ClickHouse is healthy and accepting inserts

### Execute

- Trigger the Lambda through the normal SQS path.
- Wait for the invocation to complete.
- Open the matching CloudWatch log stream.

Checklist:

- [x] Invocation located in CloudWatch logs
- [x] Invocation completed without Lambda timeout
- [x] `batchItemFailures` outcome is effectively empty for this run

### Verify Logs

Confirm the following stages are present in order:

- [x] `invocation_start`
- [x] `message_prepared`
- [x] `sub_batch_flush_start`
- [x] `sub_batch_concatenated`
- [x] `sub_batch_serialized`
- [x] `sub_batch_committed`
- [x] `invocation_complete`

Confirm useful details are visible:

- [x] `row_count` is present for the insert sub-batch
- [x] `payload_bytes` is present after serialization
- [x] `insert_token` is present on flush/commit stages
- [x] `remaining_time_ms` is visible at least on invocation and sub-batch stages
- [x] `flush_reason` is visible on flush/commit stages

Pass condition:

- [x] From the logs alone, you can explain what was inserted and which stages ran successfully

Notes:

- Dominant stage observed: `________________`
- Observed row count: `________________`
- Observed payload bytes: `________________`
- Observed flush reason: `________________`

## Scenario 2: Forced ClickHouse Insert Failure

Goal:

- prove that when ClickHouse insert fails, the logs show the last successful stage before failure and make the failure boundary obvious

### Safe Failure Injection Options

Use one of these in a non-destructive environment:

- point the Lambda at a non-listening ClickHouse host/port
- temporarily block Lambda network access to ClickHouse
- use invalid ClickHouse credentials
- use an intentionally invalid ClickHouse URL

Do not run this in a way that risks corrupting a real production environment.

Record the failure method used:

- Failure method: `________________`

### Setup

- Prepare a small valid JSONL file in S3.
- Ensure the Lambda can still fetch and parse it.
- Ensure only the ClickHouse insert step should fail.

Checklist:

- [ ] Valid input file prepared
- [ ] ClickHouse failure mode enabled
- [ ] SQS message enqueued

### Execute

- Trigger the Lambda through the normal SQS path.
- Wait for the invocation to finish.
- Open the corresponding CloudWatch log stream.

Checklist:

- [ ] Invocation located in CloudWatch logs
- [ ] Invocation did not time out
- [ ] The message was not acknowledged as committed

### Verify Logs

Confirm the following:

- [ ] `message_prepared` is present
- [ ] `sub_batch_flush_start` is present
- [ ] `sub_batch_concatenated` is present
- [ ] `sub_batch_serialized` is present
- [ ] `sub_batch_failed` is present
- [ ] `sub_batch_committed` is absent for the failed sub-batch

Confirm failure visibility:

- [ ] `sub_batch_failed` includes `outcome="clickhouse_insert_failed"`
- [ ] `sub_batch_failed` includes an `error`
- [ ] `insert_token` matches between pre-failure and failure stages
- [ ] `duration_ms` is visible for the failed insert attempt
- [ ] `remaining_time_ms` is visible around the failure

Pass condition:

- [ ] From the logs alone, you can say “serialization succeeded and the failure happened during the ClickHouse insert stage”

Notes:

- Last successful stage before failure: `________________`
- Failure error summary: `________________`
- Insert token observed: `________________`

## Scenario 3: No-Progress Safety Check

Goal:

- prove that the Lambda emits an explicit no-progress signal when work is prepared but it is no longer safe to start the insert

### Safe Ways To Trigger No-Progress

Use one of these in a test environment:

- temporarily set `MIN_REMAINING_TIME_TO_START_INSERT_MS` high enough that the Lambda refuses insert work
- use a short Lambda timeout with the same threshold logic
- combine a small workload with settings that intentionally force the “insufficient remaining time” path

Record the method used:

- No-progress method: `________________`

### Setup

- Prepare a valid small JSONL file in S3.
- Configure the Lambda so it can prepare rows but should not safely begin insert.

Checklist:

- [ ] Valid input file prepared
- [ ] No-progress configuration applied
- [ ] SQS message enqueued

### Execute

- Trigger the Lambda through the normal SQS path.
- Wait for the invocation to finish.
- Open the corresponding CloudWatch log stream.

Checklist:

- [ ] Invocation located in CloudWatch logs
- [ ] Invocation completed without timeout

### Verify Logs

Confirm the following:

- [ ] `message_prepared` is present
- [ ] `sub_batch_no_progress` is present
- [ ] `sub_batch_committed` is absent
- [ ] `sub_batch_failed` is absent unless some separate error occurred

Confirm no-progress visibility:

- [ ] `sub_batch_no_progress` includes a clear `blocker`
- [ ] `remaining_time_ms` is present
- [ ] `flush_reason` is present
- [ ] the log makes it clear that work was prepared but not inserted

Pass condition:

- [ ] From the logs alone, you can say “the Lambda intentionally refused to start the insert because the remaining budget was unsafe”

Notes:

- No-progress blocker: `________________`
- Remaining time observed: `________________`

## Retry Semantics Sanity Check

After the failure and no-progress scenarios, confirm operational behavior:

- [ ] failed/no-progress messages remain available for retry through SQS semantics
- [ ] ordinary retryable insert failures were not proactively copied to the custom failure DLQ
- [ ] if a preparation failure was tested separately, the DLQ copy contains the original body plus summarized attributes rather than an expanded payload dump

Notes:

- Retry behavior observed: `________________`
- DLQ behavior observed: `________________`

## Final Review

Summarize whether the logs made the dominant stage explicit:

- Low-volume success dominant stage was identifiable: `[ ] Yes  [ ] No`
- Insert failure boundary was identifiable: `[ ] Yes  [ ] No`
- No-progress condition was identifiable: `[ ] Yes  [ ] No`
- An operator could diagnose these runs from logs without reading code: `[ ] Yes  [ ] No`

If any answer is `No`, capture the missing signal:

- Missing signal or confusing log behavior: `________________`

## Completion Decision

Mark this task complete only if all three are true:

- [ ] successful run verified
- [ ] forced insert failure run verified
- [ ] no-progress run verified

Verifier name: `________________`
Completion date: `________________`
