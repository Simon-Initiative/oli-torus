# Core LKT-AOA State Application - Product Requirements Document

## 1. Overview

Implement the delivery-side write path that applies evaluated learner responses to the
LKT-AOA proficiency and confidence model. The capability will process either one
evaluated activity part or a bulk graded page/exam, update compact per-learner/per-LO
state without scanning attempt history, and remain atomic and idempotent under Oban
retries and concurrent workers.

This work consumes the completed semantic model-selection, typed Revision-parameter,
publication-pinning, and startup-configuration contracts from
`docs/exec-plans/current/epics/learning_model_v2/data_model/`.

## 2. Background & Problem Statement

Torus currently derives proficiency through the existing naive model. LKT-AOA requires
all opportunities to influence a sequential learner state, while confidence depends on
the breadth of distinct activity parts encountered. Reconstructing those values by
reading a learner's historical attempts would become progressively slower and would make
bulk assessment scoring impractical.

Snapshot processing may receive many evaluated PartAttempt GUIDs, may be retried, and
may overlap with another worker. The implementation therefore needs compact operational
state, exact database-enforced idempotency, deterministic within-batch ordering, and a
small fixed sequence of set-based database operations. Existing xAPI/S3/ClickHouse flows
remain the audit, analytics, training, and reconstruction path rather than the online
calculation source.

## 3. Goals & Non-Goals

### Goals

- Calculate and persist correct LKT-AOA proficiency and confidence transitions for
  evaluated PartAttempts in Sections explicitly pinned to `:lkt_aoa`.
- Support single-part submissions, multi-LO parts, multi-part activities, and bulk graded
  pages/exams through one collection-oriented operation.
- Keep database round trips bounded by operation type rather than attempt, part, or LO
  count, with no historical-attempt scan.
- Make retries and concurrent processing atomic, idempotent, and safe from lost updates
  or double confidence increments.
- Reuse the exact typed parameters, publication-pinned Revisions, semantic model enum,
  and startup-loaded configuration established by the data-model work item.
- Preserve existing summary analytics and xAPI behavior for both learning models.

### Non-Goals

- Reading, aggregating, or displaying proficiency in Metrics, dashboards, page/container
  views, or authoring Insights.
- Changing new-Project defaults to `:lkt_aoa`, exposing a model-selection UI, or migrating
  existing active Sections between models.
- Building parameter training, parameter-upload authoring, learner-state reconstruction,
  or a historical backfill workflow.
- Enforcing chronological replay across separate Oban jobs or introducing per-learner
  queues, watermarks, delay windows, or historical repair scans.
- Replacing xAPI, S3, ClickHouse, summary analytics, or existing naive-model behavior.
- Supporting partial-credit LKT outcomes, shadow models, or simultaneous parameter sets.

## 4. Users & Use Cases

- Students: receive proficiency state updates after evaluated practice and graded work,
  including assessments containing many activity parts.
- Instructors: rely on learner state that is complete and retry-safe after grading and
  manual-grading workflows, without this work adding a new UI.
- Learning engineers and researchers: obtain runtime behavior that matches the documented
  LKT-AOA transition and preserves xAPI/OLAP data for later analysis and training.
- Platform engineers and operators: process normal and bulk Snapshot Worker jobs with
  bounded query shapes, observable latency, and safe retry/concurrency semantics.

## 5. UX / UI Requirements

- No new learner, instructor, authoring, or administrative UI is introduced.
- Proficiency remains eventually consistent with asynchronous Snapshot Worker processing.
- This work must not expose controls for model selection, global coefficients, or trained
  Revision parameters.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Performance: one batch uses a small fixed number of set-based database operations; the
  number of round trips does not grow with the number of PartAttempts, parts, LO mappings,
  or affected learner-state rows. Query shapes must be evaluated with batches of 500–1000
  PartAttempt GUIDs.
- Reliability: idempotency claims, new evidence, and learner-state mutations commit in one
  transaction or all roll back. Concurrent jobs cannot lose attempts or double-apply
  proficiency/confidence.
- Scalability: do not add update churn to the approximately 300 GB `part_attempts` table;
  idempotency is an append-only narrow projection with cascade cleanup.
- Security and privacy: operational rows contain only the minimum learner/resource keys and
  model state required for delivery. Logs and telemetry must not emit learner identifiers,
  response content, parameter payloads, or high-cardinality per-attempt data.
- Determinism: contributions claimed by one batch replay by `date_evaluated` and immutable
  PartAttempt GUID tie-breaker, independent of database/input enumeration order.
- Maintainability: formulas and ordered transitions should be implemented as pure,
  independently tested domain logic, separate from query/transaction orchestration.

## 9. Data, Interfaces & Dependencies

- Depends on `Section.learning_model_version`, using only the semantic values from
  `Oli.LearningModel.ModelVersion.values()` and dispatching from the loaded Section.
- Depends on nullable typed `Revision.learning_model_parameters`. Activity difficulty
  comes from the exact PartAttempt activity Revision; LO difficulty comes from the exact
  Revision pinned by the Section publication.
- Depends on `Oli.LearningModel.Config.fetch!/0`, called once per bulk operation to obtain
  `gamma`, `rho`, `recency_decay`, and `confidence_saturation`.
- Adds one learner-state row per `(section_id, user_id, learning_objective_id)` containing
  attempt count, decayed success/failure state, recency logit, AOA, unique activity-part
  count, and confidence.
- Adds unique prior-part evidence keyed by `(section_id, user_id, activity_id, part_id)`.
- Adds `learning_model_attempt_applications`, keyed by `part_attempt_id`, with exactly the
  three fields `part_attempt_id`, `learning_model_version`, and `applied_at` and cascade
  deletion with its PartAttempt.
