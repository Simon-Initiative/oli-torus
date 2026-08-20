# Native Experiment Glossary

This glossary defines terms used throughout the native experiment documentation. Definitions are
specific to Torus unless noted otherwise.

## A

### Activation

The transition from `draft` to `active`. Activation validates the experiment configuration,
Decision Point, condition mappings, participating-section publications, and algorithm-specific
requirements. Resuming a paused experiment is not activation and does not rerun this validation.

### Algorithm

The assignment policy used to select a condition. Native experiments support
`weighted_random` and `thompson_sampling`.

### Alternatives element

A page element that renders one selected child from an Alternatives Group. Its element ID identifies
the placement within a page and forms part of `intervention_key`.

### Alternatives Group

A versioned Torus content resource containing the options that can be selected at a Decision Point.
For native experiments, the group's strategy is experiment-controlled and its options map to
experiment conditions.

### ASOF join

A time-aware ClickHouse join that matches each row on the left to the most recent eligible row on
the right at or before the left row's timestamp. The compatibility analysis uses this pattern to
associate an evaluated activity with assignment or exposure evidence known at evaluation time.

### Assignment

The persisted selection of one condition for one enrollment under a particular experiment scope.
Assignments are sticky: subsequent delivery normally reuses the existing selection.

### Assignment key

