# Native Delivery Runtime Replacement - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/ab_testing/delivery_runtime/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/delivery_runtime/fdd.md`
- Requirements: `docs/exec-plans/current/epics/ab_testing/delivery_runtime/requirements.yml`

## Scope
Implement native learner-facing delivery runtime behavior for A/B testing through `Oli.Experiments` APIs. The plan covers native alternatives assignment, sticky assignment reuse, exposure recording, evaluated-attempt outcome/reward handoff, telemetry, performance/security verification, and scenario coverage.

Guardrails:
- Do not reintroduce UpGrade assignment, mark, or log calls.
- Do not query or mutate private experiment schemas from delivery code unless the access is behind an `Oli.Experiments` public API.
- Do not add a feature flag for this slice; the PRD states no feature flags are present.
- Do not build authoring lifecycle UI, analytics dashboards, or Thompson Sampling posterior math beyond the reward handoff contract.
- Preserve first-option fallback for inactive, missing, or non-matching native experiments.

## Clarifications & Default Assumptions
- Default reward rule: an evaluated activity attempt produces reward `1.0` only for full credit and `0.0` otherwise.
- Default reward timing: record reward after the evaluated attempt is persisted. Use synchronous local database calls first; introduce Oban only if implementation proves synchronous handoff is too coupled to evaluation transactions.
- Default reward association: reward assignments whose selected alternative branch contained the evaluated activity resource, using context-owned experiment APIs or read contracts.
- Existing `"upgrade_decision_point"` strategy text remains a transition marker for native runtime dispatch until authoring lifecycle work replaces it.
- Jira issue tracking is expected for execution tracking; link the issue or ticket in implementation PRs when available.

## Phase 1: Runtime Assignment And Exposure Baseline
- Goal: Ensure delivery alternatives selection satisfies FR-001, FR-002, FR-003, FR-005, AC-001, AC-002, AC-003, and AC-005 through native `Oli.Experiments` calls.
- Tasks:
- [x] Review `Oli.Resources.Alternatives.DecisionPointStrategy` against the FDD contract for scope construction, condition-code matching, sticky assignment reuse, exposure idempotency, and first-option fallback.
- [x] Verify AC-001 by ensuring active native experiments receive assignments from `Oli.Experiments`, not UpGrade.
- [x] Verify AC-002 by ensuring repeated visits reuse the same native assignment row.
- [x] Verify AC-003 by ensuring applied decision point content creates or confirms a scoped exposure record.
- [x] Verify AC-005 by ensuring inactive, missing, or non-matching experiments render the first alternatives option.
- [x] Replace any remaining learner-facing UpGrade assignment, mark, or section-extrinsic sticky reads in the alternatives runtime path.
- [x] Resolve section/project/publication identity to stable IDs before native calls where the current slug-based scope leaves gaps.
- [x] Confirm exposure idempotency keys include enough assignment, alternatives resource, revision, and enrollment context to avoid cross-scope collisions.
- [x] Keep assignment and exposure telemetry metadata scoped and non-sensitive.
- Testing Tasks:
- [x] Add or update ExUnit tests for assigned condition rendering, sticky repeat visits, exposure recording, and first-option fallback for no experiment.
- [x] Add tests for condition mismatch and native assignment/exposure errors falling back without learner-facing failure.
- [x] Run existing native runtime domain tests.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs`
  - Command(s): `mix test <targeted alternatives delivery test file>`
- Definition of Done:
  - FR-001, FR-002, FR-003, and FR-005 are covered by targeted tests.
  - No UpGrade runtime assignment or mark call remains in the learner alternatives path.
  - Assignment and exposure failures are observable and preserve fallback behavior.
- Gate:
  - Targeted domain and alternatives tests pass before reward handoff work starts.
- Dependencies:
  - Native `Oli.Experiments` context and `experiment_*` persistence from the domain contract slice.
- Parallelizable Work:
  - Test fixture cleanup and static UpGrade reference searches can run alongside scope hardening.

## Phase 2: Evaluated-Attempt Reward Handoff
- Goal: Satisfy FR-004 by recording native outcome and reward events idempotently after evaluated activity attempts.
- Tasks:
- [x] Add a delivery reward handoff module that accepts an evaluated `ActivityAttempt` or ID and returns `:ok` for non-experiment attempts.
- [x] Add or expose an `Oli.Experiments` context API for finding reward-eligible assignments without leaking private schemas to delivery.
- [x] Build `RecordOutcomeRequest` with assignment ID, activity attempt ID, resource attempt ID, activity resource ID, score, out_of, observed_at, metadata, and deterministic idempotency key.
- [x] Build `RecordRewardRequest` with outcome ID, reward source `"activity_attempt:evaluated"`, binary reward value, metadata, and deterministic idempotency key.
- [x] Hook the handoff into the common evaluated-attempt path after persistence, covering standard evaluation first.
- [x] Add delivery-side reward telemetry for start, stop, skipped, and exception outcomes.
- [x] Ensure reward handoff failures do not roll back already-persisted learner evaluation results.
- Testing Tasks:
- [x] Add ExUnit tests for full-credit reward `1.0`, non-full-credit reward `0.0`, repeated processing idempotency, and non-experiment skip behavior.
- [x] Add tests proving duplicate reward processing does not duplicate `experiment_rewards` or `experiment_policy_updates`.
- [x] Add tests for reward handoff failure handling after evaluated attempt persistence.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs`
  - Command(s): `mix test <targeted reward handoff test file>`
