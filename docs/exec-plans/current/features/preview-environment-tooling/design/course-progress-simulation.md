# Course Progress Simulation - Detailed Design

Source Artifacts:
- PRD: `docs/exec-plans/current/features/preview-environment-tooling/prd.md`
- FDD: `docs/exec-plans/current/features/preview-environment-tooling/fdd.md`
- Plan: `docs/exec-plans/current/features/preview-environment-tooling/plan.md`

Status: planned Phase 4B expansion, supplying the learner-data portion of Phase 5.
This document specifies future behavior; the profile/cohort/timing syntax below is not yet implemented.

## 1. Slice Summary

Make `simulate_progress` a course-level operation that takes enrolled learners through a delivered
section using configurable behavior profiles. Generate varied participation, real practice retries,
scored assessment histories, and improving performance through normal delivery operations.

The operator selects a section, learners, profiles, and seed. The simulator decides which pages each
learner reaches, which questions they attempt, whether they retry, and when they stop. A learner
who intentionally stops halfway through the course is a successful simulation outcome.

In scope: existing published sections, ordered course traversal, deterministic cohort assignment,
separate proficiency and engagement controls, native activity response generation, activity/part
retries, scored assessment resubmissions, batching, bounded output, optional wall-clock pacing,
and a supported demo scenario that replaces the Phase 4 progress-simulation example in place.

Default execution generates data as quickly as the configured concurrency and load limits permit. Optional paced
execution gives each learner a separately sampled journey with profile-defined reading times,
answering times, retry delays, and breaks. There is no configured total-duration window. Actions
occur in real time while the CLI runs alongside the server; total runtime emerges from learner
behavior and course content. Stopping the CLI stops simulation for every learner and preserves
committed progress. Backdated activity generation is separately deferred.

Out of scope: a pedagogically validated student model, LLM-generated answers, browser automation,
arbitrary adaptive/lab simulations, manual grading, seed-run persistence, and automatic deletion.

## 2. Requirements Coverage

| Existing requirement | Coverage supplied by this expansion |
| --- | --- |
| FR-004 / AC-013 | Deterministic, bounded learner simulation with supported-content reporting |
| FR-004 / AC-012 | Consume existing enrolled learners and bulk-created stable references |
| FR-004 / AC-014 | Keep orchestration inside `Oli.Scenarios` |
| FR-005 / AC-016 | Supply representative participation, attempt, progress, and gradebook data |
| FR-005 / AC-017 | Preserve synchronous execution without durable simulation-run storage |

Proposed acceptance additions for implementation:

- The same seed, profile version, stable identities, and delivered content produce the same behavior
  decisions regardless of batching or worker scheduling. Database GUIDs and wall-clock times differ.
- Practice retries reproduce the activity's whole-activity or per-part delivery lifecycle.
- Scored assessment retries use observed scores and delivery policies; retained grades follow Torus
  scoring settings rather than being overwritten to match a requested target.
- Engagement and proficiency vary independently, including unfinished and never-started learners.
- The resulting attempts, progress, and grades are inspectable through normal student/instructor UI.
- Existing `pct_correct` and `assessment_attempts` scenarios retain their defined behavior.
- Omitting timing preserves fast execution. Paced profile runs spread actions across learners over
  actual elapsed time, use real persistence timestamps, respect action ordering and delivery policies,
  and release worker/database capacity while waiting. Planned waiting does not trigger action timeouts.
- Each learner independently samples timing and participation within the profile's bounds, including
  skipped activities and breaks. No total-duration target compresses or terminates those journeys.
- An operator can stop the CLI at any point; no learner simulation continues in the server or in
  detached workers. Previously committed progress remains usable and stopping is an expected outcome.
- Both CLI entry points bootstrap a dedicated seeding runtime without a web listener, unrelated job
  consumers, or application-start recovery that could interfere with the concurrently running server.
- Whole-run work limits, downstream backpressure, and compact waiting-learner state bound resource
  use in both execution modes; bounded worker concurrency alone does not satisfy this requirement.
- The existing Phase 4 progress scenario and companion runner become the canonical profile-driven
  example. Focused regression tests retain the legacy syntax contract, not a competing demo workflow.

These additions should be promoted into `requirements.yml` and Phase 4/5 tasks with implementation;
this proposal does not mark existing implementation or deployment gates complete.

## 3. Responsibilities & Boundaries

### Existing behavior and reuse

`lib/oli/scenarios/progress_simulation.ex` currently visits every page, answers graded activities,
and supports explicitly configured assessment attempts. It selects pages by resource ID by default,
samples correctness using database identities, and treats a completed worker as a completed learner.
Those choices do not describe a learner moving through a course.

The existing scenario handlers offer useful domain boundaries but should not be driven by generating
large lists of YAML directives at runtime. They resolve scenario references, accumulate engine state,
and sometimes create their own session identifiers or enroll users implicitly. Reuse/extract their
learner operations with explicit arguments, while keeping the DSL handlers thin.

