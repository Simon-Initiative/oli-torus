# MER-5867 Student / Delivery Corrections

## Purpose

This document defines the second correction PR for MER-5867. It covers the student-facing and delivery/preview side of the Learning Objectives Summary / Introduction element originally delivered in PR #6745 for MER-5807 and MER-5808.

The goal is to correct the delivery behavior and Figma fidelity after the authoring configuration is stable. The PR should preserve the existing backend discovery model where it is correct, but it must close the acceptance-criteria gaps around Summary grouping, next steps, proficiency behavior, DOT explain, page links, preview rendering, icons, accessibility, responsive layout, and dark mode.

## Proposed PR

- PR name direction: `MER-5867 Student LO element delivery corrections`
- Jira source tickets:
  - MER-5867: bugfix umbrella
  - MER-5807: Student Learning Objective Introduction Element
  - MER-5808: Student Learning Objective Summary Element
- User surface:
  - Student page delivery
  - Instructor/author preview when preview renders student-like page content
  - Existing student-facing LO component that predates these tickets and now receives updated styling/icons
- Implementation surface: `liveview/heex` / server-rendered HTML, with possible shared icon/component work
- Primary code area:
  - `lib/oli/rendering/content/learning_objectives.ex`
  - `lib/oli/rendering/content/html.ex`
  - `lib/oli/rendering/context.ex`
  - `lib/oli/delivery/learning_objectives/page_element.ex`
  - `lib/oli_web/live/delivery/student/utils.ex`
  - `lib/oli_web/delivery/instructor/preview_page_context.ex`
  - existing LO display component target to identify during implementation
- Test area:
  - `test/oli/rendering/content/learning_objectives_test.exs`
  - `test/oli/delivery/learning_objectives/page_element_test.exs`
  - `test/oli_web/live/delivery/student/utils_test.exs`
  - preview-specific tests if current coverage exists
  - scenario coverage under `test/scenarios/learning_objectives/`

## Source Of Truth

### Bugfix Source

MER-5867 is the QA correction ticket. Its checklist should be used as a complete double-check before PR handoff.

### Original Student Tickets

MER-5807 defines the student-facing Learning Objective Introduction element.

MER-5808 defines the student-facing Learning Objective Summary element.

### Existing Feature Docs

Use these existing docs as context, but treat this document as the correction scope for this PR:

- `docs/exec-plans/current/epics/lo_analytics/lo_element/prd.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/fdd.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/plan.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/requirements.yml`

### Figma Sources

Primary feature-level Figma sources for this PR:

- LO Summary from student view, proficiency accordion collapsed:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=285-42309&m=dev
- LO Summary from student view, proficiency question expanded:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=285-42456&m=dev
- Existing LO component with new styles/icons and proficiency accordion:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=256-14201&m=dev
- Existing LO component mobile, proficiency question expanded:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=435-13584&m=dev
- LO Summary responsive mobile:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=435-11038&m=dev
- LO Summary `Learning Objectives You're Applying` / Strong Proficiency section:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=287-50809&m=dev
- LO Summary `Recommended Review` section with lower proficiency LOs:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=287-50756&m=dev
- LO Summary `Recommended Review` expanded after `Show next steps`:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=287-51458&m=dev
- LO Summary `Recommended Review` expanded mobile:
  - https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates?node-id=434-8927&m=dev

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

This table keeps all MER-5867 bullets visible, while marking what belongs in this Student / Delivery PR.

