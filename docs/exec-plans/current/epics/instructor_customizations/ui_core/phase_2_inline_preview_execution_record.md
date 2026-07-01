# Phase 2 Inline Preview Execution Record

Work item: `docs/exec-plans/current/epics/instructor_customizations/ui_core`
Scope: Inline Activity Bank Selection preview bridge, first functional React preview, and basic whole-selection remove/restore vertical slice.

## Decision Update

- The earlier LiveView-owned separate selection preview route approach was discarded.
- MER-5620 does not need a new LiveView or route.
- The existing `PreviewLessonLive` remains the owning LiveView.
- The separate `/sections/:section_slug/preview/page/:revision_slug/selection/:selection_id` candidate-listing route remains controller-owned and out of scope for this ticket.
- Inline Activity Bank Selection preview now follows the preview-component pattern by emitting a React custom element from the content renderer.
- Activity Bank Selection is not registered as an activity manifest. Its custom element is bundled through the generic `instructor_preview_components.js` entry.

## Implementation Blocks

- [x] Inline render bridge
  - Added `OliWeb.Delivery.Instructor.ActivityBankSelectionPreview` as a server-side adapter.
  - Extended `Oli.Rendering.Context` with generic `instructor_preview_context` payload storage.
  - Updated `PreviewPageContext` to build selection preview payloads during instructor preview context construction.
  - Updated `Oli.Rendering.Content.Html.selection/3` to use the new custom element only for `:instructor_preview`.
- [x] React preview component
  - Added `assets/src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx`.
  - Added `preview-entry.tsx` to register `oli-activity-bank-selection-preview`.
  - Added generic webpack entry `instructor_preview_components`.
- [x] Sample activity preview
  - Selection candidates are resolved server-side with existing bank-selection logic.
  - The component receives a limit-1 sample activity payload.
  - React renders the sample by mounting the existing activity preview custom element.
- [x] Whole-selection event wiring
  - Added `bank_selection` handling to `PreviewLessonLive`.
  - Dispatches to `InstructorCustomizations.exclude_bank_selection/4` and `restore_bank_selection/4`.
  - Replies with local UI state updates for actions, removed visual state, status pill, and available count.
- [x] Legacy route preservation
  - The previous controller/template candidate-listing route remains unchanged.
  - No Activity Bank Selection preview LiveView was added.

## Verification

- [x] `mix format lib/oli/rendering/context.ex lib/oli/rendering/content/html.ex lib/oli/delivery/instructor_customizations.ex lib/oli_web/delivery/instructor/preview_page_context.ex lib/oli_web/delivery/instructor/activity_bank_selection_preview.ex lib/oli_web/live/delivery/instructor/preview_lesson_live.ex test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
- [x] `cd assets && ./node_modules/.bin/prettier --write src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx src/components/instructor_preview/activity_bank_selection_preview/preview-entry.tsx src/apps/InstructorPreviewComponents.tsx webpack.config.js`
- [x] `mix test test/oli_web/live/delivery/instructor/preview_lesson_live_test.exs test/oli/delivery/instructor_customizations/write_api_test.exs`
- [x] `cd assets && ./node_modules/.bin/eslint src/components/instructor_preview/activity_bank_selection_preview/ActivityBankSelectionPreview.tsx src/components/instructor_preview/activity_bank_selection_preview/preview-entry.tsx src/apps/InstructorPreviewComponents.tsx webpack.config.js`
- [x] `mix compile`

## Notes

- `cd assets && ./node_modules/.bin/tsc --noEmit --skipLibCheck` was attempted and failed on an existing missing `vm2` type/module resolution in `src/eval_engine/evaluator.ts`, not on the new preview files.
- Figma MCP access failed with OAuth authorization required, so visual comparison against the Figma node still needs human/browser verification.
- A repo-level `yarn format --write ...` attempt expanded to the repository's global prettier command and touched unrelated files; those accidental formatter-only changes were reverted, leaving only scoped files.

## Remaining Work

- Add warning confirmation for existing attempts/visits.
- Add fuller restore/error reply tests for bank selection events.
- Run browser/Figma visual QA and UI refinement against the Figma node once the Figma and Browser MCP contexts are available.
