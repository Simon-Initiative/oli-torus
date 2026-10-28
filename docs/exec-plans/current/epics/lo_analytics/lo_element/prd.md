# Learning Objectives Page Element - Product Requirements Document

## 1. Overview
The Learning Objectives page element lets authors insert a first-class content element into a basic page that introduces the relevant Learning Objectives for the current course container or summarizes a student's proficiency and recommended next steps for those objectives.

The element is authored as a terminal `ResourceContent` node on a page and rendered in delivery from the current section's published container scope. Author-authored configuration is advisory: delivery rediscovers the current Learning Objectives attached to in-scope activities and uses element state only for display mode, Sub-Objective inclusion, local suppressions, and Summary recommendations.

## 2. Background & Problem Statement
Authors currently attach Learning Objectives to pages and activities, and instructors and students can see Learning Objective analytics in dashboard contexts. Authors do not have a simple page-level element that can place Learning Objective introductions or student-facing summaries at meaningful points in course content.

The problem is to add this element without turning page JSON into the source of truth for Learning Objective membership. Course content can change after an author configures the element, so the student-facing render must reflect the latest published objectives in the current container while preserving author intent for recommendations and per-element suppressions.

## 3. Goals & Non-Goals
### Goals
- Add a top-level-only Learning Objectives content element to basic pages.
- Let authors switch the element between Introduction and Summary modes.
- Let authors include or hide Sub-Objectives per element.
- Let authors suppress displayed Learning Objectives for the current element without deleting objectives or untagging activities.
- Let authors add Summary-mode review and practice recommendations as advisory page references.
- Render student-facing Introduction content from the current section/container Learning Objective set.
- Render student-facing Summary content with current student proficiency and configured recommendations.
- Keep delivery discovery efficient by using `SectionResourceDepot` for cached section resources and minimizing direct database queries.

### Non-Goals
- This work does not implement DOT AI explain integration.
- This work does not create a new persisted delivery table for Learning Objectives page elements.
- This work does not make Activity Bank Selection candidates part of first-pass Learning Objective discovery.
- This work does not change Learning Objective tagging semantics for pages or activities.
- This work does not mutate authored Learning Objective data when an objective is suppressed inside one element.

## 4. Users & Use Cases
- Authors: place Learning Objective introductions before instructional content so students understand the expected skills for the current container.
- Authors: place Learning Objective summaries after instructional or practice content so students receive personalized review and practice guidance.
- Students: see current Learning Objectives and, in Summary mode, their proficiency state and recommended next steps.
- Course delivery administrators and instructors: rely on published section rendering that reflects current section content without destabilizing existing course structure.
- Engineering and QA: validate authoring, publication, and delivery behavior across the resource/revision and section-resource boundaries.

## 5. UX / UI Requirements
- The Insert menu must show a Learning Objectives item in the Content Types section with the approved label, icon, hover/focus states, and description.
- The Learning Objectives element editor must follow existing page editor patterns for terminal page elements, including normal element removal behavior.
- The element editor must expose a keyboard-accessible mode selector for Learning Objective Introduction and Learning Objective Summary.
- The element editor must expose an Include Sub-Objectives checkbox, enabled by default.
- The element editor must show the effective Learning Objective hierarchy for the current container, with parent objectives before Sub-Objectives.
- The element editor must support remove and restore actions for objectives within this element only.
- Summary mode must expose page-selection controls for review pages and practice opportunities, rendered as removable selected items.
- Student rendering must allow long objective titles and Sub-Objective text to wrap without truncation.
- Student rendering must expose the proficiency explanation accordion accessibly.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: Insert menu entries, mode selector, checkbox, remove/restore actions, page selectors, removable recommendation chips, and proficiency accordion must be keyboard operable with visible focus indicators and appropriate accessible names/states.
- Performance: Delivery must skip all new discovery work on pages without a Learning Objectives element, compute included objectives once per page render, use `SectionResourceDepot` for container/page/objective metadata where possible, and avoid per-objective or per-recommendation N+1 queries.
- Reliability: Stale advisory configuration must not break delivery when objectives or recommended pages no longer exist in the current section.
- Security: Authoring and delivery reads must remain scoped to the current project or section; recommendation selectors must not accept resources outside the current course.
- Privacy: Summary rendering may use the current student's proficiency data, but telemetry and logs must not include student PII, raw responses, or authored page content.
- Compatibility: Existing content types, question types, publication flows, and delivery rendering must continue to work unchanged for pages without the new element.

## 9. Data, Interfaces & Dependencies
- Add a new `learning_objectives` terminal member to the basic page `ResourceContent` model in `assets/src/data/content/resource.ts`.
- The element state stores `mode`, `include_sub_objectives`, and sparse advisory per-objective configuration keyed by objective resource id.
- Advisory per-objective configuration stores enabled state plus `revisit_pages` and `practice_pages` recommendation resource ids.
- The element must not be added to `ResourceGroup` and must not allow nested children.
- The authoring editor depends on current project/course Learning Objective data for the container where the page lives.
- Delivery depends on `SectionResourceDepot`, page revision `activity_refs`, objective section-resource `related_activities`, and existing Learning Objective metrics APIs.
- Rendering requires a new `Oli.Rendering.Context` field carrying precomputed Learning Objective payloads.
- Student Summary recommendations resolve section-resource titles and slugs through `SectionResourceDepot.get_resources_by_ids/2`.

