## Informal Request

- When a backfill run is cancelled, we should not see the `Resume` button. Cancelling a run is permanent. Only when a run is paused should the Resume be shown. If a pause or cancellation is in progress, the pause and cancel buttons should be shown as disabled until the action is complete, then show the `Resume` and `Cancel` for paused backfills and `Delete Run` for completed and cancelled backfills.
- When an error occurs partway through a batch being processed and the option to retry, the retry should not restart from the beginning of the batch but should retry at the failed chunk.
- A failed batch should not stop the other currently running or future batches from processing.
- When `Pause` and `Cancel` buttons are shown, the button colors should be swapped so that Pause is gray and Cancel is yellow/warning color.
- We should ensure that the statuses shown always accurately reflect the current status of a batch. We are seeing that batch status shown is sometimes out of sync, for example a job shows progress being made but says `Queued`.
- Metrics are not accurate, particularly for uncompleted batches. Is this to be expected? Is it possible to keep these backfill run metrics up to date in real time such as the count accumulation of rows as they are inserted?
- The ClickHouse analytics dashboard should show UI for available ClickHouse DB tasks, like migrate up and down, initialize the database if it has not been initialized, and reset the database, but show a modal warning dialog and require the database name to be confirmed to proceed.
