# Phase 1 Lifecycle Contract and UI Assumption Audit

Work item: `docs/exec-plans/current/epics/clickhouse_bulk_backfill_improvements`
Phase: `1`

## Current Mutation Points

The current inventory backfill lifecycle is mutated in these backend entrypoints:

- `Oli.Analytics.Backfill.Inventory.retry_batch/1`
  Resets `processed_objects`, `rows_ingested`, `bytes_ingested`, `started_at`, `finished_at`, `chunk_count`, `chunk_sequence`, and deletes prior chunk logs before re-enqueue.
- `Oli.Analytics.Backfill.Inventory.pause_run/1`
  Marks the run `:paused` immediately and sets `pause_requested` metadata before all running work has necessarily drained.
- `Oli.Analytics.Backfill.Inventory.cancel_run/1`
  Cancels outstanding batches and marks the run `:cancelled` immediately, which also makes `Delete Run` available immediately.
- `Oli.Analytics.Backfill.Inventory.recompute_run_aggregates/1`
  Derives current run state from batch counts using the existing precedence rules.
- `Oli.Analytics.Backfill.Inventory.BatchWorker.handle_failure/3`
  Marks the failed batch `:failed`, recomputes aggregates, and then forces the parent run to `:failed`.

These are the mutation points Phase 2 must refactor behind a simpler authoritative settled-state model.

## Canonical Lifecycle Contract For Implementation

The selected lifecycle contract for the remaining implementation phases is:

- `:running`
  Active state. `Pause` and `Cancel` are valid controls. `Resume` and `Delete Run` are not valid.
- `:paused`
  Settled paused state. `Resume` and `Cancel` are valid controls. `Pause` and `Delete Run` are not valid.
- `:cancelled`
  Settled terminal state. `Resume` is never valid. `Delete Run` becomes valid once the cancel request has completed and the run is authoritatively `:cancelled`.
- `:failed`
  Settled terminal state for the run when reconciliation determines no more eligible work remains and failure is the authoritative outcome. `Delete Run` is valid.
- `:completed`
  Settled terminal state after all required work finishes successfully. `Delete Run` is valid.

## Settled Delete Run Contract

`Delete Run` is allowed only after a run reaches one of these settled terminal states:

- `:completed`
- `:failed`
- `:cancelled`

`Delete Run` must not be available while the run is still in a non-terminal state:

- `:running`
- `:paused`

For cancellation specifically, the important rule is:

- a successful cancel request should leave the run in the terminal `:cancelled` state
- deletion becomes available after that authoritative transition completes

## Current UI-Derived Lifecycle Assumptions To Replace

The current `OliWeb.Admin.ClickhouseBackfillLive` logic contains assumptions that must be replaced by authoritative backend state reads:

- `resumable_run?/1`
  Treats any run with `pause_requested` metadata as resumable, even if the run is actually `:cancelled`.
- `pausable_run?/1`
  Hides `Pause` whenever `pause_requested` is set instead of relying on authoritative settled run state.
- `cancellable_run?/1`
  Keys directly off the current status set `[:pending, :preparing, :running, :paused]` and must remain aligned with authoritative backend lifecycle rules.
- `deletable_inventory_run?/1`
  Must rely on authoritative terminal state rather than metadata-derived assumptions.
- Inventory action rendering
  Renders `Pause`, `Resume`, `Cancel`, and `Delete Run` directly from helper predicates instead of from a backend-authored action contract.

## Current Backend Behaviors Explicitly Captured By Phase 1 Tests

Phase 1 baseline tests intentionally capture the current incorrect behavior so later phases can change it safely:

- retry resets batch metrics and chunk progress instead of resuming from the failed chunk
- a single failed batch pushes the run to `:failed`
- cancellation immediately marks the run `:cancelled`
- deletion is available immediately after cancellation
- stale pause metadata can make the LiveView render `Resume` for a cancelled run

Those behaviors are regression baselines, not the desired final contract.
