# Core LKT-AOA State Application - Functional Design Document

## 1. Executive Summary

This design adds the delivery-side write model for LKT-AOA proficiency and confidence. A
single collection-oriented operation consumes the evaluated `PartAttempt`s already gathered
by `Oli.Delivery.Snapshots.Worker`, claims each attempt exactly once, resolves the exact
activity and publication-pinned learning-objective parameters, replays all contributions in a
deterministic order, and atomically persists compact learner state and distinct-part evidence.

The design performs a small fixed sequence of set-based database operations. Database
round trips do not grow with attempt, activity-part, or learning-objective cardinality, and no
operation scans learner attempt history. Pure Elixir performs the necessarily linear mapping,
grouping, and transition work. PostgreSQL uniqueness, neutral-row initialization, and
deterministically ordered row locks provide idempotency and lost-update protection.

This work consumes the completed contracts in
`docs/exec-plans/current/epics/learning_model_v2/data_model/`. The complete formulas, field
semantics, evidence examples, and ordering policy remain authoritative in
`docs/exec-plans/current/epics/learning_model_v2/core_impl/informal.md`; this FDD maps them to
concrete Torus components, transaction ordering, persistence, failure handling, and tests. It
covers `FR-001` through `FR-010` and `AC-001` through `AC-032`.

## 2. Requirements & Assumptions

- Persist one compact state per Section, learner, and directly targeted learning objective
  (`FR-001`, `AC-001` through `AC-003`).
- Apply the documented pre-response prediction, running AOA, and post-response recency
  transition with a binary outcome (`FR-002`, `AC-004` through `AC-007`).
- Count confidence breadth from distinct activity parts, independently of attempt count and
  without duplicating evidence per learning objective (`FR-003`, `AC-008` through `AC-011`).
- Support one response and a 500-1000-part graded assessment through the same bounded-query
  operation (`FR-004`, `AC-012` through `AC-014`).
- Claim immutable evaluated PartAttempts exactly once without adding write churn to the
  approximately 300 GB `part_attempts` table (`FR-005`, `AC-015` through `AC-018`).
- Commit claims, evidence, and final learner states together while preventing concurrent lost
  updates (`FR-006`, `AC-019` through `AC-021`).
- Dispatch from the loaded Section and preserve current summary analytics and xAPI behavior
  (`FR-007`, `AC-022` through `AC-024`).
- Consume typed v2 parameters and one startup-loaded configuration per batch (`FR-008`,
  `AC-025` through `AC-027`).
- Replay deterministically within a transaction without imposing global chronology across
  separate jobs (`FR-009`, `AC-028` through `AC-030`).
- Emit bounded operational telemetry without learner- or attempt-level identifiers (`FR-010`,
  `AC-031`, `AC-032`).

Assumptions:

- The operation processes one homogeneous `AttemptGroup`: one Section, learner, publication,
  and resource attempt. This is the existing Snapshot contract and is validated at the new
  boundary.
- `PartAttempt.attempt_guid` is immutable and unique. Only lifecycle state `:evaluated` is
  eligible.
- An eligible attempt has a non-null `date_evaluated`; a null value invalidates the batch.
- Correctness is exactly `score == out_of`; partial credit is incorrect. The xAPI `success`
  value is not an input.
- Direct part-to-objective mappings come from the exact activity Revision's `objectives` field,
  using the same list/map compatibility semantics as `Oli.Analytics.Summary`. Parent objective
  aggregation belongs to the later usage/read work and does not create parent state here.
- `(section_id, user_id, activity_id, part_id)` retains one effective learning-objective meaning
  for the life of an active Section. A conflicting mapping detected within one batch is rejected;
  historical retagging requires a future reconciliation workflow.
- Deleting a PartAttempt makes it impossible to submit that attempt for processing again, so
  cascading deletion of its application claim is safe.
- Configuration changes apply to future transitions after node restart and do not recompute
  existing learner state.

## 3. Repository Context Summary