Relevant code evidence:

- `lib/oli/scenarios/directives/attempt_support.ex`: visits and graded start policy checks.
- `lib/oli/scenarios/directives/answer_question_handler.ex`: input mapping and real evaluation.
- `lib/oli/scenarios/directives/reset_activity_handler.ex`: reset and refreshed attempt state.
- `assets/src/components/activities/multiple_choice/MultipleChoiceDelivery.tsx`: an ungraded
  selection after evaluation automatically invokes reset-and-submit.
- `assets/src/data/activities/DeliveryState.ts`: reset-and-submit consumes the returned new GUIDs.
- `assets/src/components/activities/multi_input/MultiInputDelivery.tsx`: `submitPerPart` retries
  reset just the edited part, preserving the parent activity attempt.
- `lib/oli/delivery/attempts/activity_lifecycle.ex`: reset limits, latest-attempt checks, model
  transformations, preserved hints, and new activity/part records.
- `lib/oli_web/controllers/page_delivery_controller.ex`: graded start also checks gating. Calling
  an attempt lifecycle alone does not reproduce all of the controller's access-policy checks.
- `lib/oli/delivery/metrics.ex`: practice progress is based on completed activities and the page
  threshold, is preserved monotonically, and is distinct from correctness.

### Proposed component boundaries

- `ProgressSimulation`: normalization, compatibility routing, shared section data, batching, summary.
- `ProgressSimulation.Profiles`: versioned named presets and validated overrides.
- `ProgressSimulation.Policy`: pure seeded participation, retry, improvement, and stopping decisions.
- `ProgressSimulation.LearnerRunner`: sequential course actions for one learner and evolving state.
- `ProgressSimulation.Scheduler`: invocation-local due-action scheduling, pacing, and bounded dispatch.
- `Oli.Seeding.Runtime`: shared dev/release bootstrap for the dedicated seeding application role;
  owns only invocation-local services and shuts them down without affecting the server.
- `Oli.Scenarios.LearnerActions`: shared visit/start/save/submit/reset/hint/finalize operations,
  extracted where existing handlers need the same behavior. No scenario-name resolution here.
- `ProgressSimulation.Responses`: adapters for each supported activity configuration using the
  current attempt's full transformed model and actual part IDs.

Use normal evaluation, progress, grading, analytics, and publication boundaries. Do not write scores
or fabricate successful attempts. A sampled correctness target chooses an answer; the evaluator
determines its actual score. Do not reuse the current generic `"other"` response as an incorrect
answer to a choice/order activity when that value could never be submitted by its UI.

### Companion CLI runtime

The current development task in `seeding/lib/mix/tasks/seed.ex` starts the whole application with
`app.start`, while `rel/overlays/bin/seed` uses release `eval`, which does not itself start application
dependencies. Neither is the final companion-runtime contract. In particular, application startup
in `lib/oli/application.ex` invokes inventory recovery with boot semantics; a second full application
can treat another instance's executing inventory work as recoverable and re-enqueue it.

Implement an explicit seeding application role selected before application startup in both entry
points, behind `Oli.Seeding.Runtime`. Audit the lifecycle dependency closure and start required Repo,
caches, evaluator services, job producers, and event infrastructure. Exclude the HTTP endpoint,
unrelated Oban consumers/plugins, upload consumers, and inventory/startup recovery. Do not temporarily
start the full application and then disable children. Preserve dev/preview enablement checks.

Separate job production from job consumption. In particular, `Oli.Delivery.Snapshots` currently uses
Oban `queues: false` to select synchronous execution; disabling consumers must not accidentally change
normal delivery enqueue semantics. Introduce an explicit role-aware consumer configuration or narrow
producer adapter and prove that evaluations/finalizations still enqueue normal downstream jobs.
The dependency audit and a boot test are prerequisites to runner implementation, not release cleanup.

The server processes committed work using its existing services. Promise DB-backed UI visibility
after refresh and analytics after readiness checks. Audit cross-VM PubSub/cache invalidation explicitly:
reuse configured distribution where available, but do not assume independent local PubSub instances
communicate or promise automatic live-dashboard updates. Required invalidation must work across the
two runtimes or fail the companion-runtime gate; it cannot depend on restarting the server.

## 4. Interfaces & Signatures

### Operator-facing YAML

The common form assigns one profile to the selected enrolled learners:

```yaml
- simulate_progress:
    section: demo_section
    users: [demo_learner_1, demo_learner_2]
    profile: persistent_learner
    seed: 42
```

A mixed cohort can be expressed without enumerating every synthetic identity:

