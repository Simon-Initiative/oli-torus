# ClickHouse Query Cookbook for Native Experiments

These examples assume access to `raw_events` and `experiment_attributions`. Replace the example
IDs and timestamps. Always scope queries by section, project, experiment, and time range when those
values are known. See the [Glossary](glossary.md) for definitions of ClickHouse and experiment terms.

Because both tables use `ReplacingMergeTree`, the examples use `FINAL` for simple correctness.
For large production analyses, consider an equivalent latest-version strategy after measuring the
cost.

## Initial condition assignments by condition

Count dedicated initial condition-assignment events. Each newly persisted sticky assignment emits
one such row; later reuse does not emit another:

```sql
SELECT
    condition_code,
    assignment_scope,
    uniqExact(assignment_id) AS assignments,
    assignments / sum(assignments) OVER () AS assignment_share
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND experiment_role = 'assignment'
  AND attribution_type = 'assignment'
  AND raw_event_type = 'experiment_condition_assigned'
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY condition_code, assignment_scope
ORDER BY condition_code, assignment_scope;
```

`uniqExact(assignment_id)` protects the result from replay duplicates. These records use the
existing xAPI delivery path, so PostgreSQL remains authoritative if delivery or ingestion fails.

## Assignment exposure funnel

```sql
SELECT
    condition_code,
    uniqExactIf(
      assignment_id,
      attribution_type = 'assignment' AND raw_event_type = 'experiment_condition_assigned'
    ) AS assigned,
    uniqExactIf(assignment_id, attribution_type = 'exposure') AS exposed_assignments,
    exposed_assignments / nullIf(assigned, 0) AS assignment_exposure_rate
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND assignment_id IS NOT NULL
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY condition_code
ORDER BY condition_code;
```

This is an assignment-level funnel. For intervention-scoped experiments, one enrollment can have
multiple assignments. To report participant reach instead, replace `assignment_id` with
`enrollment_id` in both `uniqExact` expressions.

## Complete evaluated-activity outcomes by assigned condition

This ASOF pattern keeps all evaluated activities in the selected section/project and associates
each with the latest assignment evidence at or before evaluation. It is appropriate for
section-wide UpGrade-style outcome analysis; it is not proof that every activity was inside the
experiment-controlled branch.

```sql
SELECT
    raw.enrollment_id,
    evidence.condition_code,
    raw.activity_id,
    raw.activity_attempt_guid,
    raw.activity_attempt_number,
    raw.timestamp,
    raw.score,
    raw.out_of,
    if(
      isNull(raw.score) OR isNull(raw.out_of) OR raw.score = 0 OR raw.out_of = 0,
      toFloat64(0),
      ifNotFinite(raw.score / raw.out_of, toFloat64(0))
    ) AS correctness
FROM
(
    SELECT *
    FROM raw_events FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND event_type = 'activity_attempt'
      AND verb_id = 'http://adlnet.gov/expapi/verbs/evaluated'
      AND enrollment_id IS NOT NULL
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
    ORDER BY section_id, project_id, enrollment_id, timestamp
) AS raw
ASOF LEFT JOIN
(
    SELECT
        section_id,
        project_id,
        enrollment_id,
        timestamp,
        argMax(condition_code, tuple(event_version, attribution_hash)) AS condition_code
    FROM experiment_attributions FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND experiment_id = 101
      AND attribution_type IN ('assignment', 'exposure')
      AND enrollment_id IS NOT NULL
      AND condition_code IS NOT NULL
      AND timestamp >= toDateTime64('2026-07-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
    GROUP BY section_id, project_id, enrollment_id, timestamp
    ORDER BY section_id, project_id, enrollment_id, timestamp
) AS evidence
ON raw.section_id = evidence.section_id
AND raw.project_id = evidence.project_id
AND raw.enrollment_id = evidence.enrollment_id
AND raw.timestamp >= evidence.timestamp
WHERE evidence.condition_code IS NOT NULL
ORDER BY raw.enrollment_id, raw.timestamp, raw.event_hash;
```

The repository also contains a parameterized version at
`priv/clickhouse/queries/upgrade_v033_compatibility.sql`.

## Outcomes causally attributed to selected content

Use attribution rows when the question specifically requires selected-branch evidence:

```sql
SELECT
    a.condition_code,
    countDistinct(a.attribution_hash) AS attributed_outcomes,
    avg(r.score / nullIf(r.out_of, 0)) AS mean_correctness
FROM experiment_attributions FINAL AS a
INNER JOIN
(
    SELECT *
    FROM raw_events FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
) AS r
    ON r.event_hash = a.raw_event_hash
WHERE a.section_id = 2001
  AND a.project_id = 1001
  AND a.experiment_id = 101
  AND a.attribution_type = 'outcome'
  AND a.raw_event_type = 'activity_attempt'
  AND r.score IS NOT NULL
  AND r.out_of IS NOT NULL
  AND r.out_of != 0
  AND a.timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND a.timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY a.condition_code
ORDER BY a.condition_code;
```

Filtering to `raw_event_type = 'activity_attempt'` chooses the rollup attached to the activity
statement and avoids also counting the direct part evidence and the rollup attached to the page
statement. Choose one canonical xAPI statement type for each analysis.
`countDistinct(attribution_hash)` alone does not deduplicate across statement types,
because each attached attribution row has its own hash.