- `Oli.Delivery.Snapshots.Worker` receives `part_attempt_guids` and `section_slug`, bulk-loads
  evaluated attempts through `ActivityAttempt`, `ResourceAttempt`, and `ResourceAccess`, and
  loads each exact activity `Revision` through `ActivityAttempt.revision_id`.
- `Oli.Analytics.Summary.AttemptGroup` already presents the useful batch boundary. Its part
  attempts include exact activity Revisions, and its context includes user, Section, Project,
  and publication IDs.
- `Oli.Analytics.Summary.execute_analytics_pipeline/3` currently constructs the AttemptGroup,
  writes resource/response summaries, and returns it to the Snapshot Worker for xAPI emission.
- Activity objective attachment uses `revision.objectives[part_id]`; legacy list values are
  already supported by summary analytics. Objective IDs are resource IDs.
- `Oli.Publishing.DeliveryResolver.from_resource_id/2` resolves a list of resource IDs to the
  exact Revisions pinned to a Section's publications and preserves caller ordering. This is the
  existing delivery-authoritative lookup boundary.
- `PartAttempt.attempt_guid` has an existing unique index. `published_resources` has indexes on
  publication and resource IDs plus publication/resource/revision uniqueness.
- The obsolete `Oli.Delivery.Attempts.PartAttemptCleaner` runtime/admin surface is removed in
  Phase 1. The new claim foreign key still cascades from `part_attempts.id` so any supported
  direct PartAttempt deletion cannot leave orphan claims.
- `Section.learning_model_version`, `Revision.learning_model_parameters`,
  `Oli.LearningModel.ModelVersion`, `Oli.LearningModel.Parameters`, and
  `Oli.LearningModel.Config` are completed inputs from the data-model work item.
- No cache or learner-state write context exists today. New code belongs under
  `Oli.LearningModel`, while the Snapshot Worker remains the workflow integration owner.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

`Oli.LearningModel` is the public dispatch boundary:

```elixir
@spec apply_evaluated_attempts(Section.t(), AttemptGroup.t() | nil) ::
        {:ok, BatchResult.t()} | {:error, term()}
```

- `nil` data and `:naive` Sections return a successful no-op result.
- `:lkt_aoa` fetches `Oli.LearningModel.Config` exactly once and delegates to the v2
  application service.
- No fallback from an LKT-AOA error to the naive formula is permitted.

Internal modules have narrow responsibilities:

- `Oli.LearningModel.LktAoa.Application` validates and normalizes the AttemptGroup, resolves
  typed parameters, owns the `Repo.transaction/1`, performs all set-based persistence, and
  emits batch telemetry.
- `Oli.LearningModel.LktAoa.Transition` is pure domain logic. It computes stable logistic
  predictions, running AOA, decayed success/failure state, recency logit, and confidence from a
  typed state, contribution, and `%Oli.LearningModel.Config{}`.
- `Oli.LearningModel.LearningState`, `PriorActivityPartEvidence`, and `AttemptApplication` are
  Ecto schemas for the three operational tables. Changesets expose no ordinary external
  mutation surface; the application service uses validated bulk operations.
- A small `Contribution` struct carries normalized immutable input: PartAttempt ID/GUID,
  evaluation time, activity resource and Revision IDs, part ID, direct objective IDs,
  part beta, score, and out-of value.
- `BatchResult` carries only bounded aggregate counts and a status for worker flow and telemetry.
  It contains no GUIDs, user IDs, or response data.

Snapshot integration is deliberately ordered:

1. Load the Section once from `section_slug` and bulk-load the existing attempt tuples.
2. Construct `AttemptGroup` once with `AttemptGroup.from_attempt_summary/3`.
3. Call `Oli.LearningModel.apply_evaluated_attempts/2`.
4. On success, pass the already-built group through a new overload of
   `Summary.execute_analytics_pipeline/1` that performs the existing summary upserts without
   reconstructing the group.
5. On summary success, emit the existing xAPI bundle unchanged.

The existing three-argument Summary API remains as a compatibility wrapper. Running LKT-AOA
before summary writes prevents a new LKT failure from causing summary counts to be written and
then repeated. If summary or xAPI fails after LKT commits, Oban retries; the LKT claim makes the
second application a no-op and the existing downstream workflow resumes. The LKT transaction is
not distributed across summaries, S3, or xAPI.

