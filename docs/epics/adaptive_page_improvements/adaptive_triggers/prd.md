# Adaptive Triggers - PRD

## 1. Overview
Feature Name: `adaptive_triggers`

Summary: Add screen-level AI activation points to adaptive pages and extend adaptive images and navigation buttons so they can optionally invoke DOT on click. The feature is gated by the existing project trigger capability in authoring and reuses the existing client-side trigger API and section-level assistant availability in delivery.

Links:
- `docs/epics/adaptive_page_improvements/adaptive_triggers/informal.md`
- `docs/epics/adaptive_page_improvements/overview.md`
- `docs/epics/adaptive_page_improvements/plan.md`
- Jira ticket `MER-4945`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - Adaptive pages had no screen-level AI activation point equivalent to basic-page page and paragraph triggers.
  - Adaptive images and navigation buttons could not emit AI activation events even when an author wanted DOT entry points inside a screen flow.
  - Adaptive delivery already had section/resource context and the trigger client API, but no adaptive part-level bridge into that API.
- Affected users/roles:
  - Adaptive authors configuring screen-level support moments.
  - Learners interacting with adaptive screens that need contextual DOT entry points.
- Why now:
  - `MER-4945` is the first adaptive trigger expansion item in the AI lane.
  - Darren Siegel's Jira guidance broadened scope beyond a new component to include clickable image/button activation parity.

## 3. Goals & Non-Goals
- Goals:
  - Add a new adaptive part called `AI Activation Point`.
  - Support `auto` and `click` launch modes plus author-defined prompt text.
  - Allow adaptive `janus-image` and `janus-navigation-button` parts to emit AI activation when explicitly enabled.
  - Gate authoring visibility through the existing project trigger capability.
  - Reuse the existing trigger invoke API and backend conversation trigger plumbing.
- Non-Goals:
  - No new section-level AI enablement controls.
  - No new server-side trigger endpoint or storage model.
  - No support for non-image/non-navigation-button adaptive parts in this ticket.
  - No trap-state trigger behavior; that remains in `MER-4946`.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Course authors editing adaptive screens.
  - Learners consuming adaptive lesson screens in section delivery.
- Use Cases:
  - Author adds a standalone AI activation icon to a screen and configures it to auto-open DOT.
  - Author adds a clickable AI activation point that learners can invoke on demand.
  - Author enables AI activation on an adaptive image or navigation button and supplies a prompt.
  - Learner clicks an AI-enabled image or button and receives a DOT experience without losing the original button submit behavior.

## 5. UX / UI Requirements
- Key Screens/States:
  - Adaptive screen component toolbar and property editor for the new `AI Activation Point` part.
  - Adaptive image property editor with `Enable AI Activation Point` and `AI Activation Prompt`.
  - Adaptive navigation button property editor with the same AI activation fields.
  - Delivery rendering for a standalone AI icon/button in click mode and silent trigger scheduling in auto mode.
- Navigation & Entry Points:
  - Component insertion from adaptive screen authoring.
  - Existing image and navigation button part configuration flows.
  - Learner click interactions inside adaptive delivery.
- Accessibility:
  - Click-mode activation must render a keyboard-operable control with an accessible label.
  - AI-enabled images must become keyboard-invokable when they act as triggers.
- Internationalization:
  - New labels follow current static authoring patterns and should remain translation-ready.
- Screenshots/Mocks:
  - Reference the Jira/Figma materials linked from `informal.md`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale:
  - No dedicated performance/load/benchmark scope is added.
  - Trigger invocation should remain an O(1) client-side call using already available section and resource context.
- Reliability:
  - Missing prompts or missing trigger context must fail closed and avoid emitting malformed trigger requests.
  - Existing adaptive image and navigation button behavior must continue when AI activation is disabled.
- Security & Privacy:
  - Delivery continues to rely on existing section-level assistant availability and trigger authorization behavior.
  - No additional learner data is persisted by this feature.
- Compliance:
  - Clickable activation controls must remain keyboard accessible.
- Observability:
  - Backend conversation trigger descriptions must recognize adaptive trigger types for downstream prompt context and diagnostics.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - No database migration is required.
  - Adaptive part JSON gains new fields:
    - `janus-ai-trigger`: `launchMode`, `prompt`, `ariaLabel`, `customCssClass`
    - `janus-image`: `enableAiTrigger`, `aiTriggerPrompt`
    - `janus-navigation-button`: `enableAiTrigger`, `aiTriggerPrompt`
- Context Boundaries:
  - Adaptive authoring runtime controls part availability through `optionalContentTypes.triggers`.
  - Adaptive delivery passes `sectionSlug` and `resourceId` into part rendering so parts can invoke triggers.
  - Backend conversation trigger descriptions accept new trigger types without changing storage shape.
