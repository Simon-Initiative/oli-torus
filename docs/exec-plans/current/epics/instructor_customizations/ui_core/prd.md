# Activity Bank Selection and Embedded Question Remove/Restore - Product Requirements Document

## 1. Overview

MER-5620 updates Instructor View so instructors can inspect and remove or restore entire Activity Bank selections on scored and practice pages without changing authored source content or affecting prior student progress. The work should use the existing Instructor Preview customization wiring so Activity Bank selection actions flow from preview UI to LiveView and then to `Oli.Delivery.InstructorCustomizations`.

Embedded question remove/restore was part of the original Jira scope, but that path is already implemented by the merged MER-5622 / PR 6659 work. This PRD keeps the original embedded-question scope visible for traceability while treating it as existing infrastructure, not remaining implementation.

## 2. Background & Problem Statement

Instructors need to tailor assessment and practice opportunities for a specific course section or template. Existing instructor customization infrastructure stores section/page-specific exclusions outside authored revisions, preserving source content and historical attempts. The remaining MER-5620 gap is the Activity Bank Selection preview experience: showing the selection details, exposing a single remove/restore action for the whole selection, reflecting removed state in the UI, and warning instructors that changes apply only to future attempts when learners have already started or visited the page.

The shared contract in `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md` defines the LiveView/React boundary for preview customization. MER-5620 should extend or reuse that contract for `bank_selection` targets rather than introducing a separate client/server communication path.

## 3. Goals & Non-Goals

### Goals

- Render Activity Bank selections in the updated Instructor View preview UI with selection metadata and a sample question.
- Allow authorized instructors to remove and restore an entire Activity Bank selection for the current page and section/template scope.
- Route whole-selection actions through the existing preview customization contract and core instructor customization implementation.
- Clearly communicate removed state without hiding the sample question preview.
- Warn instructors when existing attempts or page visits mean customization changes apply only to future attempts.
- Preserve student progress and historical attempts.
- Keep authored source content, other pages, and other sections unaffected.

### Non-Goals

- Reimplement embedded activity remove/restore; that is already covered by merged MER-5622 / PR 6659 work.
- Manage individual candidate questions inside an Activity Bank selection; that belongs to the bank selection manager flow and related tickets.
- Add bulk candidate actions, candidate filtering, or search.
- Change authored selection logic, authored page revisions, or published source content.
- Retrospectively rewrite existing attempts.
- Introduce a new preview communication pattern outside the shared wiring contract.

## 4. Users & Use Cases

- Instructor: remove an entire Activity Bank selection from a scored or practice page so future learners do not receive questions from that selection.
- Instructor: restore a previously removed Activity Bank selection when the selection should become available again for future attempts.
- Instructor: inspect how many questions are available, how many are selected, points per question, authored selection criteria, and a sample question before deciding whether to remove the selection.
- Instructor: understand that changes after students have started or visited a page affect future attempts only.
- Author or template-level operator: apply the same remove/restore capability at template level when the owning workflow supports instructor customization.
- QA reviewer: verify that removing a selection is page-scoped and does not affect authored content, other pages, or previous student progress.

## 5. UX / UI Requirements

- Activity Bank selections must follow the approved Instructor View and Figma UI patterns.
- Each selection preview must display a heading, number of available questions, select count, points per question, authored selection criteria, and one sample question from the available questions.
- Active selections must display one remove action; removed selections must display one restore action.
- Removed selections must be visually distinct using the approved removed-state treatment: red border or accent, gray background, and a "Removed" pill or badge.
- The sample question must remain visible and keyboard-operable even when the selection is removed.
- Success confirmations must appear above the affected selection after remove or restore.
- Existing-attempt warning content must appear at the top of the page when applicable.
- Warning modal behavior must confirm remove/restore when existing attempts or visits are present.
- Remove and Restore buttons must be keyboard accessible, have visible focus states, include accessible labels, and preserve hover/disabled states.
- Design references:
  - Activity Bank Selection: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=185-8959&t=T9wp5xcQh1vNqdxN-1
  - Success Messages: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=379-7382&t=T9wp5xcQh1vNqdxN-1
  - Attempts started: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=286-8247&t=T9wp5xcQh1vNqdxN-1
  - Warning Modals: https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=379-8630&t=T9wp5xcQh1vNqdxN-1

## 6. Functional Requirements

Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)

Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Accessibility: all remove/restore controls must be keyboard accessible, visibly focusable, and understandable to screen readers.
- Reliability: remove/restore actions must be idempotent from the user perspective and must leave the UI in a recoverable state on failure.
- Security: LiveView must revalidate target identity, current page scope, and authorization before dispatching writes to the domain context.
- Performance: Activity Bank Selection preview and count updates should reuse existing page preview data and avoid introducing per-candidate query loops in render paths.
- Privacy: warning and success messages must not expose learner-specific attempt details.
- Compatibility: the feature must preserve the existing mixed LiveView/React preview model and must not disrupt embedded activity preview behavior already merged.

## 9. Data, Interfaces & Dependencies

