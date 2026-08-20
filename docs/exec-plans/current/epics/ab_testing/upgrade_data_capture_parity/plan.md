# UpGrade Data-Capture Parity - Delivery Plan

References:
- PRD: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/upgrade_data_capture_parity/requirements.yml`

## Branch And Dependency Strategy

- Final base/PR target: `hotfix-v0.34.1`.
- Temporary base: [PR #6786](https://github.com/Simon-Initiative/oli-torus/pull/6786), whose current
  unsquashed commits are ancestors of this branch.
- Incorporated prerequisite: [PR #6784](https://github.com/Simon-Initiative/oli-torus/pull/6784),
  whose two current ETL commits are carried on this branch.
- Expected upstream result: both PRs are squash-merged independently into `hotfix-v0.34.1`, so their
  resulting commit IDs will differ from the commits currently present here.

Work may proceed against this temporary baseline. Before opening the final PR, fetch the updated
`hotfix-v0.34.1`, identify the two squash commits by PR, and rebuild/rebase this branch onto that
updated target. Use `git range-diff`, `git cherry`, and file-level diffs to distinguish changes
already supplied upstream from changes unique to MER-5885; do not blindly replay the prerequisite
commits. Retain only MER-5885 documentation and implementation patches, resolve any overlapping ETL
edits against the upstream PR #6784 result, rerun every affected test, and verify that the final PR
diff contains no PR #6784 or PR #6786 patch-equivalent changes.

## Scope

Deliver three independent outcomes:

1. Restore experiment attribution on concrete existing non-`page_viewed` producers.
2. Reconstruct the v0.33.0 UpGrade section-wide evaluated-activity dataset from analytics storage.
3. Emit one initial condition-assignment event that does not depend on later learner evidence.

Do not gate raw activity capture on causal attribution. Do not introduce a universal resolver,
speculative producers, generic interaction roles, broad diagnostics, UI/export work, or unrelated
experiment-runtime changes.

## Phase 1: Freeze The Minimal Contract

- Goal: Establish one small producer and analysis contract before implementation.
- Tasks:
  - [x] Inventory the exact existing attempt and media producers and their current attribution
    behavior.
  - [x] Record the v0.33.0 `LogWorker` input/output semantics and correctness fallback as golden
    expected rows.
  - [x] Define the minimum attribution fields needed by existing roles and the minimum raw activity
    fields needed for compatibility analysis.
  - [x] Confirm how durable assignment/exposure evidence supplies condition for the compatibility
    join without requiring branch attribution.
  - [x] Add focused fixtures for attributed attempt/media events, unattributed outcomes, both
    assignment scopes, Thompson evidence, and historical missing fields.
- Testing:
  - [x] Validate fixtures against the existing xAPI schema and privacy allowlist.
  - [x] Prove the golden compatibility calculation matches v0.33.0 behavior.
- Gate A: The contract contains no speculative producer, role, field, or diagnostic requirement.

## Phase 2: Restore Focused Non-Page Attribution

- Goal: Add correct attribution to existing attempt and media host statements without changing host
  emission or experiment runtime behavior (FR-002, FR-003, FR-005, FR-008).
- Tasks:
  - [x] Extend `Oli.Delivery.Experiments.AttemptAttributions` with one focused selected-branch query
    using persisted `resource_attempts.content` from the experiment-aware delivery path. Treat the
    pruned Alternatives placement only as evidence of the branch received; resolve experiment,
    assignment, condition, and intervention identity from durable scoped records.
  - [x] Fail safe with no attribution for historical or nonstandard attempts where the persisted
    realized-content guarantee cannot be established.
  - [x] Resolve matching assignment, condition, scope, and actual intervention for part outcomes and
    activity/page rollups.
  - [x] Preserve the existing Thompson outcome/reward/policy construction and add weighted-random
    outcomes without creating rewards.
  - [x] Reconcile `MediaAttributions` around one content traversal and one tailored scoped assignment
    query for attempt and deployed-revision paths.
  - [x] Keep the existing attribution roles; do not add generic interaction or navigation/nested
    contracts.
  - [x] Ensure every producer builds and retains its host statement before optional enrichment.
  - [x] Add only focused bounded failure logging/telemetry needed to diagnose enrichment failure.
- Testing:
  - [x] Cover AC-002, AC-003, AC-004, AC-005, AC-008, AC-009, and AC-014.
  - [x] Assert no assignment query for pages without a relevant experiment-controlled placement.
  - Command: `mix test test/oli/delivery/experiments test/oli/analytics/xapi_test.exs`
- Gate B: Existing attempt/media producers are correct, host-safe, scoped, and regression-tested.

## Phase 3: Preserve The Section-Wide Raw Outcome Stream

- Goal: Make every evaluated activity reconstructable independently of causal attribution
  (FR-001, FR-004, FR-006).
- Tasks:
  - [x] Add enrollment identity to the server-built activity-attempt xAPI context without adding
    direct learner identity.
  - [x] Add only the nullable raw-event columns required for enrollment, stable attempt identity,
    evaluation time, score, denominator, and raw-event hash.
  - [x] Update direct upload, Lambda, and replay/backfill mappings from the shared minimal contract.
    Extend the PR #6784 Lambda baseline rather than duplicating its attribution parsing/insertion
    fixes.
  - [x] Keep explicit experiment rewards separate from host attempt scores; project missing
    attribution `reward_value` as null across all three paths.
  - [x] Keep raw host projection independent from attribution validation and insertion.
  - [x] Preserve historical rows with null new columns; do not populate data in the migration.
- Testing:
  - [x] Cover AC-001, AC-006, AC-007, AC-010, AC-011, and AC-014.
  - [x] Compare normalized required fields across all three projection paths.
  - Command: `mix test test/oli/analytics/xapi test/oli/analytics/backfill`
  - Command: `python3 -m pytest cloud/xapi-etl-processor/tests`
- Gate C: Attributed and unattributed evaluated activities produce equivalent complete raw rows.

## Phase 4: Compatibility Proof

- Goal: Prove the two feature goals end to end without expanding scope (FR-007).
- Tasks:
  - [x] Add a parameterized ClickHouse query or deterministic fixture join that reconstructs
    enrollment, condition, evaluation timestamp, and correctness.
  - [x] Apply the documented v0.33.0 zero/invalid-division fallback in the compatibility query, not
    during raw ingestion.
  - [x] Add focused workflow coverage for multiple enrollments, repeated evaluations, multiple
    activities, in/out-of-branch outcomes, both weighted-random scopes, and Thompson Sampling.
  - [x] Verify exact current-deployment publication behavior remains documented as the MER-5889
    limitation rather than changing it here.
  - [x] Run required security, performance, Elixir, and requirements reviews.
  - [x] Run formatting, affected suites, `git diff --check`, requirements traceability, and harness
    validation.
- Testing:
  - [x] Cover AC-012 and AC-013 and rerun all earlier phase gates.
  - Command: `mix format`
  - Command: `git diff --check`
- Gate D: Both the non-page attribution proof and v0.33.0 compatibility dataset pass independently.

## Phase 5: Capture Initial Condition-Assignment Events

- Goal: Capture one ClickHouse condition-assignment event per newly persisted assignment without
  conflating assignment with later exposure or sticky reuse (FR-009).
- Tasks:
  - [x] Emit a dedicated condition-assignment xAPI statement only when assignment persistence
    succeeds with `reused? = false`; do not emit on sticky reuse.
  - [x] Use xAPI verb `http://oli.cmu.edu/extensions/verbs/experiment_condition_assigned` with display value
    `experiment condition assigned`, normalize it as `raw_events.event_type = 'experiment_condition_assigned'`, and link
    its attribution through that statement's `raw_event_hash`, never a triggering page view.
  - [x] Set the statement timestamp and attribution `assigned_at` from the exact persisted
    assignment value.
  - [x] Include experiment, condition, assignment, scope, section, project, enrollment, algorithm,
    and policy-version identity; include `intervention_id` only for intervention scope.
  - [x] Project the assignment statement consistently through direct upload, Lambda, and
    replay/backfill, including a nullable attribution `assigned_at` column.
  - [x] Keep the assignment attribution payload free of direct learner identity, LMS identity, responses,
    realized content, and policy-state blobs.
  - [x] Update researcher documentation and queries to explain the dedicated initial
    condition-assignment event and distinguish it from later exposure and outcome evidence.
  - [ ] After PRs #6784 and #6786 land, reconcile this branch onto updated `hotfix-v0.34.1` using the
    branch strategy above and inspect the complete final-base diff.