```yaml
- bulk_create_enroll_users:
    section: demo_section
    prefix: demo
    instructors: 1
    learners: 40

- simulate_progress:
    section: demo_section
    seed: 42
    profile_version: 1
    cohorts:
      - profile: high_proficiency
        count: 10
      - profile: steady_learner
        count: 15
      - profile: persistent_learner
        count: 10
      - profile: low_engagement
        count: 5
    batch_size: 10
    max_concurrency: 4
    timeout_ms: 120000
```

Omitting top-level `users` selects all enrolled learners, excluding instructors. Counts must sum to
the selected population. Each cohort may use explicit `users: [...]` instead of `count` for exact
QA actors; reject duplicate membership, non-learners, unknown references, and unassigned users.
Reserve explicit assignments first; assign count-based cohorts from a seeded stable ordering of
the remaining learners. Cohort order resolves ties. Assignments remain fixed when batch size changes.

Use either top-level `profile` or `cohorts`. Profile mode is explicit and cannot be mixed with the
legacy top-level `pct_correct` or `assessment_attempts` controls. Legacy mode remains available for
tests that require an exact attempt script. Empty selectors/lists and unknown profile versions fail
validation. Check enrollment and cohort cardinality for the entire invocation before any visit.

### Optional real-time pacing

```yaml
- simulate_progress:
    section: demo_section
    profile: steady_learner
    seed: 42
    timing:
      mode: paced
    batch_size: 10
    max_concurrency: 4
    timeout_ms: 120000
```

- Omit `timing`, or set `timing: {mode: fast}`, for immediate execution with no artificial delays.
- `mode: paced` uses the timing defaults of each learner's profile; no duration is required or
  accepted. Paced mode initially requires profiles/cohorts; legacy explicit scripts remain fast.
- Seeded schedules stagger learner starts and include reading, answering, feedback, retry delays,
  occasional breaks, and gaps between study sessions. Each learner's schedule runs concurrently
  with the other learners' schedules, independent of enrollment batch boundaries.
- Profile version 1 uses bounded triangular distributions with explicit `min`, `typical` (mode),
  and `max` values. This gives common short/moderate delays and occasional longer delays without
  unbounded tails. Each action draws independently from its learner's seeded timing stream. Sample
  a stable learner pace tendency once and use it to adjust the distribution's mode within its bounds;
  never multiply durations in a way that violates the configured minimum or maximum.
- Operator overrides live in the profile's `overrides.timing` (or the cohort's `overrides.timing`):

```yaml
- simulate_progress:
    section: demo_section
    profile: steady_learner
    seed: 42
    timing:
      mode: paced
    overrides:
      timing:
        page_time: {distribution: triangular, min: 10m, typical: 18m, max: 40m}
        retry_delay: {distribution: triangular, min: 60s, typical: 90s, max: 3m}
        break_probability: 0.15
        break_duration: {distribution: triangular, min: 5m, typical: 15m, max: 45m}
```

- Also define `start_delay`, `answer_time`, `session_pages` (inclusive integer range), and
  `session_gap` in each profile. Suggested steady-learner defaults: start delay 0/5/30 minutes,
  answer time 15/45/120 seconds, session length 2–4 pages, and session gap 4/12/24 hours. Other presets
  vary the typical pace, session length, and gaps: low engagement has shorter sessions, more breaks,
  and longer absences; persistent learners spend more time answering and retrying. Preset tables and
  exact values are versioned QA recipes to calibrate during implementation, not empirical claims.
- Duration values accept nonnegative integer `s`, `m`, or `h` units, plus `d` for session gaps.
  Validate `min <= typical <= max`, positive page/answer/retry durations, bounded delays (at most
  seven days per delay), session length 1–100 pages, and probabilities in 0–1. Zero start delay is
  valid; equal endpoints represent a fixed delay for exact tests. Reject unknown distributions.
- `page_time` is sampled once as the minimum residence time before leaving a visited page, including
  answering and retry time. It is not an extra sleep after all activities and its sampled maximum
  does not cap actual time on a page. Leave only after both the planned actions finish and residence
  time has elapsed; many activities/retries can legitimately keep a learner on the page longer.
- `answer_time` delays an initial response; `retry_delay` is the minimum sampled interval from
  receipt of feedback to the next retry action. Apply it even when the MCQ UI would combine reset
  and submit. Do not create empty attempts early just to hold a place in the schedule.
- Sample occasional breaks at page boundaries; use `session_gap` instead when the sampled session
  length is exhausted. Gates with known future opening times may be reconsidered within existing
  action budgets; do not poll indefinitely or silently bypass date restrictions.
- Sample participation per activity opportunity using that learner's participation trait, so
  learners in one cohort can skip different activities, retry different questions, and stop at
  different points. Equal profiles do not share a precomputed itinerary. Independent journeys may
  occasionally coincide by chance; no artificial uniqueness rule should change their behavior.