- Definition of Done:
  - FR-004 and AC-004 are covered by targeted tests.
  - Outcome and reward records are idempotent by activity attempt and assignment.
  - Delivery reward telemetry exists and avoids raw learner response data.
- Gate:
  - Reward handoff tests pass and no direct delivery access to private experiment schemas is introduced.
- Dependencies:
  - Phase 1 native assignment/exposure behavior.
  - Existing attempt evaluation persistence and roll-up behavior.
- Parallelizable Work:
  - Reward handoff unit tests can be drafted while the context-owned assignment lookup API is implemented.

## Phase 3: Evaluation Path Coverage And Resilience
- Goal: Extend reward handoff coverage across evaluated-attempt paths and harden failure behavior.
- Tasks:
- [x] Identify all evaluated-attempt paths that can produce final scores: standard server evaluation, client/adaptive evaluation, manual grading, and page finalization.
- [x] Hook the reward handoff at the narrowest common boundary, or add path-specific calls where no common boundary exists.
- [x] Ensure repeated evaluated attempts, reset attempts, and manual grading updates use stable idempotency keys.
- [x] Confirm reward metadata remains minimal and excludes raw responses, LMS identifiers, and learner names.
- [x] Add bounded logging for reward handoff failures with scoped IDs only.
- Testing Tasks:
- [x] Add tests for at least standard auto-graded evaluation and one non-standard evaluated path, or document explicit follow-up coverage if current scenario support cannot express it.
- [x] Add tests for retry/reprocessing after an evaluated attempt already has native outcome/reward records.
- [x] Verify intentional logs are captured with `@tag capture_log: true` or `capture_log(...)`.
  - Command(s): `mix test <targeted activity lifecycle test file>`
  - Command(s): `mix test <targeted manual/client evaluation test file>`
- Definition of Done:
  - Evaluated activity paths either call reward handoff or have documented, ticketed follow-up with product-approved exclusion.
  - Reward failures remain isolated from learner scoring and grade persistence.
  - Security/privacy checks for metadata pass review.
- Gate:
  - Targeted attempt lifecycle tests pass before scenario coverage begins.
- Dependencies:
  - Phase 2 reward handoff module and context APIs.
- Parallelizable Work:
  - Manual grading and client/adaptive path tests can be assigned independently after the reward handoff API stabilizes.

## Phase 4: Scenario Coverage For End-To-End Runtime
- Goal: Add workflow-level proof for FR-001 through FR-005 across authoring, publication, section delivery, enrollment, exposure, and evaluated attempts.
- Tasks:
  - [x] Use the repo-local `build_scenario` skill when authoring scenario files for this phase.
  - [x] Create or update an `Oli.Scenarios` YAML scenario for native experiment assignment through delivery alternatives.
  - [x] Cover repeated learner visits reusing the same assignment.
  - [x] Cover exposure record creation after assigned decision point content is applied.
  - [x] Cover evaluated attempt outcome/reward handoff and idempotent replay.
  - [x] Cover inactive or missing native experiment fallback to the first alternatives option.
  - [x] Add companion ExUnit runner if needed by existing scenario organization.