- Testing:
  - [x] Cover AC-015 and AC-016 for both assignment scopes and supported policies.
  - [x] Prove sticky reuse emits no additional assignment statement or attribution row.
  - [x] Compare assignment projection across direct upload, Lambda, and replay/backfill.
  - [x] Rerun every earlier phase gate, formatting, `git diff --check`, requirements traceability,
    harness validation, and applicable reviews.
- Gate E: ClickHouse captures the dedicated initial condition-assignment event, earlier parity gates
  remain green, and the reconciled branch contains only MER-5885 work.

## Deferred Follow-Ups

- Navigation or nested-content attribution when a concrete producer and use case exist.
- Generic event-provenance/resolution APIs.
- Broad operational diagnostic SQL and allocation monitoring.
- Exact attempt-time publication provenance (MER-5889).
- User-facing dataset export and statistical analysis.
- Transactional assignment outbox, delivery reconciliation, and historical assignment backfill.

## Decision Log

### 2026-08-20 - Namespace The Condition-Assignment Event
- Change: Renamed the Phase 5 xAPI verb and normalized event type to
  `experiment_condition_assigned`.
- Reason: The name should distinguish native experiment assignment from other possible Torus
  condition-assignment concepts.
- Evidence: Phase 5 producer, schema, projection, and researcher-query boundaries.
- Impact: Phase 5 verification uses the namespaced value consistently; no compatibility path for
  the unreleased name is retained.