- Plan only the next due action per learner from actual outcomes. Base successive waits on actual
  action completion, and honor the page residence bound, so scheduler lag never creates a burst of
  retries less than the configured minimum apart. A separate timing stream preserves answer samples;
  actual outcomes may differ when dates, gates, content, or competing learner actions change.
- Finish when every learner reaches a terminal policy outcome, or when the operator stops the task.
  Emit a startup summary of resolved timing profiles and bounded progress at least once per minute,
  including pending actions, active learners, elapsed time, and lag; promise no fixed completion time.
- Run the CLI in a separate shell using the same dev/preview database as the running server. The
  invocation owns only its scheduler and simulation workers; stopping it must not stop the web server.
  Subsequent YAML directives execute only on normal completion, not after operator interruption.
- On Ctrl-C/process termination, stop dispatch for all learners immediately, cancel timers and queued
  actions, and shut down owned workers with a bounded grace period for in-flight atomic operations.
  Do not perform extra save/finalize/reset actions to finish a journey. A transaction already in
  flight may commit; completed data remains and unfinished transactions follow normal rollback.
  Report `interrupted` when graceful reporting is possible, with a conventional interrupted exit status,
  not a learner failure. Abrupt termination may not emit a summary. No automatic restart or resume.
- Existing server jobs resulting from already committed actions retain their normal lifecycle (for
  example analytics processing or configured assessment auto-submission). The simulator does not
  cancel these server-owned jobs; it must never leave detached simulated learners running.

### Profiles and overrides

Presets are synthetic QA behavior recipes, not classifications stored on real learner accounts.
Each learner receives fixed seeded variation within a preset; each action receives its own sample.

| Preset | Initial answer probability | Course reach | Practice participation | Persistence |
| --- | --- | --- | --- | --- |
| `high_proficiency` | 0.85–0.95 | 0.90–1.00 | 0.85–1.00 | Retry occasional misses; usually one assessment submission |
| `steady_learner` | 0.60–0.80 | 0.80–1.00 | 0.75–0.95 | Moderate practice and assessment retries |
| `persistent_learner` | 0.30–0.55 | 0.90–1.00 | 0.90–1.00 | Frequent practice retries and remediation before reassessment |
| `low_engagement` | 0.45–0.85 | 0.15–0.55 | 0.25–0.60 | Skipped practice, few retries, early stopping |

These are proposed version-1 defaults. Low engagement deliberately does not imply low proficiency.
Expose validated overrides so a cohort can be proficient but disengaged, or weak but persistent:

```yaml
- simulate_progress:
    section: demo_section
    users: [demo_learner_1, demo_learner_2]
    profile: high_proficiency
    overrides:
      course_reach: [0.3, 0.5]
      practice_participation: [0.2, 0.4]
      practice_retry_probability: 0.2
      assessment_retry_probability: 0.1
    seed: 42
```

Version-1 parameter contract (the same overrides are permitted within a cohort):

- `initial_correctness`, `course_reach`, `practice_participation`: inclusive `[min, max]`
  ranges within 0–1, sampled once per learner. Use equal endpoints for a fixed value.
- `start_probability`: probability of starting the course; default 1, low-engagement preset 0.8.
- `practice_retry_probability`, `assessment_retry_probability`, `hint_probability`: 0–1.
- `max_practice_attempts`, `max_assessment_attempts`: total attempts, integers 1–10; delivery
  limits still apply. Proposed preset caps: high 2/2, steady 3/2, persistent 4/3, low 2/1.
- `practice_target`, `assessment_target`: score ratios within 0–1 at which to stop retrying.
  Proposed targets: high 1.0/0.9, steady 1.0/0.8, persistent 1.0/0.8, low 0.8/0.6.
- `learning_gain`: nonnegative bounded probability gain per relevant completed retry/remediation
  step, capped overall at 0.98. Proposed defaults: high 0.03, steady 0.08, persistent 0.12, low 0.03.

Remaining preset defaults: retry probabilities (practice/assessment) high 0.6/0.3, steady 0.7/0.5,
persistent 0.9/0.8, low 0.2/0.1; hint probabilities high 0.1, steady 0.3, persistent 0.6, low 0.1.
Presets and formulas are versioned so tuning demo behavior does not silently change older scenarios.

### Internal operations

Proposed contracts, using explicit structs/types during implementation:

```elixir
Profiles.resolve(name, version, overrides) :: {:ok, profile} | {:error, validation_error}
Policy.next_action(learner_state, course, observations) :: action | {:stop, reason}
LearnerActions.perform(context, action) :: {:ok, observation} | {:blocked, reason} | {:error, reason}
LearnerRunner.step(context, learner_state, action) ::
  {:ok, learner_state, observation} | {:stop, learner_outcome} | {:error, reason}
ProgressSimulation.run(section, selected_users, opts) ::
  {:ok, summary} | {:interrupted, summary} | {:error, reason, summary}
```

