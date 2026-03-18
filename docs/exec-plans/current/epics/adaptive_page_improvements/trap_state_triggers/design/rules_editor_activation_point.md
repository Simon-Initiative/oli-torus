# UI Implementation Brief

## Design Sources

- Primary source:
  - Jira/Figma links captured in `docs/exec-plans/current/epics/adaptive_page_improvements/trap_state_triggers/informal.md`
- Supporting sources:
  - `assets/src/components/editing/elements/trigger/TriggerEditor.tsx`
  - `assets/src/apps/page-editor/PageTriggerEditor.tsx`
  - `assets/src/apps/authoring/components/AdaptivityEditor/ActionFeedbackEditor.tsx`
  - `assets/src/apps/authoring/components/AdaptivityEditor/ActionMutateEditor.tsx`
- Jira references:
  - `MER-4946`
  - Jira comment dated February 13, 2026 from Darren Siegel
- Figma node ids / links:
  - Feature-level Figma links are present in Jira and `informal.md`
  - Direct Figma node inspection was not available in this environment, so the brief maps the requested UI to existing Torus surfaces and the ticket notes

## Implementation Surface

- Surface: `react`
- Target user flow:
  - Author opens an adaptive rule in Advanced Author, clicks the blue `+`, chooses `Activation Point`, enters a prompt, and keeps editing the rule inline.
- Responsive considerations:
  - The action editor must fit within the existing stacked rule action list and collapse naturally on narrower widths.
- Interaction/state considerations:
  - Reuse the existing inline action-card pattern rather than opening a new modal.
  - Prompt help/samples should mirror basic-page trigger editing.
  - Warning copy should appear near the conditions / activation area when a trap-state trigger action is present.

## Design System Alignment

- Shared vs local decision:
  - `keep feature-local`
- Rationale:
  - This is a rule-editor-specific composition, but it should reuse the shared prompt-help treatment and AI iconography already present in the repo.
- Existing design-system references consulted:
  - `TriggerPromptEditor`
  - `AIIcon`
  - existing React Bootstrap alert/card/input-group patterns in adaptive authoring

## Token Mapping

- Background / surface:
  - Reuse current white/light card surface used by adaptive action editors
- Text:
  - Existing body/heading text styles from adaptive authoring panels
- Border / divider:
  - Existing rounded border/card treatment from action editors; no new token
- Fill / accent:
  - Existing DOT accent blue from current trigger affordances
- Icon:
  - Reuse `AIIcon`
- Spacing / layout:
  - Reuse current rule-editor stacked action spacing (`mb-2`, existing card padding scale)
- Typography:
  - Reuse current authoring headings and helper-text styles
- Token gaps requiring approval:
  - None required for MVP if existing card/alert styles are reused

## Icon Mapping

- Existing icons to reuse:
  - `AIIcon`
  - existing delete/trash icon treatment from adaptive action editors
- Icons that need extension:
  - None
- Notes on surface-specific icon implementation:
  - Keep icon usage in the React icon components already used across authoring

## Component Reuse Plan

- Existing components/patterns to reuse:
  - `TriggerPromptEditor`
  - existing adaptive action card/delete affordances
  - React Bootstrap alert treatment for the best-practice warning
- Components to extend:
  - `AdaptivityEditor` action dropdown / renderer
- Proposed extractions:
  - None; this should stay local to adaptive rule editing
- States that must be supported:
  - empty prompt
  - persisted prompt
  - deletion
  - trigger capability disabled
  - best-practice warning visible when trap-state activation is present

## File Targets

- Primary implementation files:
  - `assets/src/apps/authoring/components/AdaptivityEditor/AdaptivityEditor.tsx`
  - `assets/src/apps/authoring/components/AdaptivityEditor/ActionTriggerEditor.tsx`
  - `assets/src/apps/authoring/types.ts`
- Shared component targets:
  - reuse only: `assets/src/components/editing/elements/trigger/TriggerEditor.tsx`
- Feature-local component targets:
  - `assets/src/apps/authoring/components/AdaptivityEditor/`
- Styling/token touch points:
  - none expected beyond existing Bootstrap/class utilities

## Open Questions / Requires Approval

- Unmapped colors or tokens:
  - None if existing surfaces are reused
- Missing design states:
  - The exact Figma treatment for the warning block and header text placement should be checked manually if pixel parity matters
- Ambiguous interactions:
  - The ticket says “when the UI opens”; this brief assumes an inline action card, not a separate modal
- Reuse/extraction decisions needing confirmation:
  - None for MVP
- Anything else that should be confirmed before coding:
  - If product wants the warning always visible even before a trigger action is added, that is a small follow-up UX adjustment
