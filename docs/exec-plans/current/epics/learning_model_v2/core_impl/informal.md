# Learning Model: Core LKT-AOA State Application

This work item implements the delivery write path for LKT-AOA proficiency and confidence. It is the second of three implementation chunks derived from `docs/exec-plans/current/epics/learning_model_v2/informal.md`.

It depends on the model-selection and Revision parameter contracts in `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`.

The intended outcome is that one evaluated part or a complete graded exam can atomically and idempotently update all affected learner/LO states without scanning historical attempts.

## Primary performance requirement

For one submitted batch, the number of database round trips must remain a small constant. It must not grow linearly with the number of activity parts or activity/LO pairs.

The number of mathematical transitions and affected rows necessarily grows with the meaningful contributions in the batch. The prohibited pattern is a loop whose body performs an independent read and write for every LO. A grouped in-memory transition over data loaded in bulk is acceptable.

Historical responses continue to flow through xAPI, S3, and ClickHouse. Those systems support analytics, training, audit, and reconstruction; the online calculation uses compact operational state.

## `learning_state`

One materialized state row exists per Section, learner, and LO:

```text
learning_state
  section_id
  user_id
  learning_objective_id

  attempt_count
  success_score
  failure_score
  recency_logit
  aoa

  unique_activity_part_count
  confidence

  inserted_at
  updated_at
```

The uniqueness constraint is:

```text
UNIQUE(section_id, user_id, learning_objective_id)
```

`user_id` is used consistently with Torus delivery schemas. `unique_activity_part_count` is intentionally named at part granularity because confidence evidence is keyed by activity part, not merely activity.

`learning_objective_id` is the learning-objective resource ID, not a Revision ID. `activity_id` in evidence is likewise the activity resource ID. Published Revision IDs are resolved separately when loading the parameter values that apply to an attempt.

Initial values for a new learner/LO state are:

```text
attempt_count = 0
success_score = 0.0
failure_score = 0.0
recency_logit = 0.0
aoa = 0.0
unique_activity_part_count = 0
confidence = 0.0
```

The first prediction is calculated from those neutral values before the observed result is applied.

`latest_p_correct` is not required for the model transition and should not be persisted unless a concrete consumer requires it. A singular `parameter_version_id` should also not be added without a fuller audit design: one prediction uses both an activity-part parameter and an LO parameter, and a lifetime AOA may span more than one published parameter set.

## LKT-AOA transition

For the next opportunity, calculate the prediction from the pre-response state:

```text
logit(P(correct)) =
  beta_lo
  + beta_part
  + gamma * log(attempt_count + 1)
  + rho * recency_logit
```

The item coefficient is the difficulty value for the evaluated activity part. The same part coefficient is used for every LO targeted by that part.

`gamma` and `rho` come from the startup-loaded LKT-AOA application configuration and default to `0.1` and `1.0`, respectively.

`attempt_count` is per learner/LO opportunity. A part targeting three LOs contributes one opportunity to each of the three corresponding states.

After calculating `p = P(correct)`, update the running AOA without reading prior attempts:

```text
new_attempt_count = attempt_count + 1
new_aoa = (attempt_count * aoa + p) / new_attempt_count
```

Then apply the binary observed outcome:

```text
new_success_score = recency_decay * success_score + correct
new_failure_score = recency_decay * failure_score + (1 - correct)

new_recency_logit =
  log((new_success_score + 1) / (new_failure_score + 1))
```

`recency_decay` comes from the startup-loaded LKT-AOA application configuration and defaults to `0.9`.

Persisting success and failure scores avoids reconstructing them from a derived logit and keeps the implementation adaptable if decay behavior changes later.

The ordering is deliberate:

1. Predict using the state before the response outcome.
2. Add that prediction to AOA.
3. Apply the outcome to the recency state used by the next opportunity.

For the initial implementation, a part is correct only when `score == out_of`. Partial credit is treated as incorrect because the model consumes a binary outcome. If Learning Engineering selects a different binarization rule, it must be changed explicitly and covered by training/runtime parity tests. The xAPI `success` field is not the source of correctness because the current evaluated-part statement emits it as `true`.

## Confidence transition

Confidence uses breadth of evidence: the number of distinct activity parts encountered for the LO. Repeated attempts update proficiency but do not increase confidence.

