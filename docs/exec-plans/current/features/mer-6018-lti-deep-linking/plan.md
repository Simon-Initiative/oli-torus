# MER-6018 LTI Deep Linking - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/prd.md`.
- FDD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/fdd.md`.
- Canonical FR/AC: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/requirements.yml`.
- Intake/manual evidence: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/informal.md`.

## Scope

Productionize the inherited prototype, repair instructor reconfiguration, add missing-only publication application and project → template → section / previous-section inheritance, and supply permanent regression evidence. This plan does not start implementation or mark manual observations as automated proof.

Retain independent section ownership, published-revision isolation, exact tool custom values and existing LTI resource-link identities. Preserve the prototype documents as historical references. Exclude template Deep Linking authoring UI, a reset action, general section-copy controls, creation-wizard redesign and MyProse changes unless scope is explicitly revised.

## Clarifications & Default Assumptions

- Work on `MER-6018-productionize-lti-deep-linking`, based on prototype commit `db1e2b09bc9`, in the separate MER-6018 worktree.
- Integrate the current `master` base before implementation; at intake, fetched `origin/master` was 29 commits ahead of the prototype's base. Decide merge/rebase from the actual divergence and branch publication state, preserving both prototype commits and all uncommitted work.
- The owner manually verified Draft/Review authoring, direct section creation, unpublished isolation and old/new section behavior. Instructor configuration remains unverified due to the empty modal.
- Frame-name collision is a strong code-level hypothesis, not yet an automated reproduced root cause.
- Use targeted tests first, then broaden when shared lifecycle/copy changes or failures justify it. If shared test configuration/support changes, run the full `mix test` suite and verify clean ExUnit progress/summary.
- Run Mix commands with escalated permissions from the worktree. Never reset the development/demo database as part of a test run; verify test environment/database configuration before invoking the repository's `mix test` alias.
- Use installed user-level Harness skills/scripts. Use `build_scenario` and, only if needed, `extend_scenario` when implementing real scenario coverage. Do not use factories/mocks to construct scenario domain state.
- Keep the local MyProse Docker checkout/data separate from Torus CI fixtures. No real Anthropic key is needed for configuration/launch validation.
- Local temporary notes remain ignored and are not a tracked dependency of this contract. The relevant scope/evidence is promoted into the production artifacts.
- Owner decision, 2026-10-13: keep backend signed-response tests, real domain scenarios and frontend state/component tests; defer all tests requiring a running real/test tool. Do not extend LTI Example Tool, prepare a tool service or run cross-service Playwright tests in the current scope. Existing manual observations remain evidence; a new tool walkthrough is deferred. This limits verification, not the feature's production behavior.

## Phase 1: Integrate the base and protect the demonstrated lifecycle

- Requirements: FR-001, FR-004, FR-005, FR-010, FR-011.
- Goal: establish a reproducible baseline on the production branch before extending behavior.
- Tasks:
  - [x] Inspect/integrate current `master` and resolve conflicts in editing, delivery creation, publication update and section copy paths; preserve the prototype behavior.
  - [x] Prepare worktree dependencies/configuration without sharing build outputs or resetting the running demo's database.
  - [x] Audit existing tests and scenario capabilities; turn the successful manual checks into committed domain/scenario regressions.
  - [x] Verify old/new publication capture, copied URL/custom and independent destination ownership; retain the long-field regression.
- Testing Tasks:
  - [x] Add baseline evidence for AC-002, AC-012, AC-013, AC-014, AC-025, AC-026, AC-027 and direct creation in AC-028. AC-026's complete migration/rollback check remains assigned to Phase 6; later authoring/template/application phases complete their respective criteria.
  - [x] Validate and run `test/scenarios/lti_external_tool/deep_linking_test.exs` with its lifecycle/setup/membership scenarios, adding only the minimum missing setup/assertion capabilities.
  - [x] Run the existing LTI API/controller/context targets and affected delivery targets before claiming a green baseline.
  - Commands: `mix test test/oli/lti/platform_external_tools_test.exs test/oli_web/controllers/api/lti_controller_test.exs test/oli_web/controllers/api/lti_controller_integration_test.exs test/oli_web/controllers/lti_controller_test.exs test/oli/delivery_test.exs`; validate/run the newly authored scenario through its ExUnit runner.
- Definition of Done:
  - Current base and prototype are integrated without dropping behavior; permanent tests demonstrate published selection inheritance and draft/section isolation.
- Gate:
  - Targeted baseline tests pass; execution notes record commands, outcomes and any actual environmental blockers. No new workflow implementation begins against an unexplained failing baseline.
- Dependencies:
  - Planning contract present; local note/demo inventory available as supporting evidence only.
- Parallelizable Work:
  - Dependency preparation and test inventory can be independent; Git integration and shared scenario support edits remain sequential. No agent delegation is initiated by this plan alone.

## Phase 2: Fix and test Torus-owned instructor configuration behavior

- Requirements: FR-009, FR-011.
- Goal: correct and cover Torus-owned modal/frame behavior and section-local configuration persistence without requiring a tool service.
- Tasks:
  - [x] Audit the observed empty modal's regular/configuration form targets and return routing; retain frame collision as a hypothesis until actual navigation can be verified.
  - [x] Add failing component regressions for colliding regular/configuration/multiple-activity targets and incorrectly associated messages, then give mounted instances distinct stable frame targets.
  - [x] Recheck section capability/permission enforcement at launch and callback and distinguish cancellation/error from successful selection updates.
  - [x] Use signed test responses and real section data to verify instructor changes and subsequent learner launch parameters without modifying project or sibling selections.
  - [x] Record actual selector navigation/return and a complete instructor walkthrough as deferred verification; do not claim that component evidence reproduces or resolves the runtime symptom.
  - [x] Send standards-compatible custom hints from the current project draft or section selection when reopening Deep Linking, preserving saved data, selector target and signed correlation. The owner approved this generic extension on 2026-10-14; tool-side preselection remains optional.
- Testing Tasks:
  - [x] Cover AC-023, AC-024, the instructor portion of AC-029 and the Torus-owned portion of AC-022; retain AC-022's external-navigation confirmation as pending.
  - [x] Component-test embedded/new-window delivery, multiple instances, modal rendering and message source/association with controlled events and no external service.
  - [x] Run focused frame/delivery Jest tests and section callback/controller tests with signed responses and test keys.
  - Commands: targeted `yarn test` and lint/type checks in `assets/`; targeted `mix test` for affected LTI controller/context tests. No tool-dependent Playwright run is required or authorized by this phase.
- Definition of Done:
  - Torus-owned frame/message regressions pass, and instructor persistence/launch-parameter tests affect only the intended section. Actual tool navigation remains documented as deferred.
- Gate:
  - Focused frontend and backend regressions pass. Proceed with the other phases while retaining the external verification gap; component tests do not establish complete runtime proof for AC-022.
- Dependencies:
  - Phase 1 baseline; no external tool fixture/service is a prerequisite.
- Parallelizable Work:
  - Frontend regression preparation and backend authorization test inventory can be independent. Shared frame code and modal integration must be coordinated.

## Phase 3: Harden authoring using existing editor mechanisms

- Requirements: FR-001, FR-002, FR-003, FR-004.
- Goal: reliable selection persistence, prepared autosaves and standard save feedback with minimal added infrastructure.
- Tasks:
  - [x] Reconcile `design/authoring-save.md` with owner-requested simplification.
  - [x] Capture signed activity state after flushing page/target-activity persistence; preserve role/type and current access/capability checks.
  - [x] Validate/merge the signed result inside existing `ActivityEditor.edit/5`; create a fresh selection revision, preserve ordinary single/bulk selection and ordinary revision policy.
  - [x] Reuse existing `PersistenceStatus` and error banner; remove separate selection-saved confirmation.
  - [x] Prevent overlap in the active editor, discard closed/old modal callbacks and keep unsupported hosts from offering configuration.
  - [x] Remove authoring coordinator, persistent pending/cancel/supersession state, generic-resource changes and separate editor primitives.
- Testing Tasks:
  - [x] Cover AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012 and AC-029 using real scenario/domain/API and frontend tests without an external tool.
  - [x] Verify same-ID draft change refusal, ordinary revision compatibility, signed callback rejection, failed commit rollback/retry and publication isolation.
  - [x] Mount the page editor to verify preparation and `Saving...` → `All changes saved`, with no false saved indication on failure.
  - [x] Complete final format/types/lint, regression and correction-review gates.
- Definition of Done:
  - Verified selection saves preserve unrelated content through existing editing primitives; model/save feedback agree after success and failure.
- Gate:
  - Focused backend/frontend checks and applicable reviews pass. Tool/browser interoperability remains deferred.
- Dependencies:
  - Phases 1–2. Scope change explicitly authorized by the owner; committed Phase 2 section behavior remains unchanged.
- Parallelizable Work:
  - Review lenses only; implementation remains one coordinated change.

## Phase 4: Initialize missing selections during publication application

- Requirements: FR-005, FR-006, FR-011.
- Goal: extend publication application without replacing existing destination configuration.
- Tasks:
  - [x] Refactor publication initialization into a scoped, validated missing-only helper using database conflict-do-nothing semantics.
  - [x] Reuse it in direct creation and invoke it after final destination resource/migration processing inside publication application's existing transaction.
  - [x] Audit worker, major/minor, blueprint-backed and legacy entry points; preserve cache/completion ordering and existing rows even when project selection changes or vanishes.
  - [x] Ensure empty selections and resources excluded from the actual destination are skipped; propagate failures to roll back the full update.
- Testing Tasks:
  - [x] Cover AC-015, AC-016, AC-017, AC-018 and the application portion of AC-028; rerun AC-013/AC-014 direct-creation regressions.
  - [x] Exercise new activities, previously missing selections, absent/null selections, instructor overrides, filtered/retained resources, remixed publications, repeated application, conflicting inserts and failure rollback.
  - [x] Validate/run real publication-application scenarios and focused initialization/update tests; inspect query shape for scoped joins and accidental per-resource lookups.
  - Commands: targeted `mix test` for initialization, delivery/update and new scenario runners; scenario structure validation through `Oli.Scenarios.validate_file/1`.
- Definition of Done:
  - Missing selections are populated from the applied published revisions and existing rows remain unchanged; creation/application cannot succeed partially.
- Gate:
  - Major/minor, idempotency/concurrency, membership and rollback cases pass, with no additional sections created by application.
- Dependencies:
  - Phase 1 coverage and Phase 3 stable activity/publication lifecycle.
- Parallelizable Work:
  - Scenario drafting and query/transaction investigation may proceed independently; helper and update-pipeline writes must share one agreed contract.

## Phase 5: Complete template and previous-section inheritance

- Requirements: FR-007, FR-008, FR-010, FR-011.
- Goal: initialize templates and copy current template or previous-section selections into independent new sections as part of Content / curriculum.
- Tasks:
  - [x] Initialize template-owned records from the exact publication within blueprint creation after resources exist.
  - [x] Add selection copying to mandatory Content / curriculum for both template and previous-section sources in the shared copy transaction, restricted to corresponding destination resources and without a new checkbox.
  - [x] Preserve template-local and instructor changes and missing/cleared selections without project fallback; create independent destination rows and roll back on copy failure.
  - [x] Cover blueprint duplication/project-publication remaps and content-only/all-group section copies. Preserve existing base-project/blueprint provenance, publication pins and later publication-update behavior; do not change other copy groups or general update stages.
- Testing Tasks:
  - [x] Cover AC-019, AC-020, AC-021 and repeat exact-payload/isolation checks from AC-025/AC-028.
  - [x] Run real project → template → section and section → section scenarios with edited/cleared source selections, independent changes, content-only/all-group copying, destination exclusions/remaps and rollback.
  - [x] Run existing blueprint/copy scenarios and inspect that this feature copies no attempts, submissions or grades.
  - Commands: `mix test test/oli/delivery/sections/blueprint_test.exs test/oli/delivery/sections/section_copy_test.exs` plus new scenario runners; validate every new scenario YAML.
- Definition of Done:
  - New sections inherit current template/previous-section selections independently as mandatory content; missing/cleared source choices do not recover project defaults, and no learner data is copied by this feature.
- Gate:
  - Template/previous-section inheritance, rollback, provenance/pins and adjacent copy-policy regressions pass. No template Deep Linking authoring UI, new copy checkbox or general publication optimization is introduced.
- Dependencies:
  - Phase 4's reusable initialization helper and Phase 1's copy baseline inventory.
- Parallelizable Work:
  - Template-init and copy-policy test preparation can be independent; shared copy-engine changes must be coordinated with existing/remapped resources.

## Phase 5a: Inherit selections with remixed content

- Requirements: FR-012; AC-032, AC-033, AC-034; portable payload behavior from FR-010.
- Goal: inherit project/template selections when adding materials to a section or template, as approved by Darren.
- Tasks:
  - [x] Preserve authorized source identity through Add Materials and ephemeral Remix state.
  - [x] Initialize retained remixed activities from exact publications or current template rows, preserving existing destination rows and absent template choices.
  - [x] Participate in the existing remix transaction without changing general rebuild/update/copy behavior; use source-grouped, scoped bulk queries.
- Testing Tasks:
  - [x] Add schema/parser-validated real scenarios and tests for both destinations, exact snapshot/template source, independent metadata, missing/cleared/existing choices, removals, membership, rollback and query count.
  - [x] Run focused remix/LTI and adjacent publication/template/copy regressions, formatting and compilation.
  - [x] Complete security, performance, Elixir and requirements reviews and targeted cleanup.
- Definition of Done / Gate:
  - Scoped tests/reviews and Harness checks pass; no external tool setup or commit without owner approval.
- Dependencies:
  - Phases 4–5. Phase 6 is temporarily stashed and will be reconciled after this extension.

## Phase 6: Complete verification, guidance and review

- Requirements: FR-010, FR-011; final proof for all preceding requirements.
- Goal: produce a reviewable production change with permanent evidence for the active verification scope and an explicit account of deferred tool-dependent checks.
- Tasks:
  - [ ] Finish committed backend/scenario/frontend evidence and map actual proof paths to the supported ACs in `requirements.yml`; retain deferred cross-service criteria as pending.
  - [ ] Document Regular/Deep Link semantics, section-local changes, publication/template inheritance and the Torus-wrapper/tool-UI boundary.
  - [ ] Preserve existing MyProse observations and record the new complete walkthrough as deferred with AC-030. Do not start/configure a tool or add Deep Linking support to the example tool as part of this phase.
  - [ ] Run applicable review through `docs/CODEREVIEW.md`: security/performance always, plus Elixir/UI/TypeScript/requirements for this scope; resolve concrete findings.
  - [ ] Reconcile PRD/FDD/plan with final decisions and validate Harness implementation traceability. Keep excluded product ideas separate.
- Testing Tasks:
  - [ ] Close AC-028, AC-029 and AC-031 with real evidence; report AC-030 and the cross-service portion of AC-022 as deferred, and identify any other runtime evidence still pending.
  - [ ] Run affected backend/scenario/frontend suites and migration/rollback verification without an external tool. Broaden to the full backend suite if shared test support/configuration changed or unresolved regressions justify it.
  - [ ] Verify clean ExUnit output, formatting, compile/type/lint checks appropriate to actual changed files and no temporary demo/credential artifacts in the diff.
  - Commands: appropriate `mix test` targets/full suite when required, `mix format --check-formatted`, `mix compile`, focused frontend gates, `git diff --check`, installed Harness requirements/validation scripts plus nested FR/AC coverage checks.
- Definition of Done:
  - Active automated checks pass, guidance/existing compatibility notes are durable and review findings are resolved. Report remaining tool-dependent evidence explicitly; complete canonical verification remains pending until that evidence exists.
- Gate:
  - Only validated implementation evidence advances AC status to `verified`. Do not mark AC-022/AC-030 fully verified from partial or historical observations. Record the owner's deferral and distinguish completion of the current work from the canonical `implementation_complete` gate, which remains pending while required external evidence is absent.
- Dependencies:
  - All implementation phases; review and final manual checks follow the final code.
- Parallelizable Work:
  - Independent checklist reviews may run concurrently as required by repository review policy. Coordinate fixes and repeat only checks affected by new changes/findings.

## Parallelization Notes

This is a dependency-ordered plan, not authorization to spawn implementation agents. Independent reads/test inventories can be batched. Shared editor/frame, publication-transaction and copy-engine work should have one coordinated owner at a time. Repository-mandated specialist review delegation applies when review is invoked.

## Phase Gate Summary

- Gate 1: integrated base and permanent coverage of the demonstrated published lifecycle.
- Gate 2: Torus-owned modal/frame/message behavior and section-local persistence covered; actual tool navigation explicitly deferred.
- Gate 3: guarded authoring saves and coherent UI states under success, cancellation, failure and concurrent edits.
- Gate 4: exact-publication, missing-only, idempotent and transactional application.
- Gate 5: independent template initialization/inheritance with no project fallback.
- Gate 6: active backend/scenario/frontend proof, guidance, review and reconciled Harness artifacts; deferred tool-dependent verification reported without claiming complete cross-service proof.

## Phase 1 Execution Record

### Scope from plan.md

Protect existing authoring selection persistence, published-snapshot inheritance and independent section launches before modifying feature behavior. The planning contract was committed as `98d255c3e8`, after base merge `971e4c861d`.

### Implementation Blocks

- [x] Add real scenario setup/lifecycle/membership flows under `test/scenarios/lti_external_tool/`.
- [x] Use `Delivery.create_section/1` in feature hooks: the generic `section` directive directly creates resources and bypasses the prototype's initialization step.
- [x] Save through `ActivityEditor` with the containing-page lock; check launch claims via the real API/authorization endpoints and verify Torus's token signature.
- [x] Keep production code, shared scenario infrastructure and external tool services unchanged. Domain setup uses no factories, fixtures or mocks. The signed-response protocol test controls only tool JWKS HTTP retrieval with a public key derived from a test signing key.

### Test Blocks

- [x] Six targeted tests pass: old/new and unpublished publication isolation, section-local overrides, Regular selection/default behavior, signed return/save/publish/learner launch, long metadata, atomic failed creation and resource membership.
- [x] Validate all three YAML scenarios; the runner rejects execution errors and failed verifications.
- [x] Complete the affected existing LTI/delivery/copy regression run: **221 tests, 0 failures**, seed `824833`, including six new tests and the existing scenario registration hook test. ExUnit output contained normal progress/summary; OTP `os_mon` shutdown messages followed the summary.
- [x] Complete formatting, review and final Harness validation.

Commands used the test environment and an explicit local `DATABASE_URL` targeting the exclusive `oli_mer6018_test` database:

```sh
mix test test/scenarios/lti_external_tool/deep_linking_test.exs \
  test/scenarios/lti_external_tool/hooks_test.exs \
  test/oli/lti/platform_external_tools_test.exs \
  test/oli_web/controllers/api/lti_controller_test.exs \
  test/oli_web/controllers/api/lti_controller_integration_test.exs \
  test/oli_web/controllers/lti_controller_test.exs \
  test/oli/delivery_test.exs \
  test/oli/delivery/section_creation_test.exs \
  test/oli/delivery/sections/section_copy_test.exs