An observation includes actual scores, active attempt/part identities, supported model, and allowed
next actions. The runner owns session identity; retrying a question does not inherently create a new
student session. Reset returns new GUIDs immediately; read the full stored model when the public
reset response contains only a pruned delivery model. Revalidate answer generation after replacement.

Profile-mode summary distinguishes `processed`, `course_complete`, `partial`, `not_started`,
`blocked`, and `failed`, plus pages visited, practice submissions, part resets, activity resets,
assessment submissions, retry limits reached, and unsupported-content counts. Report bounded
per-profile totals and warning samples. A successfully processed partial learner is not a failure.
Keep legacy result fields stable for legacy mode; do not reinterpret `completed` as course completion.

### Invocation-wide interruption

Propagate a terminal `{:interrupted, partial_result}` outcome through the directive handler, Engine,
nested `use` execution, `SeedExecution`, CLI, and Mix entry point. Every enclosing directive loop must
halt on it, including non-ownership execution; it is not an ordinary recoverable directive error.
Preserve partial counters and an explicit `result_code: interrupted` in the bounded CLI summary.
Do not let broad rescue/catch handling convert this outcome to `execution_failed`, or `Mix.raise`
collapse a graceful signal exit into ordinary exit code 1. Map handled SIGINT/SIGTERM to 130/143.

Install signal handling before dispatch, with a shared cancellation token and invocation-owned
supervision tree. Signal handling stops dispatch immediately, discards queued work, and permits at
most five seconds for an already in-flight atomic action before terminating owned workers. Abrupt
parent death must also terminate workers; no detached tasks survive. A committed transaction can
remain, but no additional learner action may be scheduled to tidy up partial work. Signal delivery,
exit-code propagation through shell/Mix wrappers, and forced termination require process-level tests;
abrupt kills need not produce a summary. Server-owned jobs for committed actions are unaffected.

## 5. Data Flow & Edge Cases

### Course traversal and improvement

1. Resolve enrollment, profile definitions, cohort assignments, section curriculum, and work bounds.
   Traverse delivered section hierarchy in learner order, including unnumbered pages and section
   customizations. Resource IDs and authored project title maps are not navigation order.
2. Sample each learner's traits and course reach. Walk a prefix of the ordered course, then stop;
   sample practice participation within visited pages. Zero reach/no start must create no page visits.
3. Check visibility, gating, date/password policy, and effective learner settings before acting.
   A blocked page is recorded and independent later pages may be visited; do not auto-unlock content.
4. On a practice page, submit selected supported questions. After observing an inadequate score,
   sample whether the learner persists. If so, optionally request an available hint, reset the
   activity or part as its UI does, and resubmit. Stop at target, persistence decision, or attempt cap.
5. On a batch-scored page, start a real assessment, save responses, and finalize through the same
   delivery boundary as the UI. Use the finalized score to decide on a further assessment attempt.
   Do not reveal/evaluate feedback early just to drive the simulator. Score-as-you-go pages need
   their own submission adapter and policy tests; until supported, report that configuration.
6. Before reassessment, a persistent learner may revisit up to three prior eligible practice pages
   and retry below-target questions within the same per-question budget. Prefer shared objectives;
   if absent, choose nearby preceding practice deterministically. Never reset the whole practice page
   just to circumvent question limits. Keep this remediation bound fixed in profile version 1.
7. Maintain a bounded learned-correctness increment per objective. Successful practice and feedback
   exposure apply the configured gain once per completed learning step; questions without objective
   metadata use a learner-global fallback. Multiple linked objectives use their mean increment,
   preventing extra objective tags from multiplying the gain. Actual scores may fall on a later try.
8. Finish when the learner reaches their selected stopping point or exhausts work. Read resulting
   progress/grades from domain state; do not mark all visited pages or processed learners complete.

### Response and lifecycle fidelity

- MCQ: choose a real available choice; subsequent selections reset the whole evaluated activity.
- Ordering: submit a permutation of the delivered choices; retry through whole-activity reset.
- Check-all-that-apply: submit a valid choice subset; retry through whole-activity reset.
- Short answer: support authored rules for which a valid answer can be generated and checked;
  report other rule forms as unsupported rather than treating regex text as a learner answer.
- Multi-input: use `submitPerPart` and input type. Per-part mode preserves the activity attempt and
  creates part retries only for selected unsuccessful parts. Whole-activity mode creates activity
  retries with fresh parts. Therefore three learner tries do not always mean three activity records.
- Respect actual transformed content, part scoring strategy, retries, hint availability, and terminal
  states. Resolve submitted values by stable part IDs rather than positional assumptions.
- Progress records completion of work, not mastery. Practice retries preserve historical evaluation
  records; normal grading determines whether best, latest, or average scores are retained.

### Determinism, existing data, and bounds

