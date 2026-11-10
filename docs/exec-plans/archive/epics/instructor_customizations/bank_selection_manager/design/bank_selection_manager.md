# UI Implementation Brief

## Design Sources

- Primary source:
  - `MER-5622` Figma manager view `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-7391`
- Supporting sources:
  - warning modal `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-15926`
  - `docs/exec-plans/current/epics/instructor_customizations/overview.md`
  - `docs/exec-plans/current/epics/instructor_customizations/plan.md`
  - `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`
  - existing preview question brief `docs/exec-plans/current/epics/instructor_customizations/preview_components/design/preview_question_ui.md`
- Jira references:
  - `MER-5622`
- Figma node ids / links:
  - manager surface `185:7391`
  - invalid-removal modal `185:15926`

## Implementation Surface

- Surface: `liveview/heex`
- Target user flow:
  - preview-authorized instructor/admin opens a standalone management route for one activity bank selection, reviews candidate questions, previews the selected candidate, and removes or restores candidates for that selection.
- Responsive considerations:
  - Figma is desktop-first and split-panel.
  - First-pass implementation should preserve the two-column desktop layout and stack gracefully on smaller widths rather than inventing new interaction patterns.
- Interaction/state considerations:
  - global Instructor View header remains the origin-return action
  - local back returns to the preview page location/anchor
  - one selected row drives the right preview panel
  - the right preview panel is the primary `Remove` / `Restore` action surface in this work item
  - removed rows show muted state plus `Removed` pill
  - invalid removals open a modal instead of persisting

## Design System Alignment

- Shared vs local decision:
  - `keep feature-local`
- Rationale:
  - the surface is a preview-specific workflow composition, not a cross-feature primitive.
  - it should reuse existing shared shell, header, modal, button, and icon patterns where they already fit, but the manager layout itself should remain local to the instructor preview workflow.
- Existing design-system references consulted:
  - delivery shell/header in `lib/oli_web/components/delivery/layouts.ex`
  - modal component in `lib/oli_web/components/modal.ex`
  - Torus button and icon semantics via existing HEEx components and `lib/oli_web/icons.ex`

## Token Mapping

- Background / surface:
  - keep the existing preview shell surfaces and white panel surfaces already used in Instructor View
- Text:
  - use existing heading/high-emphasis tokens for title and count
  - use muted text tokens for selection metadata and secondary table text
- Border / divider:
  - use existing neutral border tokens for split panels, row separators, and modal borders
- Fill / accent:
  - reuse preview/instructor accent treatment already established by the Instructor View shell
  - use the existing primary action blue token family for actionable buttons/links
- Icon:
  - reuse existing back/chevron/trash-capable iconography from `OliWeb.Icons`
- Spacing / layout:
  - favor tokenized spacing utilities already used in preview and delivery LiveViews before introducing arbitrary values
- Typography:
  - stay aligned with existing preview shell typography rather than hardcoding Figma font values
- Token gaps requiring approval:
  - none identified for the initial spec

## Icon Mapping

- Existing icons to reuse:
  - back arrow from the preview shell
  - chevron/down caret for expandable affordances where needed
  - trash/remove icon from the existing HEEx icon layer if the surface keeps the iconized button treatment from Figma
- Icons that need extension:
  - none currently
- Notes on surface-specific icon implementation:
  - because this surface is LiveView/HEEx, prefer `OliWeb.Icons` over React-side icon modules

## Component Reuse Plan

- Existing components/patterns to reuse:
  - `Layouts.instructor_preview_header/1`
  - shared delivery header from `lib/oli_web/components/delivery/layouts.ex`
  - shared modal component from `lib/oli_web/components/modal.ex`
  - existing preview-render hydration path via `RenderedActivity.render/1` and current hooks
- Components to extend:
  - `PreviewRoutes` for the new selection-manager path helper
  - preview-session routing under the existing instructor preview live session
- Interaction-contract guidance:
  - React preview components embedded in LiveView should stay presentational.
  - This work should reuse the preview action integration established by the prior embedded-activity preview implementation rather than redefining hook/reply/local-state mechanics here.
  - For this manager surface, the relevant target kind is `bank_candidate` for candidate-row `Remove` / `Restore`.
  - LiveView remains the source of truth for whether a candidate is enabled or removed.
  - The left list should reflect that state and drive selection, but bulk or multi-select mutation controls belong to later work.
- Proposed extractions:
  - none beyond small feature-local helpers or components near the new LiveView if the template becomes too dense
- States that must be supported:
  - default loaded state with one selected candidate
  - removed row state
  - incremental appended row state
  - invalid-removal warning modal
  - whole-bank removal success followed by redirect back to the originating preview page context
  - success-flash state after mutation

## File Targets

- Primary implementation files:
  - `lib/oli_web/live/delivery/instructor/bank_selection_manager_live.ex`
  - `lib/oli_web/delivery/instructor/preview_routes.ex`
  - `lib/oli_web/router.ex`
- Shared component targets:
  - reuse existing layout/modal components instead of creating new shared primitives
- Feature-local component targets:
  - optional helper/presenter near `lib/oli_web/live/delivery/instructor/`
  - targeted tests under `test/oli_web/live/delivery/instructor/`
- Styling/token touch points:
  - existing preview/delivery HEEx utility patterns

## Preview Target Usage

- This work assumes the preceding preview-page PR already establishes the shared React <-> LiveView action pipeline.
- The manager implementation should only extend that existing model with the target kinds relevant to this surface:
  - `bank_candidate` for candidate-row `Remove` / `Restore`
- In this work item, the action originates from the right-hand preview rather than from a bulk-action control in the left list.

## Open Questions / Requires Approval

- Unmapped colors or tokens:
  - none blocking
- Missing design states:
  - no explicit mobile variant is shown in the provided Figma nodes
- Ambiguous interactions:
  - confirm whether attempts-started warning integration is in-scope here or an inbound shared-warning dependency
- Reuse/extraction decisions needing confirmation:
  - none beyond keeping the manager surface feature-local
- Anything else that should be confirmed before coding:
  - none beyond the shared attempts-started warning decision