- Integrates through `Oli.Delivery.Snapshots.Worker`, whose input is a collection of
  evaluated PartAttempt GUIDs plus the Section slug.
- Uses PostgreSQL for transactional state and database-enforced uniqueness. xAPI/S3 and
  ClickHouse remain downstream analytical/audit systems, not online read dependencies.

## 10. Repository & Platform Considerations

- Place learning-model calculation and persistence orchestration in the relevant backend
  domain context under `lib/oli/`; keep the Snapshot Worker focused on pipeline
  integration.
- Use Ecto/PostgreSQL transactions, constraints, conflict handling, and deterministic lock
  ordering. Do not perform database I/O inside a per-LO `Enum.reduce`.
- Respect Torus publication semantics and resolve learner-visible LO parameters from the
  Section-pinned publication, never authoring HEAD.
- Preserve Oban retry behavior, current summary aggregation, and xAPI
  emission.
- Changes require Elixir, security, performance, and requirements review lenses under the
  repository review policy.
- Jira is the issue-tracking system of record. No issue key was supplied with this work
  item, and analysis must not invent one.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Emit bounded telemetry for LKT-AOA batch duration, input/claimed attempt counts,
  contribution count, affected state count, new evidence count, and success/failure
  outcome without learner or attempt identifiers.
- Use AppSignal and query instrumentation to verify that database round-trip count remains
  constant as batch cardinality increases.
- Success signals are zero double applications under retry tests, zero lost updates under
  concurrency tests, complete transactional rollback on injected failure, and stable query
  counts for representative one-part and 500–1000-part batches.
- Monitor error and retry rates after deployment. Existing Sections remain `:naive` unless
  explicitly provisioned through trusted setup, limiting initial operational exposure.

## 13. Risks & Mitigations

- Multiplicative joins for large batches: use a bounded sequence of simpler set-based,
  index-supported queries and measure query count/shape with representative batches.
- Concurrent updates deadlock or overwrite state: lock affected learner/LO rows in a
  deterministic key order and keep the transaction boundary narrow.
- Oban retries double-apply proficiency: claim immutable PartAttempts through a primary-key
  conflict projection in the same transaction as all state mutations.
- Repeated activity parts inflate confidence: use conflict-tolerant evidence insertion and
  increment confidence only from rows returned as newly inserted.
- Direct PartAttempt deletion leaves orphan claims: use `ON DELETE CASCADE` and add focused
  cascade coverage. The obsolete PartAttemptCleaner/admin surface is removed in Phase 1 rather
  than preserved or replaced.
- Missing or wrong Revision parameters change predictions: consume only typed parameters
  from exact pinned Revisions and apply the explicit `0.0` cold-start rule.
- Activity-part LO mappings change after evidence was recorded: this work assumes stable
  identity/effective mapping within an active Section; a retagging reconciliation policy is
  deferred and such changes must not be treated as automatically repaired.
- Separate jobs execute out of chronological order: accept the rare cross-job order while
  guaranteeing deterministic sequential replay within each transaction.
- Large-table write amplification: never add or update a processed marker on
  `part_attempts`; keep claims in the dedicated narrow table.

## 14. Open Questions & Assumptions

### Open Questions

- No open question blocks product analysis. The FDD must select and document the bounded
  query/locking strategy and indexes after inspecting production query paths and plans.

### Assumptions

- An evaluated outcome is correct only when `score == out_of`; partial credit is incorrect
  for the initial binary model.
- `date_evaluated` is non-null for every eligible contribution. Missing dates invalidate the
  batch and roll back all claims and state changes.
- Ordering is guaranteed only among contributions claimed by the same transaction; the
  first valid job to lock a learner/LO state establishes cross-job application order.
- Activity resource ID plus part ID remains a stable evidence identity and retains its
  effective LO meaning for the life of an active Section.
- A deleted PartAttempt cannot later be resubmitted for processing, making cascade deletion
  of its idempotency claim safe.
- Global configuration changes affect new transitions after restart and do not recompute
  historical state.
- The current Snapshot Worker producer set continues to cover server/client evaluation,
  graded-page finalization, auto-submission, and manual grading.

## 15. QA Plan

- Automated validation:
  - Unit-test first/subsequent transitions, AOA order, recency updates, confidence, binary
    outcomes, typed parameter extraction, and missing-parameter cold starts.
  - Schema/migration-test defaults, numeric constraints, uniqueness, exactly-three-field
    application claims, no implicit ID/timestamps, indexes, and direct-delete cascade cleanup.
  - Integration-test single and bulk submissions, multi-LO parts, overlapping LOs,
    sequential replay, deterministic ties, retries, duplicate GUIDs, injected rollback,
    concurrent workers, and naive-section no-op behavior.
  - Add a query-count regression comparing one-part and representative bulk batches and
    inspect query plans for large GUID collections.
  - Verify Snapshot processing still emits current summaries and xAPI statements.
  - Use `Oli.Scenarios` for the publish-to-delivery-to-attempt workflow if existing
    directives can express the assertions; otherwise add focused domain integration tests
    and document why scenario infrastructure was not expanded.
  - Run targeted ExUnit suites, then broader delivery, attempt, snapshot, and
    analytics regressions; run `mix format` and warning-free compilation.
- Manual validation:
  - Exercise an LKT-AOA Section with a multi-part graded page and inspect claims, evidence,
    learner states, telemetry, and retry behavior.
  - Inspect migrations and representative PostgreSQL query plans for lock duration,
    full-table scans, index use, and bounded round trips at 500–1000 GUIDs.
  - Confirm a naive Section produces no LKT-AOA operational rows and retains current
    proficiency behavior.

## 16. Definition of Done

- [x] PRD sections complete
- [x] requirements.yml captured and valid
- [x] validation passes
