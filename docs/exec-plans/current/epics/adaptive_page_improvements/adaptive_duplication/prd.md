# Adaptive Duplication - Product Requirements Document

## 1. Overview
Enable authors to duplicate adaptive pages within a project from the same curriculum entry points used for basic pages. The duplicated adaptive page must create a new page revision and new screen/activity resources, preserve authored screen order and trap-state logic, and remap page-level internal references so the copied page points at the copied screens rather than the original ones.

Links:
- `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_duplication/informal.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/overview.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/plan.md`
- Jira ticket `MER-4082`

## 2. Background & Problem Statement
Basic pages can already be duplicated from curriculum authoring, but adaptive pages cannot. The current UI explicitly hides the duplicate action for adaptive pages, and the existing backend duplication path only performs a generic deep copy of page `activity-reference` nodes without adaptive-specific remapping.

Adaptive pages carry additional structure that makes duplication riskier than regular pages. The adaptive page revision content is the screen sequence map: `content.advancedDelivery = true`, `content.model[0].children[*].type = "activity-reference"`, each child stores `activity_id`, and each child also stores `custom.sequenceId` and `custom.sequenceName`. A concrete repository example appears in `test/oli/conversation/adaptive_page_context_builder_test.exs`, where the page content maps screen sequence entries to adaptive activity resources.

Each referenced adaptive screen/activity also has authored internal state that depends on stable IDs. Repository examples show adaptive activity content with `partsLayout`, `authoring.parts`, and `authoring.rules`; rules reference part IDs through facts like `stage.dropdown_1.selectedIndex`, and adaptive link-like content can exist in nested paths such as `content.partsLayout[].custom.nodes` or `authoring.parts[].model`. Concrete examples appear in `test/oli/delivery/attempts/activity_lifecycle/evaluate_test.exs`, `test/oli/activities/adaptive_parts_test.exs`, and `test/oli/interop/rewire_links_test.exs`.

Without an adaptive-specific duplication flow, authors must recreate adaptive pages manually, which is slow and error-prone. If duplication copies the page but leaves references pointing at original screens or stale internal IDs, the copied lesson can behave incorrectly and may corrupt author intent.

## 3. Goals & Non-Goals
### Goals
- Allow adaptive pages to expose the duplicate action in curriculum authoring when the feature is enabled.
- Duplicate an adaptive page by creating a new page revision plus new resources and revisions for each referenced adaptive screen/activity.
- Preserve authored screen order, `sequenceId`, `sequenceName`, and adaptive trap-state behavior in the copied page.
- Remap page-level activity references so the copied adaptive page references only copied adaptive screens.
- Fail closed when duplication cannot safely preserve required adaptive references.

### Non-Goals
- No cross-project cloning behavior; this work is only for duplication inside the same project.
- No redesign of adaptive authoring or flowchart authoring UX beyond enabling the existing duplicate affordance.
- No new learner-facing adaptive runtime features.
- No best-effort partial duplicate that leaves unresolved references behind.

## 4. Users & Use Cases
- Author: duplicates an adaptive page in a project curriculum to reuse an existing adaptive lesson as a starting point.
- Author: edits the duplicated adaptive page without affecting the original page or its original screens.
- Engineer or support staff: can diagnose duplication failures because the operation either succeeds with remapped references or fails without creating a broken duplicate.

## 5. UX / UI Requirements
- Adaptive pages shall expose the same duplicate action location used by duplicable basic pages in curriculum authoring when the feature flag is enabled.
- When duplication succeeds, the copied entry shall appear in curriculum with the standard copied-title convention already used by page duplication.
- When duplication fails, authoring shall show a clear error flash and shall not leave behind a partially duplicated page entry.
- The duplicate control must remain keyboard reachable and match the existing curriculum dropdown interaction model.
- No new standalone adaptive duplication UI or wizard is required for this work item.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Duplication shall run transactionally so a failure in page creation, screen duplication, or reference remapping rolls back the operation.
- The adaptive-specific duplication path shall preserve project authorization and authoring boundaries already enforced for basic page duplication.
- The operation shall not mutate the original adaptive page or any original adaptive screen/activity revisions.
- Performance should remain acceptable for normal adaptive pages by avoiding unnecessary repeated lookups and by remapping identifiers in a bounded traversal of the duplicated payloads.
- Reliability takes priority over convenience: if required adaptive references cannot be resolved or rewritten safely, the system must fail closed.

## 9. Data, Interfaces & Dependencies
- Adaptive page content currently stores screen membership and order in page revision JSON. A concrete repository fixture shows:
  - `advancedDelivery: true`
  - `model[0].type: "group"`
  - `model[0].layout: "deck"`
  - `model[0].children[*].type: "activity-reference"`
  - `model[0].children[*].activity_id: <screen resource id>`
  - `model[0].children[*].custom.sequenceId` and `custom.sequenceName`
