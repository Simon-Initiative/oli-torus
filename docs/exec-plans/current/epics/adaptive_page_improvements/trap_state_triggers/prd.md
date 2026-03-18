# Trap State Triggers - PRD

## 1. Overview
Feature Name: `trap_state_triggers`

Summary: Add a trap-state `Activation Point` action to Advanced Author adaptive rules so authors can provide a DOT prompt that fires automatically when a trap-state rule is reached. The action is authored in the existing Rules Editor, stored in the adaptive rule JSON alongside `feedback`, `navigation`, and `mutateState`, and emitted server-side after adaptive rule evaluation so the client does not have to trust or submit the authored prompt.

Links:
- `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/informal.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_triggers/prd.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/overview.md`
- Jira ticket `MER-4946`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Advanced Author adaptive rules can currently perform `Show Feedback`, `Navigate To`, and `Mutate State`, but cannot trigger DOT from a trap state.
  - Adaptive screen/component activation points from `MER-4945` cover screen and click entry points, not rules-engine trap-state outcomes.
  - Basic-page evaluations already fire AI triggers from the server when authored response triggers are present, but adaptive rule evaluation does not expose an equivalent server-side hook.
- Affected users/roles:
  - Adaptive authors creating trap-state support moments.
  - Learners who need contextual DOT support immediately after a correct/incorrect trap state fires.
- Why now:
  - `MER-4946` is the next feature in Lane 1 after `adaptive_triggers`.
  - `MER-4961` depends on this trap-state trigger foundation.

## 3. Goals & Non-Goals
- Goals:
  - Add a new Rules Editor action labeled `Activation Point`.
  - Allow authors to enter and persist a custom DOT prompt for that action.
  - Fire the trap-state activation point from the server after adaptive rules are evaluated.
  - Keep authoring availability tied to the existing project trigger capability.
  - Keep section-level assistant/trigger availability authoritative at delivery time.
- Non-Goals:
  - No new trigger endpoint or database migration.
  - No flowchart-mode authoring changes or generated-rule support in this ticket.
  - No new DOT conversation context tools beyond the trigger prompt and existing adaptive context work.
  - No LLM-generated feedback behavior; that belongs to `MER-4961`.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Course authors editing adaptive rules in Advanced Author.
  - Learners interacting with adaptive screens that evaluate through trap states.
- Use Cases:
  - Author adds an `Activation Point` action to an incorrect trap state and asks DOT to coach without revealing the full answer.
  - Author adds an `Activation Point` action to a correct trap state to prompt reflection or extension work.
  - Learner triggers the trap state and DOT opens automatically with the authored prompt.

## 5. UX / UI Requirements
- Key Screens/States:
  - Advanced Author Rules Editor action dropdown.
  - Inline Activation Point action editor within the rule action list.
  - Best-practice warning near the rule conditions / activation area when a trap-state activation point is present.
- Navigation & Entry Points:
  - Existing blue `+` action menu in `AdaptivityEditor`.
- Accessibility:
  - Prompt field label/help must remain screen-reader readable.
  - Action delete control remains keyboard reachable.
- Internationalization:
  - Labels remain static, existing-pattern strings.
- Screenshots/Mocks:
  - Jira/Figma links captured in `informal.md` and Jira comments.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale:
  - No dedicated performance/load/benchmark scope is added.
  - Adaptive submit/evaluation remains the same request shape; only one additional trigger extraction pass is added over returned rule results.
- Reliability:
  - Blank prompts fail closed and do not emit a trigger.
  - Adaptive rule results containing trigger actions must not crash existing client-side `processResults` handling.
  - Only one trap-state activation point is fired per adaptive evaluation response.
- Security & Privacy:
  - Client requests must not be allowed to submit the new trap-state trigger type directly.
  - The authored prompt remains server-authored content, not client-authored runtime payload.
  - Project trigger capability remains authoritative for authoring save validation.
- Compliance:
  - Prompt editing UI remains keyboard operable and labeled.
- Observability:
  - Backend trigger descriptions should identify trap-state trigger reason/context in logs and conversation prompt assembly.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No database migration is required.
- Context Boundaries:
  - Adaptive rule JSON in `content.authoring.rules[*].event.params.actions[*]` gains a new action type.
  - Attempt submission stays on the existing adaptive `submit_activity` path.
  - Backend trigger extraction happens after adaptive rules evaluation, before returning from the request.
