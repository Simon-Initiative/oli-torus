# MER-6018 LTI Deep Linking - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/prd.md`.
- FDD: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/fdd.md`.
- Canonical FR/AC: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/requirements.yml`.
- Intake/manual evidence: `docs/exec-plans/current/features/mer-6018-lti-deep-linking/informal.md`.

## Scope

Productionize the inherited prototype, repair instructor reconfiguration, add missing-only publication application and project → template → section inheritance, and supply permanent regression evidence. This plan does not start implementation or mark manual observations as automated proof.

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
  - [ ] Prepare worktree dependencies/configuration without sharing build outputs or resetting the running demo's database.
  - [ ] Audit existing tests and scenario capabilities; turn the successful manual checks into committed domain/scenario regressions.
  - [ ] Verify old/new publication capture, copied URL/custom and independent destination ownership; retain the long-field regression.
- Testing Tasks:
  - [ ] Cover AC-002, AC-012, AC-013, AC-014, AC-025, AC-026, AC-027 and the direct-creation portion of AC-028.
  - [ ] Validate and run a real `lti_authoring_deep_linking` scenario runner, adding only the minimum missing setup/assertion capabilities.
  - [ ] Run the existing LTI API/controller/context targets and affected delivery targets before claiming a green baseline.
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
  - [ ] Audit the observed empty modal's regular/configuration form targets and return routing; retain frame collision as a hypothesis until actual navigation can be verified.
  - [ ] Add failing component regressions for colliding regular/configuration/multiple-activity targets and incorrectly associated messages, then give mounted instances distinct stable frame targets.
  - [ ] Recheck section capability/permission enforcement at launch and callback and distinguish cancellation/error from successful selection updates.
  - [ ] Use signed test responses and real section data to verify instructor changes and subsequent learner launch parameters without modifying project or sibling selections.
  - [ ] Record actual selector navigation/return and a complete instructor walkthrough as deferred verification; do not claim that component evidence reproduces or resolves the runtime symptom.
- Testing Tasks:
  - [ ] Cover AC-023, AC-024, AC-029 and the Torus-owned portion of AC-022; retain AC-022's external-navigation confirmation as pending.
  - [ ] Component-test embedded/new-window delivery, multiple instances, modal rendering and message source/association with controlled events and no external service.
  - [ ] Run focused frame/delivery Jest tests and section callback/controller tests with signed responses and test keys.
  - Commands: targeted `yarn test` and lint/type checks in `assets/`; targeted `mix test` for affected LTI controller/context tests. No tool-dependent Playwright run is required or authorized by this phase.
- Definition of Done:
  - Torus-owned frame/message regressions pass, and instructor persistence/launch-parameter tests affect only the intended section. Actual tool navigation remains documented as deferred.
- Gate:
  - Focused frontend and backend regressions pass. Proceed with the other phases while retaining the external verification gap; component tests do not establish complete runtime proof for AC-022.
- Dependencies:
  - Phase 1 baseline; no external tool fixture/service is a prerequisite.
- Parallelizable Work:
  - Frontend regression preparation and backend authorization test inventory can be independent. Shared frame code and modal integration must be coordinated.

## Phase 3: Harden authoring correlation, persistence and UI states

- Requirements: FR-001, FR-002, FR-003, FR-004.
- Goal: prevent stale/replayed returns and lost selections/content while making save state clear.
- Tasks:
  - [ ] Produce the focused authoring-save slice design for the FDD's signed-result/editor-save contract and identify all relevant ordinary/bulk LTI edit paths.
  - [ ] Capture starting revision/edit-lock identity after pending-save preparation; bind request/result tokens to author/project/activity/deployment and validate them at retrieval/save.
  - [ ] Implement atomic freshness checks, selection-only merge, fresh revision/mapping update and authoritative response synchronization through shared editing primitives.
  - [ ] Make relevant ordinary LTI mutations advance freshness and preserve the authoritative selection against stale client payloads, while retaining non-LTI editing policy.
  - [ ] Refine role/type/actions and configured-state fallback using established authoring components; implement accessible preparing/launching/saving/success/failure states and failed-save recovery.
  - [ ] Prevent overlapping launches/edits and invalidate cancelled, terminally failed or obsolete request callbacks. Keep unsupported hosts from offering unusable configuration actions.
- Testing Tasks:
  - [ ] Cover AC-001, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011 and strengthen AC-002/AC-012 against stale autosaves.
  - [ ] Test four role/type combinations, invalid/expired/cross-associated signed returns, same-lock ordinary edits, lost locks, failed commits, replay and synchronization after a successful save.
  - [ ] Run focused editor/LTI ExUnit tests, state/orchestration/component Jest tests and the Phase 1 lifecycle scenarios without running an external tool.
  - Commands: targeted `mix test`, targeted `yarn test`, file-scoped lint/format and `yarn check-types` in `assets/`; `mix format --check-formatted` for changed Elixir files.