- Testing Tasks:
  - [x] Validate the scenario file with `Oli.Scenarios.validate_file/1`.
  - [x] Run the targeted scenario ExUnit test or scenario runner.
  - Command(s): `mix test <targeted scenario test file>`
- Definition of Done:
  - At least one scenario covers native assignment, exposure, and reward handoff in a realistic delivery workflow.
  - At least one fallback scenario covers first-option behavior with no active native experiment.
  - Scenario assertions use real application modules and avoid factories/mocks for domain setup.
- Gate:
  - Scenario validation and targeted scenario execution pass.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Scenario authoring can start once Phase 1 behavior is stable, but final reward assertions depend on Phase 2 and Phase 3.

## Phase 5: Operational, Performance, And Cut-Over Verification
- Goal: Prove the native delivery runtime is observable, performant enough for hot paths, and free of active UpGrade runtime dependency.
- Tasks:
  - [x] Search for remaining learner-runtime references to UpGrade assignment, mark, log, `Oli.Delivery.Experiments`, and `upgrade_experiment_provider`.
  - [x] Review assignment query path, sticky reuse path, exposure write path, and reward lookup/write path for indexed access and bounded scans.
  - [x] Verify telemetry events required by the FDD are emitted for assignment, reuse, fallback, exposure, reward, and reward failure/skipped outcomes.
  - [x] Confirm no feature flag was added and no UpGrade credentials are required by native delivery behavior.
  - [x] Prepare PR notes with security review points, performance review points, telemetry events, test evidence, and linked Jira issue.
  - [x] Run formatting.
- Testing Tasks:
  - [x] Run all targeted tests from previous phases.
  - [x] Run formatting for Elixir changes.
  - [x] Run harness validation after implementation docs are updated.
  - Command(s): `mix test test/oli/experiments/runtime_test.exs`
  - Command(s): `mix test <targeted alternatives, reward handoff, activity lifecycle, and scenario test files>`
  - Command(s): `mix format`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/delivery_runtime --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/delivery_runtime --check plan`
- Definition of Done:
  - Native delivery runs without learner-runtime UpGrade assignment, mark, or log calls.
  - Telemetry and bounded logs support AppSignal production investigation.
  - Security and performance review notes are ready for PR review.
  - Required harness validations pass.
- Gate:
  - All targeted tests, `mix format`, static UpGrade reference review, and harness validation pass before the work item is considered implementation-ready.
- Dependencies:
  - Phases 1 through 4.
- Parallelizable Work:
  - Static reference search, PR evidence collection, and telemetry review can run while final scenario issues are fixed.

## Parallelization Notes
- Phase 1 runtime assignment/exposure work and Phase 2 reward handoff design can be explored in parallel, but Phase 2 should not merge until Phase 1 scope and assignment receipt behavior are stable.
- Phase 3 path-specific reward coverage can split by evaluation path after the reward handoff API is fixed.
- Phase 4 scenario files can be drafted early, but final scenario assertions depend on reward handoff behavior from Phases 2 and 3.
- Phase 5 static review and PR evidence collection can run continuously as implementation progresses.

## Phase Gate Summary
- Gate A: Native assignment/exposure tests pass for AC-001, AC-002, AC-003, and AC-005, and learner alternatives path no longer depends on UpGrade assignment or mark behavior.
- Gate B: Evaluated-attempt outcome/reward handoff is idempotent and covered by targeted tests.
- Gate C: Standard and non-standard evaluated-attempt paths are covered or explicitly deferred with approved follow-up.
- Gate D: Scenario coverage validates assignment stickiness, exposure, reward handoff, and first-option fallback.
- Gate E: Formatting, targeted tests, static UpGrade reference review, telemetry review, and harness validation pass.