### 4.2 State & Data Flow

Before opening the transaction, the application boundary:

1. Validates the Section/group identity and every contribution's evaluated lifecycle, GUID,
   part ID, score fields, and `date_evaluated`.
2. Reads each exact activity Revision already attached to the PartAttempt, extracts and
   deduplicates its direct objective IDs for the part, and extracts typed `beta_part` with the
   documented `0.0` absence fallback.
3. Detects conflicting objective mappings for the same normalized evidence key within the
   batch. It does not invent union semantics for a retagged part.
4. Fetches the typed global configuration once.

The transaction then performs this fixed sequence:

1. **Claim attempts.** One parameterized `INSERT ... SELECT` selects evaluated PartAttempts by
   GUID, inserts `(part_attempt_id, :lkt_aoa, applied_at)`, ignores primary-key conflicts, and
   returns only newly claimed IDs. Duplicate input and successful retries disappear here.
2. **Filter contributions.** Retain only contributions whose PartAttempt ID was returned. If none
   remain, commit a no-op without touching evidence or state.
3. **Resolve objective Revisions.** Resolve all distinct direct objective resource IDs in one
   delivery-authoritative query using the group's Section/publication context. Missing published
   Revisions are errors. Extract typed `beta_lo`, with `0.0` only for an absent envelope.
4. **Initialize state keys.** Bulk insert neutral rows for all affected
   `(section_id, user_id, learning_objective_id)` keys with `ON CONFLICT DO NOTHING`. This is not
   the final state write; it makes every key lockable even when two jobs encounter it for the
   first time.
5. **Lock state keys.** Select every affected row `FOR UPDATE`, ordered by
   `(section_id, user_id, learning_objective_id)`. A concurrent neutral insert waits on the unique
   key, after which the waiter reads the committed state rather than calculating from zero.
6. **Capture evidence.** Deduplicate and sort claimed activity-part keys, bulk insert them with
   `ON CONFLICT DO NOTHING RETURNING`, and map only returned rows to their direct objective IDs.
   Group the resulting confidence increments by state key.
7. **Replay transitions.** Group all claimed proficiency contributions by state key, sort each
   group by `(date_evaluated, attempt_guid)`, and reduce it through the pure transition. Apply the
   grouped confidence increment once to the final state.
8. **Persist final states.** Write one final value per affected state in one bulk upsert (or one
   parameterized `UPDATE ... FROM VALUES` statement), replacing only mutable state and
   `updated_at` fields.
9. Commit claims, evidence, and learner state together.

State initialization before locking is essential. A plain `SELECT FOR UPDATE` cannot lock a row
that does not exist and would allow two first-opportunity transactions to compute from the same
neutral state. The unique neutral insert turns that absence race into PostgreSQL conflict waiting;
the subsequent ordered lock handles both new and existing rows uniformly.

The claim conflict has corresponding concurrency semantics: PostgreSQL waits on an uncommitted
conflicting application row. If the first transaction commits, the waiter returns no claim; if it
rolls back, the waiter can claim and apply the attempt.

### 4.3 Lifecycle & Ownership

- Learner state and evidence are derived operational delivery data owned by a Section. Section or
  user deletion cascades them. Resource deletion also cascades corresponding objective/activity
  rows; published content itself remains immutable.
- `learning_model_attempt_applications` is append-only and immutable. Its only lifecycle event
  after insertion is cascade deletion with the source PartAttempt.
- `learning_state` is updated only by the LKT-AOA application service. No controller, LiveView,
  import, or ordinary changeset may directly assign its calculated fields.
- The activity Revision supplies mapping and item beta for an individual historical attempt. The
  Section publication supplies the learning-objective beta at application time. Parameter payloads
  are never copied into learner state or claim rows.
- Existing summary and xAPI records keep their current ownership and retention policies. They are
  not online dependencies for applying state.