- APIs / Contracts:
  - No new HTTP route is added.
  - The new trap-state trigger is server-only and is not a valid client payload type.

### Current rule-action JSON example
```json
{
  "id": "r:123.incorrect",
  "name": "incorrect",
  "conditions": { "all": [] },
  "event": {
    "type": "r:123.incorrect",
    "params": {
      "actions": [
        {
          "type": "feedback",
          "params": {
            "id": "a_f_1",
            "feedback": { "custom": {}, "partsLayout": [] }
          }
        },
        {
          "type": "mutateState",
          "params": {
            "target": "stage.answer.enabled",
            "targetType": 4,
            "operator": "=",
            "value": "false"
          }
        }
      ]
    }
  }
}
```

### Proposed extension
```json
{
  "type": "trigger",
  "params": {
    "prompt": "The learner just triggered this incorrect trap state. Help them reflect on the mistake without giving away the answer."
  }
}
```

## 10. Integrations & Platform Considerations
- GenAI / DOT:
  - Trap-state activation points reuse the existing conversation trigger/broadcast infrastructure.
  - Adaptive trap-state triggers are a new backend-described trigger type, separate from client-submitted `adaptive_page` and `adaptive_component`.
- External services:
  - None.
- Multi-tenancy:
  - Existing section/resource/user trigger boundaries remain in force.

## 11. Feature Flagging, Rollout & Migration
No new feature flags are introduced.

Existing authoring capability gating is reused:
- projects without AI activation points enabled do not expose the Rules Editor `Activation Point` action
- adaptive activity saves containing trap-state trigger actions are rejected when project trigger capability is disabled

## 12. Analytics & Success Metrics
- KPIs:
  - Authors can add and persist trap-state activation points in Advanced Author.
  - Adaptive trap-state submissions emit a server-side trigger when appropriate.
  - Existing adaptive rule processing continues to function when trigger actions are present.
- Events / Operational Signals:
  - Existing PubSub trigger broadcasts now include a trap-state-specific adaptive trigger type.

## 13. Risks & Mitigations
- Unknown adaptive action types could break `processResults`.
  - Mitigation: make the reducer/grouping logic explicitly handle `trigger`.
- Client spoofing of the new trigger type.
  - Mitigation: reject client-submitted trap-state trigger payloads and emit them only from the server.
- Authoring save could permit hidden trigger actions when project capability is disabled.
  - Mitigation: extend adaptive content validation in `ActivityEditor`.

## 14. Open Questions & Assumptions
- Assumptions:
  - The authored trap-state prompt is sufficient for MVP; no extra automatic rule-condition summary is injected beyond trigger description text.
  - The first matching trap-state activation point per adaptive evaluation is the correct firing policy.
- Open Questions:
  - Should future work allow multiple ordered trap-state activation points per rule, or is one enough?
  - Should trap-state trigger prompts eventually receive richer adaptive-state context from `MER-4944`?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Spec pack and Rules Editor action model finalized.
- Milestone 2: Server-side adaptive trap-state trigger emission working.
- Milestone 3: Targeted backend/frontend verification green.

## 16. QA Plan
- Automated:
  - Jest/unit coverage for the new Rules Editor action component and adaptive action grouping.
  - ExUnit coverage for trap-state trigger extraction/description.
  - Controller coverage proving adaptive submit fires the trap-state trigger.
  - Activity editor validation coverage for trigger-disabled projects.
- Manual:
  - Verify `Activation Point` appears in the action menu only when triggers are enabled.
  - Verify prompt text persists after save/reload.
  - Verify DOT opens automatically on trap-state hit in a section with triggers enabled.
  - Verify section-disabled behavior does not open DOT.

## 17. Definition of Done
- [ ] `requirements.yml` exists and aligns with the feature pack.
- [ ] PRD/FDD/plan are present for `trap_state_triggers`.
- [ ] Advanced Author supports trap-state activation point authoring and persistence.
- [ ] Adaptive submit emits a server-side trap-state trigger when authored.
- [ ] Targeted verification is recorded.

## Decision Log

### 2026-03-17 - Initial feature pack for MER-4946
- Change: Added the missing feature pack for trap-state activation points in adaptive rules.
- Reason: The Jira description and Darren Siegel technical guidance require full feature workflow artifacts before implementation.
- Evidence: `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/informal.md`, Jira comments dated October 13, 2025 and February 13, 2026.
- Impact: Establishes the contract for authoring JSON shape, server-side trigger emission, and verification scope.
