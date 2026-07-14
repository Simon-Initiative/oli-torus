# Runtime Telemetry Reconciliation - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation/requirements.yml`

## Scope
Reconcile native A/B testing runtime telemetry so PostgreSQL remains authoritative only for operational runtime state, xAPI JSONL in S3 becomes durable experiment event history, and ClickHouse becomes the required serving path for dashboards, reports, monitoring queries, and dataset exports.

This plan covers the implementation work needed to classify existing slices 1-5, add experiment xAPI emission contracts, preserve runtime idempotency, quarantine PostgreSQL-backed analytics, and create the required MVP gate for dropping `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` after replacement idempotency and xAPI/ClickHouse evidence are proven.

Guardrails:
- Do not build ClickHouse projections, dashboard UX, or dataset export implementation in this slice; those belong to `experiment_olap_foundation` and `analytics`.
- Do not remove sticky assignment state, experiment definitions, decision points, conditions, lifecycle state, or current adaptive policy state from PostgreSQL.
- Do not let delivery, authoring, analytics, dashboards, or exports query private experiment schemas directly.
- Do not add a feature flag for this work item; rollout is dependency sequencing and review-gate based.
- Do not treat temporary PostgreSQL event-history tables as durable analytics history. They must be removable before MVP completion.

## Clarifications & Default Assumptions
- Default xAPI category is `:experiment` until `experiment_olap_foundation` selects a different projection strategy.
- Default emission timing is after successful `Oli.Experiments` runtime writes, using the existing `Oli.Analytics.XAPI` pipeline rather than direct S3 or ClickHouse network work in delivery transactions.
- Default duplicate behavior is to emit xAPI only for newly created runtime evidence. Reused receipts should not emit duplicate history unless implementation can prove a prior emit was missed and uses the same idempotency key.
- `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` may remain during this slice only as temporary idempotency/runtime scaffolding.
- The final drop migration is expected after `experiment_olap_foundation` proves xAPI/ClickHouse projections and replacement idempotency behavior, and before `analytics` or `manual_qa` can be marked complete.
- Telemetry, security review, performance review, and Jira traceability are explicitly planned because `harness.yml` enables telemetry, code review, performance consideration, and issue tracking.

