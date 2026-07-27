# Learning Objectives Page Element - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/lo_analytics/lo_element/prd.md`
- FDD: `docs/exec-plans/current/epics/lo_analytics/lo_element/fdd.md`
- UX screenshots:
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5802-insert-menu-learning-objectives.png`
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5803-authoring-introduction.png`
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5804-authoring-summary-review.png`
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5804-authoring-summary-practice.png`
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5807-student-introduction-collapsed.png`
  - `docs/exec-plans/current/epics/lo_analytics/lo_element/images/mer-5807-student-introduction-expanded.png`

## Scope
Implement the `learning_objectives` basic-page element from authoring through delivery. The work includes the TypeScript page-content model, top-level-only insertion policy, authoring insert menu and editor, authoring page-load objective reconciliation, delivery-time included-objective discovery, render-context precomputation, and student Introduction/Summary rendering.

Guardrails:
- Keep the element terminal. Do not add it to `ResourceGroup` or give it children.
- Enforce top-level-only placement through model policy, not only visible UI affordances.
- Treat authored objective config as advisory. Authoring page-editor load refreshes the element state by recursively resolving the current nested-container objective set, adding newly found objectives, and removing objectives no longer found.
- Treat delivery discovery as authoritative for student rendering. Delivery must still render newly discovered objectives if the author has not reloaded and saved the page editor since those objectives were added.
- Keep delivery efficient: use `SectionResourceDepot` where possible, run at most one narrow page-revision query for descendant `activity_refs`, and batch recommendation page resolution.
- Add adequate source code comments for non-obvious authoring reconciliation, recursive hierarchy traversal, query-shape constraints, and proficiency label mapping. Avoid comments that restate obvious assignments or component props.
- No new relational table, DOT AI explain integration, page-attached objective inclusion, or Activity Bank Selection candidate discovery in this implementation.

## Clarifications & Default Assumptions
- MER-5802, MER-5803, MER-5804, and MER-5807 are the Jira source tickets for this work.
- The Jira screenshots have been retrieved and saved under `docs/exec-plans/current/epics/lo_analytics/lo_element/images/`; implementation should consult them as the local UX reference artifacts instead of relying on Jira attachment availability.
- `practice_pages` and `revisit_pages` are page resource IDs in the current course unless product later defines a distinct practice-opportunity reference.
- The selected delivery container is the most specific non-root parent container for the current page, with course-root fallback when needed.
- Existing analytics labels map to student-facing labels in one rendering helper.
- No feature flag is planned because the change is additive and absent content should preserve current behavior.
- Telemetry is optional but should be considered for delivery discovery counts and timing because this path runs during page rendering.

## Phase 1: Page Content Model And Insertion Policy
- Goal: Add the terminal `learning_objectives` content type and enforce root-only placement.
- Requirements Covered: FR-001, FR-002, FR-010; AC-001, AC-002, AC-003, AC-004, AC-016, AC-030.
- Tasks:
  - [ ] Add `LearningObjectivesContentMode`, `LearningObjectiveConfig`, `LearningObjectivesContent`, and `createDefaultLearningObjectivesContent()` to `assets/src/data/content/resource.ts`.
  - [ ] Add `learning_objectives` to `ResourceContent`, `isResourceContent`, `getResourceContentName`, and the root insertable list.
  - [ ] Keep `learning_objectives` out of `ResourceGroup` and all container `allowedContentItems` results.
  - [ ] Update `canInsert` so `learning_objectives` returns true only when `parents` is empty, including drag/drop and import-adjacent callers.
  - [ ] Update page-content JSON schema validation under `priv/schemas/v0-1-0/` for the new terminal shape while preserving existing schema behavior.
  - [ ] Add concise source comments only around the root-only insertion invariant if the implementation path is not self-evident from the surrounding code.
- Testing Tasks:
  - [ ] Add TypeScript tests for default factory output, type guard recognition, display name, root insertion, nested rejection, and non-container behavior.
  - [ ] Add or update schema validation tests for valid top-level `learning_objectives` content and invalid nested placement where schema support allows.
  - [ ] Run targeted frontend tests for `assets/src/data/content/resource.ts`.
  - [ ] Run targeted backend/schema tests if page-content schema validation has existing test coverage.
  - Command(s): `cd assets && yarn test <resource-content-test-target>`; `mix test <schema-validation-test-target>`
- Definition of Done:
  - `learning_objectives` is a valid terminal top-level page content node.
  - No existing content type loses insertion support.
  - Tests cover AC-001, AC-002, AC-003, AC-004, AC-016, and AC-030 at the model/schema layer.
- Gate:
  - Do not start authoring UI wiring until the model policy is stable and test-covered.
- Dependencies:
  - `prd.md`, `fdd.md`, and `requirements.yml`.
- Parallelizable Work:
  - Schema validation updates can proceed in parallel with TypeScript model tests after the final content shape is agreed.

## Phase 2: Authoring Objective Resolution And Page-Load Reconciliation
- Goal: Resolve the current recursive container objective set during authoring page-editor load and reconcile each element's advisory state.
- Requirements Covered: FR-004, FR-005, FR-010; AC-009, AC-011, AC-012, AC-015, AC-016.
- Tasks:
  - [ ] Add a backend authoring read boundary or page-editor payload extension that returns objectives attached to activities in the current page's container and descendant containers.
  - [ ] Return objective resource ID, title, optional description, parent resource ID, child IDs, related activity IDs, and deterministic display order.
  - [ ] Add a frontend reconciliation helper that runs when the basic page editor loads a page containing `learning_objectives`.
  - [ ] Preserve existing advisory config for still-present objectives.
  - [ ] Add newly found objectives with default config: `enabled: true`, empty `revisit_pages`, and empty `practice_pages`.
  - [ ] Remove advisory config rows for objectives no longer found in the current nested container scope.
  - [ ] Ensure reconciliation does not change objective metadata, objective hierarchy, activity tags, or recommendation target pages.
  - [ ] Add source comments explaining why reconciliation runs on authoring page load and why the stored state is advisory rather than authoritative.
- Testing Tasks:
  - [ ] Add backend tests for recursive authoring objective resolution, current-container scoping, parent-before-child ordering, and no cross-project leakage.
  - [ ] Add frontend unit tests for add/remove reconciliation, preservation of configured rows, and no mutation of unrelated page content.
  - [ ] Add tests proving recommendation edits do not tag pages or activities to objectives.
  - [ ] Run targeted ExUnit and Jest tests for the new resolver and reconciliation helper.
  - Command(s): `mix test <authoring-objective-resolution-test-target>`; `cd assets && yarn test <learning-objectives-reconciliation-test-target>`
- Definition of Done:
  - Every authoring page-editor load for a page containing this element refreshes objective config membership against current recursive container data.
  - Reconciliation behavior is deterministic, local to each element, and test-covered.
- Gate:
  - Do not build the final editor controls until objective resolution and reconciliation are stable enough to drive UI state.
- Dependencies:
  - Phase 1 content model.
- Parallelizable Work:
  - Backend resolver tests and frontend reconciliation helper tests can proceed in parallel once the response shape is fixed.

## Phase 3: Authoring Insert Menu And Editor UX
- Goal: Provide the author-facing insertion and configuration UI for Introduction and Summary modes.
- Requirements Covered: FR-003, FR-004, FR-005, FR-010; AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016.
- Tasks:
  - [ ] Use `images/mer-5802-insert-menu-learning-objectives.png` as the local reference for the Insert menu item, icon placement, description behavior, and menu state styling.
  - [ ] Use `images/mer-5803-authoring-introduction.png` as the local reference for Introduction authoring layout, mode selector, Include Sub-Objectives, objective hierarchy, remove/restore behavior, empty/warning treatment, and proficiency accordion placement.
  - [ ] Use `images/mer-5804-authoring-summary-review.png` and `images/mer-5804-authoring-summary-practice.png` as local references for Summary authoring layout, review recommendations, practice recommendations, and removable chips.
  - [ ] Add the Learning Objectives entry to the Content Types insert menu with approved label, icon, hover description, focus state, hover state, and selected state.
  - [ ] Hide or disable the menu item from nested insert controls while relying on `canInsert` as the enforcement layer.
  - [ ] Add `LearningObjectivesEditor.tsx` and wire it through `createEditor.tsx`, `ContentBlock.tsx`, and `ContentOutline.tsx`.
  - [ ] Implement keyboard-accessible Introduction/Summary mode selection without losing shared element config.
  - [ ] Implement Include Sub-Objectives as element-local state, defaulting to enabled.
  - [ ] Render the resolved objective hierarchy parent-before-child with subobjective indentation.
  - [ ] Implement objective remove/restore semantics as advisory enabled-state updates only.
  - [ ] Implement Summary-mode review and practice page selectors scoped to the current course.
  - [ ] Keep recommendation chips removable and accessible.
  - [ ] Add source comments where control logic is non-obvious, especially parent/subobjective hide semantics and preservation of shared config across mode switches.
- Testing Tasks:
  - [ ] Add React/Jest coverage for insert menu behavior, top-level insertion, editor defaults, keyboard mode switching, Include Sub-Objectives, remove/restore, and recommendation selection.
  - [ ] Add accessibility-focused assertions for labels, roles, keyboard operation, and focus-visible states where existing test utilities support them.
  - [ ] Manually verify the insert menu and editor against the saved UX screenshots in `docs/exec-plans/current/epics/lo_analytics/lo_element/images/`.
  - [ ] Run targeted frontend tests plus lint/format checks for changed files.
  - Command(s): `cd assets && yarn test <learning-objectives-editor-test-target>`; `cd assets && yarn lint`; `cd assets && yarn format`
- Definition of Done:
  - Authors can insert and configure the element at top level only.
  - Editor behavior preserves advisory config correctly across mode, inclusion, removal, restore, and recommendation workflows.
  - UI tests cover AC-005 through AC-016.
- Gate:
  - Do not integrate delivery rendering until the persisted authoring state shape and editor write behavior are stable.
- Dependencies:
  - Phase 1 model policy and Phase 2 reconciliation data.
- Parallelizable Work:
  - Insert menu wiring and editor shell can proceed in parallel with recommendation selector implementation after the content factory is available.

## Phase 4: Delivery Objective Discovery And Render Precomputation
- Goal: Build an efficient delivery helper that precomputes included objectives once per page render.
- Requirements Covered: FR-006, FR-007, FR-010; AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-026, AC-030.
- Tasks:
  - [ ] Add `Oli.Delivery.LearningObjectives.PageElement` with `included_objectives/2` and render-payload preparation.
  - [ ] Scan `attempt_content` with `PageContent.flat_filter/2` and return `nil` when no `learning_objectives` element exists.
  - [ ] Resolve the current page's most specific non-root parent container from the depot schedule traversal, with course-root fallback.
  - [ ] Use `SectionResourceDepot.retrieve_schedule/1` to build an in-memory page/container map.
  - [ ] Recursively collect non-hidden descendant page section resources from the selected container.
  - [ ] Query `Revision` once for descendant page `revision_id`s, selecting only `resource_id` and `activity_refs`.
  - [ ] Use `SectionResourceDepot.objectives_with_effective_children/1` and objective `related_activities` to filter objectives by in-scope activity refs.
  - [ ] Include parent objectives when only subobjectives directly match and return deterministic parent-before-child order.
  - [ ] Query `Metrics.proficiency_per_student_for_objective/3` only when at least one Summary element is present.
  - [ ] Add bounded telemetry or debug logging only if useful, without PII or authored content.
  - [ ] Add source comments around the recursive traversal and the single-query `activity_refs` boundary so future changes do not accidentally introduce N+1 behavior.
- Testing Tasks:
  - [ ] Add ExUnit tests for no-element skip behavior and no additional objective work.
  - [ ] Add ExUnit tests for depot-first traversal, one narrow revision query, in-container inclusion, out-of-container exclusion, parent inclusion, hidden-page exclusion, stale config tolerance, and newly discovered objective defaults.
  - [ ] Add tests proving Summary proficiency is queried only when a Summary element exists.
  - [ ] Run targeted delivery helper tests.
  - Command(s): `mix test <delivery-learning-objectives-page-element-test-target>`
- Definition of Done:
  - Delivery precomputation is bounded, depot-first, and isolated from the controller.
  - The helper returns render-ready objective data and optional proficiency without mutating delivery state.
  - Tests cover AC-017 through AC-023, AC-026, and AC-030.
- Gate:
  - Do not wire renderer output until discovery semantics and performance shape are covered by tests.
- Dependencies:
  - Phase 1 content type shape.
- Parallelizable Work:
  - Delivery helper implementation can proceed in parallel with Phase 3 UI after Phase 1 is complete.

## Phase 5: Student Rendering For Introduction And Summary
- Goal: Render student-facing Introduction and Summary output from precomputed delivery payload and per-element advisory config.
- Requirements Covered: FR-008, FR-009, FR-010; AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030.
- Tasks:
  - [ ] Use `images/mer-5807-student-introduction-collapsed.png` and `images/mer-5807-student-introduction-expanded.png` as local references for student Introduction layout, hierarchy, accordion collapsed state, accordion expanded state, spacing, and wrapping.
  - [ ] Add `learning_objectives` to `Oli.Rendering.Context`.
  - [ ] Add the rendering callback and dispatch through `Oli.Rendering.Content` and `Oli.Rendering.Content.Html`.
  - [ ] Add `Oli.Rendering.Content.LearningObjectives` to normalize element config and render Introduction/Summary markup.
  - [ ] Apply per-element enabled-state filtering and Include Sub-Objectives.
  - [ ] Normalize missing proficiency to Not Enough Information.
  - [ ] Map metrics labels to approved student-facing labels and icons in one helper.
  - [ ] Resolve Summary `revisit_pages` and `practice_pages` through one `SectionResourceDepot.get_resources_by_ids/2` call per element and ignore unresolved or out-of-section resources.
  - [ ] Ensure objective titles, Sub-Objective titles, and recommendation labels wrap across supported viewport sizes.
  - [ ] Add source comments for proficiency label mapping and recommendation resolution where the mapping or filtering would otherwise be easy to misread.
- Testing Tasks:
  - [ ] Add render tests for Introduction heading, hierarchy, Include Sub-Objectives, proficiency explanation accordion, and no proficiency/recommendations.
  - [ ] Add render tests for empty objective payload behavior.
  - [ ] Add render tests for Summary proficiency defaults, label/icon mapping, recommendation resolution, and stale recommendation filtering.
  - [ ] Add viewport/manual verification notes for long title wrapping against the saved MER-5807 student screenshots.
  - [ ] Run targeted renderer tests and any changed frontend style tests.
  - Command(s): `mix test <learning-objectives-renderer-test-target>`; `cd assets && yarn test <delivery-style-or-component-test-target>`
- Definition of Done:
  - Introduction and Summary render correctly from precomputed payloads.
  - Rendering is resilient to missing config, missing proficiency, and stale recommendation IDs.
  - Tests cover AC-022 through AC-030 for render behavior.
- Gate:
  - Do not proceed to workflow hardening until student rendering passes targeted automated tests.
- Dependencies:
  - Phase 4 delivery payload and Phase 3 persisted state shape.
- Parallelizable Work:
  - Static markup/style work can proceed in parallel with recommendation resolution tests after the renderer module contract is stable.

## Phase 6: Workflow Coverage, Hardening, And Review Readiness
- Goal: Prove the authoring-to-publish-to-delivery workflow and prepare the implementation for review.
- Requirements Covered: FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-007, FR-008, FR-009, FR-010; AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, AC-014, AC-015, AC-016, AC-017, AC-018, AC-019, AC-020, AC-021, AC-022, AC-023, AC-024, AC-025, AC-026, AC-027, AC-028, AC-029, AC-030.
- Tasks:
  - [ ] Add scenario coverage for authoring an element, publishing, creating or updating a section, adding a later objective elsewhere in the same container, publishing again, and verifying delivery includes the current discovered set.
  - [ ] Confirm pages without the element render unchanged, including current attempts and page text-cache behavior.
  - [ ] Confirm all six saved UX screenshots remain present and referenced from this plan before PR handoff.
  - [ ] Audit source comments added during implementation for adequacy and restraint: comments should explain reconciliation timing, traversal/query constraints, and label mapping, not duplicate obvious code.
  - [ ] Review telemetry/logging for bounded fields and absence of PII, authored content, and raw student responses.
  - [ ] Prepare review notes for required security and performance review, plus Elixir, TypeScript, UI, and requirements review.
  - [ ] Update `requirements.yml` proofs after implementation evidence exists.
- Testing Tasks:
  - [ ] Validate any new scenario YAML.
  - [ ] Run targeted scenario ExUnit coverage.
  - [ ] Run targeted backend tests for delivery and rendering.
  - [ ] Run targeted frontend tests for page model and editor UI.
  - [ ] Run format/lint gates for touched files.
  - Command(s): `mix run -e 'Oli.Scenarios.validate_file!(\"test/scenarios/<scenario-file>.scenario.yaml\")'`; `mix test <scenario-runner-test-target>`; `mix test <delivery-and-render-test-targets>`; `cd assets && yarn test <frontend-test-targets>`; `mix format <changed-elixir-files>`; `cd assets && yarn lint`; `cd assets && yarn format`
- Definition of Done:
  - End-to-end workflow coverage passes.
  - Targeted unit, integration, rendering, and frontend tests pass.
  - Source comments are present where they preserve non-obvious intent and absent where they would add noise.
  - Security, performance, Elixir, TypeScript, UI, and requirements review readiness is documented.
- Gate:
  - Implementation is ready for PR only after all targeted tests and harness requirements validation pass.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Review preparation, source-comment audit, and requirements proof updates can proceed while final scenario coverage is being stabilized.

## Parallelization Notes
- Phase 1 is the main dependency for all implementation work because it defines the content shape and insertion rules.
- Phase 2 backend resolver work and frontend reconciliation helper tests can be split once the response shape is fixed.
- Phase 3 authoring UI and Phase 4 delivery helper work can proceed in parallel after Phase 1 because they share only the content JSON contract.
- Phase 5 rendering can start with fixture payloads while Phase 4 discovery tests are being finalized, then switch to the real helper contract before the phase gate.
- Phase 6 should remain last because it validates cross-boundary behavior and final review readiness.

## Phase Gate Summary
- Gate A: Page model, schema, and insertion policy are test-covered before UI/editor work depends on them.
- Gate B: Authoring objective resolution and page-load reconciliation are stable before the editor persists real configuration.
- Gate C: Authoring UI can create and edit valid element state before delivery rendering consumes it.
- Gate D: Delivery discovery is depot-first, bounded, and tested before renderer integration.
- Gate E: Student rendering handles Introduction, Summary, stale config, recommendations, and wrapping before workflow tests.
- Gate F: Scenario coverage, targeted tests, source-comment audit, telemetry/privacy review, and harness validation pass before PR handoff.