| # | MER-5867 bullet | Delivery PR disposition |
|---|---|---|
| 1 | Missing separate `Recommended Review` element and `Show next steps` action | In scope. Core MER-5808 Summary behavior. |
| 2 | Strong proficiency still shows revisit/practice pages | In scope. Strong LOs must not expose next steps or recommendations. |
| 3 | DOT enabled but no explain card | In scope. Add Explain card when DOT is enabled. |
| 4 | Proficiency icons are not keyboard accessible | In scope. Ensure icons/interactive wrappers satisfy accessibility expectations. |
| 5 | Plant icon for LO content type is a bullseye instead of plant | Out of scope unless the same icon appears in student-facing render. Primary fix in Authoring PR. |
| 6 | New hover effect missing when hovering over content types | Out of scope. Authoring Insert menu. |
| 7 | Garbage icons on LO component do not match Figma | In scope if the student-facing LO component uses remove/trash/garbage-like icons. Authoring remove icons are Authoring PR. |
| 8 | Four progression icons differ from Figma | In scope. Student proficiency labels/icons must match Figma and MER-5808. |
| 9 | LO Summary / Introduction description is missing | In scope for student-facing helper/intro text. Authoring descriptions are Authoring PR. |
| 10 | UI does not match Figma around removed LOs | Mostly out of scope. Removed authoring state belongs to Authoring PR. If preview/student has removed-state artifacts, validate here. |
| 11 | Parent LO removal should cascade to sub-objectives but does not | Verify in delivery as downstream behavior, but primary authoring fix belongs to Authoring PR. |
| 12 | Student page links throw 500 error | In scope. Fix delivery recommendation links. |
| 13 | Author cannot preview the new LO content type | In scope. Preview rendering uses delivery-like server render context. |
| 14 | Dark mode compatibility issues for author and student | In scope for student/delivery/preview surfaces. Authoring dark mode is Authoring PR. |
| 15 | False empty warning after adding LO type to a page that has LOs | Out of scope. Authoring PR. |
| 16 | Author Summary parent and child LOs not numbered nor contained within same cell | Out of scope. Authoring PR. |
| 17 | Replace question marks with correct icons in student-facing display | In scope. Student-facing LO display icons. |
| 18 | `Sub-objective` text should not be present | In scope for student-facing Summary/Introduction display. |

## Acceptance Criteria Digest

This section paraphrases the original Jira ACs for the student/delivery scope. Implementation should validate against the full Jira text and the Figma nodes above.

### MER-5807 - Student LO Introduction

Positive ACs:

- When a page contains a Learning Objective Introduction component, it displays all LOs associated with the container where it was placed.
- Container scope can be course, unit, module, or section.
- If `Include Sub-Objectives` is enabled by the author, sub-objectives display beneath parent LOs.
- If `Include Sub-Objectives` is disabled, only parent LOs display.
- Parent LOs always appear before associated sub-objectives.
- The component displays the `Learning Objectives` heading.
- The component appears wherever the author placed it in the course.
- A `What is proficiency and how is it estimated?` accordion appears beneath the LOs.
- The accordion is collapsed by default.
- Students can expand/collapse the accordion.
- Expanded accordion shows:
  - explanation of how proficiency is estimated;
  - definitions for `Not enough information`, `Beginning Proficiency`, `Growing Proficiency`, `Strong Proficiency`;
  - associated icon and label for each proficiency level.
- LO titles and descriptions wrap onto additional lines.
- Sub-objective text wraps onto additional lines.
- No LO or sub-objective title is truncated.
- The component expands vertically for content.
- Layout matches Figma spacing and hierarchy.
- Mobile responsive behavior should follow the Figma mobile reference and common-sense extrapolation where designs are incomplete.

Negative ACs:

- The component only displays LOs associated with the authored container.
- It does not display proficiency estimates or recommendations; those belong to Summary.
- If no LOs exist for the configured container, the component is not displayed.

Accessibility:

- Proficiency accordion is keyboard accessible.
- Accordion exposes expanded/collapsed state.
- Text reflows without loss of information when viewport or text size changes.
- No truncation of critical LO/sub-objective text.
- Focus indicators are visible.

### MER-5808 - Student LO Summary

Positive ACs:

- When a page contains a Learning Objective Summary component, it displays all LOs associated with the container where it was placed.
- Container scope can be course, unit, module, or section.
- `Include Sub-Objectives` controls whether sub-objectives are displayed under parent LOs.
- Parent-before-child hierarchy is preserved.
- Each LO displays the student's current proficiency using updated labels and icons:
  - `Not enough information`
  - `Beginning Proficiency`
  - `Growing Proficiency`
  - `Strong Proficiency`