The state stores both the count and calculated confidence:

```text
confidence = 1 - exp(-unique_activity_part_count / k)
```

`k` is the startup-loaded `confidence_saturation` value from the LKT-AOA application configuration and defaults to `3.0`.

## Prior activity/part evidence

Exact set membership is represented by a dedicated table:

```text
prior_activity_part_evidence
  section_id
  user_id
  activity_id
  part_id       # string
  inserted_at
```

Its uniqueness constraint is:

```text
UNIQUE(section_id, user_id, activity_id, part_id)
```

The table records the normalized fact that a learner encountered a particular activity part in a Section. It does not duplicate the fact per LO. A newly inserted part is mapped to all LOs targeted by the evaluated activity Revision.

This design assumes that the identity and effective LO mapping of an `(activity_id, part_id)` are stable for the evidence history of an active Section. Retagging a previously encountered part to a new LO cannot be handled correctly by the uniqueness key alone; such a publication change requires an explicit evidence/state reconciliation policy.

### Bulk evidence insertion

The entire batch is inserted with conflict-tolerant set semantics:

```sql
INSERT INTO prior_activity_part_evidence (
  section_id,
  user_id,
  activity_id,
  part_id
)
VALUES (...), (...), (...)
ON CONFLICT (section_id, user_id, activity_id, part_id)
DO NOTHING
RETURNING section_id, user_id, activity_id, part_id;
```

Only genuinely new evidence rows are returned. Existing evidence and duplicates inside the input batch do not abort the operation.

Returned parts are joined to the effective part-to-LO mappings and grouped by `(section_id, user_id, learning_objective_id)`. The resulting grouped count increments `unique_activity_part_count` for every affected state.

Examples:

- Five new parts targeting five distinct LOs produce five increments of one.
- Five new parts targeting one LO produce one increment of five.
- One new part targeting three peer LOs produces one increment for each of the three learner/LO states.
- A repeated attempt produces no confidence increment but still produces proficiency transitions for all applicable LOs.

## Required bulk use cases

The public core operation accepts a collection of evaluated part attempts. A one-part response is a batch of size one.

It must support:

1. **One activity part targeting multiple LOs.** The caller supplies the part once. The core resolves all effective LOs and updates them in one logical operation.
2. **One activity with multiple evaluated parts.** Each part may have a different difficulty coefficient and LO mapping.
3. **A graded page or exam containing many activities.** Dozens of parts may arrive together, target overlapping LOs, and contain a mixture of first and repeated encounters.
4. **Multiple contributions to the same state.** All contributions for one `(section_id, user_id, learning_objective_id)` must be applied without lost updates.

The operation must not expose or require a single-LO callback that callers invoke in an `Enum.reduce` with database I/O.

## Conceptual bulk input

The boundary begins with evaluated part-attempt GUIDs and resolves records containing at least:

```text
part_attempt_guid
section_id
user_id
activity_id
activity_revision_id
part_id
score
out_of
date_evaluated
attempt_number
effective_learning_objective_ids
```

Model parameters, mappings, current learner states, and evidence membership are loaded or claimed in bulk.

## Atomic processing boundary

The learning-model mutation needs its own database transaction. Conceptually, it performs a fixed sequence of bulk operations:

1. Retrieve the context of the evaluated part attempt guids (section id, user id, etc)
2. Resolve effective part-to-LO mappings and published activity/LO parameters in bulk.
3. Read or initialize and lock all affected `learning_state` rows in deterministic key order.
4. Insert all prior activity/part evidence rows with `ON CONFLICT DO NOTHING RETURNING`.
5. Group newly inserted evidence by learner/LO state for confidence increments.
6. Apply all ordered proficiency transitions and confidence changes.
7. Bulk insert or update the final `learning_state` rows.
8. Commit the idempotency claim, evidence, and state changes together.


It is important to find the most efficient method to READ items from steps 1, 2 and 3 above. It is likely that
this can be done in a small number of queries but we want to be careful about what we actually are joining when
the collection of part attempt guids is large (500-1000).  A larger number of much simpler queries could be better.

Failure must leave all three concerns unchanged. A partially applied exam is not acceptable.