- A future repair/backfill tool must use a separately designed administrative boundary. This
  operation neither scans for old unclaimed attempts nor reconstructs state from OLTP history.

### 4.4 Alternatives Considered

- Add a processed marker to `part_attempts`: rejected because each update would add MVCC/WAL and
  autovacuum pressure to Torus's approximately 300 GB largest table.
- Use evidence uniqueness as attempt idempotency: rejected because repeated attempts correctly
  change proficiency even when confidence breadth does not change.
- Keep encountered part IDs in an array on learner state: rejected because concurrent set updates,
  membership lookup, storage growth, and one-part/many-objective semantics are substantially less
  reliable than a normalized unique projection.
- Insert one evidence row per objective: rejected because the encountered fact is activity-part
  membership; objective fan-out is derived from the exact Revision mapping.
- Lock only existing state rows: rejected because absent rows cannot be locked and concurrent first
  updates can overwrite one another.
- Use a database query/write inside an objective reduction: rejected because round trips would grow
  with exam and mapping cardinality.
- Put all math in one large SQL CTE: rejected because sequential per-state replay, formula testing,
  and failure diagnostics are clearer in pure Elixir; a bounded series of set-based statements
  satisfies the performance contract.
- Enforce cross-job chronological ordering: rejected because it requires scans, watermarks, queues,
  or replay infrastructure disproportionate to the expected rare ordering inversion.
- Run LKT after existing summary upserts: rejected because a new LKT failure would cause Oban retry
  after non-idempotent summary increments had already occurred.
- Add a feature flag or infer selection from parameters/Project: rejected because the persisted,
  pinned `Section.learning_model_version` is the complete dispatch contract.

## 5. Interfaces

Public context boundary:

```elixir
defmodule Oli.LearningModel do
  @spec apply_evaluated_attempts(Section.t(), AttemptGroup.t() | nil) ::
          {:ok, BatchResult.t()} | {:error, application_error()}
end
```

The function verifies that a non-empty group's `context.section_id` matches the loaded Section.
It returns `{:ok, %BatchResult{status: :skipped}}` for `:naive`, and a result with input, claimed,
contribution, affected-state, and new-evidence counts for `:lkt_aoa`.

Pure transition boundary:

```elixir
@spec apply_proficiency(
        LearningState.t(),
        %{beta_lo: float(), beta_part: float(), correct: 0 | 1},
        Config.t()
      ) :: LearningState.t()

@spec apply_confidence(LearningState.t(), non_neg_integer(), Config.t()) ::
        LearningState.t()
```

`apply_proficiency/3` uses a numerically stable logistic implementation. The running average may
use the algebraically equivalent stable form
`aoa + (p - aoa) / (attempt_count + 1)` to avoid multiplying a large count by AOA. Prediction and
AOA occur before the observed outcome changes recency state.

Typed coefficient helpers accept only the implemented structs:

```elixir
@spec activity_part_beta(Revision.t(), String.t()) :: {:ok, float()} | {:error, term()}
@spec learning_objective_beta(Revision.t()) :: {:ok, float()} | {:error, term()}
```

`nil` envelope/part entry returns `0.0`; a supported explicit `0.0` also returns `0.0`. A wrong
typed payload at this supposedly validated boundary is an error rather than an absence fallback.

Summary integration adds an overload accepting `%AttemptGroup{}` (and `nil`) while retaining
`execute_analytics_pipeline/3`. No Snapshot job argument or xAPI bundle contract changes.

## 6. Data Model & Storage

Use plural PostgreSQL table names and Ecto modules while retaining the conceptual names in the
informal design.

### `learning_states`

- Composite primary key: `section_id`, `user_id`, `learning_objective_id`.
- All three are bigint foreign keys; Section and user deletion cascade. The objective references
  `resources.id` and cascades when the resource is removed.
- `attempt_count` and `unique_activity_part_count`: bigint, non-null, default `0`, check `>= 0`.
- `success_score`, `failure_score`, `recency_logit`, `aoa`, and `confidence`: double precision,
  non-null, default `0.0`.
