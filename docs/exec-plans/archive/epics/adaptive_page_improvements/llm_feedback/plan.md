# LLM Feedback - Delivery Plan

Scope and guardrails reference:
- PRD: `docs/exec-plans/current/epics/adaptive_page_improvements/llm_feedback/prd.md`
- FDD: `docs/exec-plans/current/epics/adaptive_page_improvements/llm_feedback/fdd.md`

## Scope
Deliver `MER-4961` inline adaptive LLM feedback by extending trap-state authoring with a feedback-kind activation point, synchronously generating learner-specific feedback during `submit_activity`, and rendering the result in the existing feedback popup with visible AI attribution.

## Non-Functional Guardrails
- Do not add a new delivery endpoint or a database migration.
- Preserve existing trap-state DOT activation behavior for activation points that are not marked as feedback generation.
- Limit MVP generation to supported text-entry inputs only.
- Fail closed on missing rollout, missing AI enablement, or GenAI/provider errors.
- Keep raw learner text out of telemetry and logs.

## Clarifications & Default Assumptions
- `MER-4946` is a hard implementation dependency and must land first.
- `MER-4944` adaptive context support is assumed available and is reused rather than reimplemented.
- MVP supports only `janus-input-text` and `janus-multi-line-text`.
- MVP transforms only the first matching feedback-kind activation point per learner submission.
- Preview mode remains out of scope; it should not invoke DOT for `kind: "feedback"` actions.

## AC Traceability
| Requirement | Acceptance criteria | Planned phase coverage |
|---|---|---|
| FR-001 | AC-001, AC-002 | Phase 1 |
| FR-002 | AC-003, AC-004 | Phase 2 |
| FR-003 | AC-005 | Phase 3 |
| FR-004 | AC-006, AC-007 | Phase 2, Phase 4 |
| FR-005 | AC-008 | Phase 3, Phase 4 |
| FR-006 | AC-009, AC-010 | Phase 1, Phase 4 |

## Phase Gate Summary
- Gate 1: rollout contract and authoring model are in place (`AC-001`, `AC-002`, `AC-009`).
- Gate 2: backend synchronous generation and response transformation are in place (`AC-003`, `AC-004`, `AC-006`, `AC-007`).
- Gate 3: popup attribution and legacy trap-state compatibility are in place (`AC-005`, `AC-008`).
- Gate 4: verification, telemetry, and rollout closeout are complete (`AC-006` through `AC-010`).

## Phase 1: Rollout and Authoring Contract
- Goal: expose the authoring affordance only in supported rollout-enabled contexts and persist the new action shape.
- Tasks:
  - [ ] Define scoped feature `llm_feedback` in the central feature-flag registry with authoring and delivery scope.
  - [ ] Extend adaptive authoring bootstrap/app state with rollout availability for `llm_feedback`.
  - [ ] Extend `ActivationPointActionParams` with `kind?: "dot" | "feedback"`.
  - [ ] Add a dedicated `AI-Generated Feedback` Rules Editor action and editor component.
  - [ ] Gate the action by trigger capability, rollout flag, and supported text-entry part detection.
  - [ ] Enforce one feedback-kind activation point per rule.
- Testing Tasks:
  - [ ] Add / adjust Jest coverage for Rules Editor visibility and persistence.
  - [ ] Verify unsupported screens do not expose the action.
- Definition of Done:
  - Authors can configure the new action only in supported contexts.
  - Saved rules persist `kind: "feedback"` correctly.
- Gate:
  - Gate 1 passes when authoring rollout and rule persistence behavior are covered.
- Dependencies:
  - `MER-4946`
- Parallelizable Work:
  - Feature-flag plumbing and Rules Editor UI work can proceed in parallel once the bootstrap contract is agreed.

## Phase 2: Backend LLM Feedback Orchestration
- Goal: synchronously generate inline feedback on student submit and return it as a standard feedback action.
- Tasks:
  - [ ] Add `Oli.Conversation.LLMFeedback` to normalize learner text, build adaptive context, and call `Execution.generate/5`.
  - [ ] Add server-side helper(s) to identify supported submitted text-entry inputs from the current attempt.
  - [ ] Update `AttemptController.submit_activity/2` to transform feedback-kind activation points after evaluation and before JSON response.
  - [ ] Reuse `FeatureConfig.load_for(section.id, :student_dialogue)` and tag requests with `request_type: :llm_feedback`.
  - [ ] Build a synthetic feedback model in the same shape used by existing popup feedback.
  - [ ] Fail closed when rollout, section AI enablement, supported input extraction, adaptive context build, or provider calls fail.
  - [ ] Keep the first-match-only rule for MVP latency control.