## Thompson Sampling reward summary

```sql
SELECT
    condition_code,
    countIf(reward_value = 1.0) AS successes,
    countIf(reward_value = 0.0) AS failures,
    countIf(reward_value IS NULL) AS missing_rewards,
    avg(reward_value) AS mean_reward
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND algorithm = 'thompson_sampling'
  AND attribution_type = 'reward'
  AND experiment_role = 'reward'
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY condition_code
ORDER BY condition_code;
```

`experiment_role = 'reward'` selects the canonical direct reward evidence, including part-attempt
rewards and assessment-reward handoffs attached to page statements, while excluding activity/page
rollup copies. Do not replace missing rewards with xAPI statement scores. `NULL`, `0.0`, and `1.0`
have distinct meanings.

## Reward latency after outcome

```sql
WITH
outcomes AS
(
    SELECT
        assignment_id,
        raw_event_hash,
        min(timestamp) AS outcome_time
    FROM experiment_attributions FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND experiment_id = 101
      AND attribution_type = 'outcome'
      AND raw_event_type = 'activity_attempt'
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
    GROUP BY assignment_id, raw_event_hash
),
rewards AS
(
    SELECT
        assignment_id,
        min(timestamp) AS reward_time,
        any(reward_value) AS reward_value
    FROM experiment_attributions FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND experiment_id = 101
      AND attribution_type = 'reward'
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
    GROUP BY assignment_id
)
SELECT
    quantileTDigest(0.5)(dateDiff('second', outcome_time, reward_time)) AS median_seconds,
    quantileTDigest(0.95)(dateDiff('second', outcome_time, reward_time)) AS p95_seconds
FROM outcomes
INNER JOIN rewards USING (assignment_id)
WHERE reward_time >= outcome_time;
```

For exact outcome-to-reward linkage, use `outcome_key` from the S3 attribution payload. It is not
currently a projected ClickHouse column, so the ClickHouse-only query above is assignment-level and
may be insufficient when one assignment has many outcomes.

## Media engagement by condition

```sql
SELECT
    a.condition_code,
    r.verb_id,
    countDistinct(r.event_hash) AS media_events,
    uniqExact(a.enrollment_id) AS participants
FROM experiment_attributions FINAL AS a
INNER JOIN
(
    SELECT *
    FROM raw_events FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
) AS r
    ON r.event_hash = a.raw_event_hash
WHERE a.section_id = 2001
  AND a.project_id = 1001
  AND a.experiment_id = 101
  AND a.experiment_role = 'media_interaction'
  AND a.attribution_type = 'assignment'
  AND a.timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND a.timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY a.condition_code, r.verb_id
ORDER BY a.condition_code, r.verb_id;
```

## Data-quality checks

### Outcomes carrying an unexpected reward value

This should return zero after the reward-semantics correction:

```sql
SELECT count() AS invalid_outcome_rewards
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND attribution_type = 'outcome'
  AND reward_value IS NOT NULL
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3);
```

### Rewards missing explicit values

```sql
SELECT
    experiment_id,
    condition_code,
    count() AS rows
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND attribution_type = 'reward'
  AND reward_value IS NULL
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY experiment_id, condition_code
ORDER BY rows DESC;
```

### Attributed xAPI statements missing raw rows

```sql
SELECT count() AS orphan_attributions
FROM experiment_attributions FINAL AS a
LEFT JOIN
(
    SELECT event_hash
    FROM raw_events FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
) AS r
    ON r.event_hash = a.raw_event_hash
WHERE a.section_id = 2001
  AND a.project_id = 1001
  AND a.experiment_id = 101
  AND a.timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND a.timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
  AND r.event_hash IS NULL;
```

### Multiple conditions for one assignment

```sql
SELECT
    assignment_id,
    groupUniqArray(condition_code) AS conditions
FROM experiment_attributions FINAL
WHERE section_id = 2001
  AND project_id = 1001
  AND experiment_id = 101
  AND assignment_id IS NOT NULL
  AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
GROUP BY assignment_id
HAVING length(conditions) > 1;
```

## Exporting a researcher-safe working set

Prefer pseudonymous and analysis-required fields:

```sql
SELECT
    a.experiment_uuid,
    a.section_id,
    a.project_id,
    a.enrollment_id,
    a.condition_code,
    a.assignment_scope,
    a.attribution_type,
    a.timestamp,
    r.activity_id,
    r.activity_attempt_number,
    r.score,
    r.out_of,
    a.reward_value
FROM experiment_attributions FINAL AS a
INNER JOIN
(
    SELECT *
    FROM raw_events FINAL
    WHERE section_id = 2001
      AND project_id = 1001
      AND timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
      AND timestamp <  toDateTime64('2026-09-01 00:00:00', 3)
) AS r
    ON r.event_hash = a.raw_event_hash
WHERE a.experiment_id = 101
  AND a.section_id = 2001
  AND a.project_id = 1001
  AND a.timestamp >= toDateTime64('2026-08-01 00:00:00', 3)
  AND a.timestamp <  toDateTime64('2026-09-01 00:00:00', 3);
```

Avoid exporting `raw_events.user_id`, response, or feedback unless the approved research protocol
requires them. Enrollment IDs are pseudonymous but still linkable and must be handled as restricted
research data.
