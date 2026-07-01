# LLM Feedback - PRD

## 1. Overview
Feature Name: `llm_feedback`

Summary: Allow adaptive trap-state rules to generate inline, LLM-authored feedback based on the learner's submitted text, the authored prompt, and the current adaptive screen context. The generated result must appear in the existing adaptive feedback popup, not in DOT chat, and must be labeled as AI-generated.

Links:
- `docs/exec-plans/current/epics/adaptive_page_improvements/llm_feedback/informal.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/plan.md`
- `MER-4961.md`
- Jira ticket `MER-4961`
- Related dependency `MER-4946`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Trap-state AI activation currently routes learners into DOT chat rather than the standard adaptive feedback popup.
  - Authored static feedback can react to trap-state conditions but cannot personalize itself to what the learner actually typed.
  - Adaptive delivery already has the submit/evaluate path, adaptive context builder, and GenAI service configuration plumbing, but none of those are wired together for synchronous inline feedback.
- Affected users / roles:
  - Authors building adaptive trap-state interventions.
  - Learners who need response-specific guidance without leaving the normal adaptive flow.
- Why now:
  - `MER-4961` is the follow-on story to `MER-4946` trap-state activation points.
  - `MER-4944` adaptive context work provides the screen-context building block that generated feedback should reuse.

## 3. Goals & Non-Goals
- Goals:
  - Let authors configure a trap-state action that requests AI-generated feedback with a custom prompt.
  - Support MVP input coverage for `janus-input-text` and `janus-multi-line-text` only.
  - Synchronously generate feedback during `submit_activity` using the author prompt, learner text response, and adaptive screen context.
  - Return the result as a standard feedback action so the existing feedback popup can render it.
  - Display clear `AI-generated` attribution to the learner.
  - Gate the feature through scoped rollout controls without changing existing DOT activation behavior.
- Non-Goals:
  - No new chat UI, streaming UI, or DOT window behavior for this ticket.
  - No support in MVP for numeric, multiple choice, fill-in-the-blank, or other non-text learner inputs.
  - No new GenAI feature family; the work reuses the existing `:student_dialogue` service configuration.
  - No author-preview parity requirement; MVP targets student delivery.
  - No replacement of existing trap-state DOT activation when the action is not marked as feedback generation.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Adaptive authors configuring trap-state rules.
  - Learners receiving inline adaptive feedback.
- Use Cases:
  - Author adds `AI-Generated Feedback` to an incorrect-answer trap state and writes a prompt that tells the model how to coach the learner.
  - Learner submits a short written response, triggers the trap state, and sees a targeted inline feedback popup labeled `AI-generated`.
  - Author keeps using the original DOT activation-point behavior for other trap states without changing those rules.

## 5. UX / UI Requirements
- Key Screens / States:
  - Advanced Author Rules Editor action menu and action editor for trap states.
  - Adaptive delivery feedback popup rendered by the existing `FeedbackContainer` / `FeedbackRenderer` path.
- Navigation & Entry Points:
  - Author adds the action from the trap-state `+` menu in the Rules Editor.
  - Learner receives the generated message in the standard popup after submitting a response that matches the rule.
- Accessibility:
  - The new authoring control must match current trap-state action patterns and remain keyboard-operable.
  - The learner-visible `AI-generated` attribution must be readable by assistive technology.
- Internationalization:
  - New labels should remain translation-ready and avoid hard-coding presentation-specific punctuation into the data model.
- Screenshots / Mocks:
  - Use the Jira Figma link and the notes in `MER-4961.md` as the visual reference.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale:
  - At most one synchronous LLM feedback generation should run per learner submission in MVP.
  - The submit/evaluate path must remain deterministic even when generation is skipped or fails.
- Reliability:
  - Unsupported responses, missing context, missing feature configuration, or provider failures must fail closed and must not break the rest of rule evaluation.
  - Existing non-LLM trap-state actions in the same evaluation must continue to behave normally when LLM feedback cannot be produced.
- Security & Privacy:
  - The server must build the generation request from server-resolved rule data and delivery context, not from client-tamperable prompt text.
  - Raw learner text and screen content must not be emitted in logs or telemetry payloads.
- Accessibility:
  - Learner attribution must be visible and announced in the same popup flow already used for static feedback.
- Observability:
  - Generated-feedback requests should be distinguishable from DOT chat requests in telemetry and error reporting.

## 9. Data, Interfaces & Dependencies
- Data model:
  - Adaptive rule JSON extends trap-state activation points with `params.kind`, where `kind: "feedback"` means inline generated feedback and `kind: "dot"` or `nil` preserves existing behavior.
  - Generated feedback is returned as a normal `feedback` action carrying a standard feedback model plus AI attribution metadata in `feedback.custom`.