- Check `success_score >= 0.0`, `failure_score >= 0.0`, `aoa` between `0.0` and `1.0`, and
  `confidence` between `0.0` and `1.0`. Application validation prevents non-finite writes.
- Standard UTC `inserted_at` and `updated_at` timestamps.
- No surrogate ID, latest probability, coefficient, parameter Revision, response value, or attempt
  history column is stored (`AC-001`, `AC-002`, `AC-003`).

The composite primary key is also the write/lock index. Do not add a second identical unique index.
Read-oriented indexes for instructor aggregation belong to the usage work item once its exact query
shapes are implemented.

### `prior_activity_part_evidence`

- Composite primary key: `section_id`, `user_id`, `activity_id`, `part_id`.
- Section, user, and activity resource foreign keys cascade on deletion.
- `part_id` is non-null text and uses the existing non-empty authored part-ID contract. Do not add
  an unapproved byte-length cap.
- `inserted_at` is the only timestamp; there is no update workflow or `updated_at`.
- No objective ID is stored (`AC-008`, `AC-009`).

The composite primary key supplies both set uniqueness and the `ON CONFLICT` target without a
surrogate key or redundant index.

### `learning_model_attempt_applications`

This table has exactly three fields (`AC-015`):

```text
part_attempt_id          bigint primary key, FK part_attempts.id ON DELETE CASCADE
learning_model_version   string-backed Ecto.Enum using ModelVersion.values()
applied_at               UTC timestamp
```

The Ecto schema uses `@primary_key false`, marks `part_attempt_id` as the primary key, and does not
call `timestamps()`. It has no surrogate `id`, `inserted_at`, `updated_at`, Section/user/resource
keys, GUID, outcome, parameter, or state values. A database check limits the semantic model value
to those supported by `Oli.LearningModel.ModelVersion`; the application currently inserts only
`:lkt_aoa` (`AC-016`, `AC-018`).

### Migration posture

All three tables are new and initially empty; no historical learner attempt or Revision table is
rewritten or backfilled. Use the repository's bounded migration lock pattern, including a short
transaction-local `lock_timeout`, because the cascading foreign key briefly locks the very large
`part_attempts` table during DDL acquisition. The claim primary key is already its lookup index.
Composite primary keys cover all write conflict and row-lock shapes; no JSONB or history index is
introduced.

The down migration drops only these derived operational tables, in reverse dependency order. It is
data-destructive for calculated LKT state and therefore requires reconstruction from the external
audit/analytics path before rollback if LKT-AOA has been enabled in production.

## 7. Consistency & Transactions

The transaction boundary starts with the bulk claim and ends with the final state upsert. Claim
rows, evidence rows, neutral state initialization, and calculated final states commit or roll back
together (`AC-019`). Parameter/config normalization that cannot mutate the database occurs before
the transaction where possible; authoritative published objective resolution and all state reads
occur through the transaction's Repo connection.

Lock ordering is always `(section_id, user_id, learning_objective_id)` and input evidence keys are
also deduplicated/sorted before their one insert. Multiple contributions for one state are reduced
in memory and produce one final database value (`AC-020`, `AC-021`). No worker transaction is held
open while emitting xAPI, writing S3, calling ClickHouse, or performing network I/O.

Within one state, contributions sort by `date_evaluated ASC, attempt_guid ASC` (`AC-028`). A null
evaluation date fails validation before the claim statement (`AC-029`). Transactions do not seek,
wait for, or repair earlier attempts from other jobs; whichever valid transaction obtains the state
locks first establishes cross-job ordering (`AC-030`).

Concurrent behavior is verified for:

- the same PartAttempt in two workers: the application primary key permits one claim;
- different attempts affecting the same existing state: ordered `FOR UPDATE` serializes replay;
- different attempts creating the same state: neutral insert conflict plus later lock serializes
  initialization;
- different attempts carrying the same first evidence: the state lock serializes the shared
  objective mapping and the evidence primary key permits one confidence increment.

## 8. Caching Strategy

