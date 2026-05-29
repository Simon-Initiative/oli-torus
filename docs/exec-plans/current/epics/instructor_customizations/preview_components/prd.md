# Preview Components - Product Requirements Document

## 1. Overview
`MER-5618` introduces a first-class `preview` rendering mode for supported activity types in Instructor View and replaces the current authoring-derived instructor preview for those activities with a simplified, read-only, instructor-facing question UI. The new experience must let instructors inspect the authored activity in context without exposing authoring controls they cannot use, while preserving the existing Instructor View behavior for unsupported or advanced activity types on mixed pages.

## 2. Background & Problem Statement
Today basic-page Instructor View reuses authoring web components in `mode="instructor_preview"` with editing disabled. That approach leaks authoring-specific structure, settings, and controls into an instructor workflow that is now expected to look and behave like a distinct instructional review surface. Jira for `MER-5618` requires a simplified question layout, details accordion, answer key, hints, explanation, and learning objective display for a defined set of supported activity types, while explicitly deferring remove/restore controls to future tickets. Without a dedicated preview mode, the implementation would continue to accumulate activity-specific `instructor_preview` branches inside authoring components, increasing coupling and making later instructor customization work harder to reason about.

## 3. Goals & Non-Goals
### Goals
- Introduce `preview` as the instructor-facing rendering mode for the `MER-5618` supported activity set.
- Render the new instructor-facing question UI for supported activity types in Instructor View.
- Preserve read-only behavior so instructors can inspect but not edit activity content, feedback, hints, explanations, or answer keys.
- Support mixed pages where preview-backed supported activities coexist with legacy Instructor View rendering for unsupported or advanced activities.
- Establish a stable preview rendering contract that later customization tickets can attach to without reworking the rendering architecture.

### Non-Goals
- Remove/restore actions for embedded questions or activity bank selections.
- Candidate-level management inside activity bank selections.
- Learning objective summary counters or overall points counters that aggregate page-level customization changes.
- New entry points into Instructor View or return-to-origin workflow changes.
- Adaptive page preview redesign or migration of unsupported activity types into the new question UI.
- Backend customization write APIs, persistence, and validation for enable/disable behavior.

## 4. Users & Use Cases
- Instructor: opens a page in Instructor View to understand what students will encounter and what the correct answers, hints, explanations, points, and learning objectives are for supported questions.
- Author or admin at template level: reviews supported activities in the same Instructor View experience without being able to edit them from that surface.
- Engineering team: uses the new preview contract as the rendering foundation for later tickets that add remove/restore and activity bank management behaviors.

## 5. UX / UI Requirements
- Supported activities in Instructor View must render using the approved simplified question layout from Figma.
- The supported activity set for this story is limited to:
  - Multiple Choice
  - Check All That Apply
  - Multi Input
  - Image Hotspot
  - Likert
  - Ordering
  - Directed Discussion
- Each supported preview must display:
  - activity type
  - points earned if correct
  - authored activity title
  - activity/question content
  - attached learning objectives or sub-objectives
  - a collapsed-by-default details accordion
- The details accordion must:
  - show `View Details` when collapsed
  - show `Hide Details` when expanded
  - reveal authored answer key, hints, and explanation sections when those sections exist
