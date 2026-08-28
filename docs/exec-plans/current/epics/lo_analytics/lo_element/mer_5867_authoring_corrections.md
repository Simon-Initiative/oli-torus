# MER-5867 Authoring Corrections

## Purpose

This document defines the first correction PR for MER-5867. It covers the authoring side of the Learning Objectives Summary / Introduction element that was originally delivered in PR #6745 for MER-5802, MER-5803, and MER-5804.

The goal is not to reimplement the feature from zero. The goal is to preserve the parts of PR #6745 that already work, then close the missing acceptance-criteria gaps called out by QA in MER-5867 and by the original Figma designs.

## Proposed PR

- PR name direction: `MER-5867 Authoring LO element corrections`
- Jira source tickets:
  - MER-5867: bugfix umbrella
  - MER-5802: Authoring Insert new element (LO intro & summary)
  - MER-5803: Authoring Insert LO Introduction
  - MER-5804: Authoring Insert LO Summary
- User surface: Authoring page editor
- Implementation surface: `react`
- Primary code area:
  - `assets/src/components/content/add_resource_content/`
  - `assets/src/components/resource/editors/`
  - `assets/src/data/content/`
  - `assets/test/components/resource/editors/`
  - `assets/test/data/content/`
- Secondary backend/code area when persistence or resolution behavior is involved:
  - `lib/oli/authoring/learning_objectives/page_element.ex`
  - `lib/oli/authoring/editing/page_editor.ex`
  - `test/oli/authoring/learning_objectives/page_element_test.exs`

## Source Of Truth

### Bugfix Source

MER-5867 is the QA correction ticket. Its checklist is messy and crosses authoring, student delivery, preview, DOT, dark mode, accessibility, and Figma fidelity.

For this PR, MER-5867 should be used as a double-check list after mapping back to MER-5802, MER-5803, and MER-5804.

### Original Authoring Tickets

MER-5802 defines the Insert menu behavior for the new Learning Objectives element.

MER-5803 defines authoring configuration for Learning Objective Introduction.

MER-5804 defines authoring configuration for Learning Objective Summary.

### Existing Feature Docs

Use these existing docs as context, but treat this document as the correction scope for this PR:

- `docs/exec-plans/current/epics/lo_analytics/lo_element/prd.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/fdd.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/plan.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/requirements.yml`

### Figma Sources

Primary feature-level Figma sources for this PR:

- Insert menu, only the `Objectives` option inside `Content Types`:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=342-4473&m=dev
- Complete LO Introduction authoring element:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=266-6913&m=dev
- LO Introduction authoring empty/warning state:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=266-8274&m=dev
- Complete LO Summary authoring element:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=267-6369&m=dev
- Removed LO row inside LO Summary authoring element:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=356-7784&m=dev

Supporting design-system Figma sources to consult during the UI brief:

- Icons:
  - https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-24
- Buttons:
  - https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=1007-140
- Colors:
  - https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=5-31
- Typography:
  - https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=2-22
- Spacing:
  - https://www.figma.com/design/4pTqLuqHbALAbZ31wvIHIX/NG-23---Torus-Design-System?node-id=476-3011

## MER-5867 Checklist Mapping

This table keeps all MER-5867 bullets visible, while marking what belongs in this Authoring PR.