## 10. Repository & Platform Considerations
- Follow the resource/revision and publication model: authored page JSON stores element configuration, while delivery resolves current section content through published section state.
- Keep domain discovery logic under `lib/oli/`, not in controllers or templates.
- Keep page delivery integration thin in `lib/oli_web/controllers/page_delivery_controller.ex`.
- Use existing rendering extension points under `lib/oli/rendering/` rather than introducing a separate delivery UI runtime.
- Use focused React authoring components under `assets/src/components/resource/editors/` and existing Insert menu structures under `assets/src/components/content/add_resource_content/`.
- Use targeted ExUnit and React/Jest coverage where behavior lives; use scenario coverage when validating authoring-to-publish-to-delivery workflow.
- Code review should include security and performance lenses, plus Elixir, TypeScript, UI, and requirements review because this work spans backend rendering, frontend authoring, accessibility, and PRD traceability.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The rollout is additive. Existing saved pages do not contain `learning_objectives` elements and should continue rendering exactly as they do today. Newly authored elements become active once the containing project is published into a section.

## 12. Telemetry & Success Metrics
- Success signal: authors can insert and configure the element without disrupting existing page content.
- Success signal: students see the correct current Learning Objective set for the page's delivery container, including objectives added after the element was configured.
- Success signal: Summary rendering displays current proficiency labels and configured recommendations only for relevant enabled objectives.
- Operational signal: delivery render performance for pages with the element remains bounded to one precomputation pass plus batch depot lookups.
- Telemetry, if added during implementation, should capture bounded operation names, counts, durations, and outcomes without logging student PII or authored content.

## 13. Risks & Mitigations
- Risk: Page JSON becomes stale as objectives are added elsewhere in the container. Mitigation: delivery rediscovers the authoritative objective set and treats element config as sparse advisory decoration.
- Risk: Delivery performance regresses on content-heavy courses. Mitigation: scan for the element before doing work, use `SectionResourceDepot`, rely on page `activity_refs`, and batch recommendation title resolution.
- Risk: Authors can insert the element in nested groups through drag/drop or import paths. Mitigation: enforce top-level-only insertion in `canInsert` and keep the type out of `ResourceGroup`.
- Risk: Stale recommendation page IDs or objective IDs break rendering. Mitigation: ignore unresolved recommendation resources and advisory objective configs that do not match the discovered scope.
- Risk: Summary proficiency labels differ between analytics internals and product copy. Mitigation: centralize the mapping from existing metrics labels to approved student-facing proficiency labels and icons.
- Risk: Activity Bank Selection expectations are ambiguous. Mitigation: explicitly defer bank candidate objective discovery unless product confirms it is required.

## 14. Open Questions & Assumptions
### Open Questions
- Should the final authoring preview show example proficiency values for Summary mode or remain a static configuration preview?
- Should Learning Objectives attached directly to pages, rather than activities, be included in this element if product scope changes?
- What final icon should the Insert menu use for the Learning Objectives item?
- Should Activity Bank Selection candidates contribute Learning Objectives in a later phase?
- Are `practice_pages` always page resource IDs, or can they reference another practice-opportunity abstraction?

### Assumptions
- The current work item covers MER-5802, MER-5803, MER-5804, and MER-5807.
- Summary student rendering is in scope, but DOT AI explain integration is future work.
- Learning Objective discovery for this work item means objectives attached to activities on descendant pages in the selected container.
- The selected delivery container is the most specific non-root parent container for the page.
- Missing advisory config means the discovered objective renders enabled with no recommendations.
- Existing `related_activities` post-processing is available and current for the section.

## 15. QA Plan
- Automated validation:
  - TypeScript tests for `ResourceContent` insertion rules, top-level-only constraints, default factory output, and editor merge behavior.
  - React/Jest tests for the authoring editor controls, objective remove/restore behavior, Sub-Objective inclusion, and recommendation selection state.
  - ExUnit tests for delivery included-objective discovery using `SectionResourceDepot`, page `activity_refs`, and objective `related_activities`.
  - ExUnit render tests for Introduction and Summary behavior, including missing advisory config and stale recommendation IDs.
  - Scenario coverage for authoring a Learning Objectives element, publishing, adding a later objective elsewhere in the container, and verifying delivery renders the full current objective set.
- Manual validation:
  - Verify Insert menu icon, label, hover/focus behavior, and Content Types placement against Figma.
  - Verify keyboard navigation and focus indicators in the Insert menu, editor controls, recommendation selectors, and student accordion.
  - Verify student delivery layouts on narrow and wide viewports with long objective titles.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
