# Learning Model v2: Informal Technical Direction

This document captures early architectural thinking about implementing the LKT-AOA proficiency model described in `docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`. It is intentionally informal and is not yet a detailed design.

## Primary Design Goal

Processing a new learner response should require a constant, bounded number of operational database record reads and writes, regardless of how many prior attempts the learner has made.

In particular, calculating the current proficiency must not require reading or re-aggregating historical attempts. Historical response data can continue to flow through xAPI into S3 and ClickHouse for analytics, training, auditing, and possible reconstruction, but the online calculation should use compact accumulated state.

## Persisting Model Version

The selected learning model will be persisted on both authoring projects and delivery sections through a `learning_model_version` attribute.

Both `Oli.Authoring.Course.Project` and `Oli.Delivery.Sections.Section` will define the field as an `Ecto.Enum` with semantically meaningful values:

```elixir
field :learning_model_version,
  Ecto.Enum,
  values: [:naive, :lkt_aoa],
  default: :naive
```

The values mean:

- `:naive` selects the existing proficiency model based on first-attempt performance.
- `:lkt_aoa` selects the new Logistic Knowledge Tracing with All Opportunities Averaged model.

These values describe model behavior and must be used instead of opaque names such as `:v1` and `:v2`. The persisted learning-model selection is independent of the existing `analytics_version` attributes.

The database migration will add `learning_model_version` to both projects and sections and set every existing project and every existing section to `:naive`. Database and schema defaults will also be `:naive`, preventing the migration from silently changing proficiency behavior for existing courses.

Model selection must propagate explicitly through course creation paths:

- A section created directly from a project receives the project's `learning_model_version`.
- A template created from a project receives that project's `learning_model_version`.
- A section created from a template receives the template's `learning_model_version`.

Project-to-template and project/template-to-section creation must copy the value rather than relying on the destination schema default. Duplication, cloning, and any other workflow that creates a new project, template, or section from an existing source must likewise preserve or intentionally set the source learning-model version.

Once copied, the Section's value identifies the model governing that delivery. A later change to the source project or template must not implicitly change an existing Section's model.

## `learning_state`

The central implementation idea is a materialized state record, provisionally called `learning_state`, for each learner and knowledge component (KC). In Torus, the KC is expected to correspond to the effective, most-specific learning objective or sub-objective associated with an activity.

A conceptual identity for the record is:

```text
(student_id, section_id, kc_id)
```

The section is part of the identity because proficiency is evaluated in the context of a particular course delivery and its published learning-model parameters.

The record would contain at least:

```text
learning_state
  student_id
  section_id
  kc_id

  attempt_count
  success_score
  failure_score
  recency_logit

  aoa
  latest_p_correct       # optional convenience value

  unique_activity_count # supports confidence from prior activity-part evidence
  confidence
  parameter_version_id  # if needed to identify the parameters governing the state

  inserted_at
  updated_at
```

The exact names and whether derived values such as `recency_logit` or `latest_p_correct` should be persisted remain implementation decisions.

### Why store success and failure scores?

The recency calculation updates two independent running values:

```text
new_success_score = 0.9 * success_score + correct
new_failure_score = 0.9 * failure_score + (1 - correct)

new_recency_logit =
  log((new_success_score + 1) / (new_failure_score + 1))
```

Persisting only `recency_logit` does not directly preserve the two components needed by the next update. They can theoretically be reconstructed under the current binary-outcome and fixed-decay assumptions, but persisting both component scores is simpler, clearer, and less coupled to those assumptions.

## Model Parameters Outside `learning_state`

The learner state is combined with static, published model parameters when processing an attempt. At minimum, the calculation needs:

- The item difficulty parameters, `beta_item`, for every part in the activity.
- The KC difficulty parameter, `beta_kc`, for the learning objective.
- The fixed regression coefficients, including the opportunity-count and recency weights.

These parameters are not learner-specific and should not be duplicated into every `learning_state` record. They can be read from their authoritative parameter records and may be suitable for caching, provided publication/version boundaries remain explicit.

## Incremental LKT-AOA

LKT-AOA is the arithmetic mean of the `P(correct)` predictions made for all of the learner's opportunities on a KC. It does not require retaining or rereading the individual predictions.