- When an activity contains multiple parts or selections, the answer key presentation must reflect the currently selected part and show points per part where authored.
- Preview UI must not expose authoring-only actions or labels such as scoring configuration controls, `add hint`, or `add feedback`.
- Unsupported or advanced activity types must continue using the existing Instructor View experience rather than being forced into the new layout.
- Canonical Figma references for the supported activity set are:
  - Multiple Choice
    - collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-26445&t=9kXK3bwjonVWOQAp-4`
    - expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-26375&t=9kXK3bwjonVWOQAp-4`
    - collapsed view: shows activity type, points, title, prompt, visible answer choices, learning objective text, and a collapsed `View Details` affordance.
    - expanded view: keeps the same question shell and reveals tabs for `Answer Key`, `Hints`, and `Explanation`; the answer-key tab shows the selected correct option plus authored feedback panels and learning-objective content.
  - Check All That Apply
    - collapsed/expanded reference currently points to the same node: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-26478&t=9kXK3bwjonVWOQAp-4`
    - collapsed view: should show activity type, points, title, prompt, visible checkbox choices, learning objectives, and a collapsed `View Details` affordance following the common card pattern.
    - expanded view: shows tabs for `Answer Key`, `Hints`, and `Explanation`; the answer-key tab shows which checkboxes are correct, authored correct/incorrect feedback, and associated learning objectives.
    - note: if the node still shows a collapsed-state label inconsistency such as `Hide Details` instead of `View Details`, Jira acceptance criteria remain authoritative for final behavior.
  - Likert
    - collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-7528&t=9kXK3bwjonVWOQAp-4`
    - expanded: design gap; no final expanded-state node has been identified yet
    - collapsed view: grounded in the referenced node and expected to follow the shared question-card pattern for prompt and visible response scale/options.
    - expanded view: unresolved because no final node has been identified; tabs or detail sections must be confirmed in design or defined during FDD.
  - Ordering
    - collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-7271&t=9kXK3bwjonVWOQAp-4`
    - expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-7274&t=9kXK3bwjonVWOQAp-4`
    - collapsed view: shows the standard header plus prompt and the visible ordering list without the lower details region.
    - expanded view: reveals tabs for `Answer Key`, `Hints`, and `Explanation`; the answer-key tab shows the correct final ordering, authored feedback panels, and learning-objective content.
  - Image Hotspot
    - expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-23084&t=9kXK3bwjonVWOQAp-4`
    - collapsed: inferred from the expanded design by removing the lower details region and using the collapsed `View Details` label
    - collapsed view: inferred to show the standard header, prompt, hotspot image, and collapsed `View Details` affordance, without any lower detail panels.
    - expanded view: reveals tabs for `Answer Key`, `Hints`, and `Explanation`; the answer-key area shows hotspot options, correct/incorrect feedback, targeted feedback blocks, and related learning objectives.
  - Directed Discussion
    - collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-8430&t=9kXK3bwjonVWOQAp-4`
    - expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-8431&t=9kXK3bwjonVWOQAp-4`
    - collapsed view: shows the standard header, prompt, and a read-only composer shell (`Create your new post...`) plus the collapsed details affordance.
    - expanded view: keeps the read-only composer and reveals tabs for `Participation` and `Hints`; the participation tab shows read-only participation settings such as required posts, maximum posts, required replies, maximum replies, and maximum words.
    - excluded behavior: preview should not imply a live thread, learner posts, or other interactive discussion state.
  - Multi Input
    - dropdown collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-26243&t=9kXK3bwjonVWOQAp-4`
    - dropdown expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=344-26144&t=9kXK3bwjonVWOQAp-4`
    - numeric collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=335-11048&t=9kXK3bwjonVWOQAp-4`
    - numeric expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=335-11333&t=9kXK3bwjonVWOQAp-4`
    - text collapsed: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=335-11807&t=9kXK3bwjonVWOQAp-4`
    - text expanded: `https://www.figma.com/design/wcAE7fov1FNgjpCA7KSO9m/Instructors-Customize-Assessments?node-id=372-6190&t=9kXK3bwjonVWOQAp-4`
    - collapsed view: shows the shared question shell plus the visible part prompt/input surface for the currently selected part.
    - expanded view: the lower detail region changes with the selected part and its input type; the design references indicate that dropdown, numeric, and text parts do not all reveal identical detail content.
    - dynamic behavior: a single Multi Input activity may combine dropdown, numeric, and text parts, so the expanded detail region must update as the instructor changes which part is selected rather than assuming one fixed expanded layout for the entire activity.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Accessibility: accordion controls and any interactive preview-only controls must be keyboard accessible, expose visible focus states, and preserve readable structure for screen readers.
- Reliability: the new preview mode must not create learner attempts, learner progress, submissions, or analytics events while rendering Instructor View.
- Security and authorization: preview rendering must respect existing Instructor View permissions and remain non-editable for instructor-facing users.
- Performance: mixed pages must render supported and unsupported activities without redundant per-activity fetch patterns that materially regress Instructor View load time.
- Compatibility: delivery and authoring routes must continue using their existing rendering modes and must not regress because preview metadata was added to activity registration and bundling paths.

