# Phase 4B Manual QA

The development fast run is Phase 4B evidence. The longer paced run and preview release checks are
deferred to Phase 8 integrated verification.

## Development Fast Run

Start the server in one shell:

```bash
mix phx.server
```

Run the canonical scenario in another shell:

```bash
mix seed scenarios run --file test/oli/scenarios/data/progress_simulation.scenario.yaml
```

Confirm that the command succeeds, the server stays responsive, and the created section shows
learner page progress, practice retries/hints, multiple scored attempts, and populated grades.
Confirm that server-owned Oban workers consume downstream jobs without simulator queue polling.

Running the same simulation again should report the learners under `skipped_existing_history` and
must not create another attempt history for them.

## Development Paced Run

The paced fixture has realistic waits and can run for hours:

```bash
mix seed scenarios run --file test/oli/scenarios/data/paced_progress_simulation.scenario.yaml
```

Observe learner attempts appearing over real time while the server remains available. Verify that
different learners take different participation and timing paths within their fixed profiles.

Terminate the foreground command with the terminal's normal interrupt/termination action. Confirm
that its BEAM VM and learner workers exit immediately, the server remains running, and already
committed learner progress is still visible. No completion summary or special 130/143 translation is
required after abrupt termination.

## Preview Release

Stage the canonical scenario on the preview host; release images need not contain the repository's
`test/` tree. With preview QA tools enabled, run:

```bash
bin/seed scenarios run --file /path/to/progress_simulation.scenario.yaml
```

Confirm that the companion process starts no second HTTP endpoint, normal Oban consumer/plugin,
upload pipeline, or inventory recovery task. Verify that the running server sees committed data and
can consume downstream jobs. Repeat with a small paced scenario when operationally appropriate and
terminate it to confirm the foreground-process behavior.

## Evidence to Record

- command and exit status;
- compact simulation summary, including processed/skipped/failed counts;
- server availability during and after the run;
- representative practice, hint, assessment-attempt, and gradebook records;
- one DataShop session ID per simulated learner/section; and
- confirmation that termination leaves no seed VM or learner worker running.
