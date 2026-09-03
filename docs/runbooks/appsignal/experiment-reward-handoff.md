# Experiment Reward Handoff AppSignal Runbook

## Purpose

This runbook configures production monitoring for synchronous experiment reward processing during
learner-attempt completion. Automatic finalization, manual grading, and auto-submit perform one
bounded active-Thompson section check. Participating sections record the accepted reward and update
the policy posterior in the same database transaction that evaluates the resource attempt. The
analytics-only snapshot path later reads that committed reward for the authoritative xAPI statement.

Use this runbook to:

- create the AppSignal dashboard and alerts required to observe reward latency and failures;
- distinguish policy-lock contention from general request, Oban, or database pressure;
- decide when to revisit set-oriented eligibility loading; and
- validate that telemetry is arriving after deployment.

The metrics contain only bounded status tags. They do not contain user, section, experiment,
resource, or resource-attempt identifiers.

## Delivery Guarantee

After a graded resource attempt becomes evaluated, learner-attempt processing checks whether its
section participates in an active Thompson Sampling experiment. A negative result bypasses all
reward work. A positive result records the reward before the surrounding attempt transaction can
commit. Reward-processing failure rolls back the submission; accepted reward identity and the
posterior update commit atomically. Snapshot processing never mutates reward or policy state.

## Prerequisites

- AppSignal is active and `APPSIGNAL_PUSH_API_KEY` is configured for the environment.
- The deployment includes `Oli.Delivery.Experiments.Telemetry` in the application supervision tree.
- AppSignal's automatic Phoenix, Oban, and Ecto instrumentation is enabled. Torus does not disable
  these integrations in repository configuration.
- At least one attempt has completed in a section participating in an active Thompson Sampling
  experiment after deployment.

Phoenix LiveDashboard is useful for current node, VM, and Ecto health, but it does not register the
reward-handoff custom events. AppSignal is the durable monitoring surface for the metrics below.

## Custom Metrics

All custom metrics use the prefix `oli.experiments.reward_handoff`.

| Metric | Type | Status values | Meaning |
| --- | --- | --- | --- |
| `batch.duration_ms` | Distribution | `ok`, `error`, `unknown` | End-to-end time spent processing one loaded reward batch. |
| `batch.attempt_count` | Distribution | `ok`, `error`, `unknown` | Valid resource-attempt IDs requested by the batch. |
| `batch.context_count` | Distribution | `ok`, `error`, `unknown` | Attempt contexts found and processed. |
| `batch.failure_count` | Distribution | `ok`, `error`, `unknown` | Attempts that failed during the batch. |
| `batch.completed` | Counter | `ok`, `error`, `unknown` | Completed reward batches. |
| `eligibility.duration_ms` | Distribution | `matched`, `empty`, `error`, `unknown` | Time spent validating scope, finding branch matches, querying assignments when needed, and filtering results for one attempt. |
| `eligibility.assignment_count` | Distribution | `matched`, `empty`, `error`, `unknown` | Eligible assignments returned for one attempt. |
| `eligibility.lookup` | Counter | `matched`, `empty`, `error`, `unknown` | Eligibility lookups attempted. |
| `eligibility.assignment_query` | Counter | `matched`, `empty`, `error`, `unknown` | PostgreSQL assignment queries executed. A lookup with no matching alternatives branch contributes zero. |
| `outcome` | Counter | `accepted`, `duplicate`, or `skipped`; bounded `reason` | Reward dispositions. Reasons are restricted to the allowlist in `Oli.Delivery.Experiments.Telemetry`. |
| `failure` | Counter | Bounded `reason` | Synchronous reward-processing failures. Reasons are restricted to the allowlist in `Oli.Delivery.Experiments.Telemetry`. |

Metric names are emitted exactly as `oli.experiments.reward_handoff.<metric>`. Status, outcome, and
bounded reason are the only custom dimensions. Do not add experiment, decision-point, intervention,
binding, attempt, section, enrollment, author, or learner identifiers as AppSignal tags.

## Dashboard Configuration

