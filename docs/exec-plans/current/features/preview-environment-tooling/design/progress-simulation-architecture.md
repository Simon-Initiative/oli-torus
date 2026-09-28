# Progress Simulation Architecture

## Overview

Phase 4B uses a deliberately shallow architecture:

```text
mix seed / bin/seed
  -> Oli.Seeding.Runtime
  -> Oli.Seeding.CLI
  -> Oli.Scenarios.Engine
  -> SimulateProgressHandler
  -> ProgressSimulation
       -> Task.async_stream(fast: default concurrency; paced: admitted learner count)
            -> one learner journey
                 -> LearnerActions
                 -> Responses
                 -> Pacing
```

The companion runtime starts the services required for delivery mutations but no HTTP endpoint,
upload pipeline, normal Oban consumers/plugins, or inventory recovery. The release wrapper uses
`exec`, so the BEAM VM remains the foreground process.

## Responsibilities

| Module | Responsibility |
| --- | --- |
| `ProgressSimulation` | Resolve learners and content, skip prior history, assign fixed profiles, run default-concurrency fast workers or all paced learner journeys, and reduce compact results |
| `LearnerActions` | Call authentic visit, evaluate, save, hint, reset, and finalize delivery boundaries |
| `Responses` | Create valid seeded inputs for the five supported native activity types |
| `Profiles` | Provide four immutable behavior presets and their private timing distributions |
| `Policy` | Make pure seeded reach, participation, correctness, timing, and session-gap decisions |
| `Pacing` | Sleep the current learner worker for a sampled real-time delay |
| `LearnerSession` | Derive one deterministic DataShop UUID per learner/section simulation |

## Worker and Failure Model

The simulator has no supervisor tree of its own. `Task.async_stream/3` uses its normal concurrency in
fast mode and one task per admitted learner in paced mode, and returns learner crashes as failures.
Domain operations execute synchronously in the learner task
and rely on existing database transactions and Repo/domain timeout settings.

There are no per-action tasks, action semaphores, token buckets, budget counters, cancellation tokens,
reporter processes, or central pacing timers. If an operator terminates the foreground seed command,
the VM and all learner tasks exit immediately. Previously committed transactions and already enqueued
server work remain; in-flight transactions follow normal database connection teardown.

Fast mode applies a deterministic 10–50 ms sleep at the same modeled wait points used by paced mode.
This staggers action bursts without introducing a queue-aware limiter or another process.

## Data and Determinism

Resolved pages and activity registrations are passed as one ordinary immutable map shared by BEAM
process semantics. No ETS cache or content fingerprint is needed for the supported 100-learner cap.

Seed keys use stable learner and content identities for participation, response selection, timing,
and cohort shuffling. The same seed and unchanged course yield repeatable choices, but the system does
not promise normalized output across arbitrary implementation changes or publication changes.

Every learner gets one UUIDv5 DataShop session ID derived from seed, learner identity, and section.
Study-session page counts and gaps still shape paced waits, but they don't change that identifier.

## Rerun Policy

A single preflight query partitions selected learners by existing section `ResourceAccess` history.
Fresh learners run; existing-history learners are skipped and reported. This avoids complex resume,
reconciliation, cleanup, and idempotency state while allowing a partially populated cohort to be
completed with a later invocation.

## Operational Boundary

The simulator doesn't inspect Oban backlog or alter queue concurrency. A running server may consume
downstream jobs while the companion process produces them. Offline seeding can leave jobs queued for
the next server start; operational snapshot-lock concerns are handled separately from learner
simulation.