- LOs are grouped into:
  - `Learning Objectives You're Applying` for `Strong Proficiency`.
  - `Recommended Review` for `Beginning Proficiency` and `Growing Proficiency`.
- `Recommended Review` should not render if there are no LOs in that category.
- `Learning Objectives You're Applying` should not render if there are no Strong LOs.
- For Beginning/Growing LOs with configured recommendations:
  - show a `Show next steps` action;
  - selecting it expands the recommendation panel;
  - expanded panel displays author-configured `Revisit` pages as links;
  - expanded panel displays author-configured `Practice` activities/opportunities as links;
  - selecting `Hide next steps` collapses the panel.
- Strong LOs:
  - render in `Learning Objectives You're Applying`;
  - are not expandable;
  - do not show review/practice recommendations;
  - do not show `Show next steps`.
- If a Beginning/Growing LO has no configured review/practice resources:
  - do not show `Show next steps`;
  - do not show an expandable panel;
  - do not render empty `Revisit` or `Practice` sections.
- If DOT is enabled for the course, an `Explain` card is displayed in the expanded recommendation panel.
- Selecting `Explain` prompts DOT to explain the learning objective.
- If Explain is disabled, no Explain card appears.
- A `What is proficiency and how is it estimated?` accordion appears and is collapsed by default.
- Expanded accordion shows explanation and definitions for all four proficiency levels.
- The component is mobile responsive.

Negative ACs:

- Students cannot edit LOs, recommendations, review pages, or practice opportunities.
- Only LOs associated with the configured container are displayed.
- If no LOs exist for the configured container, the component is not displayed.
- Strong LOs never display recommendation panels or next-step actions.
- If no recommendations exist for a Beginning/Growing LO, no expandable panel is shown.

Accessibility:

- `Show next steps`, `Hide next steps`, and proficiency accordion are keyboard accessible.
- Expanded/collapsed state is exposed via appropriate semantics or ARIA.
- Proficiency icons are accompanied by text labels and are not communicated by icon/color alone.
- Focus indicators are visible.
- Review/practice links have meaningful accessible names.

## Existing Student / Delivery Implementation Notes

Known current files from PR #6745:

- Discovery and payload prep:
  - `lib/oli/delivery/learning_objectives/page_element.ex`
  - `lib/oli/delivery/learning_objectives/included_objective.ex`
- Rendering:
  - `lib/oli/rendering/content/learning_objectives.ex`
  - `lib/oli/rendering/content/html.ex`
  - `lib/oli/rendering/content/markdown.ex`
  - `lib/oli/rendering/content/plaintext.ex`
  - `lib/oli/rendering/context.ex`
- Student render integration:
  - `lib/oli_web/live/delivery/student/utils.ex`
- Instructor preview render context:
  - `lib/oli_web/delivery/instructor/preview_page_context.ex`
- Existing student-facing LO components that may need style/icon updates:
  - `lib/oli_web/components/delivery/learning_objectives/`
  - `lib/oli_web/live/delivery/student_dashboard/components/learning_objectives_tab.ex`
  - `lib/oli_web/live/curriculum/entries/learning_summary.ex`
  - exact target for Figma node `256-14201` must be confirmed during implementation.

Known implementation gaps from earlier inspection:

- Summary currently renders a flat list of objectives and inline `Review` / `Practice` recommendation groups.
- There is no separate `Recommended Review` section.
- There is no `Learning Objectives You're Applying` Strong section.
- There is no `Show next steps` / `Hide next steps` action.
- Recommendations are rendered even for Strong proficiency if configured.
- DOT Explain card is not implemented in Summary recommendations.
- Progression/proficiency icons currently use Font Awesome classes such as `fa-tree`, `fa-spa`, `fa-seedling`, and `fa-hourglass-half`; these may not match Figma.
- The renderer uses `Sub-Objective` as visible label text in Summary children.
- Student links are built through `lesson_href(context, page.slug)` and need validation against the 500 error.
- Normal student rendering precomputes `learning_objectives` in `lib/oli_web/live/delivery/student/utils.ex`.
- Instructor preview context appears not to precompute `learning_objectives`, which likely explains why authors cannot preview the new LO content type.
- Existing docs mention screenshot assets under `docs/exec-plans/current/epics/lo_analytics/lo_element/images/`, but that directory is not present in the current working tree.

