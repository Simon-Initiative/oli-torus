# MER-5799 Coverage Issues Filter - Product Requirements Document

## 1. Overview

Add a project-configurable Coverage Issues filter to the Learning Objectives authoring workspace.

## 2. Background & Problem Statement

Authors need to find objectives and sub-objectives with too few formative or summative activities without manually inspecting every card.

## 3. Goals & Non-Goals

### Goals

- Identify insufficient formative and summative coverage using project thresholds.
- Make issues visible and filterable in the existing objectives editor.
- Persist shared settings at project scope.

### Non-Goals

- Change objective/activity associations or coverage source data.
- Implement the separate search or course-content filter tickets.

## 4. Users & Use Cases

- Project authors: configure coverage thresholds and identify objectives needing practice or assessment opportunities.

## 5. UX / UI Requirements

- Follow the linked Learning Objectives Updates Figma designs, including dark mode and accessible keyboard/focus/status behavior.
- Compose with Rafael's search, sort, pagination, expansion, and URL-patch conventions from MER-5797.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Evaluate issues from the request-scoped in-memory ObjectiveCoverage model; do not introduce per-row queries.
- Preserve authoring authorization and project scoping.
- Provide accessible names, state, and non-color issue indications.

## 9. Data, Interfaces & Dependencies

- Store formative and summative thresholds in `projects.attributes` through `ProjectAttributes`, shared by project authors; defaults are 3 and 3.
- Depend on MER-5794 core UI/coverage model and integrate with MER-5797 after it merges.
- Figma: Learning Objectives Updates nodes 365-14554 and 365-17228.

## 10. Repository & Platform Considerations

- Use Phoenix LiveView for editor state and Ecto embedded project attributes for persistence.
- Keep domain/persistence logic outside rendering components.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics

- Reuse existing error/latency observability for coverage loading; do not emit content bodies.

## 13. Risks & Mitigations

- MER-5797 integration changes URL/filter state: align with its table-handler and patch conventions before final integration.
- Shared-settings interpretation conflicts with older ticket wording: follow Darren Siegel's project-level direction.
- Figma pedagogy link is unpublished: do not invent a destination; obtain it from product before release.

## 14. Open Questions & Assumptions

### Open Questions

- What published URL should the Learn more control use?

### Assumptions

- A parent is included when it or any descendant sub-objective has an issue.
- Project-level thresholds apply to all project authors.

## 15. QA Plan

- Automated validation:
  - Focused ExUnit changeset/coverage and LiveView state-transition tests.
- Manual validation:
  - Verify Figma parity, keyboard operation, dark mode, and combined search/filter/sort behavior.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
