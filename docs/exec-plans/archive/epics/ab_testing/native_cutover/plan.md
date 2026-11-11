# Native Cut-Over And UpGrade Removal - Delivery Plan

Scope and reference artifacts:

- PRD: `docs/exec-plans/current/epics/ab_testing/native_cutover/prd.md`
- FDD: `docs/exec-plans/current/epics/ab_testing/native_cutover/fdd.md`

## Scope

Deliver the hard cut-over from UpGrade-backed experiment behavior to native A/B testing for new experiment behavior.

In scope:

- Route new experiment creation to native `Oli.Experiments` definitions only. Covers FR-001 and AC-001.
- Remove or disable UpGrade authoring copy, enablement labels, JSON export/import controls, and obsolete new UpGrade creation paths. Covers FR-004 and AC-004.
- Remove active runtime dependence on UpGrade assignment, mark, and log endpoints for native experiments. Covers FR-002 and AC-002.
- Preserve and surface the non-migration rule for existing UpGrade-backed definitions, learner assignments, and historical analytics. Covers FR-003 and AC-003.
- Remove or make inactive active UpGrade runtime configuration for native behavior. Covers FR-005 and AC-005.
- Add targeted telemetry, security, performance, and issue-tracking proof expected by `harness.yml`.

Out of scope:

- Migrating UpGrade experiment definitions, learner assignments, or analytics.
- Full native lifecycle UX beyond what is needed to prevent new UpGrade-backed behavior.
- Feature-flagged gradual rollout; this work item uses normal deployment sequencing.
- Thompson Sampling behavior beyond preserving native reward/outcome handoff boundaries.

## Clarifications & Default Assumptions

- Default: former JSON export routes return a disabled response for one release rather than generating JSON; implementation can choose 404 or 410 during Phase 1.
- Default: `Oli.Delivery.Experiments` is deleted when all references are gone. If deletion would inflate the PR, leave a fail-closed deprecated module and add telemetry for attempted calls.
- Default: legacy UpGrade-backed alternatives revisions remain historical artifacts and are not migrated, edited as native definitions, or used to seed native assignment.
- Default: `has_experiments` may remain as a coarse provider-neutral gate during this slice, but variable names and user copy must stop treating it as "UpGrade enabled".
- Default: operations secret cleanup is staged after code no longer reads `:upgrade_experiment_provider`, so older deployed releases are not broken by early secret removal.
- Default: Jira tracks this as an MVP dependency-removal work item with explicit non-migration scope.

## Phase 1: Cut-Over Decisions And Baseline Proof

- Goal: Lock the small policy decisions that affect implementation shape and capture a baseline of existing UpGrade references.
- Tasks:
  - [x] Decide whether former JSON export routes should be removed, return 404, or return 410.
  - [x] Decide whether legacy UpGrade experiment pages are hidden or retained with read-only native-only/non-migration messaging.
  - [x] Decide whether `Oli.Delivery.Experiments` is deleted or temporarily converted to a fail-closed deprecated module.
  - [x] Inventory code references to `upgrade_experiment_provider`, `UPGRADE_EXPERIMENT`, `Oli.Delivery.Experiments`, `ExperimentBuilder`, `SegmentBuilder`, `experiment_download`, `segment_download`, `upgrade_decision_point`, and `is_upgrade_enabled`.
  - [x] Identify the targeted ExUnit and LiveView test files that will prove authoring, route, runtime, config, and non-migration behavior.
- Testing Tasks:
  - [x] Run reference searches and save key findings in the implementation notes or PR description.
  - [x] Run existing focused tests around authoring experiments and delivery alternatives to establish baseline failures or coverage gaps.
  - Command(s): `rg -n "upgrade_experiment_provider|UPGRADE_EXPERIMENT|Oli\\.Delivery\\.Experiments|ExperimentBuilder|SegmentBuilder|experiment_download|segment_download|upgrade_decision_point|is_upgrade_enabled" lib config test priv`
  - Command(s): `mix test test/oli/authoring/experiments_test.exs`
- Definition of Done:
  - Route handling, legacy page handling, and module deletion/deprecation choices are explicit.
  - The initial reference inventory is complete.
  - Required target tests and gaps are known before code removal begins.
- Gate:
  - Do not begin code removal until the route and legacy-page decisions are recorded.
- Dependencies:
  - `domain_contract` APIs and persistence are available or stubbed enough for native authoring/runtime calls.
- Parallelizable Work:
  - Jira/operations coordination can run in parallel with code reference inventory.

## Phase 2: Authoring Surface And Export Lockdown