No cache is introduced. The batch already contains exact activity Revisions, published objective
Revisions are resolved in one indexed query, current learner state must be transactionally fresh,
and evidence/application membership is decided by PostgreSQL uniqueness. Cachex would not remove
these authoritative operations and could create stale-model or lost-update behavior.

`Oli.LearningModel.Config.fetch!/0` is an application-environment read performed once per LKT-AOA
batch, after which the immutable struct is passed through all transitions (`AC-027`).

## 9. Performance & Scalability Posture

The LKT path uses at most these statement categories for a non-empty, newly claimed batch:

1. one application `INSERT ... SELECT ... RETURNING`;
2. one publication-pinned objective-Revision resolution query;
3. one neutral state insert;
4. one ordered state lock/read;
5. one evidence insert returning new keys;
6. one final state bulk write.

An all-duplicate retry terminates after the claim. The Section and evaluated-attempt queries are
fixed Snapshot integration queries outside this transaction. The count remains constant as batch
size and activity/objective fan-out grow (`AC-012`, `AC-013`). All SQL uses arrays, `VALUES`, or
bulk Ecto operations, never database I/O from a per-part/per-objective reduction.

CPU and memory are linear in claimed attempts plus unique part/objective contributions. Maps and
`MapSet`s provide deduplication/grouping; each state retains only its ordered contributions and one
final struct. A 500-1000 GUID representative batch must be measured for bind/statement size,
query plans, lock duration, and total allocation. If PostgreSQL adapter parameter limits require
chunking in the future, chunks must remain a fixed configured number for the supported maximum or
use array/unnest forms; an unbounded query-per-chunk implementation would violate `AC-014`.

The claim query uses the existing unique `part_attempts.attempt_guid` index and lifecycle predicate.
Objective resolution uses existing publication/resource indexes. Composite primary keys support
all new conflict and lock paths. No attempt-history aggregate or write to `part_attempts` occurs.

## 10. Failure Modes & Resilience

- Unsupported Section model: return a controlled dispatch error; do not guess or downgrade.
- Invalid/mixed AttemptGroup, non-evaluated input, missing GUID/part identity, or null evaluation
  date: fail before claims.
- Missing Section publication or missing published objective Revision: roll back with a bounded
  category. Parameter absence is cold start; Revision absence is not.
- Unsupported/mismatched typed parameter at the core boundary: fail and roll back. This indicates
  persisted-data or lifecycle corruption and must not silently become beta `0.0`.
- Inconsistent objective mappings for one evidence identity in the same batch: fail with a retag
  category instead of producing enumeration-dependent confidence.
- Claim conflict: expected retry/concurrency behavior, not an error.
- State/evidence constraint or lock/deadlock error: return `{:error, reason}` so Oban retries. The
  entire LKT transaction rolls back.
- LKT commit followed by summary/xAPI failure: retry is safe because claims make LKT a no-op; the
  existing downstream retry behavior remains in force.
- Worker exhausts three attempts: existing Oban failure visibility applies. Telemetry identifies
  the bounded failure category without identifiers.

The application does not rescue node exits or database disconnects into success. PostgreSQL commit
is the authority: an uncertain worker retry safely re-enters the claim boundary.

## 11. Observability

Emit a low-cardinality telemetry span under
`[:oli, :learning_model, :lkt_aoa, :batch]`, with normal `:start`, `:stop`, and `:exception` events.
Stop measurements include native-unit duration plus input-attempt, claimed-attempt, contribution,
affected-state, and new-evidence counts. Metadata is limited to semantic model, `:ok | :error |
:skipped`, and a bounded failure-category atom (`AC-031`).

Do not include Section/user/resource IDs, PartAttempt IDs/GUIDs, part IDs, response content,
scores, parameter payloads, SQL bind values, or exception structs in custom metadata. Existing
Repo/Oban telemetry supplies database timing, retry, queue, and exception correlation.

AppSignal dashboards/queries should track duration percentiles, claimed/input ratio, state and
evidence fan-out, error categories, and Oban retries. Verification captures Repo query events around
only the operation and proves identical statement-category count for size-one and representative
large batches (`AC-032`).

