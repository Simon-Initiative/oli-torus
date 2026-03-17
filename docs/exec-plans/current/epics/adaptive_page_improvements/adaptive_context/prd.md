# Adaptive Context - Product Requirements Document

## 1. Overview
MER-4944 (`adaptive_context`) adds adaptive-page-aware context retrieval for DOT in student delivery. When DOT is available on an adaptive page, it must be able to retrieve the learner's current screen, visited-screen history, page content, and progress state so responses stay relevant without leaking unseen material.

## 2. Background & Problem Statement
- DOT currently lacks adaptive-page-specific context and therefore cannot reliably answer based on the learner's current screen or branching path.
- Adaptive pages are not always linear lessons, so authored screen order is not sufficient to determine what a learner has actually seen.
- The product risk is safety as much as usefulness: if DOT cannot distinguish visited from unvisited screens, it may reveal content or answers before the learner reaches them.
- This work item sits in the adaptive-page AI lane after page-level DOT enablement and adaptive activation plumbing, and before follow-on AI experiences that depend on richer adaptive context.

## 3. Goals & Non-Goals
### Goals
- Give DOT a retrievable adaptive-page context that is grounded in the learner's actual visit history, not assumed lesson order.
- Make the current screen and prior visited screens available to DOT together with relevant student response state.
- Preserve the boundary between visited and unvisited adaptive content so DOT does not reveal information the learner has not yet encountered.
- Reuse existing DOT visibility and section/page AI enablement rules rather than inventing a separate adaptive-only toggle.

### Non-Goals
- Redesigning the DOT UI, chat flow, or general answer-safety policy outside adaptive context inputs.
- Adding new author-facing controls for this feature beyond existing AI enablement and adaptive trigger work.
- Extending this feature to author preview, instructor insights, analytics, or debugger workflows.
- Reworking non-adaptive page context handling.

## 4. Users & Use Cases
- Student in adaptive lesson delivery: asks DOT for help and receives guidance that reflects the current screen, prior visited screens, and current progress only.
- System administrator or section operator: enables or disables AI using existing controls and expects DOT to appear only in supported delivery contexts.
- Course author or curriculum administrator: relies on adaptive pages to provide context-aware DOT behavior during student delivery without adding extra authoring steps in this story.

## 5. UX / UI Requirements
- DOT continues to use the existing student-facing entry point; this item does not add a new chat surface or authoring UI.
- DOT is visible only when existing AI enablement allows it and the adaptive page is rendered inside Torus navigation; otherwise DOT is not shown.
- Adaptive context retrieval is internal to DOT and should improve relevance without exposing raw context dumps to learners during normal use.
- When learners ask for help on adaptive pages, responses should prioritize the current screen and already visited screens and avoid implying progress on unseen screens.
- If adaptive context cannot be built, DOT must fail safely using existing fallback or error behavior rather than inventing context.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: adaptive context lookup must tolerate missing or partial attempt data without crashing the DOT dialogue session.
- Security and privacy: adaptive context must remain scoped to the current learner, section, and page attempt; telemetry and logs must not contain raw student answers or cross-learner context payloads.
- Performance: context construction must preload needed attempts and revisions in bounded queries so DOT interaction does not incur avoidable per-screen fetch loops or obvious latency regressions.
- Accessibility: existing DOT visibility, focus, and keyboard behavior must remain unchanged because this item introduces no new student controls.

## 9. Data, Interfaces & Dependencies
- A new DOT tool/function call is exposed only for supported adaptive-page delivery contexts.
- Tool input is the lesson activity attempt GUID for the learner's current adaptive screen attempt.
- Tool output is markdown that narrates visited screens in actual visit order, identifies the current screen, and includes screen content plus relevant student response state.
- The builder depends on resolving the current activity attempt to the corresponding page attempt, then loading related activity attempts and their revisions for that page attempt.
- No new persistence model is expected; the feature should reuse existing attempt history, activity revision, section, and DOT configuration data.
- This work item depends on existing DOT visibility rules, adaptive delivery attempt tracking, and GenAI tool-registration infrastructure already present in the platform.

## 10. Repository & Platform Considerations
- The adaptive page context builder should live in a non-UI backend module so LiveView and React surfaces only pass context identifiers and do not own domain lookup logic.
- Existing delivery attempt helpers and GenAI dialogue/tool-broker boundaries should be reused rather than introducing a parallel adaptive-specific chat pipeline.
- The implementation must respect section, institution, and learner scoping that already governs delivery attempts and GenAI feature selection.
- Primary verification should be targeted ExUnit and delivery integration coverage around lookup, formatting, gating, and safe failure paths.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit telemetry for adaptive context tool availability, invocation, success, failure, and latency without including raw screen content or student answers.
- Track success rate for adaptive context builds in supported delivery contexts.
- Track p95 context-build latency relative to the existing DOT send/open path.
- Use QA and post-release observation to confirm DOT does not reference unseen adaptive screens in supported flows.

## 13. Risks & Mitigations
- Wrong content ordering on branching pages: derive the narrative from actual visit history, not authored screen order.
- Large adaptive pages causing slow context builds: preload attempts and revisions in bulk and use predictable summarization or truncation if payload size becomes excessive.
- Leakage of unseen content or answers: explicitly separate visited from unvisited scope and rely on existing DOT answer-safety behavior in addition to context shaping.
- Unsupported delivery contexts causing confusing behavior: keep DOT hidden when prerequisites are not met and emit telemetry for failure analysis.

## 14. Open Questions & Assumptions
### Open Questions
- Should revisiting the same adaptive screen produce repeated narrative entries, or should the builder collapse revisits and summarize them?
- How should "not yet visited" be represented when the adaptive page contains future branch options that may never become reachable?
- Do we need explicit truncation or redaction rules when visited screens contain large student responses?

### Assumptions
- The current adaptive screen can be identified from a lesson activity attempt GUID emitted by the delivery runtime.
- Existing DOT policies for hiding unsupported experiences and refusing direct answer-giving remain in force and are not redefined by this work item.
- Current activity revision content plus latest activity and part attempts are sufficient to build useful adaptive context without new storage tables.
- This feature applies to student delivery, not author preview or instructor-facing experiences.

## 15. QA Plan
- Automated validation:
  - ExUnit coverage for activity-attempt-to-page-attempt lookup, visit-order reconstruction, markdown rendering, response inclusion, and safe failure handling.
  - GenAI/tool registration tests confirming the adaptive context tool is offered only in supported adaptive delivery sessions.
  - Delivery integration or LiveView coverage confirming DOT remains hidden when AI is disabled or the adaptive page is outside Torus navigation.
  - Telemetry tests confirming success and failure events emit without raw student answer payloads.
- Manual validation:
  - Walk a branching adaptive page as a student and verify DOT reflects the current screen and previously visited screens.
  - Prompt DOT for answers or unseen content and confirm it does not reveal exercises or future-screen information.
  - Verify DOT is hidden when AI is disabled or when the adaptive page is not rendered in the supported Torus navigation shell.
  - Revisit a screen and confirm context behavior matches the intended visit-history representation.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