Create an AppSignal dashboard named **Experiment reward handoff**. Use the production environment,
and configure the following graphs. AppSignal UI labels can vary by agent and dashboard version;
select the named custom metric and aggregation rather than relying on a particular menu location.

### 1. Batch latency

- Metric: `oli.experiments.reward_handoff.batch.duration_ms`
- Visualization: line chart
- Aggregations: p50, p95, and p99
- Group by: `status`

Rising p95 or p99 latency indicates slow batches. Compare it with batch size and eligibility latency
before attributing the change to per-attempt queries.

### 2. Eligibility latency

- Metric: `oli.experiments.reward_handoff.eligibility.duration_ms`
- Visualization: line chart
- Aggregations: p50, p95, and p99
- Group by: `status`

If eligibility latency rises with batch latency, inspect a sampled Oban transaction and its Ecto
event timeline. If batch latency rises while eligibility latency remains flat, investigate reward
persistence, policy updates, or general worker/database contention instead.

### 3. Batch size and loaded contexts

- Metrics:
  - `oli.experiments.reward_handoff.batch.attempt_count`
  - `oli.experiments.reward_handoff.batch.context_count`
- Visualization: line chart
- Aggregations: average and p95

A persistent difference between attempt and context counts means requested attempts are not being
loaded. Investigate stale IDs, evaluation state, or page-finalization enqueue behavior before
treating this as query-amplification slowness.

### 4. Query amplification

- Metrics:
  - `oli.experiments.reward_handoff.eligibility.assignment_query` as a rate or sum
  - `oli.experiments.reward_handoff.batch.completed` as a rate or sum
  - `oli.experiments.reward_handoff.eligibility.lookup` as a rate or sum
- Visualization: line chart
- Use the same time interval for all series.

The assignment-query count divided by completed batches approximates assignment queries per batch.
The assignment-query count divided by eligibility lookups shows the share of attempts whose page
content required an assignment query. Compare these ratios with average and p95 batch size.

### 5. Failures

- Metrics:
  - `oli.experiments.reward_handoff.failure`, grouped by `reason`
  - `oli.experiments.reward_handoff.batch.failure_count`
  - `oli.experiments.reward_handoff.batch.completed`, filtered to `status=error`
- Visualization: value and line charts
- Aggregation: sum

Any sustained nonzero value requires investigation. Search AppSignal logs for the stable message
`Thompson reward processing failed` during the same window. Those structured log entries include
the bounded failure classification plus the section and resource-attempt identifiers for
correlation; the identifiers are deliberately excluded from metric tags. AppSignal's automatic
Phoenix and Oban instrumentation should provide the failed transaction, exception, and retry
details where applicable.

### 6. Learner-attempt transaction performance

Add or save AppSignal performance views for the learner submission/finalization transactions used by
automatic evaluation and manual grading. Include throughput, error rate, and p95 duration. For
auto-submit, also add these metrics supplied by AppSignal's automatic Oban integration:

- `oban_job_duration`, filtered to
  `worker=Elixir.Oli.Delivery.Attempts.AutoSubmit.Worker`, grouped by `state`;
- `oban_job_count`, with the same worker filter, grouped by `state`; and
- `oban_job_queue_time`, filtered to `queue=auto_submit`, as supporting evidence of queue contention.

AppSignal includes Ecto events in sampled transaction timelines; these samples are the primary way
to identify the exact repeated or slow query after the aggregate custom metrics identify a
problematic period.

## Initial Alerts

Treat these as starting values, not permanent service-level objectives. Review the first one to two
weeks of representative production data and tune thresholds to normal batch sizes and traffic.

| Alert | Initial condition | Purpose |
| --- | --- | --- |
| Synchronous reward failure | At least one `failure` event in 10 minutes | Detect a learner-attempt reward failure and group recurring failures by bounded reason. |
| Reward batch errors | At least one `batch.completed` event with `status=error` in 10 minutes | Detect partial or complete reward failures promptly. |
| Reward batch latency | `batch.duration_ms` p95 above 2,000 ms for 15 minutes with at least 10 completed batches | Detect sustained worker degradation while avoiding alerts from isolated jobs. |
| Eligibility latency | `eligibility.duration_ms` p95 above 500 ms for 15 minutes with at least 25 lookups | Identify assignment lookup or database degradation. |
| Query amplification | Assignment-query count per completed batch above 20 for 30 minutes | Identify batches large enough for the deferred set-oriented lookup to be valuable. |
| Missing telemetry | Thompson attempt transactions are present but reward outcome telemetry has no data for 30 minutes | Detect a detached handler, an incorrect relevance gate, or metric-delivery problem. |

