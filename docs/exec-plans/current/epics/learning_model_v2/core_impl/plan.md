# Core LKT-AOA State Application - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/learning_model_v2/core_impl/prd.md`
- FDD: `docs/exec-plans/current/epics/learning_model_v2/core_impl/fdd.md`
- Detailed technical decisions: `docs/exec-plans/current/epics/learning_model_v2/core_impl/informal.md`
- Canonical requirements: `docs/exec-plans/current/epics/learning_model_v2/core_impl/requirements.yml`
- Completed dependency: `docs/exec-plans/current/epics/learning_model_v2/data_model/`

## Scope

Implement the delivery write path that applies evaluated PartAttempts to compact LKT-AOA
proficiency and confidence state. The work adds three operational tables, pure transition logic,
one atomic and idempotent bulk application service, Snapshot Worker dispatch, bounded telemetry,
and concurrency/performance verification for single responses and 500-1000-part assessments.

This plan does not implement proficiency reads or display, parent/page/container/course
aggregation, authoring Insights, model-selection UI, parameter training/upload, historical
backfill/reconstruction, cross-job chronological repair, or a new-Project `:lkt_aoa` default.
Existing `:naive` Sections retain their current behavior. No feature flag is introduced because
the persisted and trusted `Section.learning_model_version` is the rollout boundary.

Source comments are a deliverable in every phase. Add concise `@moduledoc`, `@doc`, and inline
comments where they preserve non-obvious mathematical ordering, database concurrency semantics,
retry behavior, privacy constraints, or architectural boundaries. Do not narrate syntax or leave
comments that merely repeat names; each phase gate includes reviewing comments for accuracy and
future maintenance value.

## Clarifications & Default Assumptions

- `docs/exec-plans/current/epics/learning_model_v2/core_impl/informal.md` remains authoritative
  for formulas, evidence examples, exact application-table shape, and within-batch ordering. The
  FDD defines concrete module, persistence, and transaction boundaries.
- The public boundary is `Oli.LearningModel.apply_evaluated_attempts/2`; internal v2 modules live
  under `Oli.LearningModel.LktAoa`.
- One invocation processes one homogeneous `%Oli.Analytics.Summary.AttemptGroup{}` for one Section,
  learner, publication context, and resource attempt. The boundary validates that invariant.
- Only direct learning objectives attached to the evaluated activity part receive write-time state.
  Parent-objective aggregation is deferred to the usage/read work item.
- The fixed transaction categories are: claim, publication-pinned objective resolution, neutral
  state initialization, ordered state lock/read, evidence insert/return, and one final state write.
- `Oli.Delivery.Attempts.PartAttemptCleaner` is obsolete and is removed in Phase 1 together with
  its supervisor child, admin route/LiveView, and all associated tests. This decision supersedes
  cleaner-specific wording in earlier work-item artifacts. The application-claim foreign key still
  uses `ON DELETE CASCADE` so any supported direct PartAttempt deletion cannot leave an orphan;
  cascade verification no longer depends on the retired cleaner.
- Configuration is fetched once per LKT-AOA operation. Missing supported parameter envelopes or
  part entries resolve to `0.0`; missing published Revisions and impossible typed payloads are
  controlled failures.
- Concurrency for absent state rows uses bulk neutral insertion followed by deterministic
  `FOR UPDATE` locking. A plain lock of only existing rows is insufficient.
- PostgreSQL establishes cross-job order through lock acquisition. Only contributions claimed in
  the same transaction are ordered by `date_evaluated ASC, attempt_guid ASC`.
- Specialized SQL must be parameterized. Bulk calls must use arrays, unnest, `VALUES`, or set-based
  Ecto queries and must not introduce a query inside a part/objective loop.
- Query-count comparison covers the learning-model boundary itself. Existing fixed Snapshot Section
  and attempt-loading queries are measured separately so regressions are attributable.
