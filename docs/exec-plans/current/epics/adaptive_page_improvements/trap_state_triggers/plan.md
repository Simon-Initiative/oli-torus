# Trap State Triggers - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/prd.md`
- FDD: `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/fdd.md`

## Scope
Deliver `MER-4946` by adding a trap-state `Activation Point` action to Advanced Author adaptive rules and emitting the authored DOT prompt from the server after adaptive rule evaluation.

## Non-Functional Guardrails
- Do not add a new trigger endpoint or database migration.
- Keep the authored prompt server-authored; do not require the browser to send it back.
- Fail closed on blank prompt, missing page context, or client spoof attempts.
- Preserve existing adaptive rule processing when trigger actions are present.

## Clarifications & Default Assumptions
- Darren Siegel’s February 13, 2026 Jira comment is authoritative: this is a feature, the JSON shape must be documented, and the emission path should hang off adaptive `evaluate_activity`.
- The feature is limited to Advanced Author rules, not flowchart-generated rules.
- The first trap-state activation point found in a single adaptive evaluation response is the only one fired.
- Project trigger capability and section assistant/trigger enablement remain authoritative gates.

## AC Traceability
| Requirement | Acceptance criteria | Planned phase coverage |
|---|---|---|
| FR-001 | AC-001, AC-002 | Phase 1 |
| FR-002 | AC-003, AC-004 | Phase 1 |
| FR-003 | AC-005 | Phase 2 |
| FR-004 | AC-006 | Phase 1, Phase 2 |
| FR-005 | AC-007 | Phase 2 |

## Phase Gate Summary
- Gate 1: authoring JSON shape, UI, and disabled-project validation are complete (`AC-001`, `AC-002`, `AC-003`, `AC-004`).
- Gate 2: server-side trigger extraction/emission and client-spoof protection are complete (`AC-005`, `AC-006`, `AC-007`).
- Gate 3: targeted verification and spec synchronization are complete.

## Phase 1: Authoring Action Model and Rules Editor UI
- Goal: add the new action type safely to authoring and persisted adaptive rule content.
- Tasks:
  - [ ] Add `trigger` to adaptive action typings.
  - [ ] Add `ActionTriggerEditor` using the shared prompt editor treatment.
  - [ ] Add `Activation Point` to the Rules Editor add-action menu only when triggers are enabled.
  - [ ] Show the best-practice warning in the Rules Editor when a trap-state trigger action is present.
  - [ ] Extend adaptive content validation so rule trigger actions are rejected when project trigger capability is disabled.
  - [ ] Make `processResults` tolerate `trigger` actions.
- Testing Tasks:
  - [ ] Add/update frontend unit coverage for the new action editor and action grouping.
  - [ ] Add/update `ActivityEditor` tests for disabled-project rejection.
- Definition of Done:
  - Authors can add/edit/delete trap-state activation point actions in Advanced Author.
  - Saved rule JSON includes the new action shape.
  - Hidden/disabled capability is enforced in both UI and server validation.
- Gate:
  - Gate 1 passes when authoring behavior and validation tests are green.

## Phase 2: Server-Side Trigger Emission
- Goal: emit a server-side trap-state trigger from adaptive `submit_activity`.
- Tasks:
  - [ ] Add `:adaptive_trap_state` description/support in conversation triggers.
  - [ ] Add helper(s) to extract the first trap-state activation point from adaptive rules-engine results.
  - [ ] Update `AttemptController.submit_activity/3` to run the adaptive trap-state trigger extraction path.
  - [ ] Explicitly reject client-submitted `adaptive_trap_state` payloads.
- Testing Tasks:
  - [ ] Add `Triggers` unit tests for extraction and description.
  - [ ] Add controller coverage for adaptive submit firing the trap-state trigger.
- Definition of Done:
  - Adaptive trap-state triggers are emitted server-side when authored and evaluated.
  - No client request can invoke the new type directly.
  - Existing adaptive submit response handling remains stable.
- Gate:
  - Gate 2 passes when trigger emission and spoof-protection tests are green.

## Phase 3: Verification and Spec Closeout
- Goal: verify the implementation and keep the feature pack aligned with delivered behavior.
- Tasks:
  - [ ] Run `mix format`.
  - [ ] Run targeted ExUnit coverage for trigger extraction/emission and adaptive validation.
  - [ ] Run targeted frontend unit coverage for the new action editor / adaptive action grouping.
  - [ ] Sync PRD/FDD/plan/requirements/design brief if implementation details differ from the initial plan.
- Testing Tasks:
  - [ ] Command(s): `mix test test/oli/conversation/triggers_test.exs test/oli_web/controllers/api/attempt_controller_test.exs test/oli/editing/activity_editor_test.exs`
  - [ ] Command(s): `yarn test --runInBand test/advanced_authoring/adaptivity/trap_state_trigger_action_test.tsx`
- Definition of Done:
  - Targeted verification is green.
  - The feature pack reflects the shipped implementation.
- Gate:
  - Gate 3 passes when docs and targeted verification are complete.

## Parallelisation Notes
- Phase 1 authoring work and Phase 2 backend work can overlap once the action JSON shape is fixed.
- Final verification should wait until both phases are landed so authoring, validation, and trigger emission are exercised together.

## Decision Log

### 2026-03-17 - Initial plan for MER-4946
- Change: Added the first delivery plan for trap-state activation points covering authoring, server-side emission, and targeted verification.
- Reason: The ticket had only informal notes in the repo, but the feature requires the full spec workflow before implementation.
- Evidence: `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/informal.md`
- Impact: Establishes the phase/gate structure for implementation and traceability.