The exact implementation may use writable CTEs, a small fixed number of SQL statements, and a grouped pure-Elixir transition. The requirement is atomicity and a bounded number of round trips, not forcing every calculation into one SQL expression.

## Idempotency

Evidence uniqueness protects only confidence. It does not stop the same evaluated attempt from incrementing `attempt_count`, recency, and AOA twice.

Every proficiency contribution must therefore be claimed using the immutable PartAttempt identity. An in-memory check or Oban uniqueness is insufficient.

The claim is stored in a dedicated `learning_model_attempt_applications` table rather than by adding processed fields to `part_attempts`. The production `part_attempts` table is approximately 300 GB; updating it once more for every LKT-AOA application would create avoidable MVCC tuple churn, WAL volume, dead tuples, and autovacuum pressure on Torus's largest table. The separate table keeps idempotency writes narrow and append-only.

### Application table

`learning_model_attempt_applications` has exactly three fields:

```text
part_attempt_id
learning_model_version
applied_at
```

There is no generated surrogate `id` field. `part_attempt_id` is the primary key and references `part_attempts.id`. It is the compact database identity corresponding to the immutable `PartAttempt.attempt_guid` supplied to the integration boundary.

`learning_model_version` records the model applied to the attempt and uses the same semantic enum vocabulary as Project and Section, including `:lkt_aoa`. Because a PartAttempt belongs to a Section pinned to one model, an attempt is applied at most once; `learning_model_version` does not participate in the primary key.

`applied_at` records when the application transaction succeeded and is the table's only timestamp.

The table intentionally does **not** use the standard Ecto `timestamps()` fields. It has neither `inserted_at` nor `updated_at`, and the schema must use `@primary_key false` so Ecto does not add an implicit fourth field. The row is immutable after insertion: there is no update workflow and therefore no need for `updated_at`.

No Section, user, activity, part, LO, score, `date_evaluated`, attempt GUID, model parameters, or learner-state values are duplicated into this table. Those values remain available from the PartAttempt context or their owning records. This is one application row per evaluated PartAttempt, not one row per LO targeted by that attempt.

The foreign key should use `ON DELETE CASCADE` so existing `PartAttemptCleaner` behavior is not blocked and application rows do not become orphaned after their source attempts are removed. This is safe only because a deleted PartAttempt can no longer be supplied for reprocessing; that assumption must be covered by the cleanup integration tests.

### Atomic bulk claim

The transaction claims all candidate PartAttempts with one bulk insert, conceptually:

```sql
INSERT INTO learning_model_attempt_applications (
  part_attempt_id,
  learning_model_version,
  applied_at
)
SELECT id, 'lkt_aoa', now()
FROM part_attempts
WHERE attempt_guid = ANY($1)
  AND lifecycle_state = 'evaluated'
ON CONFLICT (part_attempt_id) DO NOTHING
RETURNING part_attempt_id;
```

Only PartAttempt IDs returned by this statement may contribute proficiency or confidence changes. A repeated GUID conflicts with the primary key and returns nothing, making it a no-op without first reading the application table. A part targeting multiple LOs is claimed once and then updates every applicable learner/LO state.

The idempotency claim and state mutation belong to the same transaction. Retrying a successfully applied Snapshot Worker job must become a no-op for proficiency and confidence.

If evidence capture, ordering validation, or any `learning_state` mutation fails, the transaction rolls back the application rows as well. Conversely, application rows must never commit before their corresponding state changes. Concurrent workers claiming the same PartAttempt rely on the primary-key conflict for exact database-enforced exclusion.

## Snapshot Worker integration

The integration boundary is `Oli.Delivery.Snapshots.Worker` in `lib/oli/delivery/snapshots/worker.ex`. It already receives:

```text
part_attempt_guids
section_slug
```

Its query bulk-loads evaluated `PartAttempt` rows joined through `ActivityAttempt`, `ResourceAttempt`, `ResourceAccess`, and the activity Revision. `Oli.Analytics.Summary.AttemptGroup` supplies user, section, project, publication, part, activity, objective mapping, score, and attempt context.

Existing producers include:

- Server-side activity evaluation.
- Client-side activity evaluation.
- Graded page finalization.
- Page auto-submission.
- Manual grading.