- Focused ExUnit integration tests are the primary proof because locks, rollback, query counts, and
  internal projections are not appropriate scenario assertions. Existing producer workflow tests
  may be supplemented by `Oli.Scenarios` only if no framework extension is required.
- Jira is the execution system of record, but no issue key was supplied. Record a real association
  if one becomes available; do not invent a ticket.

## Phase 1: Operational Tables And Ecto Schemas

- Goal: Add the minimal persistence foundation and database constraints without altering or
  backfilling historical attempts.
- Tasks:
  - [x] Add one migration for `learning_states`, `prior_activity_part_evidence`, and
    `learning_model_attempt_applications` with the exact FDD columns, types, defaults, and
    ownership semantics (`FR-001`, `FR-003`, `FR-005`, `AC-001`, `AC-002`, `AC-003`, `AC-008`,
    `AC-015`, `AC-018`).
  - [x] Use composite primary keys for learner state and prior evidence; do not add redundant
    unique indexes or surrogate IDs.
  - [x] Define `learning_model_attempt_applications` with exactly `part_attempt_id`,
    `learning_model_version`, and `applied_at`; use the shared semantic enum vocabulary, no
    implicit ID, and no standard timestamps (`AC-015`).
  - [x] Add the application claim foreign key to `part_attempts.id` with `ON DELETE CASCADE`, and
    cascade Section/user/resource-owned derived data according to the FDD (`AC-018`).
  - [x] Remove the obsolete `Oli.Delivery.Attempts.PartAttemptCleaner` implementation, its
    supervision entry, admin `/part_attempts` route and LiveView, cleaner and LiveView tests, and
    any remaining references. Do not replace it with another attempt-deletion service in this work.
  - [x] Reconcile cleaner-specific wording in the PRD, FDD, informal notes, and `AC-018` so those
    artifacts describe general PartAttempt cascade deletion and the intentional cleaner removal.
  - [x] Add non-negative count/state checks and `[0.0, 1.0]` checks for persisted AOA/confidence;
    keep all three tables free of historical responses and coefficient payloads (`AC-002`,
    `AC-003`).
  - [x] Use the established short transaction-local migration `lock_timeout`; document that the
    new tables are empty and that the FK requires bounded DDL lock acquisition on the approximately
    300 GB `part_attempts` table.
  - [x] Add `LearningState`, `PriorActivityPartEvidence`, and `AttemptApplication` Ecto schemas
    with explicit primary-key/timestamp declarations and no ordinary mass-assignment API.
  - [x] Author helpful schema/migration comments explaining why natural keys are used, why the
    application table has exactly three fields, why it has no `updated_at`, and why the large
    PartAttempt table is referenced rather than updated. Avoid comments that restate field names.
- Testing Tasks:
  - [x] Add schema/migration tests for fields, Ecto types, neutral defaults, constraints, composite
    uniqueness, foreign keys, and absence of prohibited fields (`AC-001`, `AC-002`, `AC-003`,
    `AC-008`, `AC-015`).
  - [x] Add a focused persistence test that directly deletes a source PartAttempt and proves its
    application claim cascades without leaving an orphan (`AC-018`).
  - [x] Verify application startup and router compilation after removing the cleaner supervisor
    child/admin surface, and use a repository-wide reference scan to prove no stale cleaner module,
    PubSub topic, route, LiveView, or test remains.
  - [x] Run migration up/down on a clean local database; inspect generated constraints/indexes and
    record lock/retry and destructive-down implications in the phase execution record.
  - Command(s): `mix test test/oli/learning_model`, `mix compile --warnings-as-errors`, `mix ecto.migrate`, `mix format --check-formatted`
- Definition of Done:
  - The three empty operational tables match the FDD exactly, direct-delete cascade behavior is
    proven, the obsolete cleaner and its admin/runtime surfaces are gone, `part_attempts` receives
    no new column or update workflow, migration safety is recorded, and source comments preserve
    the unusual schema decisions.