- Definition of Done:
  - A selection cannot overwrite intervening edits or be applied twice; UI/model/persisted state agree after success, cancellation and failure.
- Gate:
  - Guard/failure regressions and supported-host component checks pass; no unbounded client timeout is treated as proof that persistence stopped. Cross-service authoring browser checks remain deferred.
- Dependencies:
  - Phases 1–2 and a concrete authoring-save slice design. Reuse verified frame behavior.
- Parallelizable Work:
  - UI wording/a11y and signed-protocol test preparation can proceed independently after the save contract is fixed; shared editor/domain persistence edits remain coordinated.

## Phase 4: Initialize missing selections during publication application

- Requirements: FR-005, FR-006, FR-011.
- Goal: extend publication application without replacing existing destination configuration.
- Tasks:
  - [ ] Refactor publication initialization into a scoped, validated missing-only helper using database conflict-do-nothing semantics.
  - [ ] Reuse it in direct creation and invoke it after final destination resource/migration processing inside publication application's existing transaction.
  - [ ] Audit worker, major/minor, blueprint-backed and legacy entry points; preserve cache/completion ordering and existing rows even when project selection changes or vanishes.
  - [ ] Ensure empty selections and resources excluded from the actual destination are skipped; propagate failures to roll back the full update.
- Testing Tasks:
  - [ ] Cover AC-015, AC-016, AC-017, AC-018 and the application portion of AC-028; rerun AC-013/AC-014 direct-creation regressions.
  - [ ] Exercise new activities, previously missing selections, absent/null selections, instructor overrides, filtered/retained resources, remixed publications, repeated application, conflicting inserts and failure rollback.
  - [ ] Validate/run real publication-application scenarios and focused initialization/update tests; inspect query shape for scoped joins and accidental per-resource lookups.
  - Commands: targeted `mix test` for initialization, delivery/update and new scenario runners; scenario structure validation through `Oli.Scenarios.validate_file/1`.
- Definition of Done:
  - Missing selections are populated from the applied published revisions and existing rows remain unchanged; creation/application cannot succeed partially.
- Gate:
  - Major/minor, idempotency/concurrency, membership and rollback cases pass, with no additional sections created by application.
- Dependencies:
  - Phase 1 coverage and Phase 3 stable activity/publication lifecycle.
- Parallelizable Work:
  - Scenario drafting and query/transaction investigation may proceed independently; helper and update-pipeline writes must share one agreed contract.

## Phase 5: Complete project-to-template-to-section inheritance

- Requirements: FR-007, FR-008, FR-010, FR-011.
- Goal: initialize templates and copy their current selections into new sections.
- Tasks:
  - [ ] Initialize template-owned records from the exact publication within blueprint creation after resources exist.
  - [ ] Add selection copying to the template source policy in the shared copy engine, respecting corresponding destination resource mapping.
  - [ ] Preserve template-local changes and missing/cleared selections without project fallback; keep records independent and rollback on copy failure.
  - [ ] Cover adjacent blueprint duplication/project-remap behavior and prevent accidental expansion of ordinary previous-section-copy policy.
- Testing Tasks:
  - [ ] Cover AC-019, AC-020, AC-021 and repeat exact-payload/isolation checks from AC-025/AC-028.
  - [ ] Run real project → template → section scenarios with edited/cleared template selections, destination exclusions/remaps and rollback.
  - [ ] Run existing blueprint/copy scenarios and inspect that this feature copies no attempts, submissions or grades.
  - Commands: `mix test test/oli/delivery/sections/blueprint_test.exs test/oli/delivery/sections/section_copy_test.exs` plus new scenario runners; validate every new scenario YAML.
- Definition of Done:
  - New sections inherit current template-owned selections independently, and unconfigured templates do not recover values from project content.
- Gate:
  - Template inheritance, rollback and adjacent copy-policy regressions pass. No template Deep Linking authoring UI or general copy checkbox is introduced.
- Dependencies:
  - Phase 4's reusable initialization helper and Phase 1's copy baseline inventory.
- Parallelizable Work:
  - Template-init and copy-policy test preparation can be independent; shared copy-engine changes must be coordinated with existing/remapped resources.

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

## Decision Log

### 2026-10-13 - Defer tests requiring a running external tool
- Change: Remove tool setup/extension and tool-dependent browser runs from the active phases; keep ExUnit, real domain scenarios and frontend state/component checks.
- Reason: The owner explicitly requested retaining the other proposed tests while postponing tool-dependent automation because LTI Example Tool lacks Deep Linking support.
- Evidence: `assets/automation/tests/torus/lti_external_tool/lti-external-tool.spec.ts` currently covers Regular; `test/scenarios/lti_external_tool/hooks.ex` disables Deep Linking. Signed-response backend coverage exists in `test/oli_web/controllers/lti_controller_test.exs`.
- Impact: Phases 2, 3 and 6 progress without an external service. AC-029 uses frontend coverage without one; AC-022 external navigation and AC-030's full compatibility walkthrough remain pending. Product implementation scope and the other test layers are retained.