## 12. Security & Privacy

- The public boundary accepts server-created `%Section{}` and `%AttemptGroup{}` values, not client
  JSON. Section/group identity validation prevents accidental cross-Section application.
- Model selection comes only from the loaded persisted Section. User attrs, parameter presence,
  Project defaults, `analytics_version`, and job arguments cannot override it.
- Objective parameters come from delivery-pinned Revisions; authoring HEAD is never queried.
- IDs in the three new tables are required operational learner data. No response body, score,
  attempt GUID, title, activity content, parameter payload, or unnecessary model history is copied.
- Foreign keys and Section-scoped composite keys preserve tenant boundaries. No query accepts a
  user-supplied SQL identifier or interpolated SQL value; any specialized SQL remains parameterized.
- User and Section cascade behavior supports existing deletion/privacy workflows. Claim cleanup
  follows direct deletion of the owning PartAttempt.
- Logs and custom telemetry follow the bounded aggregate-only policy in Section 11.

## 13. Testing Strategy

Tests use normal Torus factories and SQL Sandbox. Pure formula tests do not require database setup.
Concurrency tests use the repository's explicit Sandbox ownership/shared-mode pattern and real
PostgreSQL uniqueness/locks rather than mocks.

| Coverage | Verification |
| --- | --- |
| `AC-001`, `AC-002`, `AC-003` | Migration/schema tests assert composite identity, columns, neutral defaults, constraints, timestamps, and absence of prohibited fields. |
| `AC-004`, `AC-005`, `AC-006`, `AC-007` | Pure tests use hand-calculated first/subsequent transitions, pre-outcome AOA, decay, partial credit, exact credit, and stable extreme logits. |
| `AC-008`, `AC-009`, `AC-010`, `AC-011` | Integration tests cover new/repeated parts, several parts per objective, one part targeting several objectives, and exact confidence values. |
| `AC-012`, `AC-013`, `AC-014` | One public-boundary test covers single, multi-part, multi-objective, overlapping exam input; Repo telemetry compares one and 500-1000 GUID batches; manual `EXPLAIN` verifies indexed shapes and no history scan. |
| `AC-015`, `AC-016`, `AC-017`, `AC-018` | Schema tests prove exactly three claim fields; integration tests prove evaluated-only bulk return semantics, duplicate/retry no-op, shared enum, and direct PartAttempt deletion cascade. |
| `AC-019`, `AC-020`, `AC-021` | Injected post-claim/post-evidence failure tests prove rollback; two-task tests cover same claim, same existing state, simultaneous missing state, and first-evidence races; query capture proves one final state write. |
| `AC-022`, `AC-023`, `AC-024` | Public-boundary tests cover loaded-Section dispatch and naive no-op. Phase 4 Snapshot Worker tests then exercise the real call site plus server/client evaluation, graded-page finalization, auto-submit, and manual-grading producer paths while retaining summary rows and xAPI emission. |
| `AC-025`, `AC-026`, `AC-027` | Tests use differing exact activity/authoring/published objective Revisions, typed envelopes, missing/explicit-zero cases, and an injectable config fetch seam or trace to prove one fetch per batch. |
| `AC-028`, `AC-029`, `AC-030` | Shuffled/equal-time tests prove evaluation-time/GUID order; null dates prove pre-claim rollback; a two-job test documents lock-acquisition rather than chronology as cross-job policy. |
| `AC-031`, `AC-032` | Telemetry attachment tests assert aggregate measurements and bounded metadata; operational verification confirms AppSignal/Oban visibility and stable query counts. |

Add focused tests under `test/oli/learning_model/` for schemas, parameters, transitions,
application, transactions, query counts, and concurrency. Extend Snapshot and Summary tests at
their existing locations. A focused domain integration test is more
appropriate than extending `Oli.Scenarios` for transaction locks, exact query counts, and internal
projection rows; a scenario may supplement producer coverage if current directives can observe the
published-to-attempt outcome without new infrastructure.

Verification includes `mix format`, focused tests, broader delivery/attempt/snapshot/analytics
regressions, warning-free compilation, migration up/down on a clean database, migration lock review,
and representative PostgreSQL query plans.

