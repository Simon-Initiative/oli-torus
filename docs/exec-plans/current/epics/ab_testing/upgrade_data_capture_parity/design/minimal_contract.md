# Minimal Producer And Analysis Contract

## Existing Producer Inventory

The supported non-`page_viewed` producer boundary is intentionally limited to:

- evaluated part, activity, and page-attempt statements built by
  `Oli.Analytics.XAPI.StatementFactory`, with optional enrichment owned by
  `Oli.Delivery.Experiments.AttemptAttributions`;
- played, paused, seeked, and completed video statements built through
  `Oli.Analytics.XAPI.construct_bundle/2`, with optional enrichment owned by
  `Oli.Delivery.Experiments.MediaAttributions`.

There is no navigation, nested-content, universal provenance, or generic interaction producer in
this contract. Host statements exist independently of optional attribution.

The assignment runtime also emits one dedicated condition-assignment xAPI statement when a new
sticky assignment is persisted. It uses verb
`http://oli.cmu.edu/extensions/verbs/experiment_condition_assigned`
(`experiment condition assigned`) and is normalized as
`raw_events.event_type = 'experiment_condition_assigned'`. Reusing that assignment is not a new producer
event and emits nothing.

## Attribution Contract

Attempt hosts use the existing `outcome` and `reward` attribution types. Direct part evidence keeps
its native role; activity and page hosts use the existing `rollup` role. Media hosts use the
existing `media_interaction` role with assignment evidence. No new role is required.

The dedicated condition-assignment statement contains one attribution with role `assignment` and
type `assignment`. It carries experiment ID/UUID, condition ID/code, assignment ID/key/scope,
section/project/enrollment, algorithm, policy version, and exact persisted `assigned_at`.
Intervention-scoped assignments also carry `intervention_id`; section-enrollment assignments omit
it. The statement and row are created only for `reused? = false`.

The attribution's `raw_event_hash` links to this dedicated condition-assignment statement. It does
not link to a `page_viewed` statement or another event that happened to trigger assignment
resolution.

The minimum identity fields are experiment, condition, assignment, enrollment, assignment scope,
algorithm, and policy version. Intervention-scoped evidence also carries the actual intervention.
Attempt outcomes carry stable activity/resource-attempt identity, activity resource identity,
score, denominator, and observation time. Thompson reward evidence retains its outcome key, reward
key, source, and explicit value. Attribution projection must leave `reward_value` null when the
payload does not contain a reward; it must not infer reward from the host attempt score. Payloads
must not include user IDs, names, email addresses, LMS identifiers,
raw responses, realized content, or unbounded policy state.

Initial condition-assignment records capture assignment independently of later exposure, outcome,
reward, or media evidence. Existing xAPI delivery behavior is accepted for this scope;
transactional delivery, reconciliation, and historical assignment backfill are deferred.

Persisted realized attempt content or the server-resolved deployed revision proves selected branch
receipt only. Experiment, condition, assignment, enrollment, scope, and actual intervention come
from durable records scoped by project, section, user, and enrollment. A compatibility join obtains
condition from durable assignment/exposure evidence by section, enrollment, and event time; it does
not require causal branch attribution.

## Raw Activity Contract

Every evaluated activity remains a raw host row whether attribution is present or absent. The
minimum analysis fields are section ID, project ID, enrollment ID, activity resource/revision and
attempt identity, page-attempt identity when present, evaluation timestamp, raw score, denominator,
and stable raw-event hash. Historical events may omit the additive fields and must remain valid.

## v0.33.0 Golden Semantics

The historical `Oli.Delivery.Experiments.LogWorker` used the section enrollment ID as participant
identity and calculated continuous correctness as `score / out_of`. It returned `0.0` when score was
positive or negative zero, denominator was positive or negative zero, or division raised
`ArithmeticError`. The executable golden rows also treat a historical missing numeric input as the
same compatibility fallback while preserving the missing raw value for data-quality analysis.

Executable fixtures live in
`test/support/fixtures/upgrade_data_capture_parity_fixtures.ex` and are verified by
`test/oli/analytics/xapi/upgrade_data_capture_parity_contract_test.exs` against the current xAPI
schema and an explicit bounded-field allowlist with a denylist as defense in depth.

## Decision Log

### 2026-08-20 - Namespace The Assignment Statement
- Change: Renamed the statement verb and raw-event type to `experiment_condition_assigned`.
- Reason: The statement represents native experiment allocation specifically.
- Evidence: The Phase 5 producer and normalization contract.
- Impact: The minimal contract does not recognize the unreleased unqualified event name.

### 2026-08-20 - Distinguish Initial Assignment From Evidenced Reuse
- Change: Added a dedicated `experiment_condition_assigned` xAPI statement and linked `assignment/assignment`
  record with persisted `assigned_at` for new assignments only.
- Reason: The first later evidence timestamp cannot represent exact assignment time or learners who
  never produce later evidence.
- Evidence: PostgreSQL `experiment_assignments` and historical UpGrade assignment behavior.
- Impact: The minimal contract now freezes the assignment verb, raw-event type, attribution link,
  and cross-path projection while deferring stronger delivery guarantees.