## Phase 1: Audit And Disposition Baseline
- Goal: Establish the implementation inventory and source-of-truth classification for FR-001, FR-002, FR-006, AC-001, AC-002, and AC-006.
- Tasks:
  - [ ] Review slices 1-5 artifacts: `domain_contract`, `native_cutover`, `delivery_runtime`, `authoring_lifecycle`, and `thompson_sampling`.
  - [ ] Review current `Oli.Experiments` APIs for assignment, exposure, outcome, reward, policy update, and PostgreSQL-backed analytics reads.
  - [ ] Review `priv/repo/migrations/20260625120000_create_experiment_tables.exs` and schemas under `lib/oli/experiments/schemas/`.
  - [ ] Create or update a reconciliation note in this work item that classifies affected code and persistence as keep, modify, remove, or defer.
  - [ ] Classify `experiment_definitions`, `experiment_decision_points`, `experiment_conditions`, `experiment_assignments`, and `experiment_policy_states` as retained operational PostgreSQL state.
  - [ ] Classify `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` as temporary operational scaffolding with a required final removal path.
  - [ ] Identify all callers of `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, `reward_counts/1`, `policy_state_snapshot/1`, and private experiment schemas.
  - [ ] Document the recommended owner slice for the final drop migration and any unresolved removal blockers.
- Testing Tasks:
  - [ ] Add a focused test or scriptable assertion that enumerates unauthorized references to private event-history schemas/tables outside `Oli.Experiments`.
  - [ ] Run an initial reference scan for direct table/schema coupling.
  - Command(s): `rg -n "experiment_exposures|experiment_outcomes|experiment_rewards|experiment_policy_updates|Oli\\.Experiments\\.Schemas\\.(Exposure|Outcome|Reward|PolicyUpdate)|assignment_counts\\(|exposure_counts\\(|reward_counts\\(|experiment_summary\\(" lib test`
- Definition of Done:
  - A reconciliation note records the disposition of prior slice artifacts, current APIs, and affected tables.
  - The required final removal gate for temporary event-history tables is linked to later MVP work.
  - Initial coupling findings are known before code changes begin.
- Gate:
  - Phase 1 is complete only when AC-001, AC-002, and AC-006 have documented evidence and removal blockers are visible.
- Dependencies:
  - Existing slices 1-5 implementation and planning artifacts.
- Parallelizable Work:
  - xAPI event shape drafting in Phase 2 can start while the inventory is underway, but final required fields should wait for the disposition review.

## Phase 2: Experiment XAPI Contract And Builder
- Goal: Define and implement canonical experiment xAPI statement construction for FR-003, FR-005, AC-003, and AC-005.
- Tasks:
  - [ ] Add `Oli.Experiments.Telemetry` or equivalent internal module for experiment event emission.
  - [ ] Add event builder functions for assignment created, assignment reused, exposure recorded, outcome observed, reward recorded, and policy updated.
  - [ ] Use existing xAPI actor, object, verb, context, timestamp, bundle, and JSONL conventions from `Oli.Analytics.XAPI`.
  - [ ] Include required identifiers: experiment ID/UUID, project, section, publication where available, decision point, alternatives resource/revision, condition, assignment key, enrollment or learner reference where allowed, algorithm, policy version, event type, and idempotency key.
  - [ ] Include event-specific references for exposure, outcome, reward, policy update, activity attempt, resource attempt, reward value/source, and compact policy-state hashes.
  - [ ] Keep raw learner responses, learner names, LMS identifiers, full policy state, and full request payloads out of xAPI statements and logs.
  - [ ] Route experiment statements through `Oli.Analytics.XAPI.emit(:experiment, ...)`.
  - [ ] Add telemetry around experiment xAPI emission start, stop, exception, and skipped duplicate decisions.
- Testing Tasks:
  - [ ] Add unit tests for each statement builder shape and required extension field.
  - [ ] Add privacy tests proving experiment statements do not include raw learner responses or learner names.
  - [ ] Add schema validation or schema-extension tests for experiment xAPI statements.
  - Command(s): `mix test test/oli/experiments/telemetry_test.exs`
  - Command(s): `mix test test/oli/analytics/xapi/schema_validator_test.exs`
- Definition of Done:
  - Experiment xAPI statement builders exist and produce deterministic, scoped, privacy-safe statements.
  - Emission telemetry exists and carries non-sensitive metadata.
  - Statement tests cover all MVP event types.
- Gate:
  - Phase 2 is complete only when event builder tests pass and security/privacy review confirms payload minimization.
- Dependencies:
  - Phase 1 field inventory for required identifiers and idempotency keys.
- Parallelizable Work:
  - Static coupling checks from Phase 4 can be drafted in parallel after target forbidden patterns are known.

## Phase 3: Runtime Emission And Idempotency Preservation
- Goal: Wire xAPI emission into `Oli.Experiments` runtime APIs without weakening delivery correctness for FR-003, FR-005, AC-003, and AC-005.
- Tasks:
  - [ ] Emit assignment-created and assignment-reused xAPI after successful `assign_condition/1` decisions.
  - [ ] Emit exposure xAPI only when a new exposure record is created, not when an idempotent receipt is reused.
  - [ ] Emit outcome and reward xAPI only for newly recorded evidence, preserving idempotent receipt reuse.
  - [ ] Emit policy-update xAPI after Thompson Sampling state changes, using compact previous/next state hashes or minimal update metadata.
  - [ ] Ensure xAPI pipeline failure does not roll back assignment, exposure, outcome, reward, or policy-state writes.
  - [ ] Preserve current PostgreSQL idempotency behavior while temporary scaffolding remains.
  - [ ] Add scoped logs for xAPI emit failures without raw learner or response data.
  - [ ] Update or add implementation notes that explain which PostgreSQL event-history rows remain temporary and why.
- Testing Tasks:
  - [ ] Add runtime tests proving first assignment emits xAPI and sticky reuse emits the intended assignment reuse event.
  - [ ] Add tests proving repeated exposure, outcome, and reward idempotency keys do not duplicate PostgreSQL rows or xAPI events.
  - [ ] Add tests proving xAPI emission failures do not roll back runtime writes.
  - [ ] Add tests proving policy-state updates still update current PostgreSQL state for Thompson Sampling.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/telemetry_test.exs`