Given:

```text
n       = prior attempt_count
aoa     = prior running mean
p       = P(correct) predicted for the new opportunity
```

the state update is:

```text
new_attempt_count = n + 1
new_aoa = (n * aoa + p) / new_attempt_count
```

The record could instead retain a cumulative prediction sum and divide it by `attempt_count` when needed. Storing the running mean is currently preferred because it is the value displayed and consumed by downstream functionality. Either representation provides constant-time updates.

The ordering is important: `P(correct)` for an opportunity is calculated using the pre-response state. That prediction is added to AOA, and then the observed correct/incorrect outcome updates the recency state for the next opportunity.

## Confidence State

Student-level confidence depends on the number of unique activities encountered for the KC, rather than total attempts. The accumulated count belongs naturally on `learning_state`:

```text
unique_activity_count
```

The confidence value can then be calculated without reading historical attempts:

```text
confidence = 1 - exp(-unique_activity_count / k)
```

Whether an activity part has already been encountered will be determined from the dedicated prior activity/part evidence table described below. The resulting count and calculated confidence are stored in `learning_state` so confidence can be retrieved without scanning historical attempts or recalculating it at read time.

This decision does not change the core proficiency design: `learning_state` retains the compact running values required to update proficiency and LKT-AOA without scanning prior attempts.

## Constant-Work Proficiency and Confidence Update

For a response to item `B`, associated with KC `C`, the online path conceptually performs the following work:

1. Read the applicable item parameters.
2. Read the applicable KC parameters.
3. Read or initialize the learner's `learning_state` for KC `C`.
4. Calculate `P(correct)` from the state that existed before applying the new response outcome.
5. Incorporate that prediction into the running LKT-AOA value.
6. Apply the observed outcome to the success and failure scores and derive the new recency logit.
7. Attempt to insert the `(section_id, user_id, activity_id, part_id)` encounter into the prior activity/part evidence table, ignoring a uniqueness conflict when the part has already been encountered.
8. If new evidence was inserted, increment `learning_state.unique_activity_count` and calculate the new stored confidence value:

   ```text
   confidence = 1 - exp(-unique_activity_count / k)
   ```

   If the evidence already existed, leave both the unique count and confidence unchanged.

9. Atomically update the affected `learning_state` record with its new proficiency and confidence state.

The number of records touched by this path does not grow with the learner's attempt history. Evidence lookup is enforced by the table's uniqueness constraint rather than by scanning prior encounters.

Concurrency must be handled so that two responses for the same learner and KC cannot both update from the same prior state and lose one of the attempts or increment confidence incorrectly. The evidence insert and `learning_state` update must form one atomic operation, using database constraints, row locking, serialization, or an equivalent mechanism.

## Bulk Application Requirement

The learning-model implementation must support applying proficiency and confidence updates in bulk. Bulk application is a core requirement, not an optimization to be added after implementing a single-activity, single-KC path.

The design must cover at least these two use cases:

### One activity targeting multiple KCs

An activity part may be tagged with more than one effective learning objective or KC. A learner response to that activity must be capable of contributing to every applicable KC in one bulk operation.

The implementation must not require callers to invoke a single-KC update operation repeatedly for each attached KC. It must accept or resolve the complete collection of applicable KCs and apply the corresponding proficiency and confidence effects as one logical operation.

This operation must preserve the rule that confidence counts an activity at most once for each learner and KC, while repeated attempts may still contribute to proficiency.

### Bulk scoring an exam containing multiple activities

A graded page or exam may score dozens of activities together. Each activity may target one or more KCs, and multiple activities in the same scoring operation may contribute to the same KC.

The implementation must support submitting the complete scored result set as one logical bulk operation. It must not force the grading workflow to perform an independent learning-model read/update cycle for every activity or every activity/KC pairing.

Bulk scoring must correctly account for:

- All activity-to-KC contributions in the scored result set.
- Multiple activities contributing to the same learner/KC state.
- Activities that contribute to multiple KCs.
- Repeated attempts, which affect proficiency but do not repeatedly increase the unique-activity count used for confidence.
- Atomicity and concurrency, so that a partially applied exam or overlapping updates cannot leave learner state inconsistent.
- Idempotency, so retrying the same grading operation does not apply its proficiency effects more than once.