## 9. Data, Interfaces & Dependencies
- Depends on Jira `MER-5618` as the product source of truth and on the epic-level lane split documented in `docs/exec-plans/current/epics/instructor_customizations/plan.md`.
- Depends on Figma references linked from Jira for final visual structure and styling accuracy.
- Depends on activity registration and rendering infrastructure being extended to understand preview metadata for supported activity types.
- Depends on a preview context contract carrying enough read-only metadata for supported question rendering, such as activity identity, points, learning objectives, and supported layout state.
- `MER-5618` may define the preview-side contract for later customization behavior, including the event name `setActivityEnabled(enabled: boolean)` and the preview context fields needed to identify the eventual customization target.
- The operational backend for that contract is out of scope here and belongs to `MER-5639`, which owns authorization, validation, persistence, and read models for section/page activity customization.
- `MER-5620` depends on this contract to wire preview controls for embedded questions and whole activity bank selections into the backend implementation delivered by `MER-5639`.

## 10. Repository & Platform Considerations
- The frontend is a mixed React + Phoenix + LiveView system; this work should extend the existing delivery/instructor surfaces rather than introduce a new SPA shell.
- Activity rendering rules belong in the platform activity/rendering infrastructure, with browser-side code focused on question presentation and local interaction state.
- Domain rules and future customization persistence belong in backend delivery contexts, not inside preview components.
- Testing should use the cheapest high-confidence layer per behavior:
  - Elixir tests for registration and rendering selection
  - Jest for preview component logic where isolated
  - LiveView or controller/view tests for Instructor View integration
- This work item lives under `docs/exec-plans/current/epics/instructor_customizations/preview_components` and should remain aligned with the epic lane structure already documented in the same directory tree.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Operationally, preview rendering failures for supported activities should remain observable through existing error monitoring and logs.
- Product success for this story is qualitative and workflow-based:
  - supported activities render with the new preview UI in Instructor View
  - unsupported activities continue rendering without breaking mixed pages
  - no learner-attempt or submission side effects occur while using Instructor View

## 13. Risks & Mitigations
- Scope bleed from adjacent tickets: keep remove/restore, bank management, counters, and navigation behaviors out of this work item and reference their owning Jira stories explicitly.
- Rendering contract instability: define preview mode and preview context cleanly now so later customization tickets do not require another migration of supported activities.
- Mixed-page regressions: preserve fallback rendering for unsupported activity types and verify pages that combine supported and unsupported activities.
- Authoring coupling risk: avoid continuing the `mode="instructor_preview"` pattern inside authoring components for the supported activity set.
- Activity-specific variance risk: handle shared preview chrome centrally and isolate only genuinely activity-specific rendering inside per-activity preview components.

## 14. Open Questions & Assumptions
### Open Questions
- How should the expanded Likert preview be resolved given that only a collapsed-state design reference has been identified so far?

### Assumptions
- Jira story boundaries are authoritative for functional scope, including the explicit note that remove/restore buttons belong to future tickets.
- The supported activity set for `MER-5618` is exactly the seven activity types named in Jira unless a later product decision explicitly expands that scope.
- Unsupported and advanced activities may appear on the same page as supported activities and should keep the existing Instructor View rendering path.
- `preview` mode is introduced in this story because no other ticket in the epic owns the architectural shift away from authoring-derived instructor preview.
- Later tickets will reuse the preview rendering contract created here rather than replacing it with a separate customization-only UI mode.
- It is acceptable for this story to define a future-facing preview event contract without shipping the backend customization implementation behind that contract.
- Directed Discussion preview scope is considered sufficiently defined by the referenced Figma nodes: prompt, read-only composer shell, and an expanded details region centered on participation settings and hints rather than live discussion interaction.
- The preview context contract for `MER-5618` should be treated as a stable v1 contract that includes rendering identity and shared presentation data plus a neutral future-facing customization target, while deferring operational remove/restore behavior to later tickets.
- The exact field list and serialization shape of that v1 preview context contract should be finalized in the FDD rather than left as an unresolved product-scope question.

## 15. QA Plan
- Automated validation:
  - targeted Elixir tests for activity registration, manifest parsing, and Instructor View rendering mode selection
  - targeted frontend tests for shared preview primitives and activity-specific preview behavior where logic is isolated enough for Jest
  - targeted controller, view, or LiveView tests proving supported activities render with the new preview path while unsupported activities preserve legacy behavior
- Manual validation:
  - open Instructor View on pages containing each supported activity type and confirm the new layout matches Figma
  - verify the details accordion labels and conditional sections for answer key, hints, explanation, points, and learning objectives
  - verify authoring-specific controls are absent and content remains non-editable
  - verify mixed pages still render unsupported activities with the legacy experience
  - verify Instructor View does not generate learner attempts, submissions, progress, or analytics side effects

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