- Definition of Done:
  - Runtime APIs emit xAPI statements after successful writes and preserve sticky assignment, reward idempotency, and current policy-state behavior.
  - xAPI failure modes are observable but do not break learner-facing delivery.
- Gate:
  - Phase 3 is complete only when AC-005 is proven by runtime tests and no delivery hot path performs direct S3 or ClickHouse work.
- Dependencies:
  - Phase 2 event builders.
- Parallelizable Work:
  - Phase 4 PostgreSQL analytics quarantine can proceed in parallel once runtime API call sites are stable enough to classify allowed operational reads.

## Phase 4: PostgreSQL Analytics Quarantine And Coupling Gates
- Goal: Prevent future product analytics, dashboards, reports, and exports from using PostgreSQL event-history tables for FR-004, FR-007, AC-004, and AC-007.
- Tasks:
  - [ ] Reclassify `Oli.Experiments` PostgreSQL aggregate functions as operational/debug-only or deprecate them for product analytics.
  - [ ] Update module docs or function docs for `experiment_summary/1`, `assignment_counts/1`, `exposure_counts/1`, and `reward_counts/1` to state they are not product analytics APIs.
  - [ ] Adjust existing analytics tests so PostgreSQL aggregate tests are operational-only evidence, not product dashboard/export proof.
  - [ ] Add static or ExUnit-based coupling check for dashboard, dataset, export, report, and analytics code paths.
  - [ ] Forbid direct references to `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates` outside `Oli.Experiments` unless explicitly allowlisted for operational scaffolding.
  - [ ] Forbid private schema aliases `Oli.Experiments.Schemas.Exposure`, `Outcome`, `Reward`, and `PolicyUpdate` outside the owning context and approved tests.
  - [ ] Add PR/review guidance for this slice noting that security and performance review must check analytics source-of-truth boundaries.
- Testing Tasks:
  - [ ] Add coupling-check tests that fail on direct schema/table use in product analytics surfaces.
  - [ ] Run targeted analytics and coupling tests.
  - Command(s): `mix test test/oli/experiments/analytics_test.exs test/oli/experiments/coupling_test.exs`
- Definition of Done:
  - Product analytics cannot accidentally consume temporary PostgreSQL event-history tables without failing a test or review gate.
  - Existing PostgreSQL aggregate functions are clearly marked operational-only or deprecated for product analytics.
- Gate:
  - Phase 4 is complete only when AC-004 and AC-007 are enforced by tests or mandatory review gates.
- Dependencies:
  - Phase 1 caller inventory.
- Parallelizable Work:
  - Documentation updates from Phase 5 can proceed in parallel after coupling rules are finalized.

## Phase 5: Removal Handoff And Downstream Slice Contract
- Goal: Make final table removal executable by downstream MVP slices for FR-006, AC-006, and roadmap consistency.
- Tasks:
  - [ ] Update this work item's reconciliation note with the exact replacement behavior required before dropping each temporary table.
  - [ ] Define the removal readiness checklist for `experiment_exposures`, `experiment_outcomes`, `experiment_rewards`, and `experiment_policy_updates`.
  - [ ] Identify which follow-on slice owns each prerequisite: xAPI statement completeness, ClickHouse projection, direct uploader/backfill support, dataset export support, replacement idempotency, and drop migration.
  - [ ] Record the recommended final gate: after `experiment_olap_foundation` proves xAPI/ClickHouse projections and replacement idempotency, before `analytics` or `manual_qa` can complete.
  - [ ] Add issue-tracking notes for Jira so table removal is not lost as optional cleanup.
  - [ ] Update any affected slice references if they still describe PostgreSQL event-history tables as durable audit or analytics sources.