- Adaptive screen/activity content stores authored runtime state inside its revision content, including:
  - `partsLayout[*].id` and `type`
  - `authoring.parts[*].id` and `type`
  - `authoring.rules[*].conditions[*].fact` references such as `stage.<part_id>...`
  - possible nested internal-link structures in adaptive rich-content payloads
- The implementation depends on specializing the current `ContainerEditor.duplicate_page/4` flow so adaptive pages do not use the generic basic-page duplication mapper unchanged.
- The work depends on existing authoring resource/revision creation, adaptive activity creation/editing semantics, and any existing link-rewrite or ID-rewrite helpers that can be reused safely.

## 10. Repository & Platform Considerations
- Current curriculum authoring intentionally hides the duplicate action for adaptive pages in `lib/oli_web/live/curriculum/entries/actions.ex`, and existing LiveView coverage asserts that behavior in `test/oli_web/live/curriculum/container_test.exs`.
- Current basic-page duplication is implemented in `lib/oli/authoring/editing/container_editor.ex` and deep-copies page `activity-reference` nodes generically; that path must remain intact for non-adaptive pages while adaptive pages take a specialized implementation.
- The design must respect the Torus resource/revision model: duplication means new resources and new revisions, not edits to existing published or authoring resources.
- Backend domain rules belong in `lib/oli/...`; LiveView should remain a thin caller that surfaces success or failure.
- Expected verification should include targeted ExUnit coverage for duplication/remapping behavior and LiveView coverage for the duplicate affordance and failure handling.

## 11. Feature Flagging, Rollout & Migration
- This work item requires a canary rollout feature with slug `adaptive_duplication`.
- The duplicate affordance for adaptive pages and the adaptive-specific duplication backend path shall be gated together so disabled environments preserve current behavior.
- A rollout data migration should seed the global stage to `full` so the feature is available by default after deployment while retaining an Admin kill switch.
- Rollout should be managed through the repository's incremental feature rollout process so administrators can set the global stage to `full` for normal operation and quickly return it to `off` if post-deployment issues are reported.

## 12. Success Metrics
- Success signal: authors can duplicate adaptive pages without manual recreation, and copied pages reference copied screens rather than originals.
- Failure signal: duplication fails closed instead of producing broken copied pages.
- No feature-specific telemetry, metrics, dashboards, or AppSignal instrumentation are required for this work item.

## 13. Risks & Mitigations
- Risk: copied adaptive pages could still reference original screen resources.
  - Mitigation: build the duplicate as a two-phase mapping flow that first creates copied screen resources, then rewrites the copied page’s `activity-reference.activity_id` values from old-to-new.
- Risk: adaptive screen behavior could break because internal authored references depend on stable part IDs or nested content paths.
  - Mitigation: audit and cover the known adaptive payload shapes in tests, including `partsLayout`, `authoring.parts`, `authoring.rules`, and nested adaptive link content.
- Risk: adaptive duplication work could regress existing basic-page duplication.
  - Mitigation: explicitly branch adaptive and non-adaptive duplication logic and keep current basic-page tests passing.
- Risk: partial duplicates could be left behind when one screen copy fails mid-operation.
  - Mitigation: keep duplication transactional and rollback on any failed copy or remap step.

## 14. Open Questions & Assumptions
### Open Questions
- Which adaptive payload paths beyond the currently known `partsLayout`, `authoring.parts`, `authoring.rules`, and nested adaptive link nodes require identifier remapping for full safety?
- Should adaptive duplication reuse existing ID/link rewrite helpers directly, or should it introduce an adaptive-specific mapper to avoid unintended behavior on basic pages?
- Do any adaptive screen templates or trap-state authoring constructs maintained primarily by Devesh require additional review before implementation is finalized?

### Assumptions
- Duplication is only expected within the same project, so copied adaptive screens remain valid in the same project resource namespace.
- `custom.sequenceId` and `custom.sequenceName` are part of the author-intended adaptive flow and must be preserved on the copied page unless an implementation-level reason requires regeneration.
- Blocking duplication is preferable to creating a duplicate with unresolved internal references.

## 15. QA Plan
- Automated validation:
  - Add backend ExUnit coverage for adaptive page duplication that verifies new screen resources are created, page `activity-reference` entries are remapped, and original resources remain unchanged.
  - Add targeted tests for failure handling when adaptive references cannot be safely duplicated or remapped.
  - Update LiveView tests so adaptive pages expose the duplicate action only when the feature is enabled and continue to surface author-facing errors on failure.
  - Preserve or extend existing basic-page duplication coverage to prove non-adaptive behavior does not regress.
- Manual validation:
  - Duplicate an adaptive page from curriculum authoring and confirm the copied page appears with copied-title naming.
  - Open both original and copied adaptive pages and confirm edits to copied screens do not alter the original screens.
  - Verify known internal adaptive references, including screen sequence ordering and trap-state behavior, continue to function on the copied page.
  - Verify a forced failure path does not leave a copied page or copied screens behind.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