The amount of mathematical work and the number of learner/KC states affected may necessarily grow with the size of the scored result set. The architectural requirement is that the implementation expose a genuine bulk boundary and avoid a number of database round trips proportional to the number of activities or activity/KC pairings.

The detailed processing, storage, ordering, and batching approach for satisfying these requirements remains to be designed.

## Prior Activity / Part Evidence

Prior encounters will be represented in a dedicated table rather than embedded as an array in `learning_state`. The table records that a student has previously encountered a particular part of an activity within a section.

A conceptual schema is:

```text
prior_activity_part_evidence
  section_id
  user_id      # the student
  activity_id
  part_id      # string
  inserted_at
```

The table has a uniqueness constraint over all four identifying fields:

```text
UNIQUE(section_id, user_id, activity_id, part_id)
```

This gives the table set semantics: the presence of a row answers whether that student has previously encountered that activity part in that section. Repeated attempts do not create additional rows.

The evidence record is deliberately independent of a KC. A newly encountered activity part can be mapped to all of its applicable KCs when updating the corresponding `learning_state` records. This avoids duplicating the underlying encounter fact when one part targets multiple KCs.

## Bulk Evidence Capture

If seen activity parts are represented by a dedicated evidence/encounter table, PostgreSQL can capture an entire submitted collection with one bulk insert:

```sql
INSERT INTO prior_activity_part_evidence (
  section_id,
  user_id,
  activity_id,
  part_id
)
VALUES
  (...),
  (...),
  (...)
ON CONFLICT (section_id, user_id, activity_id, part_id)
DO NOTHING
RETURNING section_id, user_id, activity_id, part_id;
```

The uniqueness constraint gives the table set semantics. `ON CONFLICT DO NOTHING` is important because a prior encounter is an expected condition, not an error that should abort the bulk operation. PostgreSQL returns only rows that were actually inserted. Consequently, both the returned row count and the returned identities describe genuinely new encounters; previously seen parts and duplicates within the submitted batch are omitted.

The total number of inserted rows is not sufficient by itself to update confidence. The new encounters must be grouped by the corresponding `learning_state` identity because a batch may contain:

- Parts that target different KCs.
- Multiple parts that target the same KC.
- A part that targets multiple KCs.
- A mixture of new and previously encountered parts.

For example, five new single-part questions that each target a distinct KC produce five learner-state increments of one. Five new parts that all target the same KC produce one learner-state increment of five.

If the evidence table does not contain `kc_id`, the returned activity-part identities can be joined to the applicable activity-part-to-KC mappings and grouped by learner-state identity:

```sql
WITH newly_seen AS (
  INSERT INTO prior_activity_part_evidence (...)
  VALUES (...)
  ON CONFLICT (...) DO NOTHING
  RETURNING section_id, user_id, activity_id, part_id
)
SELECT
  newly_seen.section_id,
  newly_seen.user_id,
  mappings.kc_id,
  count(*) AS unique_part_increment
FROM newly_seen
JOIN activity_part_kc_mappings AS mappings
  ON mappings.activity_id = newly_seen.activity_id
 AND mappings.part_id = newly_seen.part_id
GROUP BY
  newly_seen.section_id,
  newly_seen.user_id,
  mappings.kc_id;
```

The grouped results can feed a bulk update or upsert of the affected `learning_state.unique_activity_count` values. PostgreSQL writable CTEs make it possible for the encounter insert, KC resolution, grouping, and learner-state update to occur atomically in one SQL statement. Whether all of those steps should be combined into one statement or performed as a small fixed number of statements remains a detailed design decision.

## Parameter Storage Design

Learning-model parameters must live on the resource Revision so that they participate in the existing authoring and publication lifecycle. A parameter update produces an unpublished revision, active sections continue using their currently published revisions, and a later publication can introduce a new parameter set without mutating the parameters used by existing sections.

Revision will have one dedicated JSONB field:

```text
learning_model_parameters
```

The field is deliberately named for the broader learning model rather than for beta coefficients. Learning Model v2 uses beta coefficients, but future v3 or v4 models may require different parameters.

Revision already has a generic `parameters` map used by existing resource workflows. The learning-model representation will use this new dedicated field rather than overloading that generic map, giving learning-model parameters an independent contract and evolution path.