- Testing Tasks:
  - [ ] Add ExUnit coverage for normalization, context/prompt construction, response transformation, and failure behavior.
  - [ ] Add controller tests for rollout disabled, AI disabled, unsupported input, and provider failure cases.
- Definition of Done:
  - Student submit requests can return generated inline feedback without opening DOT.
  - Generation errors do not break submit success or unrelated actions.
- Gate:
  - Gate 2 passes when the backend transform is deterministic and failure-safe.
- Dependencies:
  - Phase 1
  - `MER-4944`
- Parallelizable Work:
  - The generation module and controller transform can be developed in parallel once the synthetic feedback contract is fixed.

## Phase 3: Delivery Rendering and Compatibility
- Goal: render attribution in the existing popup flow and preserve legacy trap-state behavior.
- Tasks:
  - [ ] Render `AI-generated` attribution from feedback-model metadata in `FeedbackRenderer`.
  - [ ] Ensure popup styling and focus behavior remain unchanged for generated feedback.
  - [ ] Update trap-state client invocation logic so `kind: "feedback"` never opens DOT.
  - [ ] Verify non-feedback activation points still follow the current DOT flow.
- Testing Tasks:
  - [ ] Add / adjust frontend tests for popup attribution rendering.
  - [ ] Add regression coverage for `triggerCheck` filtering of feedback-kind activation points.
- Definition of Done:
  - Generated feedback uses the standard popup with visible attribution.
  - Existing DOT trap-state activation still works for `kind: "dot"` and legacy rules.
- Gate:
  - Gate 3 passes when popup attribution and compatibility tests are green.
- Dependencies:
  - Phase 2 synthetic feedback contract
- Parallelizable Work:
  - Popup attribution and trigger-check compatibility can proceed in parallel after the response contract is stable.

## Phase 4: Verification and Rollout Closeout
- Goal: complete targeted verification, telemetry validation, and rollout-ready documentation closeout.
- Tasks:
  - [ ] Run targeted backend and frontend tests for authoring, controller transformation, popup rendering, and legacy trigger compatibility.
  - [ ] Verify telemetry uses `request_type: :llm_feedback` and excludes raw learner text.
  - [ ] Perform manual QA for project-flag off, section-flag off, supported input, unsupported input, and generation failure flows.
  - [ ] Confirm project and section rollout playbook for internal enablement.
- Testing Tasks:
  - [ ] Command(s): `mix test test/oli_web/controllers/api/attempt_controller_test.exs test/oli_web/controllers/api/trigger_point_controller_test.exs test/oli/conversation/llm_feedback_test.exs`
  - [ ] Command(s): `yarn test --runInBand assets/test/advanced_authoring/adaptivity/rule_editor_test.ts assets/test/parts/feedback_renderer_test.tsx`
- Definition of Done:
  - Targeted verification is green.
  - Telemetry and rollout assumptions are validated.
  - The spec pack stays aligned with the implementation plan.
- Gate:
  - Gate 4 passes when verification and rollout closeout are complete.
- Dependencies:
  - Phases 1 through 3
- Parallelizable Work:
  - Manual QA and telemetry validation can run in parallel with final test sweeps.

## Parallelisation Notes
- Phase 1 rollout plumbing and authoring UI can be split once the bootstrap contract is defined.
- Phase 2 backend orchestration should settle the response contract before Phase 3 finalizes renderer work.
- Phase 4 is primarily closeout and can overlap with late-stage bug fixes.

## Decision Log

### 2026-03-31 - Initial phased plan for MER-4961
- Change: Added the missing phased delivery plan for `llm_feedback`, covering rollout gating, authoring, backend generation, popup rendering, and rollout closeout.
- Reason: The feature had an informal note and a local implementation sketch but no durable execution plan.
- Evidence: `docs/exec-plans/current/epics/adaptive_page_improvements/llm_feedback/informal.md`, `MER-4961.md`
- Impact: Establishes delivery sequencing and explicit gate coverage for the adaptive AI lane.
