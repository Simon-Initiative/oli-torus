# Adaptive Context - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_context/prd.md`
- FDD: `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_context/fdd.md`

## Scope
Implement adaptive-page-aware DOT context for student delivery by adding a backend adaptive context builder, conditionally exposing an adaptive-only dialogue tool in supported Torus adaptive delivery, wiring the adaptive client to keep the current activity-attempt GUID synchronized with `WindowLive`, and hardening the feature with telemetry, authorization checks, and targeted automated/manual verification.

## Clarifications & Default Assumptions
- Existing assistant enablement and adaptive-with-chrome placement rules remain the only rollout gates; no new feature flag is planned.
- The adaptive tool contract will require `activity_attempt_guid`, `current_user_id`, and `section_id` at the dialogue-function layer, while the core builder stays centered on the activity-attempt GUID.
- Default revisit handling is to preserve actual attempt order when the stored attempt data supports it; if not, implementation may collapse revisits into one screen entry with explicit visit count, but that deviation must be documented before merge.
- Scenario coverage is optional for this work item; start with ExUnit, LiveView, and Jest because the main risks are builder correctness and UI/runtime integration rather than a long multi-step authoring workflow.

## Phase 1: Backend Adaptive Context Builder
- Goal: Create the backend module and data-access helpers that can resolve an adaptive activity attempt into learner-safe markdown context.
- Tasks:
  - [ ] Add `Oli.Conversation.AdaptivePageContextBuilder` under `lib/oli/conversation/` with a public `build/3` contract.
  - [ ] Add or extend attempt queries in `Oli.Delivery.Attempts.Core` for ordered adaptive activity-attempt retrieval with revision and part-attempt preload support.
  - [ ] Implement adaptive sequence extraction from page revision content plus visit-state extraction from adaptive extrinsic state.
  - [ ] Render markdown sections for current screen, visited screens, and not-yet-visited screens, covering `AC-003`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, and `AC-008`.
- Testing Tasks:
  - [ ] Add ExUnit coverage for attempt resolution, access validation, visit ordering, response inclusion, unvisited-screen exclusion, and safe-failure paths.
  - [ ] Add markdown-focused assertions for current-screen labeling and learner-safe omission of unseen-screen content.
  - Command(s): `mix test test/oli/conversation/... test/oli/delivery/...`
- Definition of Done:
  - Builder returns stable markdown for valid adaptive attempts.
  - Builder rejects invalid section/user mismatches and malformed attempt inputs.
  - All Phase 1 automated tests pass locally.
- Gate:
  - No UI or dialogue wiring work begins until the builder contract and output shape are stable enough for function integration.
- Dependencies:
  - PRD and FDD approved.
- Parallelizable Work:
  - Sequence extraction and markdown formatter work can proceed in parallel once the builder input/output contract is settled.

## Phase 2: Dialogue Tool Exposure And Runtime Sync
- Goal: Expose the adaptive context function only in supported adaptive sessions and keep the current activity-attempt GUID synchronized with the LiveView dialogue session.
- Tasks:
  - [ ] Refactor `OliWeb.Dialogue.StudentFunctions` to produce a session-aware function list and add the `adaptive_page_context` spec covering `AC-001`.
  - [ ] Implement the thin dialogue-layer wrapper that validates arguments and delegates to `AdaptivePageContextBuilder`.
  - [ ] Update `OliWeb.Dialogue.WindowLive` to accept adaptive context, store `current_activity_attempt_guid`, and handle a new `"adaptive_screen_changed"` event.
  - [ ] Add a Phoenix hook on the dialogue root and a small adaptive delivery bridge that emits current attempt GUID changes from the React runtime, covering `AC-002` and keeping tool calls current.
- Testing Tasks:
  - [ ] Add LiveView tests for adaptive-only tool exposure, non-adaptive/disabled hiding behavior, and runtime event handling for `AC-001` and `AC-002`.
  - [ ] Add Jest coverage for the adaptive bridge so screen changes emit GUID updates only in supported viewer mode.
  - Command(s): `mix test test/oli_web/live/dialogue/...` and `cd assets && yarn test adaptive`