Although the database representation is JSONB, application code will not treat it as an arbitrary map. A custom Ecto type will encode and decode the field using explicit, versioned Elixir structs.

### Parameter envelope

Every stored parameter value will use a self-describing envelope. The envelope distinguishes the learning-model version, the serialization schema version, and the kind of resource-specific parameter payload.

An LO/KC Revision will use a representation such as:

```json
{
  "schema_version": 1,
  "model": "lkt_aoa",
  "model_version": 2,
  "parameter_type": "kc",
  "payload": {
    "beta_kc": -0.42
  }
}
```

An activity Revision will store a separate item-difficulty parameter for every activity part:

```json
{
  "schema_version": 1,
  "model": "lkt_aoa",
  "model_version": 2,
  "parameter_type": "activity",
  "payload": {
    "parts": {
      "part-1": {
        "beta_difficulty": -0.18
      },
      "part-2": {
        "beta_difficulty": 0.37
      }
    }
  }
}
```

Part IDs are strings and identify parts within the activity Revision. Item difficulty is defined per activity part, not once for the activity and not separately for every part/KC pairing. When a part targets multiple KCs, the same part-difficulty parameter is used for each applicable KC calculation.

Each part is represented by an object instead of mapping its ID directly to a float. This allows later model versions to add part-level parameters without replacing the overall storage design. A future payload might, for example, contain:

```json
{
  "parts": {
    "part-1": {
      "beta_difficulty": -0.18,
      "discrimination": 0.91,
      "guessing": 0.2
    }
  }
}
```

### Versioned Elixir types

The conceptual module organization is:

```text
Oli.LearningModel.Parameters
Oli.LearningModel.Parameters.Type

Oli.LearningModel.V2.KCParameters
Oli.LearningModel.V2.ActivityParameters
Oli.LearningModel.V2.PartParameters

Oli.LearningModel.V3.KCParameters
Oli.LearningModel.V3.ActivityParameters
```

The custom Ecto type will inspect `model`, `model_version`, and `parameter_type`, dispatch decoding to the corresponding versioned module, and return a typed struct. It will also validate and serialize those structs back to JSONB. Consumers of learning-model parameters should use these typed structures rather than directly interpreting stored maps.

`model_version` and `schema_version` have separate meanings:

- `model_version` identifies the learning algorithm and behavior, such as Learning Model v2.
- `schema_version` identifies the serialized representation and permits its encoding to evolve without claiming that the learning algorithm itself changed.

### Validation and defaults

The parameter boundary must validate at least the following:

- The model and model version are supported.
- The parameter type agrees with the Revision's resource type.
- KC payloads have the fields required by that model version.
- Activity part keys correspond to parts that exist in the same activity Revision.
- Numeric parameter values are finite and within any bounds required by the model.
- Unknown model or schema versions produce a controlled error rather than being interpreted as v2.

Missing parameters represent an untrained KC or activity part. The v2 runtime may use `0.0` as the cold-start fallback, but missing and explicitly stored `0.0` are distinct states because zero is also a valid trained coefficient. This distinction allows Torus to identify and flag parts that do not yet have learned difficulty parameters.

When an activity Revision changes its part structure, its parameter payload must be reconciled with that same Revision: deleted part IDs must not retain active parameters, and newly added parts begin without trained parameters.

### Future model versions

The single JSONB column remains stable as v3 and v4 parameter structures are introduced. New versioned structs and decoders can coexist with the v2 types, allowing historical and actively deployed revisions to retain their original parameter representations.

Parameter upgrades create new unpublished resource revisions rather than transforming published Revision data in place. This preserves the publication audit trail and ensures active sections continue to use the parameter version with which they were deployed.

The initial representation assumes one learning-model parameter set per Revision. If Torus later needs to execute multiple models simultaneously against the same Revision, such as v2 production scoring alongside v3 shadow evaluation, the representation will need to support multiple named parameter sets or move those parallel sets into a related structure. Simultaneous model execution is not part of the initial design.

## Integration Points

### Evaluated part attempts and the Snapshot Worker

The first proficiency-update integration point is the existing snapshot creation path centered on `Oli.Delivery.Snapshots.Worker` in `lib/oli/delivery/snapshots/worker.ex`.