## Proposed Correction Harness Process

Use this document as the PR-level correction plan. Before implementation:

1. Ensure the Authoring PR has landed or confirm that its authoring data shape is stable.
2. Create a UI implementation brief for this Delivery PR using `implement_ui` / repo-local `ui_workflow`.
3. The brief must inspect the Figma nodes listed above.
4. The brief should classify the implementation surface as `liveview/heex` or `mixed` if any React delivery surface is discovered.
5. The brief should map:
   - Summary section structure;
   - `Recommended Review` card/list treatment;
   - `Learning Objectives You're Applying` section;
   - `Show next steps` / `Hide next steps` interaction;
   - expanded next-step panel;
   - DOT Explain card placement;
   - proficiency icons;
   - existing LO component visual updates;
   - mobile responsive behavior;
   - dark mode token mapping;
   - link styles and accessibility semantics.
6. After the brief is approved, use `harness-develop` slice by slice.
7. Commit after each completed, tested slice.

## Proposed Slices

### Slice D1 - Summary Grouping And Section Structure

Purpose:

- Implement MER-5808's Summary grouping model.

Likely work:

- Render `Recommended Review` as a distinct section for Beginning/Growing LOs.
- Render `Learning Objectives You're Applying` as a distinct section for Strong LOs.
- Do not render either section if empty.
- Preserve container-scoped objective discovery and parent-before-child order.
- Decide and document how `Not enough information` appears. MER-5808 lists it as a proficiency state but only explicitly assigns Beginning/Growing to `Recommended Review` and Strong to `You're Applying`.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- `test/oli/rendering/content/learning_objectives_test.exs`

Validation:

- Render tests for both sections.
- Render tests for empty section omission.
- Manual Figma comparison against nodes `285-42309`, `287-50809`, and `287-50756`.

### Slice D2 - `Show next steps` / `Hide next steps`

Purpose:

- Add expandable next-step behavior for Recommended Review LOs with configured recommendations.

Likely work:

- Add keyboard-accessible expand/collapse behavior, preferably with native `<details>` / `<summary>` unless the Figma/UI brief requires a different accessible pattern.
- Closed state shows `Show next steps`.
- Open state shows `Hide next steps`.
- Expanded panel displays configured `Revisit` and `Practice` links.
- Do not render empty `Revisit` or `Practice` sections.
- Do not render next-step action for Beginning/Growing LOs without recommendations.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- `test/oli/rendering/content/learning_objectives_test.exs`

Validation:

- Render tests for `Show next steps`.
- Render tests for expanded panel markup.
- Render tests that no action appears without recommendations.
- Accessibility-oriented assertions for semantic expand/collapse where feasible.
- Manual Figma comparison against nodes `287-51458` and `434-8927`.

### Slice D3 - Strong Proficiency Recommendation Suppression

Purpose:

- Ensure Strong LOs never display recommendation panels or next-step actions.

Likely work:

- For `High` / `Strong Proficiency`, ignore configured revisit/practice resources in student Summary render.
- Keep proficiency badge/label visible.
- Ensure stale recommendation resolution remains batched and filtered.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- `test/oli/rendering/content/learning_objectives_test.exs`

Validation:

- Render test with Strong LO and configured recommendations verifies:
  - Strong section renders;
  - no `Show next steps`;
  - no linked revisit/practice resources;
  - no empty panel.

### Slice D4 - Proficiency Icons, Icon Accessibility, And `Sub-objective` Text

Purpose:

- Align student-facing progression/proficiency iconography and text with Figma.

Likely work:

- Replace current Font Awesome icon mapping if it differs from Figma.
- Ensure all icon-only or icon-led affordances include text labels or accessible names.
- Ensure proficiency is not communicated by icon/color alone.
- Remove visible `Sub-Objective` label text where Figma does not show it.
- Confirm whether sub-objectives are numbered, indented, or otherwise grouped by design.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- `lib/oli_web/icons.ex` if the correct icons should be added to HEEx icon system.
- possibly `lib/oli_web/components/delivery/learning_objectives/` for the existing LO component.

Validation:

- Render tests for expected icon markers/classes/components if stable.
- Render tests that `Sub-Objective` text is absent where required.
- Manual Figma comparison against nodes `256-14201`, `285-42309`, `287-50809`, and `287-50756`.

### Slice D5 - DOT Explain Card

Purpose:

- Show Explain card in expanded next-step panel when DOT/Explain is enabled.

Likely work:

- Identify the existing DOT enablement flag/path for delivery page render context.
- Add enough render context or options to determine whether Explain should appear.
- Render Explain card only when enabled.
- Wire action to prompt DOT to explain the LO, using existing DOT/dialogue mechanisms if available.
- Keep Explain card out of render when disabled.

Likely files:

- `lib/oli/rendering/context.ex`
- `lib/oli/rendering/content/learning_objectives.ex`
- possibly delivery/student dialogue or DOT helper modules, to be identified during implementation.

Validation:

- Render tests for enabled/disabled Explain card.
- Integration or LiveView test if action needs event wiring.
- Manual Figma comparison against expanded next-step nodes.

Open dependency:

- Confirm exact existing DOT integration point before coding this slice.

### Slice D6 - Student Links 500 And Preview Support

Purpose:

- Fix student page links and enable author/instructor preview of the LO content type.

Likely work:

- Reproduce or reason through 500 from recommendation page links.
- Validate whether `lesson_href(context, page.slug)` receives page slugs or revision slugs as expected by routes.
- Ensure preview routes use preview-aware link builders.
- Add `learning_objectives` payload precomputation to instructor preview render context if missing.
- Avoid student-specific proficiency calls when preview user/context should not have student proficiency.
- Preserve normal student delivery path.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- `lib/oli/rendering/content/url_helpers.ex`
- `lib/oli_web/live/delivery/student/utils.ex`
- `lib/oli_web/delivery/instructor/preview_page_context.ex`
- `test/oli_web/live/delivery/student/utils_test.exs`
- preview context tests to identify or add.

Validation:

- Test that generated student recommendation links match working student lesson routes.
- Test that preview links use preview routes.
- Test that preview render context includes enough LO payload to render the element.
- Manual author preview smoke check.

### Slice D7 - Existing LO Component Visual Refresh

Purpose:

- Update the pre-existing student-facing LO component shown in Figma node `256-14201`.

Likely work:

- Identify the component currently showing LOs at the beginning of a page.
- Align its styling and icons with Figma.
- Add or confirm the `What is proficiency and how is it estimated?` expandable section.
- Ensure mobile expanded version matches node `435-13584`.

Likely files to investigate:

- `lib/oli_web/live/curriculum/entries/learning_summary.ex`
- `lib/oli_web/components/delivery/learning_objectives/`
- other render paths found by searching for the existing heading/copy.

Validation:

- Component/render tests if existing.
- Manual Figma comparison against nodes `256-14201` and `435-13584`.

### Slice D8 - Student Dark Mode And Responsive Pass

Purpose:

- Resolve student dark mode and mobile/responsive issues after structural fixes.

Likely work:

- Audit hardcoded light backgrounds, borders, text colors, and icon fills.
- Prefer tokenized Tailwind utilities or existing CSS variables.
- Ensure mobile Summary layout follows nodes `435-11038` and `434-8927`.
- Ensure long LO titles, descriptions, links, and action labels wrap without overlap or truncation.

Likely files:

- `lib/oli/rendering/content/learning_objectives.ex`
- relevant HEEx/CSS files for existing LO component.