- Gate:
  - Gate A: Storage tests and migration inspection prove `AC-001` through `AC-003`, `AC-008`,
    `AC-015`, and direct-delete cascade under `AC-018`; the old cleaner, its supervisor/admin
    references, and all redundant index, timestamp, or history fields are absent.
- Dependencies:
  - Completed data-model work item and its deployed migration/contracts.
- Parallelizable Work:
  - Ecto schema modules/tests can proceed alongside migration review after field types and natural
    keys are fixed; only one developer should own the migration sequence and index definitions.

## Phase 2: Pure Transition And Contribution Domain

- Goal: Implement deterministic, independently testable model math and input normalization before
  introducing transactional persistence.
- Tasks:
  - [x] Add typed internal `Contribution` and aggregate-only `BatchResult` structs with enforced
    fields and specs; keep GUIDs/learner IDs out of `BatchResult`.
  - [x] Implement activity-part objective extraction with the existing Summary list/map semantics,
    per-part deduplication, direct-objective-only behavior, and same-evidence mapping consistency
    validation (`FR-004`, `AC-012`).
  - [x] Implement typed activity-part and learning-objective coefficient extraction. Use exact
    typed v2 envelopes, return `0.0` only for documented absence, preserve explicit `0.0`, and
    reject impossible payload/resource mismatches (`FR-008`, `AC-025`, `AC-026`).
  - [x] Implement pure `LktAoa.Transition` probability, AOA, success/failure decay, recency logit,
    binary outcome, and confidence functions using numerically stable logistic and running-average
    forms (`FR-002`, `FR-003`, `AC-004` through `AC-007`, `AC-010`).
  - [x] Implement pure grouping and replay helpers that sort each learner/objective sequence by
    `date_evaluated ASC, attempt_guid ASC`, reject null evaluation times, and produce one final
    state plus aggregate confidence increment per key (`FR-009`, `AC-011`, `AC-021`, `AC-028`,
    `AC-029`, `AC-030`).
  - [x] Keep `Oli.LearningModel.Config` as an explicit function argument throughout pure logic;
    do not read application configuration or environment state inside reductions (`AC-027`).
  - [x] Author helpful source comments documenting predict-before-outcome ordering, why xAPI success
    is not used, the numerically stable formula forms, direct-objective scope, deterministic tie
    breaking, and the intentional absence of cross-job chronology. Do not comment elementary map
    or arithmetic operations.