The worker receives:

```text
part_attempt_guids
section_slug
```

The input is already a collection rather than a single attempt GUID. This makes the worker a natural place to drive the required bulk proficiency, confidence, and evidence operation. A single activity submission can supply multiple evaluated parts, and finalizing a graded page or exam can supply evaluated parts from multiple activities in one invocation.

The worker performs one query over the supplied GUIDs and joins each matching part attempt to its surrounding delivery context:

```text
PartAttempt
  -> ActivityAttempt
  -> ResourceAttempt
  -> ResourceAccess
  -> activity Revision
```

Only part attempts whose lifecycle state is `:evaluated` are selected. The resulting rows are passed to `Oli.Analytics.Summary.execute_analytics_pipeline/3`, which turns them into an `Oli.Analytics.Summary.AttemptGroup` before updating current analytics summaries and emitting xAPI statements.

### Existing producers of snapshot work

The evaluated-part collection reaches the worker through several existing delivery flows:

- Server-side activity evaluation calls `Snapshots.maybe_create_snapshot/3` after the evaluation transaction succeeds.
- Client-side activity evaluation uses the same snapshot helper after persistence.
- Graded page finalization collects the part-attempt GUIDs produced while rolling up all applicable activities and submits the complete collection to the snapshot path.
- Page auto-submission invokes the worker directly with the finalized part-attempt collection.
- Manual grading ultimately uses the client-evaluation path for newly evaluated parts and therefore also reaches snapshot processing.

When Oban snapshot queues are enabled, `Oli.Delivery.Snapshots.queue_or_create_snapshot/2` enqueues the collection. When snapshot queues are disabled, primarily for synchronous execution and tests, it calls `Worker.perform_now/2` directly. The worker is configured for up to three Oban attempts.

### Context already available for learning-model updates

The queried records and resulting `AttemptGroup` already provide most inputs required by the v2 model:

- `PartAttempt.attempt_guid` provides an immutable event identity for idempotency.
- `PartAttempt.part_id` identifies the activity part and its per-part difficulty parameter.
- `PartAttempt.score` and `PartAttempt.out_of` provide the evaluated result from which correct/incorrect can be derived.
- `PartAttempt.date_evaluated` and attempt numbers provide available ordering information.
- The joined activity Revision provides the activity resource ID, the part-to-objective mapping in `objectives`, and will provide the activity's `learning_model_parameters`.
- `ResourceAccess` provides `user_id` and `section_id`.
- The resource attempt identifies the containing page attempt.
- `AttemptGroup.Context` adds `project_id` and resolves the publication associated with the section/project pair.

The existing analytics implementation demonstrates the relevant bulk shape. `Oli.Analytics.Summary` expands each evaluated part through the activity Revision's `objectives[part_id]`, groups objective contributions, and performs bulk `INSERT ... ON CONFLICT DO UPDATE` operations for summary records. The learning-model update has stronger sequential and idempotency requirements, but it can begin from the same evaluated-part collection and part-to-KC mapping.

Additional data will still need to be resolved in bulk:

- The applicable published KC Revisions and their `learning_model_parameters`.
- The fixed v2 model coefficients, including the opportunity-count and recency weights.
- The affected `learning_state` records.
- Newly inserted prior activity/part evidence rows.

### Proposed pipeline boundary

The proficiency integration belongs within the snapshot worker's processing of the evaluated-part collection, preferably as a distinct step operating on the constructed `AttemptGroup`. This keeps query/context construction shared with summary analytics and xAPI generation while giving the learning-model mutation its own explicit transactional boundary and error handling.

The bulk learning-model operation must consume the entire collection at once. It must not be called separately from an `Enum.reduce` for every part or attached objective. A one-part submission is simply a bulk collection of size one; the same boundary also supports a multi-part activity and a complete graded exam.

### Integration constraints discovered in the current flow

The following behaviors of the snapshot path must shape the implementation:

1. **Idempotency is mandatory.** The worker is retryable, and a supplied GUID may be processed again. The evidence-table uniqueness constraint prevents confidence from counting a part twice, but it does not prevent proficiency, recency, attempt count, or AOA from being applied twice. The learning-model operation must claim or otherwise deduplicate each evaluated part-attempt GUID before changing `learning_state`.