- Seed keys use explicit seed, profile version, stable learner subject/reference, section identity,
  stable page/activity identity, part identity, and action/attempt index. Avoid auto-increment IDs
  and global RNG dependence in profile mode. Separate streams for participation, answers, and retries.
- Exact replay across rebuilt demo environments requires stable scenario content keys; imported
  content uses preserved resource identity where available. Report the identity/content fingerprint
  used. Do not promise equivalence across changed publications or unseeded dynamic transformations.
- Initial profile mode requires selected learners with no existing page access/attempt history in
  the section. Fail preflight otherwise. This gives a clear first supported contract and avoids
  silently adding another course's worth of attempts on rerun. No automatic cleanup is performed.
- Resume/reconciliation is a later extension and a dependency for a retry-safe deployment demo.
  A deterministic seed is not idempotency; ordinary attempt IDs do not identify a simulation run.
- Shared immutable course inputs are loaded once. Learner-dependent settings, realized pools, and
  active attempts are obtained when needed. Park only learner/session IDs, curriculum cursor, sampled
  traits, RNG/action counters, due time, page-entry time, remaining budgets, and compact retry/objective
  counters. Never retain full models, Ecto association graphs, observations, or completed action history
  for sleeping learners. Sparse retry/objective counters are bounded by course cardinality and action
  limits; retain only necessary recent remediation IDs. Reload current models around dispatch, release
  them afterward, and reduce observations/results incrementally into bounded totals and warning samples.
- Bound selected learners to 10,000, cohorts to 100, configured attempt caps to 10, and actions per
  learner to 10,000. Keep concurrency cap 16 (default 4) and batch-size cap 100. Add `max_actions`
  for the whole invocation: default 100,000, operator-adjustable from 1 to a hard cap of 1,000,000.
  Count every dispatched domain action, including reads/visits, hints, saves, resets, submissions,
  finalizations, and blocked attempts; waiting consumes none. Preflight a conservative course/cohort
  estimate before mutation and reject estimates exceeding the budget. Dynamic pools are additionally
  constrained by the shared dispatch counter; exhaustion terminates the invocation as `budget_exhausted`
  with partial results, not silent success. The population limit is not a promise that every population
  fits every course/budget. One invocation-wide counter prevents parallel workers overspending it.
- Use incremental result reduction and enforce `timeout_ms` as a per-learner cumulative active-work
  budget in profile mode, excluding all scheduled waiting. Cap each dispatched action by that learner's
  remaining budget, including when concurrency is one. Preserve legacy timeout semantics; the current
  legacy sequential branch's missing timeout enforcement must also be addressed explicitly.
- In paced mode, use a bounded in-memory due-action queue with at most one pending action per learner
  and no more than one in flight for that learner. Dispatch only due work, bounded by concurrency;
  `batch_size` bounds a dispatch slice, not a group that must finish the course before others start.
  Keep no database transaction, connection, or worker task open across a scheduled delay. Use timers
  and a monotonic elapsed clock to wait; ordinary persistence uses the real system clock.
- Backpressure delays overdue work without violating order or concurrency. Apply the load policy below
  in both fast and paced modes. Measure schedule lag and
  report inability to keep pace. Refresh policy/settings at action boundaries and fail/report stale
  external state rather than silently acting against superseded attempts. No new Oban seed jobs,
  durable scheduler records, or web-runtime coordinator are introduced.
- Course policies limiting attempts are ordinary constrained outcomes. Unexpected lifecycle errors
  and timeouts are failures, with partial committed actions reported. Continue independent learners.
- CLI exit must reflect actual failures; retain separate counters for modeled disengagement, policy
  blocking, and unsupported content. Never silently equate a worker return with a successful course.

### Downstream load and retained-state budgets

Worker concurrency does not bound the snapshot/analytics jobs produced by evaluation and assessment
finalization. Add a global dispatch token bucket: default 10 domain actions/second, burst at most
`max_concurrency`, validated operator range 1–50 actions/second. Fast mode omits learner delays but
still respects this rate and backpressure; pacing never accelerates to catch up after a pause.

Before mutation, discover the normal downstream queues from the delivery dependency audit and verify
read-only backlog measurement is available. Count ready/retryable/executing work and scheduled work
due now in those queues across the shared environment, not only jobs from this invocation. Pause
dispatch at 1,000 outstanding jobs and resume at 500 or fewer; check before initial dispatch and at
most once per second thereafter. These are conservative v1 operational defaults to verify on the
demo, not a throughput guarantee. Delayed future jobs such as assessment auto-submit are excluded
until due. Observe backlog without reserving jobs, cancelling existing work, or holding a transaction.
Small in-flight/polling overshoot is expected and must be measured; never claim a strict queue cap.