### 2026-08-20 - Add A Fifth Phase For Initial Assignment Records
- Change: Added a phase that emits and projects one dedicated `experiment_condition_assigned` xAPI statement
  and linked attribution only for a newly persisted condition assignment.
- Reason: ClickHouse currently observes assignments only through later evidence, while UpGrade
  captured the initial assignment separately.
- Evidence: Historical UpGrade `/api/assign` behavior, current `experiment_assignments.assigned_at`,
  and the `AssignmentDecision.reused?` boundary.
- Impact: Gate E now covers the assignment verb, raw-event type, attribution linkage, AC-015,
  AC-016, and final reruns. Durable delivery and reconciliation remain deferred.

### 2026-08-19 - Replace Seven-Phase Universal Attribution Plan
- Change: Replaced the prior seven-phase plan with four phases centered on concrete producer
  attribution and unconditional raw outcome parity.
- Reason: The earlier plan treated richer causal provenance as a prerequisite for v0.33.0 parity and
  introduced speculative roles, producers, fields, diagnostics, and runtime queries.
- Evidence: Historical `v0.33.0` UpGrade logging behavior and the discarded implementation after
  commit `aab6c72c5f9e459b436917525335327bafcb38ef`.
- Impact: Implementation restarts from the minimal contract; prior phase completion is intentionally
  void and no implementation phase is currently complete.

### 2026-08-19 - Separate Branch Receipt From Assignment Identity
- Change: Clarified that persisted realized attempt content proves only which Alternatives branch
  the learner received.
- Reason: Assignment, condition, experiment, and intervention identity are not established by page
  content and must remain grounded in durable scoped experiment records.
- Evidence: `lib/oli/delivery/experiments/activity_provider.ex`,
  `lib/oli/resources/alternatives.ex`, `lib/oli/delivery/attempts/page_lifecycle/hierarchy.ex`, and
  `test/oli/delivery/attempts/page_lifecycle_test.exs`.
- Impact: Phase 2 retains the focused design while making its evidence boundary and historical
  fallback behavior explicit.

### 2026-08-19 - Define Temporary Stack And Squash Reconciliation
- Change: Recorded PR #6786 as the temporary base, PR #6784 as an incorporated prerequisite, and
  `hotfix-v0.34.1` as the final PR target; added a mandatory post-merge reconciliation gate.
- Reason: Both prerequisite PRs are expected to be squash-merged, invalidating their current commit
  ancestry and making a naïve rebase or replay likely to duplicate upstream work.
- Evidence: GitHub PRs
  [#6786](https://github.com/Simon-Initiative/oli-torus/pull/6786) and
  [#6784](https://github.com/Simon-Initiative/oli-torus/pull/6784), plus current local branch
  ancestry.
- Impact: Development can use the pending prerequisite behavior, but the final PR cannot open until
  the branch is rebuilt/rebased on updated hotfix and its diff contains only MER-5885 work.