2. **The operation is asynchronous by default.** Evaluation commits before snapshot work is normally processed by Oban. Proficiency and confidence will therefore be eventually consistent with the evaluated attempt unless this integration is deliberately moved into the grading transaction. Consumers must not assume the updated values are visible immediately when grading returns.

3. **The current worker query does not define an order.** PostgreSQL may return the supplied part attempts in any order. LKT recency and sequential `P(correct)` calculations are order-sensitive when multiple parts in one batch affect the same KC. The learning-model operation must define deterministic ordering or explicitly define batch-snapshot semantics before processing those contributions.

4. **A worker batch is implicitly homogeneous.** `AttemptGroup.from_attempt_summary/3` builds one context from the first result, so current callers are expected to supply part attempts from one learner, section, and containing resource attempt. The learning-model integration should validate this invariant or partition unexpected mixed input rather than silently applying the first row's context to every result.

5. **Correctness semantics must be explicit.** Current resource-summary analytics treats a part as correct only when `score == out_of`; partial credit is treated as incorrect. The v2 implementation must confirm that this is the intended binary outcome definition. The xAPI statement's current `success` field is not an appropriate source because it is emitted as `true` for evaluated part attempts.

6. **The learning-model write must be atomic.** Evidence insertion, idempotency enforcement, and all proficiency/confidence changes for the collection must either succeed together or leave the learning state unchanged. The surrounding analytics pipeline does not currently wrap all of its steps in one database transaction, so the learning-model step needs its own transaction.

### Proficiency calculation and read integration points

A repository-wide scan found that `Oli.Delivery.Metrics` in `lib/oli/delivery/metrics.ex` is the primary production boundary for calculating and reading proficiency. Most learner and instructor surfaces call one of its proficiency functions directly or indirectly.

The current naive implementation reads `Oli.Analytics.Summary.ResourceSummary` records and derives proficiency primarily from first-attempt counts. Its core calculation is:

```text
(first_attempts_correct + 0.2 * incorrect_first_attempts) / first_attempts
```

It reports `"Not enough data"` when there are fewer than three first attempts, then assigns the existing Low, Medium, and High labels. The current functions calculate variants of this value by objective, page, container, learner, or section.

The principal Metrics entry points are:

```text
proficiency_for_student_per_learning_objective/3
raw_proficiency_per_learning_objective/2
proficiency_per_container/2
proficiency_per_student_across/2
proficiency_for_student_per_container/3
proficiency_for_student_per_page/2
proficiency_per_student_for_page/2
proficiency_per_page/2
proficiency_per_student_for_objective/3
objectives_proficiency/3
student_proficiency_for_objective/2
proficiency_range/2
```

One production path currently bypasses this boundary: `Oli.InstructorDashboard.Oracles.ProgressProficiency` in `lib/oli/instructor_dashboard/oracles/progress_proficiency.ex` contains its own `ResourceSummary` query and repeats the naive first-attempt formula and minimum-attempt check. This query must be moved behind the model-aware proficiency boundary; otherwise intelligent-dashboard student proficiency will continue using the naive model for LKT-AOA sections.

The scenario proficiency assertion in `lib/oli/scenarios/directives/assert/proficiency_assertion.ex` also reads raw naive-model counts and repeats part of the formula. It must use the model-aware API so scenario coverage can assert either model correctly. Authoring Insights and activity statistics also expose first-attempt counts, but those are descriptive analytics rather than reads of the learner proficiency model and should not automatically change when a section selects LKT-AOA.

#### Current consumers

The scan identified the following major proficiency read surfaces:

- Student lesson, prologue, and review views display proficiency for attached learning objectives.
- The student dashboard displays page- and container-level proficiency.
- The classic instructor dashboard displays proficiency by page, container, and learner.
- Learning-objective page elements and expanded objective components read per-student values and section distributions.
- `Oli.Delivery.Sections.get_objectives_and_subobjectives/2` enriches objective hierarchy data with student proficiency or section distributions.
- Intelligent-dashboard `ProgressProficiency` and `ObjectivesProficiency` oracles feed cached dashboard snapshots, student-support classification, challenging-objective summaries, CSV exports, and recommendations.
- Scenario proficiency assertions read both individual and aggregate proficiency for integration tests.