mix format --check-formatted test/support/scenarios/lti_external_tool/deep_linking_hooks.ex \
  test/scenarios/lti_external_tool/deep_linking_test.exs
```

All three YAML files passed `Oli.Scenarios.validate_file/1` and `DirectiveParser.load_file!/1`; Harness structure and nested FR/AC traceability checks passed. The development/demo database was not used. The full backend suite was not run: shared test support/configuration and production code were unchanged.

### Work-Item Sync

The concrete runner path replaces the provisional scenario name. Initial setup represents an already stored selection; the separate signed-response test covers callback/result retrieval and the existing editor-save boundary. Proof paths were added for the baseline criteria in `requirements.yml`, without promoting whole-feature AC statuses from partial evidence. These tests do not cover browser autosave orchestration, stale/replayed saves, template inheritance, publication application or complete widening-migration rollback; those remain assigned to later phases.

### Review Loop

Round 1 completed with separate security, performance and Elixir reviewers following `docs/CODEREVIEW.md`: **no findings** and no fixes required. Review was limited to Phase 1's new tests/hooks and execution documentation. Residual verification gaps are listed above; inherited prototype hardening remains future work.

### Done Definition

- [x] Phase tasks complete and baseline test coverage committed.
- [x] Targeted and affected regression tests pass.
- [x] Review findings resolved and validation passes.

## Phase 2 Execution Record

### Scope from plan.md

Fix and cover the Torus-owned instructor modal/frame/message behavior and section-local configuration boundary. Phase 1 baseline coverage was committed as `0be517589c`. No external tool service was started or used by these automated checks.

### Implementation Blocks

- [x] Give every mounted frame a stable unique form target without changing the LTI resource-link identity. Associate responses with the mounted frame, Torus origin and expected request UUID; do not turn errors or close messages into success.
- [x] Add `Oli.Lti.SectionDeepLinkLaunch` to authorize instructor/admin configuration, verify signed account/section/activity/deployment correlation and recheck current permission/capability before persistence. Learners cannot request configuration launch parameters.
- [x] Use the existing nonce store for indexed latest-request state, cancellation and one successful save per request. Serialize these operations with the section row lock and preserve both selection and request on failed writes. No additional migration was introduced.
- [x] Start configuration with a trusted-Origin POST and reject noncanonical resource IDs. Reuse the authorization helper's resolved context when constructing claims.
- [x] Cancel through a signed initiating-account/route-bound POST, including after expiry or permission/capability loss. An already committed selection is reported as completion and reloaded. Older or cancelled requests cannot subsequently save.
- [x] Intercept Bootstrap hiding before dismissal, wait for cancellation acknowledgement, show progress/failure with Close retry and invalidate terminal errors. Keep successful completion separate from cancellation.
- [x] Escape tool return metadata in HTML data attributes; retain actionable validation/save errors, handle missing/malformed content-item claims and accept valid audience arrays without crashing on invalid ones.
- [x] Include current string custom parameters in authoring/section Deep Linking requests. Omit unsupported legacy values only from this optional hint; preserve stored data and all existing Regular behavior.

### Test Blocks

- [x] Add 21 real scenario/controller tests for section configuration, authorization, signed association, callback validity/replay, cancellation/supersession, revoked access/capability, resource aliases, administrator identity and failed-write rollback/retry.
- [x] Add 20 frame/modal component tests for unique/stable targets, embedded/new-window modes, source/origin/request association, separate terminal outcomes, pending preparation, cancellation acknowledgement/failure and the committed-return race.
- [x] Complete the affected backend regression run: **242 tests, 0 failures**, seed `241148`, including Phase 1 coverage and existing LTI/delivery/creation/copy tests. ExUnit output contained normal progress/summary; the existing OTP `os_mon` shutdown messages followed the summary.
- [x] Add three signed-request regressions for the owner-approved current-selection hint extension, bringing the section configuration suite to 24 tests. The same affected backend run passed with **245 tests, 0 failures**, seed `114676`; no new frontend changes required repeating its checks.
- [x] Strengthen the no-project-fallback case after requirements review: remove a section's selection while retaining the configured project and sibling selections, then verify no hint or recreated row. The focused 24-test suite passed again, seed `378488`.
- [x] Complete frontend regression coverage: **28 tests, 0 failures** across the new LTI component suites and existing modal suites. TypeScript, scoped ESLint and Prettier checks passed.
- [x] Complete scoped `mix format --check-formatted`, test-environment `mix compile --warnings-as-errors`, all four scenario schema/parser validations and Harness structure/nested traceability checks.

Backend commands loaded local `oli.env` and overrode only `DATABASE_URL` for test execution/compilation, targeting the exclusive `oli_mer6018_test` database. Tests did not use the development/demo database. Shared backend test support/configuration was unchanged; the full backend suite was not required. The optional shared `Modal.onRequestClose` behavior was checked alongside existing modal regressions.

```sh
mix test test/scenarios/lti_external_tool/deep_linking_test.exs \
  test/scenarios/lti_external_tool/section_configuration_test.exs \
  test/scenarios/lti_external_tool/hooks_test.exs \
  test/oli/lti/platform_external_tools_test.exs \
  test/oli_web/controllers/api/lti_controller_test.exs \
  test/oli_web/controllers/api/lti_controller_integration_test.exs \
  test/oli_web/controllers/lti_controller_test.exs \
  test/oli/delivery_test.exs \
  test/oli/delivery/section_creation_test.exs \
  test/oli/delivery/sections/section_copy_test.exs