- APIs / Contracts:
  - Existing trigger client payload is reused with new `trigger_type` values:
    - `adaptive_page`
    - `adaptive_component`
  - Adaptive trigger payloads continue to send `resource_id`, `prompt`, and contextual `data`.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Author | Add/configure adaptive trigger part and image/button AI fields | Only when project trigger capability is enabled |
| Learner | Invoke adaptive trigger entry points in delivery | Subject to existing DOT availability |
| Admin | Same as author in authorized projects | No new role behavior |

## 10. Integrations & Platform Considerations
- LTI 1.3:
  - No new launch contract is introduced.
- GenAI (if applicable):
  - DOT invocation reuses the current adaptive/basis trigger infrastructure and conversation pipeline.
- External services:
  - None.
- Caching/Perf:
  - No new caching layer.
- Multi-tenancy:
  - Existing section/resource context and trigger API boundaries remain in force.

## 11. Feature Flagging, Rollout & Migration
No new feature flags are introduced in this feature.

Existing authoring capability gating is reused:
- Projects without trigger support do not expose the adaptive trigger part or related image/button AI fields.
- Delivery relies on the existing trigger instance availability path for section-level assistant enablement.

## 12. Analytics & Success Metrics
- KPIs:
  - Authors can place screen-level AI entry points in adaptive screens when triggers are enabled.
  - Click-mode and auto-mode adaptive triggers invoke DOT with the expected payload shape.
  - AI-enabled adaptive navigation buttons preserve original submit behavior while also invoking DOT.
- Events / Operational Signals:
  - Existing trigger invocation flow now includes `adaptive_page` and `adaptive_component` trigger types.

## 13. Risks & Mitigations
- Adaptive and basic trigger payloads could diverge.
  - Mitigation: centralize adaptive payload creation in a shared helper and reuse the existing trigger invoke API.
- Authoring availability could drift from project trigger capability.
  - Mitigation: gate the selector/store and toolbar visibility from the same `allowTriggers` source.
- Image/button trigger behavior could regress core interaction.
  - Mitigation: only emit AI triggers when explicitly enabled, and keep navigation button submit behavior intact.

## 14. Open Questions & Assumptions
- Assumptions:
  - Existing trigger instance availability already reflects section-level assistant enablement, so adaptive parts can rely on that gate instead of introducing a second delivery-specific flag.
  - The new adaptive trigger part should visually align with current DOT iconography rather than introducing a new visual system.
- Open Questions:
  - Should additional adaptive parts gain the same optional AI activation fields in later work?
  - Should the auto-trigger delay remain fixed or become configurable in follow-on work?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Shared adaptive trigger payload helper and screen-level part added.
- Milestone 2: Image and navigation button AI activation extensions shipped.
- Milestone 3: Backend trigger descriptions and targeted verification completed.

## 16. QA Plan
- Automated:
  - Jest tests for click-mode and auto-mode AI trigger part delivery.
  - Jest tests for image and navigation button trigger behavior.
  - Jest test for authoring trigger-part availability gating.
  - ExUnit tests for backend adaptive trigger descriptions.
- Performance Validation:
  - Confirm no new hot path beyond existing trigger invoke calls.
- Manual:
  - Verify the adaptive toolbar shows `AI Activation Point` only when project triggers are enabled.
  - Verify image/button AI fields appear only when trigger capability is enabled.
  - Verify click-mode accessibility behavior and auto-mode trigger launch timing in adaptive delivery.

## 17. Definition of Done
- [ ] `requirements.yml` exists and aligns with the feature pack.
- [ ] PRD/FDD/plan validate successfully.
- [ ] Adaptive trigger authoring and delivery behavior are documented in sync with implementation.
- [ ] Targeted backend and frontend verification are recorded.

## Decision Log

### 2026-03-10 - Initial sync to implemented adaptive trigger behavior
- Change: Added the missing PRD for `MER-4945` covering the adaptive trigger part, image/button extensions, existing capability gating, and reused trigger API.
- Reason: The code was implemented before the feature pack existed, so the authored scope needed to match the actual delivered behavior rather than only the informal ticket summary.
- Evidence: `assets/src/components/parts/janus-ai-trigger/*`, `assets/src/components/parts/aiTrigger.ts`, `assets/src/components/parts/janus-image/*`, `assets/src/components/parts/janus-navigation-button/*`, `lib/oli/conversation/triggers.ex`
- Impact: Establishes the authoritative scope and AC source for FDD/plan/requirements traceability.