Most presentation modules consume the established numeric or categorical results and do not independently calculate the underlying learner estimate. If the model-aware boundary preserves those contracts, those consumers should not need to know whether their data came from naive-model `ResourceSummary` records or LKT-AOA `learning_state` records. Confidence and coverage are new data, however, and will require an explicitly extended contract rather than being hidden in an existing label-only return value.

One downstream calculation deserves separate attention: instructor-dashboard summary projections and CSV helpers reconstruct an approximate numeric "Average Class Proficiency" from categorical objective distributions. The current code contains representative weights of Low/Medium/High = 20/60/100 in `lib/oli/instructor_dashboard/data_snapshot/projections/summary.ex` and its CSV helper, while `lib/oli/instructor_dashboard/data_snapshot/projections/summary/projector.ex` uses 30/60/90. LKT-AOA has actual numeric values, so its aggregate should be carried in the oracle contract rather than converted to a label and then approximated back into a number. Naive-model behavior can remain unchanged for compatibility, but the two existing approximations should not become part of the LKT-AOA model.

### Runtime learning-model selection

Selection of the proficiency implementation will use the Section field defined in "Persisting Model Version":

```elixir
field :learning_model_version,
  Ecto.Enum,
  values: [:naive, :lkt_aoa],
  default: :naive
```

`analytics_version` selects analytics storage/query infrastructure and must not be used as a proxy for the learning model. A section may continue using the existing analytics pipeline while independently selecting `:naive` or `:lkt_aoa` proficiency.

Existing sections are migrated to `:naive`. New sections inherit `learning_model_version` from their creating project or template, as described above.

Changing `learning_model_version` after learners have generated evidence is not a simple display preference. A `:naive` section will not necessarily have complete LKT-AOA `learning_state` records, while an `:lkt_aoa` section's displayed history cannot be reconstructed from naive summary counts. The field should therefore be treated as immutable after learner activity begins unless a dedicated backfill and migration operation is performed. Any permitted change must also invalidate instructor-dashboard snapshots and other cached proficiency results.

The snapshot integration must inspect the Section's learning-model version as well. Existing summary analytics should continue to be produced because they support functionality beyond proficiency, but the new `learning_state` and evidence mutation is required only for sections using `:lkt_aoa`, unless a separate shadow/backfill mode is deliberately introduced.

### Recommended naive/LKT-AOA dispatch design

Keep `Oli.Delivery.Metrics` as a compatibility facade for its existing callers, but move model-specific calculation and querying into explicit providers, conceptually:

```text
Oli.Delivery.Proficiency
Oli.Delivery.Proficiency.Estimate
Oli.Delivery.Proficiency.Naive
Oli.Delivery.Proficiency.LktAoa
```

`Naive` will contain the current `ResourceSummary` queries and first-attempt heuristic. `LktAoa` will read `learning_state`, use LKT-AOA as the learner/KC proficiency score, expose stored confidence, and perform the required objective hierarchy aggregation.

Metrics functions should dispatch on a Section struct:

```elixir
def proficiency_per_student_for_objective(
      %Section{learning_model_version: :naive} = section,
      objective_ids,
      opts
    ),
    do: Proficiency.Naive.proficiency_per_student_for_objective(section, objective_ids, opts)

def proficiency_per_student_for_objective(
      %Section{learning_model_version: :lkt_aoa} = section,
      objective_ids,
      opts
    ),
    do: Proficiency.LktAoa.proficiency_per_student_for_objective(section, objective_ids, opts)
```

Several existing functions accept only `section_id`, which prevents dispatch without another lookup. Their preferred API should be overloaded or changed to accept `%Section{}`. Temporary integer-ID clauses can load the Section and delegate for compatibility:

```elixir
def proficiency_per_student_for_objective(section_id, objective_ids, opts)
    when is_integer(section_id) do
  section_id
  |> Sections.get_section!()
  |> proficiency_per_student_for_objective(objective_ids, opts)
end
```

Internal callers that already hold the Section should pass it directly to avoid repeated database reads. In particular, `Oli.Delivery.Sections`, expanded objective components, learning-objective page elements, and dashboard oracles generally already have or can obtain the Section at their outer boundary.