| # | MER-5867 bullet | Authoring PR disposition |
|---|---|---|
| 1 | Missing separate `Recommended Review` element and `Show next steps` action | Out of scope. Student Summary behavior, handled in Delivery PR. |
| 2 | Strong proficiency still shows revisit/practice pages | Out of scope. Student Summary behavior, handled in Delivery PR. |
| 3 | DOT enabled but no explain card | Out of scope. Student Summary behavior, handled in Delivery PR. |
| 4 | Proficiency icons are not keyboard accessible | Mostly out of scope. If authoring renders the proficiency explanation icons, verify no authoring regression; primary fix in Delivery PR. |
| 5 | Plant icon for LO content type is a bullseye instead of plant | In scope. Insert menu and outline icon should match Figma. |
| 6 | New hover effect missing when hovering over content types | In scope. Insert menu hover/focus/selected behavior. |
| 7 | Garbage icons on LO component do not match Figma | In scope for authoring editor remove/restore controls. Student-side icon gaps are Delivery PR. |
| 8 | Four progression icons differ from Figma | Out of scope unless authoring preview/explanation uses them. Primary fix in Delivery PR. |
| 9 | LO Summary / Introduction description is missing | In scope for authoring element descriptions. Student-side summary intro/helper text is Delivery PR. |
| 10 | UI does not match Figma around removed LOs | In scope. Removed objective state in authoring editor. |
| 11 | Parent LO removal should cascade to sub-objectives but does not | In scope for authoring remove/restore behavior. Delivery visibility should be checked later. |
| 12 | Student page links throw 500 error | Out of scope. Delivery PR. |
| 13 | Author cannot preview the new LO content type | Out of scope unless root cause is authoring state. Likely Delivery PR because preview render context is server-side delivery-like rendering. |
| 14 | Dark mode compatibility issues for author and student | In scope for authoring. Student dark mode is Delivery PR. |
| 15 | False empty warning after adding LO type to a page that has LOs | In scope. Insert/load refresh behavior in authoring. |
| 16 | Author Summary parent and child LOs not numbered nor contained within same cell | In scope. Summary authoring hierarchy/table/cell layout. |
| 17 | Replace question marks with correct icons in student-facing display | Out of scope. Delivery PR. |
| 18 | `Sub-objective` text should not be present | In scope only if authoring Figma removes that label; primary known issue appears student-facing and belongs to Delivery PR. |

## Acceptance Criteria Digest

This section paraphrases the original Jira ACs for the authoring scope. Implementation should validate against the full Jira text and the Figma nodes above.

### MER-5802 - Insert Menu

Positive ACs:

- A new `Learning Objectives` element is available in the page editor Insert menu.
- The element uses the approved Figma icon and label.
- The element appears in the `Content Types` section only.
- Hovering over the element shows the description: `Render a learning objective introduction or summary.`
- Hover, focus, and selected states match Figma.
- Hover-description behavior is standardized across Insert menu content elements.
- Selecting the element inserts a new Learning Objectives component onto the current page.
- The inserted component can switch between Introduction and Summary via dropdown.

Negative ACs:

- Adding the element does not modify existing page content.
- Existing content types and question types keep existing behavior.
- The element is only available in `Content Types`.
- New hover behavior does not alter existing insert-menu functionality.

Accessibility:

- Insert menu items are keyboard accessible.
- Focus indicators are visible.
- The Learning Objectives item has an accessible name matching the visible label.
- Hover descriptions are also available to keyboard users via focus and should be announced where appropriate.

### MER-5803 - Authoring LO Introduction

Positive ACs:

- New Learning Objectives elements default to `Learning Objective Introduction`.
- A dropdown switches between `Learning Objective Introduction` and `Learning Objective Summary`.
- A description explains the purpose of the selected element.
- `Include Sub-Objectives` is shown and enabled by default.
- When `Include Sub-Objectives` is off, only parent LOs are shown.
- When `Include Sub-Objectives` is on, sub-objectives are shown under parent LOs.
- The element automatically displays LOs attached to activities or pages within the container where the element is placed.
- Parent LOs are always before sub-objectives.
- Sub-objectives are visually indented beneath parent LOs.
- Each LO has a Remove action.
- Remove puts the LO in a removed state without deleting it from the course.
- Removed LOs can be restored.
- Removing a parent LO also removes displayed sub-objectives from the introduction.
- A collapsible `What is proficiency and how is it estimated?` section is displayed.
- Expanding that section shows approved explanatory content.
- If no LOs exist in the selected container, a warning message is displayed.
- The warning says no LOs are attached to activities in the current container.

Negative ACs:

- Removing an LO from the introduction does not remove it from the course or tagged activities.
- `Include Sub-Objectives` only affects the current Learning Objectives element.
- Switching between Introduction and Summary does not modify LO data.
- The proficiency explanation is informational only and cannot be edited by authors.
- If no LOs exist, no empty LO cards are displayed.

Accessibility:

- Dropdown is keyboard accessible.
- Checkbox exposes checked state.
- Proficiency accordion is keyboard operable and exposes expanded/collapsed state.
- Warning messages are accessible status messages and not color-only.
- All interactive controls have visible focus indicators.

### MER-5804 - Authoring LO Summary

Positive ACs:

- Author can select `Learning Objective Summary` from the type dropdown.
- A description explains the purpose of the Summary element.
- `Include Sub-Objectives` is shown and enabled by default.
- Sub-objective include/exclude behavior matches Introduction.
- The element automatically displays LOs attached to activities or pages within the container.
- Parent-before-child hierarchy is preserved.
- Sub-objectives are visually indented.
- Each LO has Remove and Restore behavior matching Introduction.
- Removing a parent also removes displayed sub-objectives from the summary.
- Removing a sub-objective does not remove its parent.
- For each displayed LO, authors can associate one or more pages for students to revisit.
- Selected review pages render as removable chips.
- Authors can add review pages via `Add Page(s)`.
- Authors can remove selected review pages.
- Only pages in the current course can be selected.
- For each displayed LO, authors can associate practice opportunities related to the LO.
- Authors can add practice opportunities via `Add Practice`.
- Authors can remove selected practice opportunities.
- Only practice opportunities in the current course can be selected.
- Student guidance/helper text explains that students will see how proficiency aligns with LOs and receive recommended review/practice next steps.
- A collapsible `What is proficiency and how is it estimated?` section is shown below the element.
- Empty-state warning is displayed when no LOs exist in the container.

Negative ACs:

- Removing an LO from Summary does not remove it from the course or tagged activities.
- Adding review pages or practice opportunities does not tag those items to the LO.
- Only current-course pages/practice opportunities can be selected.
- Switching Introduction/Summary preserves shared configured settings where applicable.
- Proficiency explanation is informational and not editable.

Accessibility:

- Dropdown, checkbox, page selector, practice selector, chips, and accordion are keyboard accessible.
- Chips expose label and remove action.
- Focus indicators are visible.

## Current Implementation Notes

Known current files from PR #6745:

- Insert menu entry lives in `assets/src/components/content/add_resource_content/NonActivities.tsx`.
- Generic insert menu item lives in `assets/src/components/content/add_resource_content/ResourceChoice.tsx`.
- Authoring editor lives in `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`.
- Authoring styles live in `assets/src/components/resource/editors/LearningObjectivesEditor.scss`.
- Outline item currently comes from `LearningObjectivesOutlineItem` in `LearningObjectivesEditor.tsx`.
- Reconciliation helper lives in `assets/src/data/content/learningObjectives.ts`.
- Page editor refresh path lives in `assets/src/apps/page-editor/PageEditor.tsx`.

Known implementation gaps from earlier inspection:

- Insert/outline icon currently uses `bullseye`, not the Figma plant/tree icon.
- The editor has an `h3` label but appears to lack the Figma description text for Introduction/Summary.
- Existing remove/restore icon classes likely do not match Figma.
- Removed objective state exists but likely does not match Figma visual treatment.
- Parent removal cascade has delivery-side behavior in tests, but authoring state/UI needs explicit validation and likely correction.
- Adding the element inserts with an empty `learning_objectives` config first, then asynchronously refreshes; this likely causes the false no-LO warning until refresh.
- Summary authoring list currently renders parent and child as separate list items, so it may not satisfy the Figma requirement that parent/child are numbered and contained in the same cell.
- Existing `LearningObjectivesEditor.scss` uses local CSS variables/classes; dark mode should be audited against authoring theme variables.

## Proposed Correction Harness Process

Use this document as the PR-level correction plan. Before implementation:

1. Create a UI implementation brief for this Authoring PR using `implement_ui` / repo-local `ui_workflow`.
2. The brief must inspect the Figma nodes listed above.
3. The brief should classify the surface as `react`.
4. The brief should map:
   - plant/tree icon source;
   - insert menu hover/focus/selected states;
   - authoring card/panel surfaces;
   - warning state;
   - removed LO visual state;
   - remove/restore icon buttons;
   - dark mode token mapping;
   - Summary parent/sub-objective row layout.