- Testing Tasks:
  - [ ] Run documentation/reference scans to catch stale durable-PostgreSQL wording in A/B testing planning artifacts.
  - [ ] Run harness validation for this work item after plan/docs updates.
  - Command(s): `rg -n "durable.*PostgreSQL|PostgreSQL.*analytics|experiment_exposures|experiment_outcomes|experiment_rewards|experiment_policy_updates" docs/exec-plans/current/epics/ab_testing`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --check plan`
- Definition of Done:
  - Downstream slices have an explicit, testable contract for replacing temporary event-history tables and dropping them before MVP completion.
  - Jira/review notes identify final table removal as a release gate.
- Gate:
  - Phase 5 is complete only when the removal handoff is explicit enough for `experiment_olap_foundation`, `analytics`, and `manual_qa` to plan against.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Jira/review notes can be drafted while final coupling checks are being implemented.

## Phase 6: Final Verification, Review, And Formatting
- Goal: Prove the reconciliation is complete, tested, observable, and ready for downstream OLAP implementation.
- Tasks:
  - [ ] Run targeted experiment runtime, telemetry, analytics, coupling, and xAPI tests.
  - [ ] Run `mix format`.
  - [ ] Run a focused security review of xAPI payload fields, scope validation, private schema access, and telemetry/log metadata.
  - [ ] Run a focused performance review of delivery emission overhead, PostgreSQL hot-path writes, and removal of dashboard/export aggregate pressure from PostgreSQL.
  - [ ] Prepare PR evidence with changed boundaries, temporary table classifications, xAPI event list, coupling checks, test commands, and unresolved downstream ownership questions.
  - [ ] Link the Jira issue or create implementation tracking notes according to `docs/ISSUE_TRACKING.md`.
  - [ ] Run all required harness validation commands.
- Testing Tasks:
  - [ ] Run all targeted ExUnit tests added or changed by this work.
  - [ ] Run formatting.
  - [ ] Run harness validation.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs test/oli/experiments/telemetry_test.exs test/oli/experiments/analytics_test.exs test/oli/experiments/coupling_test.exs`
  - Command(s): `mix format`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/runtime_telemetry_reconciliation --check plan`
- Definition of Done:
  - Requirements FR-001 through FR-007 and AC-001 through AC-007 have implementation or planning proof.
  - Targeted tests, formatting, security review, performance review, and harness validation pass.
  - Downstream OLAP work can proceed without PostgreSQL event-log analytics assumptions.
- Gate:
  - Phase 6 is complete only when validation passes and PR/review evidence records the temporary-table removal gate.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Security review, performance review, and PR evidence collection can proceed while final test failures are being fixed.

## Parallelization Notes
- Phase 1 audit and Phase 2 xAPI event shape drafting can overlap, but Phase 2 should not finalize required fields until Phase 1 identifies current idempotency and scope fields.
- Phase 3 runtime wiring and Phase 4 coupling checks can proceed in parallel after Phase 2 event builders stabilize.
- Phase 5 downstream removal handoff can start once Phase 1 table classifications are known, but it should be finalized after Phase 4 coupling rules are in place.
- Security and performance review should be distributed across Phases 2 through 6 because this work touches telemetry payloads, delivery runtime overhead, and analytics source-of-truth boundaries.
- No frontend or React work is expected. If implementation discovers a UI-facing monitoring surface, that work should move to `analytics` or a follow-on UI-backed slice.

## Phase Gate Summary
- Gate A: Prior slices, APIs, tables, and callers are classified; final removal blockers are documented.
- Gate B: Experiment xAPI builders produce scoped, privacy-safe, schema-valid statements for all MVP event types.
- Gate C: Runtime APIs emit xAPI after successful writes while preserving sticky assignment, idempotent rewards, and current policy state.
- Gate D: PostgreSQL-backed event-history tables and aggregates are blocked from product dashboards, reports, exports, and large analytics.
- Gate E: Downstream slices have a concrete removal checklist and final table removal is recorded as an MVP release gate.
- Gate F: Targeted tests, `mix format`, security review, performance review, issue-tracking notes, and harness validation pass.
