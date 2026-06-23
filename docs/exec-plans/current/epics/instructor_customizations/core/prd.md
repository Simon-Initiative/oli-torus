# Instructor Activity Customization Core - Product Requirements Document

## 1. Overview
Instructor Activity Customization Core enables instructors to remove and restore assessment or practice questions for a specific course section and basic page without changing authored course content, publication records, or section resources. The first slice covers delivery-side persistence, validation, attempt-time application, and scenario-testable APIs for embedded activities, entire activity bank selections, and individual activity bank candidates.

This work is the core implementation lane for `MER-5639` under the Instructor Customization of Assessments epic. Later UI lanes will consume this slice to render controls, candidate-management screens, counters, and navigation affordances.

## 2. Background & Problem Statement
Today, authored page content and published section content are the durable source for what learners encounter. Instructors need a way to tailor questions in a live section, but mutating authored revisions, creating new publications, or editing section resources would violate Torus's publication and delivery stability model.

The problem is to introduce instructor-owned delivery configuration that is scoped tightly enough to avoid accidental cross-section, cross-page, or cross-selection effects, while still applying reliably before new learner attempts are created. Existing attempts must remain stable because they already store transformed content and activity attempts.

## 3. Goals & Non-Goals
### Goals
- Store instructor customization state outside authored page revisions, publications, and section resource records.
- Support section-specific and page-specific exclusion and restoration of embedded activities, whole activity bank selections, and selection-local bank candidates on basic pages.
- Apply customization during new attempt creation before activity attempts and transformed page content are persisted.
- Preserve existing attempts and instructor Student Preview attempts until a new attempt is created.
- Keep all validation, authorization, lookup, and bank-count rules behind a delivery context API.
- Provide scenario-testable non-UI behavior before UI implementation begins.
- Keep delivery-time lookup efficient by reading page exclusion state once per section and page.

### Non-Goals
- Adaptive page customization is not included in this slice.
- UI layout, visual design, bulk selection, filtering, counters, and jump navigation are owned by later epic lanes.
- This work does not create new publications, revise source project content, or mutate section resources.
- This work does not alter, invalidate, or rebuild historical or active attempts.
- This work does not require an audit trail for who created or removed an exclusion.

## 4. Users & Use Cases
- Instructors: Disable or restore questions for one course section and page so learners receive a tailored assessment or practice experience on future attempts.
- Course delivery administrators: Support instructor-owned section customization without destabilizing authored content or other sections.
- Students: Encounter only the currently enabled activities when a new page attempt is created, while previously created attempts remain consistent.
- UI implementation teams: Consume a stable context API and read model for page-level and selection-level customization state.
- QA and engineering: Validate the full non-UI workflow through Oli.Scenarios without relying on browser automation.

## 5. UX / UI Requirements
- The core slice must expose APIs that later Instructor Preview UI controls can call to enable or disable embedded activities, whole bank selections, and bank candidates.
- The core slice must expose read models that let UI surfaces render current enabled or disabled state for page content and activity bank candidate lists.
- UI clients may present optimistic state, but server-side context functions remain authoritative for authorization, target validation, and the bank selection count rule.
- Static instructor preview routes that render filtered content or controls must read the same customization state as delivery; active Student Preview attempts must remain attempt-consistent until reset or completion creates a new attempt.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: Exclusion rows that become stale after republishing, selection changes, activity deletion, or bank logic changes must not break delivery or UI reads.
- Security: Writes must require instructor permission for the target section or an admin-equivalent permission, centralized in `Oli.Delivery.InstructorCustomizations`.
- Privacy: The feature stores section, page, selection, and activity resource identifiers only; no learner response data or authored content snapshots are persisted by this customization table.
- Performance: New attempt creation must load all customization state for a section and page with one page-level query before activity realization.
- Accessibility: Later UI surfaces must expose enable and disable states accessibly, but this core slice only defines the data and server behavior needed by those surfaces.
- Compatibility: Practice and graded basic pages must both use the same attempt-time customization behavior.