- Goal: Stop all new UpGrade-backed authoring and remove UpGrade export/import affordances.
- Tasks:
  - [x] Update `lib/oli_web/live/experiments/experiments_live.ex` to remove UpGrade copy, login link, enable-UpGrade label, and JSON download buttons.
  - [x] Update `lib/oli_web/live/workspaces/course_author/experiments_live.ex` with the same native-only behavior.
  - [x] Replace new experiment creation through `"upgrade_decision_point"` alternatives revisions with native authoring calls through `Oli.Experiments` where the native authoring API is available.
  - [x] Add native-only/non-migration messaging for visible legacy UpGrade-backed projects if Phase 1 selects a retained historical notice.
  - [x] Remove or disable `lib/oli_web/controllers/experiment_controller.ex` download actions and router routes for `segment.json` and `experiment.json`.
  - [x] Delete or disconnect `Oli.Delivery.Experiments.ExperimentBuilder` and `Oli.Delivery.Experiments.SegmentBuilder` after routes no longer call them.
  - [x] Rename assigns and local variables such as `is_upgrade_enabled` to provider-neutral native terminology where they remain relevant.
- Testing Tasks:
  - [x] Add or update LiveView tests that assert UpGrade copy and JSON controls are absent from both authoring surfaces.
  - [x] Add or update controller/router tests for the selected disabled response or route removal.
  - [x] Add or update tests showing new experiment creation routes to native definitions only.
  - [x] Add or update tests showing legacy UpGrade-backed records are not offered for migration/import/export.
  - Command(s): `mix test test/oli_web/live/experiments`
  - Command(s): `mix test test/oli_web/controllers/experiment_controller_test.exs`
  - Command(s): `mix test test/oli/authoring/experiments_test.exs`
- Definition of Done:
  - Authors cannot create new UpGrade-backed experiments through the covered LiveViews.
  - UpGrade JSON export/import controls are absent or disabled.
  - Former JSON routes cannot generate UpGrade payloads.
  - Non-migration behavior is visible wherever legacy content remains visible.
- Gate:
  - Authoring gate must pass before runtime cut-over is exposed, so new UpGrade-backed behavior cannot be created during runtime replacement.
- Dependencies:
  - Phase 1 route and legacy-page decisions.
  - Native authoring API availability from `Oli.Experiments`.
- Parallelizable Work:
  - LiveView copy/control removal and route/controller lockdown can proceed in parallel after Phase 1 decisions.

## Phase 3: Runtime Path Replacement And Fail-Closed Removal

- Goal: Ensure delivery assignment, exposure marking, and reward/outcome paths no longer call UpGrade endpoints.
- Tasks:
  - [x] Replace `Oli.Resources.Alternatives.DecisionPointStrategy` calls to `Oli.Delivery.Experiments.enroll/3` with `Oli.Experiments.assign_condition/1`.
  - [x] Route exposure recording through `Oli.Experiments.record_exposure/1` after assigned content is applied.
  - [x] Preserve first-option fallback when no active native experiment applies or when a controlled native fallback response is returned.
  - [x] Stop using legacy section extrinsic state as the authoritative sticky assignment source for native experiments.
  - [x] Replace `Oli.Delivery.Experiments.LogWorker.maybe_schedule/3` usage in evaluated attempt flows with native outcome/reward handoff, or remove scheduling until the delivery-runtime handoff lands.
  - [x] Delete `Oli.Delivery.Experiments` or convert it into the Phase 1-selected fail-closed deprecated module.
  - [x] Add bounded telemetry/AppSignal reporting for any deprecated UpGrade runtime call if a fail-closed module remains.
- Testing Tasks:
  - [x] Add or update alternatives strategy tests proving native assignment is used and first-option fallback remains stable.
  - [x] Add or update evaluated attempt lifecycle tests proving UpGrade log jobs are not scheduled.
  - [x] Add or update tests proving no UpGrade `init`, `assign`, `mark`, or `log` HTTP calls are reachable from native paths.
  - [x] Add scenario coverage if the implementation spans authoring, publication, section delivery, enrollment, and learner attempt workflows.
  - Command(s): `mix test test/oli/rendering/alternatives`
  - Command(s): `mix test test/oli/delivery/attempts/activity_lifecycle`
  - Command(s): `mix test test/oli/delivery/experiments`
  - Command(s): targeted scenario test command if scenario coverage is added.
- Definition of Done:
  - Native delivery uses `Oli.Experiments` for assignment and exposure.
  - Evaluated attempts do not enqueue UpGrade logging.
  - Runtime paths cannot perform UpGrade HTTP assignment, mark, or log calls.
  - Learner-facing fallback behavior remains stable.
- Gate:
  - Runtime gate passes only when reference searches and targeted tests show no active UpGrade runtime calls remain.
- Dependencies:
  - Phase 2 prevents new UpGrade-backed authoring.
  - Native delivery API contracts from `Oli.Experiments`.
- Parallelizable Work:
  - Alternatives assignment replacement and evaluated-attempt log removal can proceed in parallel once the native API request shapes are stable.

## Phase 4: Configuration, Operations, And Observability Cleanup