- Testing Tasks:
  - [x] Add hand-calculated first/subsequent transition tests covering pre-response probability,
    AOA order, decayed scores, recency logit, exact/partial credit, and confidence (`AC-004`,
    `AC-005`, `AC-006`, `AC-007`, `AC-010`).
  - [x] Test stable extreme logits, neutral state, multiple sequential contributions, shuffled
    input, equal timestamps, null dates, and independent state groups (`AC-005`, `AC-028`,
    `AC-029`, `AC-030`).
  - [x] Test legacy list/map objective shapes, duplicate objective IDs, one part targeting several
    objectives, inconsistent mappings, typed parameter values, all cold-start cases, and explicit
    zero (`AC-011`, `AC-012`, `AC-025`, `AC-026`).
  - Command(s): `mix test test/oli/learning_model/lkt_aoa/transition_test.exs test/oli/learning_model/lkt_aoa/contribution_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - Formula and normalization modules are pure, typed, deterministic, fully covered without a Repo,
    and their source comments make the model ordering and fallback rules auditable.
- Gate:
  - Gate B: Pure tests prove `AC-004` through `AC-007`, `AC-010`, `AC-011`, `AC-025`, `AC-026`,
    and `AC-028` through `AC-030`, and prove the contribution-normalization portion of `AC-012`.
    The public collection-oriented operation portion of `AC-012` remains Phase 3 scope. No model
    rule depends on enumeration order or runtime configuration lookup.
- Dependencies:
  - Gate A for the canonical state struct; coefficient types/config come from the completed
    data-model work item.
- Parallelizable Work:
  - Formula/confidence work and contribution/parameter normalization can proceed concurrently if
    their typed structs and error vocabulary are agreed first.

## Phase 3: Atomic Bulk Application And Concurrency Safety

- Goal: Implement the bounded, idempotent PostgreSQL transaction and public semantic dispatch.
- Tasks:
  - [x] Add `Oli.LearningModel.apply_evaluated_attempts/2` with loaded-Section dispatch: `nil` and
    `:naive` return aggregate no-op results; only `:lkt_aoa` fetches configuration once and invokes
    the application service (`FR-007`, `AC-022`, `AC-023`, `AC-027`).
  - [x] Validate a homogeneous internal AttemptGroup, evaluated lifecycle, immutable GUID, part
    identity, scores, Section identity, and non-null evaluation dates before attempting claims.
  - [x] Implement one parameterized `INSERT ... SELECT ... ON CONFLICT DO NOTHING RETURNING` claim
    for evaluated GUIDs and allow only returned PartAttempt IDs to contribute (`FR-005`, `AC-016`,
    `AC-017`).
  - [x] Resolve all distinct objective Revisions in one delivery-authoritative, publication-pinned
    query and extract typed beta values; fail on missing published Revisions rather than treating
    them as untrained (`FR-008`, `AC-025`, `AC-026`).
  - [x] Bulk insert neutral state keys, then select every affected state `FOR UPDATE` in deterministic
    composite-key order so both existing-state and absent-state races serialize (`FR-006`,
    `AC-019`, `AC-020`).
  - [x] Bulk insert deduplicated/sorted prior evidence with conflict-ignore/return semantics, map
    only new rows to direct objectives, and group confidence increments (`FR-003`, `AC-009`,
    `AC-010`, `AC-011`).
  - [x] Replay all claimed contributions in memory and perform one final bulk write per operation,
    never one database write per contribution or objective (`FR-004`, `AC-012`, `AC-013`,
    `AC-021`).
  - [x] Keep claims, evidence, neutral rows, locked reads, and final states inside one
    `Repo.transaction/1`; return controlled bounded failure categories for Oban retry (`AC-019`).
  - [x] Author helpful source comments at the specialized SQL and transaction boundaries explaining
    returned-row authority, conflict wait/rollback semantics, neutral-insert-before-lock necessity,
    total lock ordering, evidence fan-out, and why no external I/O may occur in the transaction.
    Avoid line-by-line SQL paraphrases.
- Testing Tasks:
  - [x] Add application tests for one part, multi-objective parts, multi-part activities, overlapping
    exam objectives, repeated parts, several contributions to one state, and one final row per
    state (`AC-009` through `AC-013`, `AC-021`).
  - [x] Test duplicate GUIDs in one input, successful retry, non-evaluated attempts, and two workers
    claiming the same PartAttempt (`AC-016`, `AC-017`).
  - [x] Test real concurrent updates to one existing state, simultaneous creation of one absent
    state, and concurrent first evidence; assert no lost attempts or double confidence (`AC-020`).
  - [x] Induce failures after a claim and after evidence insertion using a real transaction/database
    failure boundary rather than an in-memory assertion; prove claims, evidence, and final states
    all roll back (`AC-019`).
  - [x] Prove naive and nil batches create no operational rows and config is fetched exactly once
    for each LKT-AOA operation (`AC-022`, `AC-023`, `AC-027`).
  - [x] Capture Repo events for a small bulk case and fail the test if a persistence query appears
    inside the contribution/objective reduction (`AC-013`).
  - Command(s): `mix test test/oli/learning_model/lkt_aoa/application_test.exs test/oli/learning_model/lkt_aoa/concurrency_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - The public operation is atomic, idempotent, concurrency-safe for existing and missing states,
    applies confidence only from returned evidence, fetches one config, and uses a fixed set of bulk
    persistence boundaries documented by accurate source comments.
- Gate:
  - Gate C: Integration/concurrency tests prove `AC-009` through `AC-013`, `AC-016`, `AC-017`,
    `AC-019` through `AC-023`, and `AC-025` through `AC-030`; no partial transaction or lost update
    remains.