Validation:

- Manual dark mode check.
- Manual mobile viewport check.
- Render tests for wrapping-friendly classes where not brittle.

## Validation Matrix

| Requirement / Bug | Slice | Automated validation | Manual validation |
|---|---|---|---|
| MER-5807 Introduction displays scoped LOs | Existing/D7 | Existing delivery/page element tests | Student page smoke check |
| MER-5807 Include Sub-Objectives controls children | Existing/D7 | Existing render tests | Figma/mobile check |
| MER-5807 no proficiency/recommendations in Introduction | Existing/D7 | Existing render tests | Figma node `256-14201` |
| MER-5807 proficiency accordion | D4/D7 | Render tests | Figma nodes `285-42456`, `435-13584` |
| MER-5807 wrapping/no truncation | D8 | Class/render tests if useful | Desktop/mobile viewport check |
| MER-5808 Summary displays proficiency labels/icons | D1/D4 | Render tests | Figma visual check |
| MER-5808 `Recommended Review` section | D1 | Render tests | Figma node `287-50756` |
| MER-5808 `Learning Objectives You're Applying` section | D1 | Render tests | Figma node `287-50809` |
| MER-5808 `Show next steps` / `Hide next steps` | D2 | Render tests | Figma nodes `287-51458`, `434-8927` |
| MER-5808 no next steps without recommendations | D2 | Render tests | Student smoke check |
| MER-5808 Strong hides recommendations | D3 | Render tests | Student smoke check |
| MER-5808 DOT Explain card | D5 | Render/integration tests | Figma expanded panel check |
| MER-5867 student links 500 | D6 | Route/link tests | Student click-through smoke check |
| MER-5867 author cannot preview | D6 | Preview context/render test | Author preview smoke check |
| MER-5867 progression icons differ | D4 | Render/icon tests | Figma icon check |
| MER-5867 question marks replaced | D4/D7 | Render/icon tests | Figma icon check |
| MER-5867 `Sub-objective` text absent | D4 | Render test | Figma visual check |
| MER-5867 student dark mode | D8 | Limited class tests if useful | Manual dark mode check |
| MER-5867 mobile responsive Summary | D8 | Limited render tests if useful | Figma nodes `435-11038`, `434-8927` |

## Out Of Scope For This PR

- Insert menu icon and hover behavior.
- Authoring editor base layout, descriptions, removed state, and warning state.
- Authoring parent/sub-objective grouped cell layout.
- Authoring false empty warning after insertion.
- Any change that mutates authored objective tags or activity objective relationships.

## Open Questions / Requires Approval

- How should `Not enough information` LOs be grouped in Summary? MER-5808 lists it as a proficiency state but defines explicit groups only for Beginning/Growing and Strong.
- Are `Practice` recommendations expected to link to activities/practice opportunities, or are page resource IDs acceptable for this correction? Current implementation uses page IDs.
- What is the canonical DOT/Explain enablement source in delivery render context?
- What exact action should Explain trigger from a server-rendered page element? Existing DOT/dialogue APIs must be identified before implementation.
- Which existing LO component corresponds to Figma node `256-14201`? Confirm by current UI search/manual runtime inspection.
- Should correct icons be added to `lib/oli_web/icons.ex`, reused from existing `OliWeb.Icons`, or left as existing icon-font classes? Prefer design-system icon source first.
- Should `Show next steps` be implemented with native `<details>/<summary>` or a LiveView/JS interaction? Native details gives accessibility and no custom state, but Figma may require custom button treatment.

## Handoff To Implementation

Before code:

1. Confirm the Authoring PR has stabilized the authored content/config shape.
2. Run the UI design workflow/brief for this Student / Delivery PR.
3. Confirm open questions above, especially `Not enough information`, `Practice` target type, and DOT integration.
4. Start with Slice D1 using `harness-develop`.
5. After each slice:
   - update this document's validation matrix if scope shifts;
   - run targeted tests;
   - run manual Figma checks when relevant;
   - commit atomically.