- Interfaces:
  - Reuse `PUT /api/v1/state/course/:section_slug/activity_attempt/:guid`.
  - Reuse `Oli.Conversation.AdaptivePageContextBuilder.build/3` for adaptive screen context.
  - Reuse `Oli.GenAI.FeatureConfig.load_for(section.id, :student_dialogue)` and `Oli.GenAI.Execution.generate/5`.
- Dependencies:
  - Hard dependency on `MER-4946` trap-state activation-point support.
  - Functional dependency on `MER-4944` adaptive context availability for richer generation context.
- Database / migrations:
  - No new tables or migrations are expected.

## 10. Repository & Platform Considerations
- Authoring work lives in the adaptive Rules Editor and authoring app bootstrap/store state.
- Delivery orchestration belongs in the existing attempt submit path rather than a new endpoint.
- The generation helper should live in a non-UI backend module under `lib/oli/conversation/`.
- Scoped feature rollout should use the existing `Oli.ScopedFeatureFlags` infrastructure instead of ad hoc environment checks.

## 11. Feature Flagging, Rollout & Migration
- Add scoped feature `llm_feedback` to the defined feature list with `[:authoring, :delivery]` scope.
- Authoring exposure requires:
  - project-level `llm_feedback` enabled
  - existing adaptive trigger capability enabled
- Delivery transformation requires:
  - section-level `llm_feedback` enabled
  - section `assistant_enabled == true`
  - section `triggers_enabled == true`
- No data migration is required.

## 12. Telemetry & Success Metrics
- Emit dedicated telemetry for:
  - LLM feedback request start / stop
  - success / failure outcome
  - latency
  - rollout stage
- Success indicators:
  - Authors can configure the action only in supported contexts.
  - Learners receive inline generated feedback without opening DOT.
  - Generated feedback carries visible AI attribution.
  - Existing trap-state DOT activation keeps working for non-feedback actions.

## 13. Risks & Mitigations
- Synchronous generation could slow the submit path.
  - Mitigation: limit MVP to the first matching LLM-feedback action per submission and reuse existing routing / breaker controls.
- Generated feedback could lose attribution if metadata is attached at the wrong layer.
  - Mitigation: carry attribution on the feedback model that already reaches the popup renderer.
- Authoring could expose the action on unsupported screens.
  - Mitigation: gate by supported part types and fail closed again on the server.
- Generation failures could block normal trap-state behavior.
  - Mitigation: drop only the generated-feedback transform and preserve the rest of the evaluated actions.

## 14. Open Questions & Assumptions
- Assumptions:
  - When multiple supported text-entry responses are submitted together, MVP concatenates them into a single normalized learner-response block for the generation request.
  - Preview mode remains unchanged and does not attempt synchronous GenAI generation in this ticket.
  - The learner-facing label is a compact `AI-generated` attribution rendered in the popup chrome, not mixed into the generated prose itself.
- Open Questions:
  - Should the authoring affordance remain a dedicated `AI-Generated Feedback` action long-term, or eventually fold into the existing `Show Feedback` editor as an alternate mode?
  - Do we want a configurable fallback learner message when generation fails, or should MVP simply omit generated feedback?

## 15. QA Plan
- Automated:
  - Jest coverage for Rules Editor visibility, persistence, and preview-safe behavior.
  - Jest or React testing coverage for feedback attribution rendering.
  - ExUnit coverage for generation request construction, controller-side action transformation, feature-flag gating, and failure handling.
  - Regression coverage confirming non-feedback trap-state activation still uses the current DOT path.
- Manual:
  - Verify the action is hidden when project rollout is off or no supported text-entry part exists.
  - Verify a learner submission on a flagged section produces inline feedback with `AI-generated` attribution.
  - Verify unsupported input types do not generate feedback.
  - Verify section AI disabled or feature flag disabled causes no generated feedback.

## 16. Definition of Done
- [ ] `requirements.yml` exists and matches the PRD scope.
- [ ] PRD, FDD, and plan are present and aligned.
- [ ] Rollout and gating behavior are specified for both authoring and delivery.
- [ ] Verification approach covers authoring, backend generation, popup rendering, and compatibility with legacy DOT trap-state actions.

## Decision Log

### 2026-03-31 - Initial feature-pack authoring for MER-4961
- Change: Added the missing PRD for `llm_feedback` using Jira, `informal.md`, and `MER-4961.md` as the source pack.
- Reason: The work item was classified as a feature in the adaptive-page AI lane but did not yet have the standard feature artifacts.
- Evidence: `docs/exec-plans/current/epics/adaptive_page_improvements/llm_feedback/informal.md`, `MER-4961.md`, Jira `MER-4961`
- Impact: Establishes the product scope and rollout contract for FDD, plan, and requirements work.