If queue observation fails, pause and report the issue rather than continuing blind. Five continuous
minutes of load/observation pause terminates with `downstream_overloaded` and partial results; an
operator may retry after restoring capacity under the documented fresh-history/reconciliation rules.
This is a safety failure, not a learner timing window or modeled disengagement. Report action rate,
queue depth, throttle reason, lag, and active/paused counts in bounded progress output. A server or
normal external consumer must drain queued work; the companion CLI does not take over its consumers.

Measure scheduler-owned retained memory with 10,000 logical waiting learners on a fixed small course:
target at most 64 MiB excluding the single shared course representation and the application baseline.
Exercise many completed actions to prove no retained-history growth for fixed course/learner counts.
Also test increasing objective/activity cardinality, document the measured supported course envelope,
and reject inputs exceeding that envelope before dispatch. Keep large scheduler tests pure; they do
not require creating 10,000 database learners. Measure full-process memory and DB/queue load separately
on the real 40-learner example so the compact-state target does not hide shared-input/runtime costs.

### Deferred backdating and analytics readiness

Add an explicit historical window only after tracing every affected timestamp and analytics producer.
`Oli.DateTime` overrides are process-local; activity reset and hierarchy code also call
`DateTime.utc_now()`, and progress SQL uses `NOW()`. A `time` directive alone cannot consistently date
the resulting activity history, jobs, snapshots, and engagement records.

The historical slice must define ordered session/action timestamps per learner, propagate time to
worker processes and supported lifecycle/analytics boundaries, and verify enrollment/access/attempt/
snapshot consistency. Prefer explicit clock context/default-real-time APIs. Do not bulk-rewrite only
attempt timestamps after evaluation. No sleeping for simulated days. Date gates and deadlines must
use the same event clock. This deferred work is not required for paced mode, which uses actual time
throughout the existing application. Paced mode must reject an active scenario-time override rather
than combining real wall-clock pacing with partial clock substitution.

Analytics readiness is a separate end-of-scenario step using existing supported analytics operations.
Real delivery actions may produce asynchronous work; successful simulation does not by itself mean
every downstream dashboard is ready. Report unsupported datasets rather than claiming all analytics.

## 6. Test Plan

Unit tests cover deterministic assignments, pure retry/stop policy, parameter validation, bounds,
stable sampling, and response validity against native evaluators. Use fixed logical identities;
do not assert that two tiny random cohorts must always have ordered aggregate grades.

Integration scenarios use real project creation, publishing, sections, enrollment, and lifecycle calls:

- Practice pages contain all five supported types and both multi-input submission modes. Verify
  activity and part histories, preserved page attempt identity, retained hints, valid responses,
  and progress derived from actual submissions.
- Assessment pages allow multiple submissions with explicit best/latest/average settings. Verify
  distinct assessment attempts, saved/evaluated part state, finalization, and gradebook aggregation.
- Fixed policies (probability 0 or 1) guarantee retries, stopping, no start, partial completion, and
  limit handling. Test probabilistic profiles over a larger fixed population with sensible ranges.
- Compare normalized outcomes for different batch sizes/concurrency and rebuilt stable fixtures.
- Test timing validation, triangular sampling bounds, learner-specific journeys, activity skipping,
  session breaks, cross-cohort interleaving, lag/backpressure, and exclusion of idle time from work
  budgets. Use a controlled scheduler clock for unit tests; do not wait hours in CI. Verify page
  residence and minimum retry delays even under delayed dispatch, with no total-duration cutoff.
- Add a short real-time integration run proving separated actual persistence timestamps and no idle
  transactions or occupied workers. Test Ctrl-C/termination with pending and in-flight actions: all
  owned learner workers stop, committed attempts remain, unfinished assessments are not force-submitted,
  subsequent directives do not execute, and the concurrently running server stays available. Distinguish
  server-owned processing of committed actions from prohibited detached simulation work.
- Reject scenario-time overrides in paced mode. Verify immediate default execution and matching
  behavior decisions when fast/paced runs encounter equivalent external state. Verify the documented
  CLI process-lifetime behavior for both development and preview entry points.
- Test unknown content/rules, transformed choices, stale GUIDs, dynamic replacement, learner settings,
  gating, date/password restrictions, existing history, timeout, and partial failure counters.
- Verify legacy explicit-attempt and single-`pct_correct` behavior remains compatible.
- Run the supported mixed-cohort scenario through dev `mix seed` and preview `bin/seed`. Inspect
  learner histories, instructor gradebook, practice progress, and explicitly supported analytics.
- Boot each actual CLI entry point alongside a running server. Prove required dependencies start,
  no second endpoint/consumer or startup recovery runs, an unrelated executing inventory batch remains
  untouched, normal delivery jobs enqueue, and server-visible state/cache invalidation works.
- Send SIGINT and SIGTERM during waits and in-flight actions through dev and release wrappers.
  Verify 130/143, terminal propagation through nested `use` and non-ownership Engine loops, no later
  directives, bounded worker shutdown, and no generic failure rewrite. Include abrupt parent death.