## 14. Backwards Compatibility

- Every existing and ordinarily created Section remains `:naive`, so it performs no new state,
  evidence, or claim writes (`AC-022`, `AC-023`).
- Existing Snapshot job arguments, producers, queue, retry count, summary data, and xAPI statement
  format remain unchanged (`AC-024`).
- The three-argument Summary API remains available; its new prebuilt-group overload removes duplicate
  construction without changing callers outside the Worker.
- Revisions with no learning-model parameters are valid. LKT-AOA treats absence as the documented
  `0.0` cold start (`AC-025`, `AC-026`).
- No history backfill is required to deploy the tables. LKT state begins only for attempts applied
  after a Section has been intentionally created as `:lkt_aoa` through trusted setup.
- No page/container/course read behavior or Metrics API changes in this work. Those consumers remain
  owned by `docs/exec-plans/current/epics/learning_model_v2/usage/`.
- There is no feature flag and no silent model fallback. Persisted Section selection is the rollout
  boundary.

## 15. Risks & Mitigations

- First-state race causes lost updates: neutral bulk insert before ordered row locks makes absent
  keys serializable.
- Same attempt is applied twice: primary-key claim and returned-row filtering are in the mutation
  transaction.
- Confidence increments twice: evidence primary key and `RETURNING` make only the winning insert
  count.
- Large exams produce multiplicative joins: use a fixed series of simple indexed queries and pure
  grouping rather than one activity/objective/state cross-product query.
- Lock contention or deadlocks: lock short-lived state rows in one total order, sort evidence keys,
  and perform no external I/O in the transaction.
- Floating-point overflow or precision drift: reject non-finite inputs at the established typed
  boundary, use stable logistic/running-average forms, and constrain stored probability values.
- Missing publication data is mistaken for an untrained beta: distinguish absent parameter envelope
  (`0.0`) from absent pinned Revision (error).
- A retagged part makes normalized evidence ambiguous: validate same-batch mappings, preserve the
  stable-mapping assumption, and defer historical reconciliation explicitly.
- New failure point causes legacy summary duplication: apply LKT before summary writes and make LKT
  idempotent when later steps retry.
- DDL waits behind traffic on the large PartAttempt table: use a bounded migration lock timeout and
  documented retry window.
- Query-count tests pass on tiny input but fail at operational size: include 500-1000 GUID verification
  and query-plan capture before rollout.

## 16. Open Questions & Follow-ups

No unresolved decision blocks implementation.

Follow-ups outside this work item:

- Define and implement a reconciliation/rebuild workflow before allowing objective retagging or
  parameter republishing for active LKT-AOA Sections.
- Decide whether exact historical configuration audit/versioning is required beyond deployment
  configuration history.
- Build the usage/read layer for learner, instructor, page, container, course, and authoring views.
- Change the default for newly created Projects to `:lkt_aoa` only after core and usage rollout is
  approved; do not mutate existing Sections.
- Add an administrative parameter-upload/training workflow separately.
- Revisit read-oriented indexes only with the usage work item's measured query shapes.

## 17. References

- `docs/exec-plans/current/epics/learning_model_v2/core_impl/informal.md`
- `docs/exec-plans/current/epics/learning_model_v2/core_impl/prd.md`
- `docs/exec-plans/current/epics/learning_model_v2/core_impl/requirements.yml`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/fdd.md`
- `docs/exec-plans/current/epics/learning_model_v2/data_model/informal.md`
- `docs/design-docs/attempt-handling.md`
- `docs/design-docs/attempt.md`
- `docs/design-docs/publication-model.md`
- `lib/oli/delivery/snapshots/worker.ex`
- `lib/oli/analytics/summary.ex`
- `lib/oli/analytics/summary/attempt_group.ex`
- `lib/oli/publishing/delivery_resolver.ex`
- `lib/oli/learning_model/model_version.ex`
- `lib/oli/learning_model/parameters.ex`
- `lib/oli/learning_model/config.ex`