- Uses `Oli.Delivery.InstructorCustomizations` as the authority for authorization, target validation, persistence, and read models.
- Uses the preview customization wiring contract in `docs/exec-plans/current/epics/instructor_customizations/preview_customization_wiring.md`.
- Requires `bank_selection` preview targets with `pageResourceId` and `selectionId`.
- Should reuse existing `actions`, `customizationTarget`, `visualState`, and `statusPill` preview context concepts where applicable.
- LiveView remains responsible for screen-level state: flashes, warning banner/modal state, page-level counts, and any aggregate updates.
- React preview components remain responsible for local UI state and dispatching customization intents.
- Depends on existing core implementation from MER-5639 and existing preview component infrastructure from MER-5618.
- Must not alter student attempts that were already created before a remove/restore action.

## 10. Repository & Platform Considerations

- Backend changes belong in `lib/oli/` contexts for domain behavior and `lib/oli_web/` LiveViews/hooks/templates for transport and UI orchestration.
- Frontend changes should stay within the existing React preview component and Phoenix hook model under `assets/src/`.
- Delivery customization must respect the publication/resource/revision model and avoid mutating authored content.
- Tests should use targeted ExUnit, LiveView, TypeScript/Jest, or scenario coverage depending on the final implementation boundary.
- Code review should include security and performance lenses by default, plus Elixir, TypeScript, UI, and requirements review where touched files warrant them.
- Jira `MER-5620` remains the issue-tracking system of record for this work item.

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Success signal: instructors can remove and restore whole Activity Bank selections in Instructor View without regressions to embedded activity remove/restore.
- Success signal: future attempts exclude removed selections and include restored selections.
- Success signal: existing attempts and student progress remain unchanged.
- Operational signal: LiveView/domain errors for invalid targets, unauthorized writes, and failed persistence should remain observable through existing logging, telemetry, and AppSignal paths.
- Product telemetry beyond existing platform signals is not required unless the implementation already exposes a suitable customization event.

## 13. Risks & Mitigations

- Risk: duplicating the embedded activity implementation could introduce inconsistent behavior. Mitigation: treat MER-5622 / PR 6659 embedded remove/restore as existing infrastructure and only extend the path for `bank_selection`.
- Risk: Activity Bank Selection counts could become stale after remove/restore. Mitigation: derive counts from the same server-owned customization state used by delivery and refresh affected UI from LiveView replies or assigns.
- Risk: removed selections could look active. Mitigation: use explicit `visualState` and `statusPill` values instead of inferring state only from button labels.
- Risk: stale or malformed browser events could mutate the wrong target. Mitigation: validate payload shape in the hook, validate page/selection target in LiveView, and rely on `Oli.Delivery.InstructorCustomizations` for domain validation and authorization.
- Risk: template-level customization may not propagate to future course sections. Mitigation: copy blueprint `section_page_activity_exclusions` during section duplication from a customized template, while leaving already-created sections unchanged.

## 14. Open Questions & Assumptions

### Open Questions

- Should the Activity Bank Selection user-facing action copy be "Remove/Restore" everywhere, or should any surface use "Enable/Disable" copy from the Jira comment?
- What exact attempt/visit signal determines whether the warning banner and confirmation modal are shown for practice pages?
- Should the "Saving..." and "Changes have been saved" messages reuse existing preview flash behavior or require a distinct save-status component?

### Assumptions

- Embedded activity remove/restore is complete enough to be reused as the reference implementation for this ticket.
- Activity Bank Selection remove/restore maps to `Oli.Delivery.InstructorCustomizations.exclude_bank_selection/4` and `restore_bank_selection/4`, or equivalent core APIs.
- Removed Activity Bank selections remain visible in Instructor View and keep their sample question operable.
- Changes apply only to future page views or attempts and do not modify existing attempts.
- Template-level UI is reached through Product/Template Customize Content page Edit links, which use the same instructor-style `PreviewLessonLive` route for the blueprint section.
- Future course sections created from a customized template inherit the template's activity exclusions; already-created sections do not receive later template customization changes.
- This ticket does not include individual bank candidate management.

## 15. QA Plan

- Automated validation:
  - Add or update LiveView tests for `bank_selection` remove/restore event handling, target validation, success/error replies, and warning state where server-owned.
  - Add or update context tests if whole-selection behavior has gaps in `Oli.Delivery.InstructorCustomizations`.
  - Add or update frontend tests for Activity Bank Selection preview state, action rendering, disabled/loading behavior, removed visual state, and accessibility-critical labels.
  - Add scenario coverage if final behavior crosses authoring, publishing, section delivery, and future attempt creation.
- Manual validation:
  - Verify Activity Bank Selection preview against Figma in active and removed states.
  - Verify remove/restore on scored and practice pages before and after attempts or visits exist.
  - Verify future attempts reflect selection removal/restoration while existing progress remains unchanged.
  - Verify embedded activity remove/restore still works after bank-selection changes.
  - Verify keyboard navigation, focus states, screen-reader labels, warning content, and success confirmations.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
- [ ] Activity Bank Selection preview displays required metadata and sample question
- [ ] Whole-selection remove/restore routes through the shared preview customization contract
- [ ] Warning messaging for future-attempt-only changes is implemented and verified
- [ ] Embedded activity remove/restore remains unchanged and regression-tested where relevant
- [ ] Automated and manual QA expectations are satisfied