A stable string identifying the logical assignment. Its components depend on assignment scope. See
[Key formats](data-reference.md#key-formats).

### Assignment scope

The boundary at which Torus creates and reuses an assignment:

- `intervention`: one assignment per experiment, intervention, and enrollment;
- `section_enrollment`: one assignment per experiment, section, and enrollment.

Thompson Sampling supports only intervention scope.

### Assignment unit

The entity assigned to a condition. Native experiments currently use the section enrollment.

### Attribution

Bounded experiment evidence attached to an xAPI host statement. Attribution describes the
experiment, condition, assignment, scope, and evidence type without embedding realized content,
raw responses, or full learner identity.

### Attribution hash

An opaque SHA-256 identifier for one attribution attached to one host event. It is derived from the
raw event hash and the attribution key and is used for deduplication and joins.

### Attribution type

The kind of evidence represented by an attribution: `assignment`, `exposure`, `outcome`, `reward`,
or `policy_update`. This differs from the host-specific experiment role.

## B

### Backfill

Replay of historical S3 xAPI JSONL into ClickHouse using the current normalization contract.

### Bundle

One or more xAPI statements grouped for upload. A bundle becomes a JSONL object in S3 when the S3
ingestion mode is used.

### Bundle ID

The identifier included in an S3 JSONL filename to distinguish one uploaded xAPI bundle.

## C

### ClickHouse

The analytical database containing normalized `raw_events` and `experiment_attributions` tables.

### Completion

The lifecycle transition from `active` or `paused` to `completed`. Completion ends assignment
activity, records `ended_at`, freezes the final policy snapshot, and makes structural configuration
and section participation read-only. It does not delete research data.

### Condition

An experimental treatment or comparison group. A condition has a stable code, label, mapped
Alternatives option, availability, position, and allocation weight.

### Condition code

The stable researcher-facing string identifying a condition, such as `control`. It should remain
semantically unchanged throughout the experiment and should not contain learner information.

### Condition ID

The database identifier for a condition. It is suitable for joins within one Torus database;
`condition_code` is generally easier to interpret in research output.

### Correctness

For UpGrade-compatible activity analysis, the derived ratio `score / out_of`, with the documented
zero, missing-value, and invalid-division fallback applied by the analysis query.

## D

### Decision Point

The author-facing name for an experiment-controlled Alternatives Group. It defines the available
options and can be placed on one or more pages.

### Direct ingestion

An xAPI ingestion mode that writes normalized rows directly to ClickHouse instead of relying on the
S3-to-SQS-to-Lambda path. The normalized field contract is intended to match Lambda and backfill.

## E

### Enrollment ID

The pseudonymous participant identifier for one user's enrollment in one section. The same person
in two sections has two enrollment IDs. It is linkable restricted data, not anonymous data.

### Event hash

An opaque SHA-256 identifier derived from the exact persisted xAPI statement bytes. It identifies a
raw host event and joins `raw_events` to `experiment_attributions`.

### Event version

The timestamp used by ClickHouse `ReplacingMergeTree` tables to select a replacement row for the
same primary key.

### Experiment role

How attribution evidence is used on a particular host statement. Direct evidence uses roles such as
`assignment`, `exposure`, `outcome`, `reward`, or `policy_update`; copied evidence can use `rollup`,
and video attribution uses `media_interaction`. The role can differ from `attribution_type`.

### Experiment slug

A short, human-readable label for an experiment. A slug is unique only within its project in a
particular Torus instance. It is not a portable or globally unique experiment identifier. Use the
experiment UUID when correlating exports or data across Torus instances.

### Evidenced assignment

An assignment represented by at least one successfully ingested attribution row in ClickHouse.
This is not necessarily the complete set of assignments persisted in PostgreSQL.

### Exposure

Evidence that a learner was shown the selected experiment content at a particular placement. An
exposure includes the assignment, intervention, content revision, and recorded time.

### Exposure key

The stable idempotency key for an exposure:
`assignment:<assignment_id>:placement:<page_resource_id>:<content_element_id>`.

## F

### `FINAL`

A ClickHouse query modifier that applies row replacement before returning results from a
`ReplacingMergeTree`. It is convenient for correctness but can be expensive on large ranges, so
queries should be tightly scoped and measured.

### Fixed-control allocation

An optional Thompson Sampling guardrail that reserves a target share of assignments for the control
condition.

## G

### Guardrail

A configured constraint or warning around adaptive allocation, such as warm-up assignments,
maximum condition share, fixed-control allocation, or imbalance threshold.

## H

### Host event

The underlying xAPI statement describing course activity, such as a page view, evaluated attempt,
or video interaction. Host events exist independently of optional experiment attribution.

### Host event type

The normalized host category stored on attribution rows, such as `page_viewed`, `activity_attempt`,
`page_attempt`, `part_attempt`, or `video`.

## I

### Idempotency

The property that retrying the same logical assignment, exposure, outcome, or reward does not
create a new logical evidence record. Stable keys and hashes support this behavior.

### Imbalance threshold

A Thompson Sampling guardrail used to warn when an observed condition assignment share differs
from an even allocation by more than the configured amount.

### Intervention

One concrete experiment placement, identified by experiment, page resource, and Alternatives
element ID. An experiment may have several interventions that use the same Decision Point.

### Intervention key

The string `<page_resource_id>:<content_element_id>` identifying an intervention placement. See
[Key formats](data-reference.md#key-formats).

## J

### JSON Lines (JSONL)

A text format containing one complete JSON document per line. Torus stores xAPI bundles in S3 as
`.jsonl` objects.

## L

### Lambda ingestion

The S3-to-SQS-to-AWS-Lambda path that reads xAPI JSONL, normalizes host and attribution rows, and
writes them to ClickHouse.

## M

### Max condition share

A Thompson Sampling guardrail limiting the largest share of assignments that any one condition may
receive.

### Media interaction

The experiment role used when a supported video event is attributed to the selected assignment and
intervention. Its attribution type is `assignment`; it is not an outcome or reward.

## N

### Normalized score

An explicitly calculated score on a common scale, used by assessment reward evidence. It is
distinct from a host event's raw `score` and from the policy's binary `reward_value`.

### Null reward

The absence of explicit reward evidence, represented as `NULL`. It must not be replaced with an
attempt score and is distinct from a real reward value of `0.0`.

## O

### Outcome

Experiment evidence connecting an evaluated attempt to an assignment and selected branch. Outcome
payloads include attempt identity, score, denominator, and observation time.

### Outcome key

The stable identity linking an outcome to a later reward. A common form is
`outcome:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>`.

## P

### Page resource ID

The stable resource identifier for a page, independent of a particular page revision.

### Page revision ID

The identifier for one immutable version of a page resource.

### Participant

For native experiment analysis, one section enrollment identified by `enrollment_id`.

### Participating section

A course section selected to take part in an experiment. Its published content must contain the
experiment's Decision Point before activation.

### Policy state

Transactional runtime state used by an assignment algorithm. Thompson Sampling policy state
contains bounded per-condition posterior counters and parameters. Full mutable policy state is not
embedded in xAPI attribution payloads.

### Policy update

A change to adaptive policy state after reward processing. The current runtime persists the update
and emits bounded operational telemetry; it does not create a dedicated xAPI host statement.

### Policy version

The versioned identifier for assignment behavior, currently `weighted_random:v1` or
`thompson_sampling:v2`.

### PostgreSQL assignment store

The transactional source of truth for complete persisted experiment assignments. Use it for an
authoritative allocation audit; ClickHouse contains only assignments evidenced by ingested events.

### Prior alpha and prior beta

Thompson Sampling beta-distribution parameters representing prior successful and unsuccessful
outcomes before observed rewards are added.

### Publication

An immutable snapshot of authored project content. Publications are made available to course
sections through section publication.

## R

### Raw event

The normalized ClickHouse representation of one xAPI host statement. It is stored in `raw_events`
whether or not experiment attribution exists.

### Realized content

The learner-specific page content after the selected Alternatives branch has been applied. It can
prove which branch was received but does not independently prove experiment, assignment, or
condition identity.

### ReplacingMergeTree

A ClickHouse table engine that can retain multiple physical versions of a logical row and select
the latest version during merges or `FINAL` queries.

### Replay

See [Backfill](#backfill).

### Reward

Explicit evidence supplied to an experiment policy. Thompson Sampling uses binary rewards of `0.0`
or `1.0`. Weighted-random outcomes do not create policy rewards.

### Reward key

The stable identity for a reward. A common form is
`reward:activity_attempt:<activity_attempt_id>:assignment:<assignment_id>`.

### Reward source

A string identifying how a reward was produced, such as `activity_attempt:full_credit` or
`assessment_page:normalized_score`.

### Reward threshold

For a Thompson assessment binding, the normalized-score cutoff from `0` to `1`. A score equal to or
above the threshold produces reward `1.0`; a lower score produces reward `0.0`.

### Role

See [Experiment role](#experiment-role).

### Rollup

The experiment role used when direct part-attempt outcome or reward evidence is copied to its
activity- or page-attempt host. Rollups allow host-level analysis but can duplicate one logical
piece of evidence across several statements.

## S

### S3

Amazon Simple Storage Service. In S3 ingestion mode, it stores source xAPI JSONL objects. These
objects can contain the full xAPI actor and other sensitive learner data.

### Score and out-of

The observed points earned and possible points on an attempt. They are stored on raw events and are
distinct from normalized score and reward value.

### Section

A learner-facing course offering created from published content.

### Section publication

The published course content made available to a learner-facing section. Experiment activation
checks the published Alternatives revision available in each participating section.

### Section-enrollment scope

See [Assignment scope](#assignment-scope).

### Sticky assignment

An assignment that is reused for subsequent eligible delivery rather than recalculated. Changing a
condition's availability does not rewrite existing assignments.

## T

### Thompson Sampling

An adaptive assignment algorithm that samples each condition's beta posterior and updates that
posterior from explicit binary reward evidence. It uses intervention assignment scope.

## U

### UUID

A portable experiment identifier suitable for cross-environment exports. The numeric experiment ID
is the local database identifier. Unlike the experiment slug, the UUID does not depend on the
project or Torus instance for uniqueness.

### UpGrade-compatible analysis

An analysis that reconstructs the historical UpGrade-style tuple of enrollment, assigned
condition, evaluation timestamp, and continuous correctness from Torus analytics data.

## W

### Warm-up assignments

The number of early Thompson Sampling assignments allocated using warm-up weights before adaptive
posterior sampling begins.

### Weighted random

A deterministic fixed-allocation algorithm that selects conditions according to relative weights.
It supports intervention and section-enrollment assignment scopes and does not adapt from rewards.

## X

### xAPI

Experience API, the JSON statement format Torus uses to represent learning events. A statement has
an actor, verb, object, context, optional result, and timestamp.

### xAPI actor

The actor object in a source xAPI statement. S3 can contain the full actor and sensitive account
information. ClickHouse projects only the account identifiers `raw_events.user_id` and
`raw_events.home_page` from it.

### xAPI extension

A URI-keyed field used to add Torus-specific context to an xAPI statement. Experiment evidence is
stored under `http://oli.cmu.edu/extensions/experiment_attributions`.
