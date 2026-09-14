# Course Progress Simulation Detailed Design

## Purpose

`simulate_progress` creates realistic QA and demo learner history by taking enrolled learners through
a delivered course. It uses production visit, evaluation, hint, reset, save, and finalization
lifecycles. It does not write requested scores directly.

This Phase 4B contract replaces the earlier Phase 4 simulator contract. It intentionally favors a
small supported surface over a general simulation framework.

## Scenario Contract

A scenario selects either one fixed profile for all selected learners:

```yaml
- simulate_progress:
    section: demo_section
    users: [learner_1, learner_2]
    profile: steady_learner
    seed: 42
```

or count-based cohorts whose counts exactly cover the selected population:

```yaml
- simulate_progress:
    section: demo_section
    seed: 42
    cohorts:
      - {profile: high_proficiency, count: 10}
      - {profile: steady_learner, count: 15}
      - {profile: persistent_learner, count: 10}
      - {profile: low_engagement, count: 5}
```

`users` is optional; omitting it selects all enrolled learners. The directive accepts only `section`,
`users`, `seed`, `profile`, `cohorts`, and `timing`. Profiles cannot be versioned or overridden.
The retired `pct_correct` and `assessment_attempts` inputs remain explicitly rejected with migration
guidance.

## Fixed Profiles

Each preset has exactly six behavior settings:

- course reach;
- activity participation;
- initial correctness;
- practice attempt count;
- assessment attempt count; and
- improvement per attempt.

The supported presets are `high_proficiency`, `steady_learner`, `persistent_learner`, and
`low_engagement`. Attempt counts are fixed and modest; the largest current preset allows four
practice attempts and three assessment attempts. An incorrect practice attempt requests a hint when
one is available before reset and retry.

Profiles also have private, fixed timing distributions. These aren't scenario overrides and don't
expand the behavior contract.

## Learner Journey

For each learner, the simulator:

1. Samples course reach, activity participation, initial correctness, and a pace tendency from the
   supplied seed and stable learner identity.
2. Visits a prefix of delivered pages in curriculum order, including section customizations and
   unnumbered pages returned by the delivery resolver.
3. Samples participation for each ungraded activity. Scored assessment activities always
   participate once their page is reached.
4. Builds UI-valid responses for multiple choice, ordering, check all that apply, short answer, and
   multi-input activities from the current transformed model and real part IDs.
5. Uses whole-activity or per-part reset as required for real practice retries. Incorrect attempts
   request available hints.
6. Saves scored responses, finalizes the page attempt, and starts another scored assessment attempt
   until the profile or section attempt cap is reached.
7. Raises correctness probability by the profile's fixed improvement for every attempt number. The
   evaluator still determines each observed score and the configured grading policy determines the
   retained grade.

Unsupported activity models or response rules are counted as compact warnings. Manual grading and
unsupported assessment scoring modes are reported rather than bypassed.

## Fast and Paced Timing

Fast mode is the default and performs no artificial waits.

```yaml
- simulate_progress:
    section: demo_section
    profile: steady_learner
    timing: {mode: paced}
```

Paced mode samples triangular distributions for start delay, page residence, answer delay, retry
delay, break duration, and study-session gap. Profiles also sample break probability and pages per
study session. Every learner receives a unique seeded journey. Page residence has a ten-minute
minimum and retry timing has a sixty-second minimum in the fixed presets.

The learner worker sleeps directly with `Process.sleep/1`. There is no central scheduler, duration
window, historical timestamp backfill, or telemetry subsystem. Because the release wrapper runs the
BEAM process in the foreground, stopping the command terminates its learner workers immediately.
Already committed database transactions remain committed; no cleanup or resume is attempted.

## Concurrency and Bounds

The implementation uses one unordered `Task.async_stream/3`. Fast mode uses its normal scheduler-based
concurrency and adds a deterministic 10–50 ms delay at modeled wait points; paced mode sets
concurrency to the admitted learner count so every learner's realistic waits can overlap.
At most 100 learners may be selected, and profiles own the fixed attempt caps. Delivery operations run
directly in the learner worker and rely on normal Repo and domain timeouts.

There is no action budget, token bucket, action-rate control, per-action task, cumulative active-work
timeout, course-size envelope, central waiting queue, memory benchmark, or rich progress reporter.
Oban remains responsible for persistence and concurrency of downstream jobs and is not polled by the
simulator.

## Existing History and Reruns

Before learner work starts, the simulator queries existing `ResourceAccess` rows for the selected
section. Learners with any existing section history are skipped and counted in
`skipped_existing_history`; fresh learners continue. Phase 4B does not reconcile or resume partial
history, delete progress, persist seed-run records, or backdate events.

## DataShop Session Identity

Each learner simulation derives one UUIDv5 identifier from the seed, stable learner identity, and
section slug. That identifier is reused for the learner's full journey, including visits, answers,
resets, and scored submissions. Save and hint APIs that don't accept an explicit identifier remain
associated with attempts created under that session.

Modeled study-session boundaries affect pacing only. They do not rotate DataShop IDs. Lower-level
exact-sequence directives keep independent transient UUIDs and expose no session state or rotation
option.

## Result Contract

The result reports compact counts for selected, processed, skipped, failed, completed/partial/blocked
journeys, page visits, practice and assessment submissions, resets, hints, retry-limit encounters,
and bounded unsupported-content warnings. It includes profile totals for cohort inspection but no
action telemetry, scheduler lag, fingerprints, cancellation state, or resume token.

## Verification

Automated coverage must prove:

- parser and JSON-schema parity for a single profile, count cohorts, timing mode, removed options,
  invalid names, unmatched counts, enrollment, and the 100-learner cap;
- deterministic profile decisions, response variation, improvement by attempt number, and one
  learner/section DataShop UUID;
- authentic delivery lifecycles for all five native activity types, both multi-input submission
  modes, hints, practice resets, multiple assessment attempts, evaluator scores, and grading policy;
- existing-history learners are skipped and reported;
- fast mode avoids waits and the pacing helper sleeps for requested sampled durations;
- development `mix seed` dispatches through the dedicated companion runtime without starting the
  full web application.

Long real-time paced behavior, foreground-process termination, and the preview `bin/seed` release
entry point remain hybrid/manual checks because CI must not wait hours and doesn't provide a deployed
preview environment.