- Definition of Done:
  - Adaptive sessions expose the new tool and non-adaptive sessions do not.
  - The current activity-attempt GUID updates when the learner changes adaptive screens in supported mode.
  - Existing DOT behavior on non-adaptive pages is unchanged.
- Gate:
  - Phase 2 passes only when the dialogue session can consume the builder without manual patching or hidden global state.
- Dependencies:
  - Phase 1 complete.
- Parallelizable Work:
  - LiveView event handling and frontend bridge work can proceed in parallel after the event payload contract is fixed.

## Phase 3: Telemetry, Security Hardening, And Negative Cases
- Goal: Add operational visibility, tighten safe-failure behavior, and cover the feature’s primary regression risks.
- Tasks:
  - [ ] Add adaptive-context telemetry for tool exposure, tool call, build success, and build failure, covering `AC-009`.
  - [ ] Ensure telemetry payloads exclude raw student answers, screen content, and free-form prompts.
  - [ ] Harden argument validation and error-path messaging so invalid or unsupported requests fail closed without leaking cross-user or unseen content.
  - [ ] Verify the tool description and builder output work together to reinforce `AC-010` and the unseen-content boundary in practice.
- Testing Tasks:
  - [ ] Add telemetry tests for emitted event names, measurements, and metadata exclusions.
  - [ ] Add negative-path tests for mismatched learner/section, missing visit state, and unsupported adaptive contexts.
  - [ ] Prepare a short manual QA script for branching adaptive pages, prompt-injection-style answer requests, and hidden-DOT cases.
  - Command(s): `mix test test/oli/gen_ai/... test/oli/conversation/...`
- Definition of Done:
  - Telemetry exists for success/failure paths and is free of raw learner content.
  - Negative-path tests pass and safe error behavior is documented.
  - Manual QA script is ready for the final verification pass.
- Gate:
  - No merge recommendation until telemetry and negative-case coverage are in place.
- Dependencies:
  - Phase 2 complete.
- Parallelizable Work:
  - Telemetry wiring and negative-case tests can proceed in parallel once the final builder/function event names are fixed.

## Phase 4: Final Verification And Merge Readiness
- Goal: Run the end-to-end verification sweep, confirm requirement coverage, and leave the work item ready for implementation or review closure.
- Tasks:
  - [ ] Run the most targeted backend, LiveView, and frontend test suites touched by the implementation.
  - [ ] Execute manual QA against a branching adaptive page and record results against `AC-001` through `AC-010`.
  - [ ] Confirm no schema migration, no feature flag, and no non-adaptive regression remains outstanding.
  - [ ] Update requirement proofs or plan references if implementation adds or moves verification targets.
- Testing Tasks:
  - [ ] Backend targeted suite for builder, telemetry, and dialogue integration.
  - [ ] Frontend targeted suite for adaptive bridge behavior.
  - [ ] Manual QA checklist pass for hidden DOT, current screen relevance, visited history, and unseen-content refusal.
  - Command(s): `mix test ...`, `cd assets && yarn test ...`
- Definition of Done:
  - Automated suites relevant to the changed behavior pass.
  - Manual QA confirms adaptive DOT context behavior on supported pages.
  - Work item docs still validate after any proof/reference updates.
- Gate:
  - Final gate is satisfied only when targeted tests, manual QA, and work-item validation all pass.
- Dependencies:
  - Phases 1 through 3 complete.
- Parallelizable Work:
  - Backend and frontend test execution can run in parallel after code is stable; manual QA follows once a deployable branch exists.

## Parallelization Notes
- Phase 1 should stay mostly serial until the builder contract is fixed; after that, helper-query work and markdown-format work can split safely.
- Phase 2 supports backend LiveView work and frontend bridge work in parallel once the event payload is agreed.
- Phase 3 allows telemetry and negative-case test authoring in parallel.
- Phase 4 is primarily verification and should not begin until implementation churn is low.

## Phase Gate Summary
- Gate A: Backend builder contract and ExUnit coverage for `AC-003` through `AC-008` are green.
- Gate B: Adaptive-only tool exposure and runtime GUID sync satisfy `AC-001` and `AC-002`.
- Gate C: Telemetry, security hardening, and negative-case coverage satisfy `AC-009` and support `AC-010`.
- Gate D: Targeted automated tests, manual QA, and plan validation all pass.