- Use controlled queue observations to verify rate limits, high/low-water hysteresis, measurement
  failure, overload termination, and unchanged unrelated jobs. Measure real queue growth and server
  responsiveness with the demo, including an existing backlog; quantify polling/in-flight overshoot.
- Exercise 10,000 logical parked learners and repeated completed actions; measure retained memory,
  ensure models/history are released, and test course-cardinality and whole-run budget rejection.

### Replace the Phase 4 progress examples

Update `test/oli/scenarios/data/progress_simulation.scenario.yaml` in place to be the canonical
40-learner mixed-profile course scenario. Preserve its useful course setup: the two ungraded pages
before the assessment, native activity coverage, and configurable repeated assessment submissions.
Extend that setup with objective links and retry policies needed for profile-driven practice and
remediation. Replace its existing learner-group `pct_correct`/`assessment_attempts` simulation blocks
with the cohort-driven operation; do not leave them running alongside the new operation on the same
learners. Fresh-history preflight would correctly reject that double simulation.

Rewrite `test/oli/scenarios/progress_simulation_scenario_test.exs` to verify the new canonical
scenario's participation, practice/part retries, assessment histories, and actual grade/progress
outcomes. Retain exact-script compatibility cases in `progress_simulation_test.exs` and
`data_generation_directives_test.exs`, adding focused legacy cases if the replaced runner supplied
unique coverage. Preserve `Oli.Scenarios.Hooks.create_bulk_users/1` and its independent example.

Update `test/support/scenarios/README.md` and CLI documentation/references to use the same canonical
file path. Keep its default fast for local QA/CI. Supply a documented paced variant using the same
course setup and profile contract, with timing changed to paced, and test it with controlled/short
delays. Do not duplicate a second divergent demo course or advertise an unimplemented CLI override.
The replacement and its dev/preview verification are Phase 4B deliverables, not deferred to Phase 5.

Deliver Phase 4B in four dependency-ordered increments:

1. Dedicated companion-runtime dependency audit/bootstrap and invocation-wide cancellation contracts,
   verified through both real entry points before long-running scheduling is added.
2. Shared learner operations and valid native-response adapters, including whole-activity/per-part
   practice retries and authentic batch-scored assessment submission.
3. Versioned profiles, deterministic policy, cohort assignment, ordered traversal, bounded runner,
   structured summary, compact paced scheduler, and rate/backlog protection. Keep explicit scripts
   available for exact QA cases.
4. Replace the existing Phase 4 progress example/runner with the supported mixed-cohort scenario,
   objective links, retry policies, validation, release/dev execution, and documented expected UI states.

Historical session/analytics time contracts remain deferred; existing-history reconciliation is a
separate Phase 5 dependency. Neither capability is implied by completion of these four increments.

Implementation gates: schema validation, targeted ExUnit integration and legacy suites, compilation,
formatting, security/performance review, and bounded-work measurement on the 40-learner demo.
Also require isolated companion boot, terminal cancellation, downstream-load protection, and the
10,000-learner compact-state benchmark; failures in these gates block the paced capability claim.
This design-only change requires document validation and `git diff --check`.

## 7. Risks & Open Questions

- Presets are demo defaults and require calibration against the representative course. Their numbers
  do not represent scientifically validated learner populations.
- Arbitrary author rules, dynamic pools, advanced activities, and score-as-you-go assessments need
  explicit support, not an activity-slug-only guarantee. Report supported capabilities by configuration.
- Correctness probabilities can improve without every observed score increasing. Enforcing a target
  grade by overwriting results would invalidate the dataset; use explicit scripts for exact outcomes.
- Course access checks currently span UI orchestration and backend lifecycles. Extract/reuse checks
  before claiming learner-equivalent traversal, including section-specific visibility and audience.
- Large simulations generate real analytics/background work. Existing dev/preview containment and
  synthetic-data requirements apply; add no production-clone safety claim or seed-specific job system.
- Historical date fidelity and resumable reruns remain separately scoped work. The first release
  should advertise fast or paced fresh-section simulation and explicitly list those limitations.
- Paced runs depend on their invoking process remaining alive and can encounter real deadlines,
  auto-submit jobs, or external edits. They must recheck learner state and report constrained or
  unfinished work. Runtime emerges from independently sampled journeys; operator interruption is
  an ordinary supported stop, not a reason to finish or erase the learners' remaining work.

No blocking product question is required to review this proposal. Preset values, the four initial
profile names, and historical simulation priority are concrete defaults open to refinement.

## 8. Definition of Done

- [x] Requirement coverage is explicit
- [x] Interfaces are concrete
- [x] Test plan covers main and edge paths
- [x] Validation passes

Design completion does not indicate implementation completion. The supported demo is delivered only
after increments 1–4 pass their integration and CLI checks.