## 9. Data, Interfaces & Dependencies
- Add a delivery-owned exclusion table, expected to be named `section_page_activity_exclusions` or equivalent, with one active exclusion per row.
- Exclusion state is scoped by `section_id` and `page_resource_id`; selection-scoped rows also include the authored `selection_id`.
- Exclusion kinds must distinguish embedded activities, whole bank selections, and bank candidates.
- Embedded activity and bank candidate exclusions identify activities by activity resource id; whole bank selection exclusions are identified by page resource id, selection id, and kind.
- Restore behavior is modeled by deleting the matching active exclusion row.
- The primary backend boundary is `Oli.Delivery.InstructorCustomizations`.
- Delivery integration depends on the current new-attempt path around `Oli.Delivery.Attempts.PageLifecycle.Hierarchy.create/1`, `Oli.Delivery.ActivityProvider.provide/6`, activity references, selection fulfillment, and transformed content persistence.
- Scenario coverage may require extending the Oli.Scenarios directive set for section/page activity, selection, and candidate enable or disable operations.

## 10. Repository & Platform Considerations
- Follow Phoenix context boundaries: domain rules belong under `lib/oli/`, while controllers, LiveViews, scenario handlers, and UI endpoints should remain thin callers.
- Respect the resource/revision and publication model: use page resource ids for customization scope so state survives page republishing when the same page resource receives a new revision.
- Do not rely on `SectionResource` records for this feature.
- Keep selection-specific bank candidate exclusions local to one selection; do not add them to a page-wide blacklist that affects other selections.
- Use Ecto constraints and indexes to enforce idempotent toggles and efficient page-level reads.
- Use targeted ExUnit and Oli.Scenarios tests for backend and workflow validation.
- Instructor Preview may be served by LiveView or legacy controller-backed paths; this core must stay independent of that transport layer and integrate with the active preview owner in later UI work.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

The rollout is additive: introduce the new table, context, delivery-time filtering, and scenario coverage before UI lanes call the APIs. Existing courses and attempts should continue to behave unchanged unless an instructor customization row exists for the section and page.

## 12. Telemetry & Success Metrics
- Emit or preserve operational visibility for customization writes and delivery-time application using existing Torus telemetry or logging patterns where appropriate.
- Success is measured by scenario coverage proving section/page/selection isolation, stable historical attempts, correct new-attempt filtering, and bank count guardrails.
- Delivery-time customization should not introduce repeated database reads per activity or selection during a single page attempt creation.

## 13. Risks & Mitigations
- Risk: Customization accidentally affects another section, page, or selection. Mitigation: scope uniqueness constraints and read models by section, page resource, selection id when relevant, and exclusion kind.
- Risk: Candidate exclusions make a bank selection impossible to fulfill. Mitigation: enforce the minimum active candidate count in server-side write functions.
- Risk: Existing attempts change after an instructor toggles customization. Mitigation: apply filtering only during new attempt creation and never rewrite stored transformed content for active or historical attempts.
- Risk: Republished or changed content leaves stale exclusion rows. Mitigation: tolerate stale rows in reads and ignore exclusions that no longer match current page content or selection logic.
- Risk: Delivery performance regresses on activity-heavy pages. Mitigation: load a compact page exclusion view once and pass it into activity realization.

## 14. Open Questions & Assumptions
### Open Questions
- Should a future cleanup job remove stale exclusions for permanently deleted pages, sections, or resources, or should stale rows remain indefinitely until an operational need appears?
- Which existing authorization helper should be treated as the canonical instructor/admin permission for `:customize_section` writes?
- Should telemetry be a new named event family for this feature, or should implementation rely on existing delivery/context instrumentation patterns?

### Assumptions
- `MER-5639` is the Core-Impl lane for the Instructor Customization of Assessments epic.
- Embedded activity exclusions are keyed by activity resource id, not authored activity-reference element id.
- Instructor customizations apply only when a new attempt is created.
- Instructors may disable an entire bank selection, but may not disable individual bank candidates below the selection's configured count.
- No audit trail is required for this slice.
- Adaptive pages remain unsupported by this initial implementation.

## 15. QA Plan
- Automated validation:
  - ExUnit coverage for schema changesets, context idempotency, target validation, authorization errors, and read model conversion.
  - Activity provider tests for embedded activity filtering, whole selection filtering, selection-local candidate filtering, score/out-of behavior, and transformed content persistence.
  - Oli.Scenarios coverage for real authoring, publishing, section, and attempt workflows across practice and graded basic pages.
  - Scenario DSL validation and targeted scenario runner execution for new directives.
- Manual validation:
  - Developer smoke checks in Instructor Preview or equivalent routes once UI callers exist.
  - Confirm active Student Preview attempts remain unchanged until reset or completion creates a new attempt.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