If the AppSignal alert builder cannot express a ratio, graph both counters and evaluate the ratio
during investigation. If it cannot compare transaction presence with missing custom-metric data,
treat the missing-telemetry condition as a deployment check rather than an automated alert. Do not
encode section or learner IDs as tags to make either condition more granular.

## Investigation Procedure

1. Confirm the affected time window and reason in the synchronous failure graph.
2. Search logs for `Thompson reward processing failed` in that window and use its identifiers to
   correlate the failure with the relevant transaction.
3. Compare batch duration with attempt count, context count, and eligibility duration when legacy
   batch processing is involved.
4. Calculate assignment queries per completed batch for the same window when applicable.
5. Open AppSignal performance samples for affected learner-attempt transactions in that window.
6. Inspect the Ecto event timeline for repeated eligibility-assignment queries and individually slow
   queries.
7. For auto-submit, check Oban throughput, retries, and execution time in the `auto_submit` queue.
8. Use Phoenix LiveDashboard to check current Ecto latency, database pool pressure, scheduler usage,
   memory, and node health when the issue is ongoing.
9. Compare other AppSignal Phoenix/Ecto transaction performance. Broad degradation suggests shared
   database or infrastructure pressure rather than reward-handoff query amplification.

## Optimization Decision

Revisit set-oriented reward eligibility loading when representative production data shows all of
the following:

- batch duration increases materially with batch attempt count;
- eligibility duration accounts for a meaningful portion of batch duration;
- assignment queries per batch are consistently high rather than isolated outliers; and
- AppSignal transaction samples show policy-row lock waits or repeated eligibility queries, rather
  than general database pressure, as the dominant cost.

Correctness failures, missing contexts, or reward persistence errors should be fixed independently;
batching eligibility queries is not the remedy for those conditions.

## Post-Deployment Validation

- [ ] Confirm AppSignal receives reward outcome telemetry after a Thompson attempt completes.
- [ ] Confirm an induced Thompson reward failure increments `failure`, retains a bounded `reason`,
      and produces a `Thompson reward processing failed` log entry.
- [ ] Confirm all batch and eligibility distributions appear on the dashboard.
- [ ] Confirm only documented `status` values are present.
- [ ] Confirm AppSignal learner-attempt samples contain the relevance, accepted-reward, and
      policy-state Ecto timeline events.
- [ ] Confirm the dashboard time range and environment match the deployment being validated.
- [ ] Exercise alert notification routing in a non-production environment or through AppSignal's
      alert test facility.
- [ ] Record the production baseline and revise the initial thresholds after representative usage.

## Deployment and Rollback Order

Ship this feature as one release unit; the intermediate phase commits are not independently
deployable.

1. Apply the PostgreSQL migrations in timestamp order, followed by the additive ClickHouse
   migration. The new ClickHouse evidence fields are nullable, so existing rows and older producers
   remain valid.
2. Deploy web nodes and auto-submit Oban workers from the same release so learner-driven and
   scheduled finalization use identical synchronous reward semantics.
3. Verify reward-handoff telemetry, then configure the dashboard and alerts above. Dashboard
   creation is an external operational action and is not performed by repository deployment.
4. For code rollback, first pause or drain the affected Oban queue, deploy code that still reads
   both `experiment_controlled` and the legacy `upgrade_decision_point` alias, and only then consider
   schema rollback. Do not roll back PostgreSQL after intervention-scoped production writes unless
   the data-loss implications have been reviewed. ClickHouse rollback removes only the additive
   nullable columns.

No content backfill, historical revision rewrite, author re-save, forced republication, or
feature-specific experiment conversion job is part of deployment or rollback.