The LKT-AOA mutation should be a distinct pipeline step operating on the constructed evaluated-part collection. Current summary analytics and xAPI emission continue for both model versions because they support concerns beyond proficiency. The new mutation runs only when the Section has `learning_model_version: :lkt_aoa`, unless an explicit shadow/backfill mode is introduced later.

Snapshot work normally runs asynchronously through Oban and may be attempted up to three times. Proficiency is therefore eventually consistent with grading, and the mutation must be idempotent.

## Ordering and batch semantics

The model uses **sequential replay within each bulk application**. Contributions available to the same transaction are ordered deterministically, and each observed result updates the learner state used to calculate the next contribution's prediction. A bulk operation optimizes database access but does not change these within-batch sequential semantics.

The primary ordering field is the evaluated PartAttempt's `date_evaluated`, ascending. For each `(section_id, user_id, learning_objective_id)` state, apply contributions in this order:

```text
date_evaluated ASC, part_attempt_guid ASC
```

`part_attempt_guid` is the deterministic tie-breaker when two part attempts have the same `date_evaluated`. The tie-breaker does not claim additional temporal meaning; it ensures retries, nodes, and database query plans always replay the same sequence. Database return order, input GUID order, activity order on a page, and `Enum` traversal order must not determine model behavior.

The Snapshot Worker bulk-load query should return `PartAttempt.date_evaluated` and may apply this ordering in SQL. The learning-model boundary must still enforce or verify the ordering before grouping and replay so correctness does not depend on a caller preserving query order.

Only evaluated PartAttempts are valid inputs, so `date_evaluated` must be non-null for every contribution. A missing value is invalid batch input and must cause the learning-model transaction to fail without claiming idempotency or partially updating evidence or learner state.

Ordering is applied independently within each learner/LO state. One activity part targeting multiple LOs occupies the same `(date_evaluated, part_attempt_guid)` position in each affected state's sequence. Contributions for unrelated learner/LO states do not need to be interleaved because they do not affect one another.

### Ordering across separate Oban jobs

Torus does **not** guarantee or attempt to enforce chronological application across separate Snapshot Worker jobs. If a job containing a later PartAttempt acquires the learner-state lock and commits before a different job containing an earlier PartAttempt, the later attempt is applied first. When the earlier job subsequently runs, it applies against the state that already includes the later result. This is accepted behavior.

The current evaluation paths enqueue Snapshot Worker jobs immediately after successful attempt finalization, so meaningful cross-job reordering is expected to be very rare. The implementation must not add a per-learner queue, chronological watermark, delay window, scan for earlier unclaimed attempts, historical replay, or repair process merely to eliminate this possibility.

`date_evaluated` ordering therefore governs only the contributions claimed by the current transaction. It is not a global ordering guarantee across the learner's complete attempt history. Concurrency controls still must prevent lost updates and double application, but whichever valid job acquires the locked learner state first establishes the cross-job application order.

## Concurrency

Concurrent jobs for the same learner/LO must not both read the same prior state and overwrite one another. The transaction must lock or atomically update affected states in a deterministic order to avoid lost updates and reduce deadlock risk.

The evidence uniqueness constraint handles concurrent first encounters: only one transaction inserts the evidence row. The successful insert alone causes the confidence increment.

## Verification boundary

This chunk is complete when tests demonstrate:

- Correct first and subsequent LKT-AOA transitions.
- Multiple contributions to the same state within one bulk application use sequential replay ordered by `date_evaluated`.
- Equal `date_evaluated` values within one bulk application are replayed deterministically by `part_attempt_guid`.
- Correct cold-start behavior for missing beta parameters.
- Multi-LO parts update every applicable state.
- A bulk exam updates overlapping states with bounded database round trips.
- Repeated parts affect proficiency but not confidence breadth.
- `learning_model_attempt_applications` persists exactly the three specified fields and no Ecto-generated ID or standard timestamps.
- Duplicate GUIDs and Oban retries do not double-apply state.
- PartAttempt cleanup cascades to its application claim without blocking cleanup or leaving an orphan.
- Concurrent updates cannot lose attempts or double-increment confidence.
- Any transaction failure rolls back idempotency, evidence, and state together.
- Naive sections do not write LKT-AOA operational state.
- Snapshot processing remains compatible with summary analytics and xAPI emission.
