# Adaptive Triggers - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/adaptive_page_improvements/adaptive_triggers/prd.md`
- FDD: `docs/epics/adaptive_page_improvements/adaptive_triggers/fdd.md`

## Scope
Deliver `MER-4945` adaptive screen-level AI activation points plus optional AI activation on adaptive images and navigation buttons, using the existing trigger invoke API and existing authoring capability gating.

## Non-Functional Guardrails
- Do not add a new trigger endpoint or database migration.
- Preserve existing image and navigation-button behavior when AI activation is disabled.
- Keep authoring availability tied to the existing trigger capability source.
- Reuse current section-level DOT availability rather than introducing duplicate delivery flags.
- Do not trust client-authored adaptive prompt text; resolve adaptive prompts from delivered content on the server.
- Prefer cached section-resource lookup paths when available and avoid full-row project fetches in adaptive trigger validation.

## Clarifications & Default Assumptions
- The Jira comment from Darren Siegel is authoritative for scope and includes image/button trigger extensions.
- Click-driven adaptive triggers should use `adaptive_component`; screen auto-trigger should use `adaptive_page`.
- Navigation-button AI activation should occur only on learner click, not on programmatic state resets.
- Section-disabled behavior continues to rely on existing trigger instance availability in delivery.
- Adaptive trigger client payloads omit authored prompt text; the backend resolves and validates prompt text from delivered adaptive content.

## AC Traceability
| Requirement | Acceptance criteria | Planned phase coverage |
|---|---|---|
| FR-001 | AC-001, AC-002 | Phase 1 |
| FR-002 | AC-003, AC-004, AC-005 | Phase 1, Phase 2 |
| FR-003 | AC-006, AC-007 | Phase 3 |
| FR-004 | AC-008 | Phase 2, Phase 4 |
| FR-005 | AC-009 | Phase 3, Phase 4 |

## Phase Gate Summary
- Gate 1: adaptive authoring capability gating and new trigger-part schema are complete (`AC-001`, `AC-002`, `AC-003`).
- Gate 2: delivery payload reuse and trigger invocation behavior are complete (`AC-004`, `AC-005`, `AC-008`).
- Gate 3: image/button extension behavior and backend adaptive trigger descriptions are complete (`AC-006`, `AC-007`, `AC-009`).
- Gate 4: targeted verification and doc/traceability validation are complete (`AC-002`, `AC-004`, `AC-005`, `AC-006`, `AC-007`, `AC-009`).

## Phase 1: Adaptive Trigger Part and Authoring Capability Gating
- Goal: expose the new adaptive trigger part and related authoring schema only when trigger capability is enabled.
- Tasks:
  - [x] Add `janus-ai-trigger` manifest, authoring entry, delivery entry, schema, and author placeholder.
  - [x] Add `allowTriggers` to adaptive authoring bootstrap state from `optionalContentTypes.triggers`.
  - [x] Hide `janus_ai_trigger` from part selectors/toolbars when triggers are disabled.
  - [x] Label the new part in the adaptive property editor.
- Testing Tasks:
  - [x] Cover AC-002 with a selector test for `selectPartComponentTypes`.
  - [x] Confirm AC-001 and AC-003 through schema/registration review and authoring visibility checks.
- Definition of Done:
  - The standalone trigger part exists in adaptive authoring.
  - The part is unavailable when trigger capability is disabled.
  - The part exposes launch mode and prompt configuration.
- Gate:
  - Gate 1 passes when AC-001, AC-002, and AC-003 are represented in authoring behavior and tests.
- Dependencies:
  - Existing adaptive authoring capability bootstrap only.
- Parallelizable Work:
  - Part registration and authoring gating can proceed in parallel.

## Phase 2: Shared Trigger Payload Helper and Standalone Delivery Behavior
- Goal: reuse the existing trigger invoke contract for adaptive screen-level activation points.
- Tasks:
  - [x] Add shared helper utilities for prompt validation, payload construction, and guarded invocation.
  - [x] Pass `sectionSlug` and `resourceId` into adaptive part props during delivery rendering.
  - [x] Implement click-mode standalone trigger rendering and invocation.
  - [x] Implement one-time auto trigger scheduling for standalone adaptive triggers.
  - [x] Ensure auto mode waits for valid `resourceId`/`sectionSlug` context before consuming its once-per-session guard.
  - [x] Fail closed for AC-008 when required context or trigger instance availability is missing.
- Testing Tasks:
  - [x] Cover AC-004 with a click-mode Jest test.
  - [x] Cover AC-005 with an auto-mode Jest test.
  - [x] Add a regression test proving auto mode does not burn its session guard before `resourceId` is available.
  - [x] Review helper guard behavior for AC-008.
- Definition of Done:
  - Adaptive standalone triggers invoke the existing trigger API with the correct adaptive payload types.
  - Auto mode does not render a click control.
  - Missing context does not produce malformed trigger calls.
- Gate:
  - Gate 2 passes when AC-004, AC-005, and AC-008 align with delivery behavior.
- Dependencies:
  - Phase 1 authoring model availability.
- Parallelizable Work:
  - Shared helper and prop plumbing can proceed in parallel with standalone part UI work.