- Dependencies:
  - Gates A and B.
- Parallelizable Work:
  - Claim/evidence SQL and state-lock/final-write SQL can be developed separately behind explicit
    internal interfaces, while pure test-data builders proceed in parallel. Transaction assembly
    and concurrency tests must have one owner to preserve statement and lock order.

## Phase 4: Snapshot Worker And Summary/XAPI Integration

- Goal: Insert semantic learning-model application into the established evaluated-attempt workflow
  without changing job arguments, summaries, xAPI statements, or naive behavior.
- Tasks:
  - [x] Add a Summary pipeline overload for a prebuilt `%AttemptGroup{}`/`nil` while retaining the
    existing three-argument API and response shape.
  - [x] Refactor `Oli.Delivery.Snapshots.Worker` to load the Section once, construct AttemptGroup
    once, apply the learning model, then execute existing summary upserts and xAPI emission in that
    order (`FR-007`, `AC-022`, `AC-024`).
  - [x] Preserve empty evaluated-attempt behavior, project/publication determination, bundle IDs,
    Oban queue/max-attempt settings, job arguments, and downstream xAPI payload/category.
  - [x] Propagate LKT errors as Oban-retryable failures; never fall back to naive. Ensure an LKT
    commit followed by summary/xAPI failure retries as an LKT no-op (`FR-005`, `AC-017`, `AC-024`).
  - [x] Audit the existing server/client evaluation, graded-page finalization, auto-submission, and
    manual-grading producers to confirm they still converge on this Worker without producer-specific
    learning-model loops (`AC-024`).
  - [x] Author helpful source comments explaining why LKT runs before summary writes, why the
    AttemptGroup is built once, and how application claims make downstream retry safe. Preserve or
    improve existing comments around empty work and xAPI emission; remove any comment made stale by
    the refactor.
- Testing Tasks:
  - [x] Extend Snapshot Worker tests for `:naive`, `:lkt_aoa`, empty/no-evaluated inputs, one part,
    bulk graded page, multi-objective mapping, and controlled LKT failure (`AC-022`, `AC-023`,
    `AC-024`).
  - [x] Assert current resource/response summaries are still produced for both model versions and
    preserve the existing xAPI construction/emission path.
  - [x] Inject or use an existing downstream summary/xAPI failure path, retry the same job, and
    prove learner state is not applied twice while downstream processing can continue (`AC-017`,
    `AC-024`).
  - [x] Run the focused tests for all known Snapshot producers; use a scenario only if current
    directives can exercise and assert the workflow without DSL changes.
  - Command(s): `mix test test/oli/delivery/snapshots/worker_test.exs test/oli/analytics/summary test/oli/delivery/attempts`, `mix format --check-formatted`
- Definition of Done:
  - Every evaluated-attempt producer retains existing behavior, Sections dispatch from their loaded
    semantic value, LKT runs before summaries, xAPI output is unchanged, and source comments make
    the cross-system retry ordering explicit.
- Gate:
  - Gate D: Snapshot and producer regressions prove `AC-017` and `AC-022` through `AC-024`; naive
    Sections write no LKT rows and an LKT-AOA Section never silently uses naive proficiency.
- Dependencies:
  - Gate C.
- Parallelizable Work:
  - Summary overload tests and producer-path audit can proceed alongside Worker test preparation;
    merge them before changing Worker control flow to avoid duplicate AttemptGroup construction.

## Phase 5: Telemetry, Scale, And Operational Hardening

- Goal: Prove the operational contract under representative cardinality and expose bounded signals
  for latency, errors, retries, and fan-out.