5. After the brief is approved, use `harness-develop` slice by slice.
6. Commit after each completed, tested slice.

## Proposed Slices

### Slice A1 - Insert Menu Fidelity

Purpose:

- Align MER-5802 Insert menu behavior with Figma.

Likely work:

- Replace `bullseye` with approved plant/tree icon.
- Make sure `Objectives` appears only in `Content Types`.
- Match hover/focus/selected visual states.
- Ensure description appears on hover and focus.
- Ensure keyboard accessibility and visible focus.

Likely files:

- `assets/src/components/content/add_resource_content/NonActivities.tsx`
- `assets/src/components/content/add_resource_content/ResourceChoice.tsx`
- `assets/src/components/content/add_resource_content/AddResourceContent.modules.scss`
- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx` for outline icon if same icon is used there.

Validation:

- Jest test for hover/focus description.
- Jest test that root insert menu shows `Objectives` and nested insert menus do not.
- Manual Figma comparison against node `342-4473`.

### Slice A2 - Authoring Element Descriptions And Base Layout

Purpose:

- Align the main authoring element shell for Introduction and Summary with Figma.

Likely work:

- Add missing mode-specific description text.
- Match heading, dropdown, checkbox, spacing, panel structure, and warning placement.
- Preserve existing mode-switch behavior without dropping config.

Likely files:

- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`
- `assets/src/components/resource/editors/LearningObjectivesEditor.scss`

Validation:

- Jest assertions for Introduction description.
- Jest assertions for Summary description.
- Jest assertions for mode switching preserving `learning_objectives` config.
- Manual Figma comparison against nodes `266-6913`, `266-8274`, and `267-6369`.

### Slice A3 - Removed State And Remove / Restore Controls

Purpose:

- Make removed LOs match Figma and preserve non-destructive semantics.

Likely work:

- Replace current remove/restore icons with approved icons.
- Match removed row visual state from Figma.
- Ensure remove/restore has objective-specific accessible names.
- Confirm Remove only flips advisory `enabled`, without mutating course objectives or activity tags.

Likely files:

- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`
- `assets/src/components/resource/editors/LearningObjectivesEditor.scss`
- `assets/test/components/resource/editors/learning_objectives_editor_test.tsx`
- `assets/test/data/content/learningObjectives_test.ts`

Validation:

- Jest test for remove advisory state.
- Jest test for restore advisory state.
- Jest test for accessible names.
- Manual Figma comparison against node `356-7784`.

### Slice A4 - Parent / Sub-Objective Hierarchy And Cascading Remove

Purpose:

- Correct parent-child behavior and visual grouping in authoring.

Likely work:

- Ensure parent LOs and sub-objectives are displayed in a single grouped unit where Figma requires it.
- Add numbering for parent and child rows in Summary authoring if required by Figma.
- Remove `Sub-Objective` label text if the authoring design does not show it.
- Removing a parent should hide or mark its displayed sub-objectives consistently with the design.
- Removing a sub-objective should not remove its parent.
- Preserve underlying advisory config rows so restoring/toggling does not lose page recommendations.

Likely files:

- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`
- `assets/src/components/resource/editors/LearningObjectivesEditor.scss`
- `assets/test/components/resource/editors/learning_objectives_editor_test.tsx`

Validation:

- Jest test for parent removal cascade.
- Jest test for sub-objective removal not removing parent.
- Jest test for parent-before-child order.
- Manual Figma comparison against Summary and removed-row nodes.

### Slice A5 - False Empty Warning After Insert

Purpose:

- Fix the bug where adding an LO element to a page with LOs briefly or persistently shows the no-LO warning until refresh.

Likely work:

- Review insert flow in `NonActivities.tsx` and refresh path in `PageEditor.tsx`.
- Avoid rendering empty warning while async objective resolution is still pending.
- If existing `resourceContext.learningObjectives` already has data, initialize/reconcile the inserted content before or immediately after insertion.
- Preserve no-LO warning when resolution completes with an empty list.

Likely files:

- `assets/src/components/content/add_resource_content/NonActivities.tsx`
- `assets/src/apps/page-editor/PageEditor.tsx`
- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`
- `assets/test/components/resource/editors/learning_objectives_editor_test.tsx`

Validation:

- Jest test that insertion with existing `resourceContext.learningObjectives` does not show false warning.
- Jest test that real empty state still shows warning.
- Manual check with a page containing objective-attached activities.

### Slice A6 - Authoring Dark Mode Pass

Purpose:

- Resolve authoring dark mode compatibility issues for all authoring LO surfaces.

Likely work:

- Audit styles for hardcoded light backgrounds, borders, and text.
- Prefer existing authoring CSS variables or Tailwind/token utilities.
- Ensure removed state, warning state, chips, dropdown, checkbox, and buttons remain readable.

Likely files:

- `assets/src/components/resource/editors/LearningObjectivesEditor.scss`
- possibly insert menu styles under `assets/src/components/content/add_resource_content/`.

Validation:

- Manual authoring dark mode review.
- Add test only if existing test infrastructure can assert class/state without brittle visual assertions.

## Validation Matrix

| Requirement / Bug | Slice | Automated validation | Manual validation |
|---|---|---|---|
| MER-5802 Insert menu item appears in Content Types | A1 | Existing/new Jest insert menu test | Figma node `342-4473` |
| MER-5802 approved icon | A1 | Class/component assertion if stable | Figma icon comparison |
| MER-5802 hover/focus/selected states | A1 | Focus/hover helper text tests | Figma visual comparison |
| MER-5803 default Introduction | A2 | Factory/editor test | Authoring smoke check |
| MER-5803/5804 mode dropdown preserves config | A2 | Jest mode-switch test | Authoring smoke check |
| MER-5803/5804 descriptions present | A2 | Jest text assertions | Figma nodes `266-6913`, `267-6369` |
| MER-5803 empty warning | A2/A5 | Jest warning tests | Figma node `266-8274` |
| MER-5803/5804 include sub-objectives | A2/A4 | Jest state/render tests | Authoring smoke check |
| MER-5803/5804 parent-before-child | A4 | Jest order test | Figma visual comparison |
| MER-5803/5804 remove/restore non-destructive | A3/A4 | Jest config-state tests | Authoring smoke check |
| MER-5803/5804 parent removal cascades display | A4 | Jest cascade test | Authoring smoke check |
| MER-5804 review chips scoped to course | Existing/A3 | Existing Jest/Persistence tests | Authoring smoke check |
| MER-5804 practice chips scoped to course | Existing/A3 | Existing Jest/Persistence tests | Authoring smoke check |
| MER-5867 false empty warning | A5 | New Jest test | Manual insertion check |
| MER-5867 author dark mode | A6 | Limited class tests if useful | Manual dark mode check |

## Out Of Scope For This PR

- Student Summary grouping (`Recommended Review`, `Learning Objectives You're Applying`).
- `Show next steps` and expanded next-step panels.
- Strong proficiency recommendation suppression in student rendering.
- DOT Explain card.
- Student page links 500.
- Instructor/student preview render context unless authoring state is proven to be the root cause.
- Student-facing LO introduction/summary dark mode.
- Student-facing progression icon replacement.

## Open Questions / Requires Approval

- What exact plant/tree icon source should be canonical for React authoring surfaces? Prefer the Torus design-system icon catalog first, then feature Figma extraction if missing.
- Should the outline item use the same plant/tree icon as the Insert menu?
- Does the authoring design require parent and sub-objectives in one semantic row/cell for both Introduction and Summary, or only Summary?
- In authoring, when a parent is removed, should sub-objectives be visually hidden entirely or shown as part of the removed group? MER-5803/5804 say removing parent removes displayed sub-objectives; Figma should decide visual treatment.
- Are `practice_pages` acceptable as page resource IDs for this correction PR, or should authoring begin supporting activity/practice-opportunity targets? The original implementation uses page IDs; MER-5804 text says practice opportunities.

## Handoff To Implementation

Before code:

1. Run the UI design workflow/brief for this Authoring PR.
2. Confirm open questions above.
3. Start with Slice A1 using `harness-develop`.
4. After each slice:
   - update this document's validation matrix if scope shifts;
   - run targeted tests;
   - commit atomically.