```

In `assets/`, run the LTI component and modal Jest suites with `--runInBand --coverage=false`, `tsc --noEmit --skipLibCheck`, and file-scoped ESLint/Prettier. Local verification used the repository's Node 24 runtime directly to avoid the installed Yarn wrapper selecting another Node version.

### Work-Item Sync

FDD interfaces and transaction rules now describe the implemented POST launch/cancel and indexed pending-state contract. Added proof paths for AC-022, AC-023, AC-024 and the instructor portion of AC-029; whole-feature statuses remain at `verified_plan`. Component evidence confirms the frame collision and message regressions but does not establish that they caused or fixed the observed empty MyProse modal. Actual selector navigation/return, Bootstrap event wiring/focus behavior and the complete compatibility walkthrough remain deferred with the cross-service portion of AC-022 and AC-030. Authoring orchestration remains Phase 3; template behavior remains Phase 5.

On 2026-10-14 the owner manually confirmed that MyProse's selector renders inside the instructor modal, changed the selection and verified persistence after refresh, the next learner launch using the new configuration and cancellation retaining the saved selection. The practice-page launch uses the current section configuration without requiring Reset Answers. This supports the main instructor flow in AC-022–AC-024; browser keyboard/focus behavior, multiple-instance navigation and the complete AC-030 compatibility walkthrough remain pending. The owner also approved offering current custom parameters to compatible tools; AC-001 and AC-023 now capture this contract and link the signed-request tests. Existing non-string legacy values remain untouched in storage and Regular launches, and are excluded only from this standards-compatible optional hint.

### Review Loop

Separate security, performance, Elixir, UI and TypeScript reviews followed `docs/CODEREVIEW.md`. Findings were resolved with server cancellation/supersession, controlled Bootstrap dismissal, terminal-error invalidation, safe expired/revoked cancellation, trusted-Origin POST initiation, canonical resource identities, missing-claim validation, reuse of resolved authorization context and indexed pending-state queries. Final re-reviews reported **no remaining findings**. Section-lock contention was not benchmarked; external browser/tool behavior remains unverified.

The current-selection hint extension received separate security, performance, Elixir and requirements reviews. A requirements coverage gap was resolved with the configured-project/missing-section regression above; final reviews reported no remaining findings. Formatting, warnings-as-errors compilation and Harness structure/nested traceability passed. The owner requested the name `SectionDeepLinkLaunch`; all code/test/document references were updated and the affected 69-test run passed, seed `674844`. The owner explicitly approved committing Phase 2 after these reviews and manual checks. Later implementation commits require a new explicit approval.

### Done Definition

- [x] Phase tasks complete; the owner verified the main instructor flow with MyProse. Remaining browser/compatibility checks are explicitly deferred.
- [x] Targeted and affected regression tests and relevant format/compile/type/lint checks pass.
- [x] Review findings resolved and work-item evidence reconciled.

## Decision Log

### 2026-10-14 - Extend configuration requests with current selection hints
- Change: Add the optional standard custom claim using string parameters from the current project draft or section/activity selection. Preserve empty strings and serialized JSON verbatim; omit non-string legacy values without modifying persisted data.
- Reason: The owner requested Torus support for any compatible selector after confirming the instructor modal renders MyProse. The current MyProse selector does not initialize itself from those parameters.
- Evidence: `test/scenarios/lti_external_tool/section_configuration_test.exs` covers section overrides, project-draft isolation, both authoring roles, missing selections, standards-compatible values and unchanged selector targets/storage.
- Impact: Three additional backend regressions, no schema/frontend/tool changes, and no committed implementation until the owner's explicit approval. Actual tool UI preselection is not guaranteed.

### 2026-10-14 - Complete section request cancellation and supersession
- Change: Make configuration start a trusted-Origin POST, keep one indexed pending request per section/activity and acknowledge signed cancellation before modal dismissal. Safely cancel after expiry/revocation and reload a return that committed first.
- Reason: Review exposed late writes after close/newer configuration, premature Bootstrap dismissal, terminal-error retry mismatch, permanent cancellation refusal, CSRF risk, identifier aliases and an unindexed delete.
- Evidence: `lib/oli/lti/section_deep_link_launch.ex`, `test/scenarios/lti_external_tool/section_configuration_test.exs`, `assets/test/components/lti/external_tool_configuration_test.tsx`.
- Impact: Phase 2 gate is satisfied for active automated scope with no new migration. External navigation/compatibility remains deferred; Phase 3 authoring hardening is next.

### 2026-10-13 - Phase 2 instructor return authorization
- Change: Implement the FDD's section correlation/current-permission boundary and one successful save per request, alongside unique mounted frames and distinct modal outcomes.
- Reason: Failing component and backend tests demonstrated target collision, false success and insufficient configuration authorization; no external tool was run.
- Evidence: `assets/test/components/lti/`, `test/scenarios/lti_external_tool/section_configuration.scenario.yaml`, `test/scenarios/lti_external_tool/section_configuration_test.exs`.
- Impact: Complete scoped frontend/backend verification before closing Phase 2. Preserve the explicit external-navigation deferral and existing resource-link identity; use the existing nonce table without a migration.

### 2026-10-13 - Defer tests requiring a running external tool
- Change: Remove tool setup/extension and tool-dependent browser runs from the active phases; keep ExUnit, real domain scenarios and frontend state/component checks.
- Reason: The owner explicitly requested retaining the other proposed tests while postponing tool-dependent automation because LTI Example Tool lacks Deep Linking support.
- Evidence: `assets/automation/tests/torus/lti_external_tool/lti-external-tool.spec.ts` currently covers Regular; `test/scenarios/lti_external_tool/hooks.ex` disables Deep Linking. Signed-response backend coverage exists in `test/oli_web/controllers/lti_controller_test.exs`.
- Impact: Phases 2, 3 and 6 progress without an external service. AC-029 uses frontend coverage without one; AC-022 external navigation and AC-030's full compatibility walkthrough remain pending. Product implementation scope and the other test layers are retained.

### 2026-10-13 - Use the public section-creation boundary in baseline scenarios
- Change: Add feature-local scenario hooks for explicit publication selection and `Delivery.create_section/1`; keep execution evidence in this plan.
- Reason: The generic section directive bypasses the prototype initialization being protected; hooks exercise the wizard's public command without changing shared infrastructure.
- Evidence: `lib/oli/scenarios/directives/section_handler.ex`, `lib/oli/delivery.ex`, and `test/support/scenarios/lti_external_tool/deep_linking_hooks.ex`.
- Impact: Phase 1 adds permanent coverage without a running tool or production-code changes. Broader behavior hardening and migration rollback remain in their planned phases.


### 2026-10-15 - Extend Phase 5 to previous-section copying
- Change: Include current source Deep Links in mandatory Content / curriculum for both template and previous-section copies, with independent destination rows and no new checkbox.
- Reason: Explicit owner approval before Phase 5 implementation.
- Evidence: FR-008 and AC-020/AC-021 in `requirements.yml`; shared copy policy in `lib/oli/delivery/sections/copy_options.ex`.
- Impact: Extend Phase 5 implementation/tests to section → section, preserving existing provenance, publication pins, other groups and learner-data boundaries. Phase 4 was committed with owner approval as `2231ccf50e`; this does not authorize a Phase 5 commit.

## Phase 3 Execution Record

### Scope from plan.md

Productionize authoring through existing editor mechanisms. The owner rejected the initial overcomplicated approach and requested reusing the page's save indicator. Phase 2 is committed as `f8f4bd8b35`; the owner approved Phase 3 and its cleanup, committed as `3bc97a98be` on 2026-10-15.

### Implementation Blocks

- [x] Remove the separate LTI coordinator, authoring nonce generations/cancel endpoint, generic-resource edit changes and new ordinary revision policy.
- [x] Reuse existing deferred persistence to flush page and target activity; fix its in-flight/queued barrier and failure propagation rather than tracking a second set of save promises.
- [x] Keep signed author/tool correlation and current permission/capability/lock checks. Compare captured revision plus deterministic server state so in-place ordinary edits are detected.
- [x] Add a sole signed-result update to `ActivityEditor.edit/5`, deriving the selection-only merge under its existing transaction/lock and cloning only for the selection save. Ordinary single/bulk edits retain current selection and normal revision policy.
- [x] Reuse existing `PersistenceStatus` and error banner, synchronize the authoritative activity model, and remove `Selection saved`. Close is local; callback itself never writes. An uncertain network result requests reload.
- [x] Retain role/type choices, supported-host gating, portable metadata fallback, active-frame message filtering and trigger focus return.

### Test Blocks

- [x] Initial reduced editor/LTI/API run passed **166 tests, 0 failures**, including the real signed callback rejection workflow. A final compatibility rerun follows the small ordinary API cleanup.
- [x] Five focused frontend suites passed **35 tests, 0 failures**: mounted page editor, deferred persistence, authoring configuration and existing frame/section modal suites.
- [x] Final backend/API/editor run passed **167 tests, 0 failures**, seed `730519`. Broader affected frontend checks passed **216 tests across 30 suites**, including the five 35-test feature suites. TypeScript, ESLint/Prettier, scoped Mix formatting, compilation with warnings as errors and Harness structure/design/nested traceability checks passed.

### Work-Item Sync

PRD, FDD, design and requirements now describe the smaller authoring contract and standard feedback. AC-007 is scoped to the active editor; no persisted cross-tab newest-request-wins or acknowledged server cancellation policy is claimed for authoring. Whole-feature statuses remain `verified_plan`; external/browser proof remains deferred. Phase 4 publication application and Phase 5 inheritance remain untouched.

### Review Loop

- [x] Separate security/performance/Elixir/UI/TypeScript/requirements reviews completed. Fixed the lock-to-containing-page association and linked the mounted save-status test to AC-005. No remaining code findings; correction reviews did not restore removed infrastructure.

### Done Definition

- [x] Authoring behavior implemented through existing mechanisms.
- [x] Final verification and correction reviews pass.
- [x] No Phase 3 commit without separate owner approval.

### 2026-10-15 Cleanup

- Run `change-cleanup` in owner-selected `self-driving` mode against `origin/master`, focused on outstanding Phase 3 changes. Trace new tests to Jest/ExUnit discovery, scenario assets/hooks to their executing tests and the design to the active plan; no orphaned added files were found in this slice.
- Remove the unused prototype result-retrieval endpoint, controller action, domain wrapper and frontend helper. The existing UI submits the signed token directly to the guarded save endpoint; update protocol tests and design/FDD to match that active flow.
- Return only consumed model/title/objectives/tags fields, derive preparation feedback from existing state, rename the page handler to reflect all three events and document meaningful Elixir public input/output contracts. Keep existing persistence/authorization behavior and the reduced scope.
- Keep shared scenario hooks in `test/support/scenarios/lti_external_tool/`, compiled by Mix without `Code.require_file`. The full suite run after that move completed with 9,644 tests and three failures outside Deep Linking: filesystem traversal timeout in preview-seed checks, connection failures in getting-started simulation and a payment billing-descriptor expectation. Its isolated 47-test Deep Linking run passed.
- The cleanup regression run exposed a branch-local timestamp-sensitive assertion: an upsert can return a constructed `inserted_at` while PostgreSQL preserves the original value on conflict. Reload the two persisted baselines before asserting the complete row remains unchanged; production code is unaffected.
- Final cleanup verification passed: **167 backend tests**, seed `601812`, with clean ExUnit progress/summary; **216 frontend tests across 30 suites**; TypeScript, scoped ESLint/Prettier/Mix formatting, warnings-as-errors compilation and Harness structure/design/traceability. Separate security, performance, Elixir, TypeScript, UI and requirements reviews reported no remaining findings. Corrected a misplaced return-value doc line during the review loop. Browser/tool interoperability remains deferred and all Phase 3 changes remain uncommitted.


The simplified authoring scope preserves signed validation and meaningful stale-state detection, while removing the independent coordinator, persistent authoring request/cancel/supersession state, generic-resource edits and forced fresh ordinary revisions. Successful ExUnit output contained only progress/summary after its normal pre-test seed output; OTP shutdown messages follow the summary. No new external-tool/browser automation or migration was introduced. The owner's Phase 3 commit approval does not authorize commits for later phases.

## Phase 4 Execution Record

### Scope from plan.md

Initialize missing selections from the explicitly applied publication after final destination processing, retaining all existing section choices. Reuse direct-creation initialization; cover current worker and legacy major/minor application routes without introducing a migration or a tool service.

### Implementation Blocks

- [x] Exclude existing section/resource rows before validating candidates; validate portable selections and batch conflict-do-nothing inserts through the existing database utility.
- [x] Initialize after migration/post-processing inside the current update transaction; add the same transaction-bound behavior to both legacy update branches. Completion is emitted only on success.
- [x] Route unchanged publication diffs through the existing minor-update pipeline so repeated application can initialize missing selections while retaining normal resource processing, migration and post-processing.
- [x] Complete focused and affected backend tests, documentation and final verification checks.

### Test Blocks

- [x] Add schema/parser-validated scenario setup and a major-update workflow using real directives/domain APIs, with no factory, fixture, mock or external service for domain setup.
- [x] Complete 13 exact snapshot, overrides, missing/cleared, conflict-at-insert, destination membership, worker, blueprint-backed/remixed and major/minor rollback/retry checks. The conflict case uses an actual database trigger to insert a winning row after discovery; it deterministically exercises conflict handling without parallel-session stress testing.
- [x] Run affected delivery/LTI regressions: **270 tests, 0 failures**, seed `358347`. This includes the new runner, all LTI scenarios, existing platform context, delivery/creation, old/new major/minor, blueprint and section-copy suites. Successful ExUnit output contains only normal progress/summary after setup; the existing OTP shutdown messages follow the summary.
- [x] Scoped `mix format --check-formatted`, test-environment `mix compile --warnings-as-errors`, `git diff --check` and Harness structure/design/requirements traceability passed. No shared test support or frontend code changed in this phase, so the prior full-suite and frontend results remain recorded without redundant reruns.

### Work-Item Sync

Phase 3 is committed with explicit owner approval. Phase 4 was committed with owner approval as `2231ccf50e`; template/previous-section creation/copy policy remains Phase 5. Whole-feature requirements retain `verified_plan` pending final verification and deferred external evidence.

### Review Loop

- [x] Initial security, performance, Elixir and requirements reviews completed. The owner requested a stricter SQL audit and cleanup; the correction pass and its evidence are recorded below. External-tool/browser checks and parallel-session stress remain deferred.

### Done Definition

- [x] Phase tasks and tests complete.
- [x] Verification, reviews and documentation validation pass.
- [x] No Phase 4 commit without separate owner approval.


### Phase 4 Cleanup and SQL Audit (2026-10-15)

- Continue `change-cleanup` in the owner-selected `self-driving` mode against `origin/master`, focused on outstanding Phase 4 changes. The new ExUnit runner is automatically discovered, executes both new YAML files through `Oli.Scenarios.execute_file/2`, and reaches existing hooks from compiled test support. No added slice files are orphaned.
- Keep SQL optimizations confined to Deep Linking initialization: filter absent and JSON-null selections in SQL, use a correlated `NOT EXISTS` for existing choices, and reuse the parameter-bounded bulk insert utility. Retain the uniqueness constraint and conflict-do-nothing behavior, with no new index or migration.
- Move the shared portable-selection validator into the existing deep-link schema, keeping the authoring delegate. This removes a dependency cycle without changing validation behavior. Correct new specs that referenced a nonexistent `Section.t()`.
- Add initializer query-count/returned-row assertions. Test repeated application and unchanged-publication updates through the normal pipeline, preserving selection values and destination membership. These tests use real domain setup and writes, without fixtures or mocks.
- SQL diagnostics use only the isolated test database and rolled-back scenario setup. In a 2,003-activity diagnostic (501 configured choices), filtering reduced transferred rows from 1,502 to zero when all choices existed and from 2,003 to 501 when missing. Initialization uses one discovery query plus parameter-bounded inserts, with no per-activity queries and no insert for an empty result. Comparing equivalent queries on the same fixture, `NOT EXISTS` produced a Hash Anti Join and reduced shared buffer hits from 15,257 to 482 (4.604 ms to 3.298 ms). These are local diagnostic measurements, not production latency guarantees.
- An intermediate cleanup introduced a shortcut around normal publication processing. The owner rejected that broader optimization: remove it, its special concurrency handling and its test. Restore the original Project lookup and publication-read placement. Keep unchanged diffs in the existing minor pipeline; do not optimize general updates without separate approval. Earlier 36/50-to-6/7 statement comparisons applied only to intermediate implementations and do not describe the retained flow.
- The owner manually confirmed that applying a publication retained the original section choice and initialized the newly added tool from that publication. Phase 5 remains separate; no Phase 4 commit is authorized by this review request.
- After scope reduction, the focused runner passed **18 tests, 0 failures**, seed `108480`; the expanded regression passed **321 tests, 0 failures**, seed `748235`. It covers LTI scenarios/context, direct creation, current/legacy major/minor updates, blueprints, section copy and LTI callback controller suites. ExUnit output is clean apart from normal progress and summary; existing setup/shutdown output stays outside it.
- Security, performance, Elixir and requirements correction reviews report no remaining findings for the reduced scope. Scoped formatting, test-environment warnings-as-errors compilation, `git diff --check` and Harness structure/design/nested traceability passed. Requirements stay `verified_plan`; real-tool automation, parallel-session stress and production latency guarantees remain outside the completed evidence. Phase 4 remains uncommitted.


## Phase 5 Execution Record

### Scope from plan.md

Initialize templates from exact published selections and copy current source-owned selections into independently owned destination records for both templates and previous sections. Deep Links belong to mandatory Content / curriculum. Preserve the existing copy/update pipeline and introduce no new copy checkbox or migration.

### Implementation Blocks

- [x] Initialize template selections inside blueprint creation.
- [x] Copy current source selections inside the existing shared copy transaction, restricted to destination resources.
- [x] Document mandatory content semantics and preserve existing processing/provenance/pins.

### Test Blocks

- [x] Add real scenario coverage for template and previous-section inheritance, missing/cleared values, isolation, remaps and rollback.
- [x] Validate YAML and run focused/affected regressions with clean ExUnit output.
- [x] Run format, compilation and Harness verification.

### Work-Item Sync

- [x] Update PRD, FDD, plan and AC-020/AC-021 with the approved previous-section scope.
- [x] Link actual implementation proof without promoting deferred external-tool evidence.

### Review Loop

- [x] Run security, performance, Elixir and requirements review after verification.

### Done Definition

- [x] Phase tasks, tests, reviews and validation pass.
- [x] No Phase 5 commit without separate owner approval.


### Verification and Review Evidence

- Phase 4 was committed with explicit owner approval as `2231ccf50e`. Phase 5 documents were extended and validated before coding. Phase 5 remains uncommitted.
- `test/scenarios/lti_external_tool/inheritance_setup.scenario.yaml` passes schema/parser validation and is reached by the automatically discovered `inheritance_test.exs` runner. Setup uses `Oli.Scenarios.execute_file/2` and real domain APIs, with no fixtures, factories, mocks or external tool process; no shared test-support/configuration changes were made.
- The focused runner passed **13 tests, 0 failures**, seed `239506`. It verifies published template capture versus draft edits, current template/instructor overrides, long URL/title/text and nested custom metadata, content-only/all-group copies, independent edits and subsequent publication application, missing/cleared choices without fallback, source/destination membership, actual project-clone remaps, rollback/retry and unchanged source learner access/attempt records.
- Expanded LTI/delivery/publication/copy regression passed **335 tests, 0 failures**, seed `817841`. Adjacent project-clone, copy-options, certificate and new-course LiveView regressions reported **129 tests, 0 failures (13 excluded)**, seed `797828`. Successful ExUnit output contains only normal progress and summary after setup; existing OTP shutdown output follows the summary.
- A rolled-back, isolated SQL diagnostic used 2,003 activities and five unrelated copies sharing resource IDs. The new copy operation inserted **501 choices in one INSERT … SELECT with five parameters**, using existing section-resource/deep-link composite indexes without a global scan of deep-link rows. Local warm-cache execution was 9.164 ms, including the insert; this is not a production SLA or a claim of heap-free reads. No index or migration was added.
- Separate security, performance, Elixir and requirements reviews found no remaining issues. Corrected the Blueprint function's documented step order without changing execution. Existing lifecycle processing, final AI-override ordering, copy groups, publication pins and project/blueprint provenance remain intact.
- Scoped formatting, test-environment compilation with warnings as errors, `git diff --check` and Harness structure/design/requirements validation pass. AC-019/AC-020/AC-021 and supporting payload/isolation criteria link the new runner; whole-feature statuses remain `verified_plan`. External-tool/browser proof remains deferred, and Phase 6 is not executed as part of this phase.


### Phase 5 Formal Cleanup (2026-10-15)

- Run `change-cleanup` in `self-driving` mode against `origin/master`, focused on outstanding Phase 5 changes since `2231ccf50e`. Review helper placement/reuse, public contracts, specs, stale state and added-file reachability. No changes outside this phase were needed.
- Clarify that `copy_section_deep_links/2` requires an authorized source and a destination created within the caller's source-locked transaction. Keep the query, transaction boundaries and existing pipeline stages unchanged.
- Remove duplicate SQL-shape assertions from the membership test; the dedicated multi-selection test still proves one INSERT … SELECT, while the membership test retains source/destination filtering assertions. Keep test helpers local instead of adding shared support for these two small, different capture contracts.
- Trace `inheritance_test.exs` through ExUnit discovery to `inheritance_setup.scenario.yaml`, its composed setup and existing compiled hooks. Verify the production helper is called by `SectionCopy.copy/3`; no Phase 5 files or entrypoints are orphaned, and no stale assigns/props or unsupported types were introduced.
- Post-cleanup focused validation passed **13 tests, 0 failures**, seed `840844`, with clean ExUnit output. The earlier 335-test regression and 129-test adjacent result remain applicable because cleanup changes only API documentation and a redundant test assertion. Scoped formatting, compilation with warnings as errors, Harness checks and `git diff --check` pass. The separate security/performance/Elixir/requirements reviews remain recorded above; Phase 5 remains uncommitted.

## Phase 5a Execution Record

### Scope from plan.md

Darren-approved project/template remix inheritance, preserving destination ownership and existing curriculum behavior. Phase 6 remains in stash `c439c03b5bd7b7c35cf105bc8cceb6cb781e4ec7` while this extension is implemented.

### Implementation Blocks

- [x] Preserve source identity and scope inheritance to retained added material.
- [x] Reuse transactional bulk initialization/copy behavior.

### Test Blocks

- [x] Add and validate realistic scenario coverage.
- [x] Run focused and affected checks; record outcomes.

### Work-Item Sync

- [x] Add approved scope to PRD, FDD, plan and FR-012 / AC-032–AC-034 before coding.

### Review Loop

- [x] Complete applicable independent reviews and cleanup.

### Done Definition

- [x] Tests, reviews and documentation validation pass; no commit without owner approval.

### Phase 5a Review and Cleanup (2026-10-15)

- Use `change-cleanup` in the owner's selected `self-driving` mode against `origin/master`, restricted to the outstanding remix extension. Replace the modal's previous source-type map with the chosen-source-key map and derive telemetry types, avoiding parallel state. Reuse `Source.selection_identity/2`, one visibility set per template source, the existing portable-selection initializer and the section-copy query. Add precise public contracts and keep provenance in Remix state rather than the shared hierarchy struct.
- Dedicated security, performance, Elixir and requirements reviews completed. Correct two review findings: skip non-page/empty content during activity extraction, and exclude hidden/removed template descendants from inheritance using the same visibility set. The latter leaves existing curriculum reconstruction behavior unchanged. Correction reviews report no remaining findings; no broader publication/update optimization was added.
- Trace the new automatically discovered `remix_test.exs` and `remix_live_test.exs` runners to `remix.scenario.yaml` / `remix_setup.scenario.yaml` and the existing inheritance/setup/hooks. New workflow setup uses `Oli.Scenarios.execute_file/2` and real APIs without domain factories or mocks. The empty-root regression uses the production project-creation API because scenario-built roots supply model content and cannot express that prerequisite. No shared test support/configuration changed.
- The 22 new remix-focused tests passed (seed `312691`), including actual LiveView picker check/uncheck/recheck/save, current source metadata and independent rows, exact publication retention, both destination types, cleared/missing choices, removed/unreferenced/hidden pages, moved container pages, empty-content roots, membership, rollback/retry, preserved destination choices and bounded query counts. The earlier affected regression passed 372 tests (seed `564452`) before the final two review regressions; final verification is recorded below.
- Performance review confirms one candidate SELECT plus parameter-bounded bulk INSERTs per publication source and one INSERT … SELECT per template source; no per-activity queries or external tool calls. These are query-shape assertions/static review, not production latency or contention benchmarks.
- Phase 6 remains in its original stash until this extension is reviewed by the owner. Its final guide/status reconciliation is deferred to restoration; no commit is authorized by this execution record.

### Phase 5a Final Verification

- Final affected regression passed **374 tests, 0 failures**, seed `816953`: all LTI feature scenarios/context tests; remix domain, scenario/product-source and LiveView suites; direct delivery creation; current/legacy major/minor publication updates; blueprint and shared section-copy regressions. Successful ExUnit output contains only normal progress and summary after standard setup; existing OTP shutdown messages follow the summary.
- Scoped `mix format --check-formatted`, test-environment `mix compile --warnings-as-errors`, `git diff --check`, Harness work-item validation and planning traceability passed. Supplemental canonical nested validation confirms 12 FRs / 34 ACs, unique IDs, valid aggregate statuses and existing relative proof paths. FR-012 / AC-032–AC-034 retain `verified_plan`, consistently with the pre-final-verification contract; Phase 6's canonical final gate/external-tool deferrals remain separate.
- Four independent review lenses and targeted cleanup are complete with no remaining findings. No production query-plan/large-scale contention benchmark or external tool/browser interoperability claim is made. No migration, shared test configuration/support change, commit or stash restoration was performed.