Dispatch should be centralized rather than allowing each LiveView, component, or oracle to branch on `learning_model_version`. The Section is the source of truth; callers should not pass an independent version option that can disagree with it.

### Canonical read contract

The current API has several incompatible result shapes: raw naive-model tuples, numeric values, label strings, nested maps, and student rows. A model-neutral internal result should be introduced for new code:

```text
Proficiency.Estimate
  section_id
  user_id
  kc_id
  score                  # 0.0..1.0 or nil
  label                  # low, medium, high, or not_enough_information
  confidence             # 0.0..1.0 or nil
  attempt_count
  unique_activity_count
  learning_model_version
```

The `Naive` provider can populate fields available from `ResourceSummary` and leave unsupported confidence fields unset. The `LktAoa` provider can populate the complete structure from `learning_state`. Existing Metrics functions can adapt these estimates back into their current return shapes so existing UI code can migrate incrementally.

`raw_proficiency_per_learning_objective/2` is specifically coupled to the naive model's tuple of summary counts and should not become a polymorphic function that returns a different tuple for LKT-AOA. It should become a `Naive` implementation detail or be deprecated in favor of the canonical estimate API. Scenario assertions and other callers needing a numeric value should consume an estimate rather than reproduce a model formula.

Proficiency bucketing must also belong to the selected provider. `Naive` must preserve its current behavior for existing sections. `LktAoa` must apply the LKT-AOA display rules and its own insufficient-information/coverage rules. A shared `proficiency_range/2` that assumes naive-model first-attempt counts is not sufficient for both models.

### LKT-AOA read behavior

For a direct KC or sub-objective read, the `LktAoa` provider should query `learning_state` by section, user, and KC and return its stored AOA proficiency and confidence. It must not scan or aggregate historical part attempts.

For a parent LO, the provider must resolve its effective sub-objectives and aggregate their `learning_state` scores using the LKT-AOA weighting and coverage rules. Section-level instructor views should perform this across learners in set-based queries and then construct the same label distributions expected by existing consumers.

The new state is keyed by KC rather than page or container. Existing Metrics APIs nevertheless expose page-, container-, and course-scoped proficiency. LKT-AOA cannot preserve the meaning of those APIs merely by replacing their `ResourceSummary` query: the technical notes define sub-objective and LO aggregation, but do not yet define page or container proficiency.

Before enabling LKT-AOA on those screens, Product and Learning Engineering must define whether a page/container value is:

- An aggregation of the current learner states for KCs addressed within that scope.
- Weighted by opportunities, unique activity parts, or another coverage measure.
- Allowed to reuse a learner's section-wide KC state on every page where that KC appears.
- Suppressed or presented differently when the scope has incomplete KC coverage.

The `LktAoa` provider should own that eventual policy. Until it is defined, page- and container-level consumers must be explicitly feature-gated or show an unavailable/not-enough-information state for LKT-AOA sections; they must not silently fall back to the naive first-attempt heuristic while objective-level views use LKT-AOA.

### Dashboard oracle and cache integration

`Oli.InstructorDashboard.Oracles.ProgressProficiency` should delegate its proficiency portion to the version-aware facade instead of querying `ResourceSummary` directly. `Oli.InstructorDashboard.Oracles.ObjectivesProficiency` already delegates to Metrics, but it must pass the Section rather than only its ID so dispatch does not require another lookup.

The current downstream dashboard projections expect learner proficiency as a number in the `0.0..1.0` range and objective distributions using the existing labels. Those shapes can remain compatible with LKT-AOA. Confidence and coverage should be added as new fields in oracle payloads and projections rather than encoded into the numeric proficiency value or label.

Objective oracle payloads should also carry actual numeric aggregate values when available. Dashboard summary cards and CSV exports should consume those values for LKT-AOA instead of reconstructing approximate percentages from Low/Medium/High distributions. Label distributions remain useful for presentation and classification, but they should not be the only data passed downstream.

Oracle implementation versions must be incremented when their payload or calculation changes, and changing a Section's learning-model version must invalidate or rebuild cached dashboard snapshots. Otherwise, a section could continue displaying cached naive-model results after selecting LKT-AOA.
