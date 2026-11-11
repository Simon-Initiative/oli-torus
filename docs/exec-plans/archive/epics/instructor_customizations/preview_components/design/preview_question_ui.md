# UI Implementation Brief

## Design Sources

- Primary source:
  - Feature-level Figma file for `MER-5618`: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments`
- Supporting sources:
  - Scope clarification and architectural notes in `docs/exec-plans/current/epics/instructor_customizations/preview_components/informal.md`
  - Torus design-system Figma references for buttons, icons, colors, spacing, and typography from `.agents/skills/implement_ui/references/design_system_sources.md`
  - Epic scope and lane split from `docs/exec-plans/current/epics/instructor_customizations/overview.md`
  - Product scope and activity-specific references from `docs/exec-plans/current/epics/instructor_customizations/preview_components/prd.md`
- Jira references:
  - `MER-5618` Update Instructor View Question UI
  - related future tickets that constrain this slice boundary: `MER-5639`, `MER-5620`, `MER-5625`, `MER-5622`, `MER-5623`, `MER-5624`, `MER-5626`, `MER-5619`, `MER-5617`
- Figma node ids / links:
  - MCQ collapsed `344:26445`, expanded `344:26375`
  - CATA collapsed / expanded reference `344:26478`
  - Likert collapsed `372:7528`
  - Ordering collapsed `372:7271`, expanded `372:7274`
  - Image Hotspot expanded `344:23084`, collapsed inferred from that node
  - Directed Discussion collapsed `372:8430`, expanded `372:8431`
  - Multi Input dropdown collapsed `344:26243`, expanded `344:26144`
  - Multi Input numeric collapsed `335:11048`, expanded `335:11333`
  - Multi Input text collapsed `335:11807`, expanded `372:6190`

## Implementation Surface

- Surface: `mixed`
- Target user flow:
  - Instructor, author, or admin enters Instructor View for a basic page and sees supported activities rendered through the new preview mode rather than the current authoring-derived instructor preview.
  - The current preview path in `lib/oli_web/controllers/page_delivery_controller.ex` builds `ActivitySummary` values with `authoring_script` and `authoring_element`, and `lib/oli/rendering/activity/html.ex` renders those elements when `mode == :instructor_preview`.
  - `MER-5618` should replace that supported-activity path with first-class preview registration data instead of adding more `mode === "instructor_preview"` branches inside authoring components.
- Responsive considerations:
  - The provided Figma references are desktop-oriented card layouts.
  - The preview card and lower detail region should remain readable in narrower widths, but this ticket should not invent new breakpoint-specific behavior beyond sane stacking/wrapping.
  - Multi Input and Directed Discussion are the highest-risk layouts for overflow because their expanded states contain tabs and vertically dense detail content.
- Interaction/state considerations:
  - `MER-5618` implements collapsed and expanded question preview states, not functional remove/restore behavior.
  - Tabs inside expanded previews are read-only content switches, not authoring tabs.
  - Frontend types already reserve `preview` as a delivery-mode concept in `assets/src/components/activities/types.ts`; the new work should align server-to-client naming around that mode rather than perpetuating `instructor_preview` as the long-term UI contract.
  - Mixed pages must support supported activities using preview mode while unsupported activities remain on the legacy instructor-preview path.

## Design System Alignment

- Shared vs local decision:
  - `keep feature-local`
- Rationale:
  - The new preview card, detail region, answer-key panels, learning-objective row, and activity-specific preview compositions are tightly coupled to instructor activity preview and should stay near the activity system.
  - These are not generic cross-product primitives yet; extracting them to `design_tokens/` now would be premature and would mix domain-specific activity semantics into the shared primitive layer.
  - Existing shared button guidance is still relevant for future remove/restore work, but `MER-5618` itself should not implement that button behavior.
- Existing design-system references consulted:
  - Torus button primitives in `lib/oli_web/components/design_tokens/primitives/button.ex`
  - token policy in `docs/design_tokens.md`
  - icon module in `assets/src/components/misc/icons/Icons.tsx`
  - current activity preview rendering path in `lib/oli/rendering/activity/html.ex`

## Token Mapping

- Background / surface:
  - Preview cards use the existing white card surface with subtle border treatment matching the Figma cards.
  - Detail panels for feedback/readonly fields map to the light neutral input/surface token family already visible in existing Torus UI.
- Text:
  - Activity type metadata uses muted secondary text tokens.
  - Question title uses the stronger heading/high-emphasis text token.
  - Body, answer choice, participation labels, and feedback text use the standard body/high text tokens.
  - Learning objective labels use the existing uppercase low-emphasis micro-label treatment.
- Border / divider:
  - Card border, tab underline, readonly field border, and feedback panel border should map to existing neutral border tokens.
  - Do not hardcode one-off border values where token classes already exist.
- Fill / accent:
  - The accordion affordance and active tab underline use the primary action blue token family.
  - Selected radio/checkbox states inside answer-key views should reuse the existing primary interactive accent.
- Icon:
  - Chevron affordance can reuse the existing React `ChevronDown` icon.
  - Remove/trash icon treatment is future-facing for `MER-5620`; do not block `MER-5618` on introducing a new trash primitive.
- Spacing / layout:
  - The preview card uses a consistent padded vertical stack.
  - Choices, hotspot options, and ordering items use repeated list-item spacing that should become shared preview-local layout helpers rather than copied per activity.
- Typography:
  - Figma uses `Open Sans` and `Public Sans` treatments already common in the repo; map to the repo’s existing text utility classes and heading/body conventions instead of baking raw font values into each preview.
- Token gaps requiring approval:
  - None are required to start `MER-5618`.
  - If a future React shared primitive layer is introduced, button and tab styling may warrant a real React-side `design_tokens` home later, but that should not be coupled to this ticket.

## Icon Mapping

- Existing icons to reuse:
  - `ChevronDown` from `assets/src/components/misc/icons/Icons.tsx` for the details toggle.
  - `ClearIcon` from `assets/src/components/misc/icons/Icons.tsx` is the closest existing trash/remove treatment if later work needs a React-side starting point, but `MER-5618` should not introduce remove behavior just to satisfy Figma chrome.
  - Existing radio and checkbox visual treatments already present in the activity system should inform readonly answer-key rendering where practical.
- Icons that need extension:
  - None are required to land `MER-5618`.
- Notes on surface-specific icon implementation:
  - React preview components should use the React icon layer, not HEEx icons.
  - HEEx/LiveView button primitives are useful reference for semantics and token alignment, but not the rendering layer for these preview custom elements.

## Component Reuse Plan

- Existing components/patterns to reuse:
  - Existing stem and readonly content rendering patterns from delivery components where they can be reused without pulling learner-attempt or authoring-only context.
  - Existing readonly rendering logic for choices, hotspot labels, and part selection where it can be extracted away from `AuthoringElementProvider`.
  - Existing React icon components, especially `ChevronDown`.
  - Existing activity model parsing and activity-specific data structures inside each activity directory.
- Components to extend:
  - Activity manifest/type infrastructure to add `preview` metadata.
  - Activity registration/build pipeline to include preview element + preview script.
  - Rendering pipeline that currently selects `authoring_element` for `:instructor_preview`.
- Proposed extractions:
  - Create a preview-local shared library under `assets/src/components/activities/common/preview/` for:
    - `ActivityPreviewCard`
    - `PreviewHeader`
    - `PreviewDetailsToggle`
    - `PreviewTabs`
    - `PreviewPanel`
    - `LearningObjectiveList`
    - readonly feedback panels
  - Create `PreviewElement.ts` and `PreviewElementProvider.tsx` alongside the existing `AuthoringElement` / `DeliveryElement` base components.
  - Keep these extractions feature-local to the activities system rather than promoting them into `design_tokens/`.
- Existing components/patterns explicitly not recommended for reuse:
  - `assets/src/components/tabbed_navigation/Tabs.tsx`: bootstrap/nav-tab styling and authoring-era semantics do not match the Figma preview tabs.
  - authoring-only affordances such as `common/authoring/RemoveButton.tsx`, `HintsAuthoringConnected`, and authoring explanation editors: they couple preview rendering to authoring stores and labels that the new UI is meant to remove.
  - full delivery surfaces such as live directed-discussion thread views: the Figma preview is intentionally read-only and narrower than learner delivery.
- States that must be supported:
  - collapsed preview card
  - expanded preview card
  - tabbed detail states for activities that show `Answer Key`, `Hints`, `Explanation`
  - Directed Discussion-specific expanded tabs `Participation` and `Hints`
  - Multi Input expanded state that changes when the selected part/input type changes
  - unsupported-activity fallback state at the page level
  - design-gap handling for Likert expanded and inferred handling for Hotspot collapsed

## File Targets

- Primary implementation files:
  - `lib/oli_web/controllers/page_delivery_controller.ex`
  - `lib/oli/rendering/activity/html.ex`
  - `lib/oli/rendering/activity/activity_summary.ex`
  - `lib/oli/activities.ex`
  - `lib/oli/activities/activity_registration.ex`
  - `lib/oli_web/templates/page_delivery/instructor_page_preview.html.heex` or its equivalent template file if script injection needs to separate preview bundles from authoring bundles
  - `assets/webpack.config.js`
  - `assets/src/components/activities/types.ts`
- Shared component targets:
  - `assets/src/components/activities/PreviewElement.ts`
  - `assets/src/components/activities/PreviewElementProvider.tsx`
  - `assets/src/components/activities/common/preview/*`
- Feature-local component targets:
  - `assets/src/components/activities/multiple_choice/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/check_all_that_apply/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/multi_input/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/image_hotspot/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/likert/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/ordering/*Preview.tsx` + `preview-entry.ts`
  - `assets/src/components/activities/directed-discussion/*Preview.tsx` + `preview-entry.ts`
  - each corresponding `manifest.json`
- Styling/token touch points:
  - reuse existing tokenized utility classes in activity React surfaces first
  - do not extend `TabbedNavigation` from `assets/src/components/tabbed_navigation/Tabs.tsx` for this preview work; it is bootstrap/nav-tab oriented and semantically tied to the old authoring pattern
  - do not reuse `common/authoring/RemoveButton.tsx` for preview mode; it is authoring-context dependent and visually mismatched to the Figma remove affordance

## Preview Contract Implications

- The preview UI needs a stable v1 context even though `MER-5618` does not ship remove/restore.
- The context should carry:
  - rendering identity for the page and activity
  - shared display data such as title, points, and learning objectives
  - a neutral future-facing customization target for later tickets
- The context should not yet encode:
  - persisted enabled/disabled state transitions
  - attempt-impact warnings
  - selection/candidate management payloads
  - aggregated LO or points counters
- The design brief implication is that shared preview primitives should accept this context shape directly rather than inferring critical metadata from authoring stores.

## Open Questions / Requires Approval

- Unmapped colors or tokens:
  - no blocking token gaps identified for `MER-5618`
- Missing design states:
  - no final expanded design for Likert
  - no dedicated collapsed node for Image Hotspot; collapsed behavior is inferred from the expanded node plus the common preview pattern
  - CATA collapsed/expanded references currently point to the same node; implementation should follow Jira acceptance criteria for `View Details` vs `Hide Details` even if the design artifact remains mislabeled
- Ambiguous interactions:
  - for `MER-5618`, the remove button visible in several Figma nodes is presentational context only and must not become functional behavior in this slice
  - Multi Input part switching inside expanded preview must be treated as a first-class state change because the expanded content varies by input type
- Reuse/extraction decisions needing confirmation:
  - confirm the preview-local shared library should remain under `activities/common/preview/` and not become a React `design_tokens/` initiative in this ticket
  - confirm whether `previewcontext` should already carry `canCustomize` and a neutral `customizationTarget` in `MER-5618`, even though remove/restore behavior lands later
- Anything else that should be confirmed before coding:
  - final interpretation of Likert expanded should be resolved in `harness-architect` / FDD unless design provides a final node first
  - future `MER-5620` work should plan to align its remove button implementation to the Torus shared button semantics where practical, but that should not expand `MER-5618`
  - preview bundle naming should be finalized in `harness-architect` so webpack manifest expansion, activity registration, and page template script injection stay aligned