- Tasks:
  - [x] Emit `[:oli, :learning_model, :lkt_aoa, :batch]` start/stop/exception telemetry with native
    duration and aggregate input, claimed, contribution, affected-state, and new-evidence counts
    (`FR-010`, `AC-031`).
  - [x] Restrict custom metadata to model, bounded result, and bounded failure category; exclude
    Section/user/resource IDs, PartAttempt IDs/GUIDs, part IDs, response values/content, scores, SQL
    binds, exception structs, and parameter payloads (`AC-031`).
  - [x] Measure statement-category count for size-one and 500-1000-GUID operations; retain the six
    or fewer LKT statement categories and short-circuit all-duplicate retries after the claim
    (`FR-004`, `AC-013`, `AC-014`, `AC-032`).
  - [x] Capture representative `EXPLAIN` plans for claim and publication/state queries; verify the
    existing attempt-GUID/publication indexes and new composite primary keys are used, with no
    attempt-history scan.
  - [x] Measure transaction/lock duration and memory/CPU growth for large overlapping-objective
    batches; confirm growth is linear and no unbounded task fan-out or query chunking appears.
  - [x] Exercise higher-contention concurrent batches and expected Oban retries; classify deadlock,
    constraint, invalid-input, and publication/parameter failures with bounded atoms.
  - [x] Document AppSignal verification for duration percentiles, failure/retry rates, and aggregate
    fan-out without adding a runtime dashboard or feature flag.
  - [x] Author helpful source comments defining the telemetry event contract/privacy exclusions and
    explaining any array/unnest or `VALUES` SQL chosen to preserve constant round trips. Comments
    must not expose sample learner identifiers or duplicate observability documentation verbatim.
- Testing Tasks:
  - [x] Add telemetry attachment tests for event names, measurements, success/skipped/error outcomes,
    bounded failure categories, and forbidden metadata (`AC-031`).
  - [x] Add a query-count regression that compares one and 500-1000 GUIDs with representative
    multi-objective fan-out and fails on a new per-cardinality statement (`AC-013`, `AC-014`,
    `AC-032`).
  - [x] Add/extend concurrency stress tests for overlapping state/evidence keys and assert exact final
    attempt/evidence counts with no deadlock in repeated runs (`AC-019`, `AC-020`).
  - [x] Record manual query plans, timings, lock observations, and AppSignal/local telemetry evidence
    in the phase execution record.
  - Command(s): `mix test test/oli/learning_model/lkt_aoa/performance_test.exs test/oli/learning_model/lkt_aoa/telemetry_test.exs test/oli/learning_model/lkt_aoa/concurrency_test.exs`, `mix format --check-formatted`
- Definition of Done:
  - Query count is cardinality-independent at the supported batch size, plans use intended indexes,
    concurrency remains exact, telemetry is useful and privacy-bounded, and source comments preserve
    the performance/observability invariants.
- Gate:
  - Gate E: Automated and manual evidence proves `AC-013`, `AC-014`, `AC-019`, `AC-020`, `AC-031`,
    and `AC-032`; no blocking query, lock, memory, telemetry-cardinality, or privacy issue remains.
- Dependencies:
  - Gates C and D.
- Parallelizable Work:
  - Telemetry implementation/tests and performance fixture/query-plan preparation can proceed in
    parallel. Run scale and contention tests only after the transaction statement order is stable.

## Phase 6: Integrated Regression, Review, And Handoff

- Goal: Verify the complete core implementation, reconcile traceability, and hand stable write-side
  interfaces to the usage work item.
- Tasks:
  - [x] Run every targeted suite from prior phases together and resolve cross-boundary failures.
  - [x] Run broader relevant learning-model, delivery attempt, Snapshot, analytics summary,
    publishing resolver, application-startup, router, and admin regressions as risk warrants.
  - [x] Perform clean migration up/down verification and a manual LKT-AOA multi-part graded-page run;
    inspect application claims, evidence, learner state, retry no-op behavior, summary output, xAPI,
    and telemetry.
  - [x] Confirm a trusted `:lkt_aoa` Section exercises only the new model and an ordinary `:naive`
    Section creates no new operational rows; confirm no UI/default/usage-scope change entered this
    work item (`FR-007`, `AC-022`, `AC-023`, `AC-024`).
  - [x] Audit all introduced source comments and module/function docs for accuracy against the final
    code. Add helpful comments for any remaining non-obvious transaction, formula, retry, publication,
    cascade, or privacy invariant; update comments made stale during integration; remove narrative
    or redundant comments.
  - [x] Reconcile `requirements.yml` statuses and concrete code/test/manual proof paths for
    `FR-001` through `FR-010` and `AC-001` through `AC-032`.
  - [x] Run the repository review workflow with required security and performance reviews plus the
    applicable Elixir and requirements reviews; remediate findings and rerun affected tests.
  - [x] Record any real Jira association in the work item/PR without inventing a key.
  - [x] Document the stable usage-layer inputs: state identity/fields, confidence semantics,
    Section dispatch, direct-objective write scope, eventual consistency, and absence of read-oriented
    indexes until measured by `usage`.