- Goal: Remove active UpGrade runtime configuration requirements and provide operational proof for cut-over.
- Tasks:
  - [x] Remove native runtime decisions based on `:upgrade_experiment_provider`.
  - [x] Remove or make inactive reads of `UPGRADE_EXPERIMENT_PROVIDER_URL`, `UPGRADE_EXPERIMENT_USER_URL`, and `UPGRADE_EXPERIMENT_PROVIDER_API_TOKEN` once no code path needs them.
  - [x] Update deployment or operations notes for secret cleanup order: deploy cut-over code first, remove secrets second.
  - [x] Confirm AppSignal/telemetry covers native assignment, fallback, exposure, reward/outcome errors, and any deprecated UpGrade call attempts.
  - [x] Perform security review for obsolete secret exposure, legacy route leakage, tenant scope preservation, and non-migration of learner data.
  - [x] Perform performance review for native delivery assignment path latency, removal of external HTTP calls, and absence of obsolete credential lookups.
- Testing Tasks:
  - [x] Add or update tests proving native runtime works with UpGrade env vars unset.
  - [x] Run reference searches for remaining active config or env-var reads.
  - [x] Run targeted telemetry/error tests if instrumentation is added. No new telemetry instrumentation was added beyond existing native context events and bounded disabled-export logging.
  - Command(s): `rg -n "upgrade_experiment_provider|UPGRADE_EXPERIMENT_PROVIDER|UPGRADE_EXPERIMENT_USER|UPGRADE_EXPERIMENT" config lib test priv`
  - Command(s): targeted config/telemetry ExUnit tests.
- Definition of Done:
  - Native behavior does not require UpGrade credentials.
  - Operations cleanup order is documented.
  - Security and performance review notes are captured in the PR or execution record.
  - Required telemetry is present or existing native telemetry is verified.
- Gate:
  - Do not request operations secret removal until code no longer reads the obsolete config in native paths.
- Dependencies:
  - Phase 3 runtime replacement.
- Parallelizable Work:
  - Operations notes, security review checklist, and telemetry review can run in parallel with final config removal.

## Phase 5: Final Verification And Release Readiness

- Goal: Prove the cut-over satisfies requirements, accepts the deliberate compatibility break, and is ready for review.
- Tasks:
  - [x] Run final reference searches for all removed UpGrade authoring, route, runtime, and config symbols.
  - [x] Confirm each acceptance criterion AC-001 through AC-005 has direct implementation proof or test proof.
  - [x] Confirm documentation/product behavior states that old UpGrade experiments and learner assignments are not imported.
  - [x] Confirm no feature flag rollout path was introduced for this work item.
  - [x] Update PR description or execution record with key decisions, tests, security/performance review notes, and operations cleanup instruction.
  - [x] Run formatting and targeted test suite.
- Testing Tasks:
  - [x] Run all targeted tests from prior phases.
  - [x] Run `mix format`.
  - [x] Run broader `mix test` if changes touch shared delivery/runtime or if targeted tests expose cross-module risk.
  - [x] Run harness requirements and work-item validation.
  - Command(s): `mix format`
  - Command(s): `mix test <targeted test files from phases 2-4>`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/native_cutover --action verify_plan`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/ab_testing/native_cutover --action master_validate --stage plan_present`
  - Command(s): `python3 /Users/eliknebel/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/ab_testing/native_cutover --check plan`
- Definition of Done:
  - AC-001: New experiment creation uses native definitions only.
  - AC-002: Native assignment, exposure/mark, and reward/log paths do not call UpGrade endpoints.
  - AC-003: Non-migration rule is reflected in behavior and documentation.
  - AC-004: UpGrade JSON export/import controls are absent or disabled.
  - AC-005: Native behavior does not require active UpGrade credentials.
  - Targeted tests, formatting, reference searches, and harness validation pass.
- Gate:
  - Release readiness is blocked until all acceptance criteria have proof and no active UpGrade runtime call references remain.
- Dependencies:
  - Phases 1 through 4 complete.
- Parallelizable Work:
  - Documentation/proof collection can run while final targeted tests execute.

## Parallelization Notes

- Phase 1 decisions are the main sequencing bottleneck. After they are recorded, LiveView cleanup and route/controller lockdown can run concurrently.
- Runtime assignment replacement and evaluated-attempt log removal can be split between engineers if both consume the same `Oli.Experiments` request/response contract.
- Operations cleanup notes and review checklists can start before final config deletion, but secret removal must wait until native paths no longer read UpGrade config.
- Scenario coverage should wait until the authoring and runtime paths are stable enough to avoid churn in workflow setup.

## Phase Gate Summary

- Gate A: Phase 1 decisions recorded for JSON route handling, legacy page handling, and `Oli.Delivery.Experiments` deletion versus fail-closed behavior.
- Gate B: Authoring surfaces cannot create or export UpGrade-backed experiments.
- Gate C: Delivery assignment, exposure, and reward/outcome paths cannot call UpGrade endpoints.
- Gate D: Native behavior does not require UpGrade configuration or credentials, and operations cleanup ordering is documented.
- Gate E: AC-001 through AC-005 have passing test or implementation proof, targeted tests pass, `mix format` passes, and harness plan validation passes.