## Phase 3: Image and Navigation Button Extensions plus Backend Trigger Types
- Goal: extend existing adaptive parts to emit AI activation on click and ensure backend descriptions understand the new trigger types.
- Tasks:
  - [x] Add `enableAiTrigger` and `aiTriggerPrompt` to adaptive image schema and delivery behavior.
  - [x] Add the same fields to adaptive navigation button schema and click path.
  - [x] Preserve normal navigation-button submit behavior while emitting AI activation.
  - [x] Prevent programmatic button state changes from emitting AI activation.
  - [x] Add `adaptive_page` and `adaptive_component` support to conversation trigger descriptions.
  - [x] Resolve adaptive prompt text and normalized component metadata from delivered content on the server instead of trusting client payload prompt text.
  - [x] Deduplicate repeated adaptive auto-trigger submissions with backend cooldown admission.
- Testing Tasks:
  - [x] Cover AC-006 with an adaptive image click test.
  - [x] Add an image regression test for late DOT availability after initial render.
  - [x] Cover AC-007 with an adaptive navigation-button click test.
  - [x] Cover AC-009 with backend trigger description tests.
  - [x] Cover adaptive prompt resolution and duplicate suppression with controller tests.
- Definition of Done:
  - Image and navigation button triggers are opt-in and click-driven.
  - Navigation-button submit semantics remain intact.
  - Backend accepts and describes adaptive trigger types.
- Gate:
  - Gate 3 passes when AC-006, AC-007, and AC-009 are verified by targeted tests.
- Dependencies:
  - Phase 2 shared helper and payload contract.
- Parallelizable Work:
  - Image and navigation-button extensions can proceed in parallel after the helper contract is stable.

## Phase 4: Verification and Spec Synchronization
- Goal: complete targeted verification and close the spec-pack gap created by implementing before documenting.
- Tasks:
  - [x] Run `mix format`.
  - [x] Run targeted ExUnit coverage for adaptive trigger descriptions, prompt resolution, duplicate suppression, and adaptive trigger content validation.
  - [x] Run targeted Jest coverage for standalone trigger part, image trigger, navigation-button trigger, and authoring availability.
  - [x] Run targeted eslint on touched frontend files.
  - [x] Add PRD, FDD, plan, and requirements artifacts for `adaptive_triggers`.
  - [x] Validate the feature pack and requirements traceability tooling.
- Testing Tasks:
  - [x] Command(s): `mix test test/oli/conversation/triggers_test.exs test/oli_web/controllers/api/trigger_point_controller_test.exs test/oli/editing/activity_editor_test.exs`
  - [x] Command(s): `yarn test --runInBand test/data/persistence/trigger_test.ts test/parts/ai_trigger_test.tsx test/parts/navigation_button_ai_trigger_test.tsx test/parts/image_ai_trigger_test.tsx`
- Definition of Done:
  - Targeted verification is green.
  - The feature pack exists and validates.
  - Requirements traceability is promoted through FDD and plan stages.
- Gate:
  - Gate 4 passes when docs and validation artifacts are green alongside the targeted tests.
- Dependencies:
  - Phases 1 through 3 completed.
- Parallelizable Work:
  - Documentation sync can run in parallel with final lint/test passes.

## Parallelisation Notes
- Phase 1 and Phase 2 have limited overlap once the capability gate contract is known.
- Phase 3 can proceed in parallel on image and navigation-button tracks after the helper contract from Phase 2 is stable.
- Phase 4 is a closeout phase once implementation behavior is settled.

## Decision Log

### 2026-03-10 - Capture the work as already-implemented phases
- Change: Added a feature-level delivery plan that reflects the implementation order and marks the completed workstreams, verification commands, and AC coverage.
- Reason: `MER-4945` was implemented before a feature plan existed, so the phase record needed to be reconstructed from the delivered code and tests.
- Evidence: `assets/test/parts/ai_trigger_test.tsx`, `assets/test/parts/navigation_button_ai_trigger_test.tsx`, `assets/test/parts/image_ai_trigger_test.tsx`, `assets/test/advanced_authoring/part_component_types_test.ts`, `test/oli/conversation/triggers_test.exs`
- Impact: Establishes plan-stage traceability for requirements validation and future follow-on tickets in the adaptive AI lane.

### 2026-03-12 - Reflect hardening work in phase records
- Change: Updated the plan to capture server-side prompt resolution, backend duplicate suppression, cached lookup behavior, and the new regression coverage for delayed resource context and late DOT availability.
- Reason: Follow-up implementation work changed the adaptive trigger runtime path and verification surface after the original phase reconstruction.
- Evidence: `lib/oli/conversation/triggers.ex`, `lib/oli/authoring/editing/activity_editor.ex`, `assets/src/components/parts/janus-ai-trigger/AITrigger.tsx`, `assets/src/components/parts/janus-image/Image.tsx`, `assets/test/parts/ai_trigger_test.tsx`, `assets/test/parts/image_ai_trigger_test.tsx`, `test/oli_web/controllers/api/trigger_point_controller_test.exs`
- Impact: Keeps Gate 2 through Gate 4 aligned with the delivered controls and the tests required to keep them from regressing.