- Testing Tasks:
  - [x] Run the integrated focused backend suite with intentional logs captured according to repo
    policy, then run broader regressions proportionate to the final diff.
  - [x] Run formatting and warning-free compilation.
  - [x] Run requirements traceability and Harness work-item validation after proof reconciliation.
  - Command(s): `mix test test/oli/learning_model test/oli/delivery/snapshots/worker_test.exs test/oli/delivery/attempts test/oli/analytics/summary`, `mix format --check-formatted`, `mix compile --warnings-as-errors`, `python3 /Users/darren/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/learning_model_v2/core_impl --action master_validate --stage implementation_complete`, `python3 /Users/darren/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/learning_model_v2/core_impl --check all`
- Definition of Done:
  - All requirements have honest automated or hybrid proof, migrations and representative scale are
    verified, current naive/summary/xAPI behavior is preserved, source comments are accurate and
    useful, all selected review lenses are clean, and the usage work can depend on a stable write
    model without reinterpreting implementation details.
- Gate:
  - Gate F: All automated/manual validation and required reviews pass with no blocking correctness,
    security, performance, migration, compatibility, telemetry, traceability, or documentation
    finding.
- Dependencies:
  - Gates A through E.
- Parallelizable Work:
  - Manual runtime/migration checks, proof-map preparation, source-comment audit, and review setup can
    proceed concurrently after the integrated automated suite passes; remediation and final
    validation remain serialized.

## Parallelization Notes

- Phase 1 schema/test work may overlap migration safety review, but one migration owner must control
  natural keys, foreign keys, and index creation.
- In Phase 2, pure formula/confidence logic is independent from contribution/parameter normalization
  once structs and errors are fixed.
- In Phase 3, set-based claim/evidence persistence and state lock/write persistence may be authored
  independently behind agreed interfaces. Transaction composition, ordering, and concurrency tests
  must remain centralized.
- Phase 4 Summary overload work and producer audit are separable until Worker control flow changes.
- Phase 5 telemetry and scale-fixture work are separable, but final measurements must use the merged,
  stable transaction.
- Do not parallelize competing migrations, alternate formula implementations, or alternate lock
  orders. Do not split one assessment into per-part jobs merely to create parallel work.
- Coordinate shared changes to `AttemptGroup`, Snapshot factories, and learning-model test helpers to
  avoid duplicated builders or divergent objective-mapping semantics.

## Phase Gate Summary

- Gate A: Minimal operational tables, exact keys/fields, constraints, migration safety, direct-delete
  cascade, and complete removal of the obsolete PartAttemptCleaner runtime/admin surface are complete.
- Gate B: Pure typed normalization, coefficient fallback, model transitions, confidence, and
  deterministic within-batch replay are complete.
- Gate C: The public bulk operation is atomic, idempotent, bounded, and concurrency-safe.
- Gate D: Snapshot dispatch and summary/xAPI integration preserve all existing producer behavior and
  retry safely.
- Gate E: Representative scale, query plans, contention, telemetry, AppSignal posture, and privacy
  constraints are verified.
- Gate F: Integrated regressions, migration/runtime checks, comment audit, requirements traceability,
  documentation handoff, and required code reviews are complete.
