# Native Experiment Data Guide

This guide explains the research data produced by Torus native experiments. It covers both
weighted-random and Thompson Sampling experiments, from the original xAPI statements stored in
Amazon S3 to the normalized tables available in ClickHouse.

Use the companion documents for details:

- [Experiment workflow](workflow.md): plan, author, configure, activate, operate, complete,
  archive, and analyze an experiment.
- [Glossary](glossary.md): definitions for experiment, authoring, lifecycle, xAPI, storage, and
  analytics terminology.
- [Data and key reference](data-reference.md): JSON shape, ClickHouse columns, event lifecycle,
  identifiers, and key formats.
- [ClickHouse query cookbook](queries.md): assignment balance, outcomes, rewards, conversion,
  data-quality checks, and UpGrade-compatible analysis.

## The two-layer data model

Native experiment data has two independent layers:

1. **[xAPI statements](glossary.md#xapi-statement)** describe what happened in the course: a page was viewed, a video was played, or
   an attempt was evaluated. Every supported xAPI statement becomes a row in `raw_events`.
2. **[Experiment attribution](glossary.md#attribution)** describes the experiment evidence attached to that xAPI statement: an
   assignment, exposure, outcome, reward, or policy update. Each attribution object becomes a row
   in `experiment_attributions`.

The tables join through:

```text
raw_events.event_hash = experiment_attributions.raw_event_hash
```

An event does not need attribution to appear in `raw_events`. This distinction matters: the raw
activity stream is appropriate for section-wide outcome analysis, while attribution rows support
causal or policy-specific analysis.

## Where the data lives

### Amazon S3

In the S3 ingestion mode, Torus writes xAPI statement bundles as [JSON Lines](glossary.md#json-lines-jsonl) files. Each line is one
complete xAPI JSON document. The object key is:

```text
<partition>/<partition_id>/<category>/<UTC timestamp>_<bundle_id>.jsonl
```

For delivery data, this commonly resembles:

```text
section/42/attempt_evaluated/2026-08-20T13-45-02Z_A1B2C3.jsonl
section/42/page_viewed/2026-08-20T13-44-10Z_D4E5F6.jsonl
section/42/video/2026-08-20T13-46-31Z_G7H8I9.jsonl
section/42/experiment_condition_assigned/2026-08-20T13-43-55Z_J1K2L3.jsonl
```

The bucket name is specific to the Torus instance. Access to source xAPI must be controlled because
the S3 statement can contain the full xAPI actor, including sensitive learner account information,
and may also contain responses or feedback. ClickHouse does not project the full actor: its actor-related
columns are limited to the account identifiers `raw_events.user_id` and `raw_events.home_page`.
ClickHouse response and feedback columns can still contain sensitive learner data and require the
applicable approval. The `experiment_attributions` extension deliberately excludes names, email
addresses, LMS identifiers, raw responses, realized content, and policy-state blobs.

S3 is also the replay source. The same JSONL can be transformed by the Lambda pipeline or replayed
into ClickHouse by the backfill tooling.

### ClickHouse

Researchers normally work with two tables:

- `raw_events`: one normalized row per xAPI statement.
- `experiment_attributions`: zero or more normalized attribution rows per xAPI statement.

Both are [`ReplacingMergeTree`](glossary.md#replacingmergetree) tables. For reproducible analysis over recently replayed or replaced
data, use [`FINAL`](glossary.md#final) or an equivalent latest-version aggregation where the additional cost is
acceptable.

## Weighted random and Thompson Sampling

| Characteristic | Weighted random | Thompson Sampling |
| --- | --- | --- |
| Policy version | `weighted_random:v1` | `thompson_sampling:v2` |
| Assignment scopes | `intervention`, `section_enrollment` | `intervention` only |
| Allocation | Deterministic weighted selection from configured condition weights | Samples each condition's beta posterior |
| Outcome evidence | Yes | Yes |
| Reward evidence | No policy reward is created by the attempt attribution path | Explicit binary reward, normally `0.0` or `1.0` |
| Policy updates | Weighted-random updates are no-ops | Reward updates successes, failures, and posterior parameters |

Important distinctions:

- `raw_events.score` and `raw_events.out_of` are observed attempt performance.
- `experiment_attributions.normalized_score` is an explicitly supplied normalized assessment
  result when that evidence exists.
- `experiment_attributions.reward_value` is explicit experiment-policy reward evidence. It is
  `NULL` when no reward was supplied and is never inferred from the xAPI statement's attempt score.
- A valid reward of `0.0` is different from `NULL`: zero is observed failure/no credit; null means
  no reward evidence.

## Participant identity

Use `enrollment_id` as the pseudonymous participant identifier for section-level analysis. The same
person enrolled in two sections has two different enrollment IDs. Do not join experiments through
the xAPI actor account unless a separately approved research protocol explicitly requires it.

Always scope analysis by at least `section_id` and `project_id`. Include `experiment_id` or
`experiment_uuid` for experiment-specific work. `publication_id` identifies the section publication,
but exact attempt-time publication provenance is a known limitation tracked separately.

## Recommended analysis workflow

1. Select the section, project, experiment, and analysis time range.
2. Inspect initial condition-assignment and exposure counts before calculating outcomes; use the
   transactional assignment store when delivery completeness must be audited.
3. Use `enrollment_id` as the participant key.
4. Use `raw_events` for the complete evaluated-activity outcome stream.
5. Use `experiment_attributions` for assignment, exposure, outcome, reward, and policy evidence.
6. Join attribution to its raw event through `raw_event_hash`; join section-wide outcomes to durable
   assignment evidence by section, project, enrollment, and event time when branch attribution is
   not required.
7. Keep `NULL` distinct from zero, especially for `reward_value`, scores, and denominators.
8. Document whether repeated attempts are all included, reduced to the first attempt, or reduced to
   the last attempt.

## Known limitations

- Older statements may predate newer nullable columns such as `enrollment_id`; nulls are expected.
- Attribution is optional and fails safe. A valid xAPI statement can have no experiment attribution.
- Attempt and media attribution require evidence that the learner received the selected branch.
- The current compatibility analysis uses the most recent applicable assignment evidence at or
  before the outcome timestamp; it does not infer condition from mutable authoring content.
- Exact attempt-time publication provenance is tracked by MER-5889.
