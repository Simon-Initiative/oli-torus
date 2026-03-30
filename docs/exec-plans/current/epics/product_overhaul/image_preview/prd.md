# Image Preview - Product Requirements Document

## 1. Overview
MER-4052 (`image_preview`) adds cover-image mockups to Template Overview so authors and admins can see a selected cover image as students will see it in My Course, Course Picker, and the Student Welcome page. The feature should reuse the same runtime rendering units that production student surfaces use for the image-bearing portions of each context so image treatment stays synchronized when those surfaces change, while matching the gallery and modal behavior shown in the linked Figma designs. Surrounding page chrome may be represented by a maintained preview shell where full-page reuse would be too brittle or impractical inside the inline gallery.

## 2. Background & Problem Statement
- Template managers need a reliable way to verify cover image presentation before publishing or sharing a template.
- Existing preview approaches that imitate production rendering are brittle because they can drift from the actual student-facing markup, styling, and responsive behavior.
- MER-4052 and its linked Figma designs define additional UI behavior beyond simple rendering parity: the cover-image section sits below Paywall Settings, shows no mockups until an image is present, applies hover styling to mockups, and opens a modal carousel when a mockup is clicked.
- The older product-to-template terminology update has already been completed elsewhere and should not drive implementation scope for this work item.

## 3. Goals & Non-Goals
### Goals
- Provide mockup coverage for My Course, Course Picker, and Student Welcome cover-image presentation.
- Keep the image-bearing portions of preview output in lockstep with production by extracting and reusing canonical rendering templates or components from the destination student surfaces.
- Match the MER-4052 Figma interaction model for upload state, thumbnail gallery, hover styling, and modal expansion.
- Preserve destination-surface fallback behavior, responsive treatment, and accessibility semantics inside the mockup and modal flow.
- Make the feature safe for normal template-management use by enforcing existing authorization and institution scoping.

### Non-Goals
- Building a screenshot, image-compositing, or static-mock preview pipeline.
- Reopening completed terminology-renaming work from Product to Template.
- Redesigning the student-facing My Course, Course Picker, or Welcome page layouts beyond the refactors required to share rendering units.
- Changing template publication, enrollment, or learner navigation behavior outside the preview workflow.
- Introducing a new student-facing entry point or a separate standalone preview application.

## 4. Users & Use Cases
- Template author or institution admin: uploads or changes a template cover image and checks the generated mockups for each supported student context before saving or publishing.
- Template maintainer: updates shared destination image-bearing UI and expects preview output to reflect the same change without a second implementation pass, while accepting that surrounding preview-shell framing may sometimes need separate maintenance.
- Template manager reviewing design details: hovers a mockup to confirm interactive affordance, then opens the modal and steps through the three preview states in a carousel.
- Student: indirectly benefits because template managers validate the meaningful runtime image presentation rather than a detached schematic.

## 5. UX / UI Requirements
- The Cover Image section appears below Paywall Settings on Template Overview, consistent with MER-4052 and the linked Figma states (`275:11413`, `363:6938`, `334:4814`).
- The upload affordance uses the newer design-system button styling shown in Figma together with the existing drag-and-drop area.
- When no cover image is selected, the section shows the upload affordance only and no mockup gallery.
- After a cover image is available, the section shows a large selected mockup plus three smaller mockups representing My Course, Course Picker, and Student Welcome.
- The large selected preview shows the full uploaded cover image asset at a readable size.
- Each of the three context mockups presents a scaled-down full-context composition of the corresponding learner-facing surface so reviewers can see the cover image in place without the preview reflowing into a narrow-card layout.
- The preview should prioritize fidelity of the image slot, image treatment, and immediately surrounding context; exact reproduction of all surrounding page chrome is preferred but not required when it would materially complicate maintainability or inline rendering safety.
- Hovering a mockup applies the drop-shadow hover state shown in Figma.
- Clicking a mockup opens a modal carousel that lets the user move across the three mockups without leaving Template Overview.
- Preview controls and modal controls must be keyboard accessible, expose clear accessible names, and preserve visible focus treatment.
- Any new cover-image labels or helper text must use the existing localization pipeline rather than hard-coded strings.
- The feature must not add or change student navigation; students continue to encounter these renderings only through their normal destination surfaces.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Reliability: preview rendering must fail safely with the same fallback behavior used by the destination surface and must not crash the hosting LiveView or controller flow when image data is missing or invalid.
- Performance: preview context selection and initial render should reuse existing data and rendering paths without introducing obvious duplicate work or N+1 query patterns.
- Security and privacy: preview access must stay scoped to authorized template-management users in the correct institution and must not expose cross-tenant template data.
- Accessibility: the preview experience must preserve accessible names, semantic structure, keyboard reachability, and visible focus behavior for the interactive preview gallery and modal, and should retain the accessible semantics of reused runtime image-bearing components where those components are rendered directly.
- The feature does not require new telemetry instrumentation.

## 9. Data, Interfaces & Dependencies
- The feature reuses existing template cover-image data and does not require new persistence tables or schema changes.
- Shared view-layer rendering units must accept stable assigns for cover-image metadata and any destination-specific display fields needed by My Course, Course Picker, and Welcome.
- The preview host depends on the existing Template Overview surface, the destination student-facing rendering paths, and the authorization logic that already governs template editing.
- The modal interaction should prefer reuse of the existing certificate-preview modal patterns where that reuse can match the MER-4052 carousel behavior without user-visible divergence.
- No new third-party services or external APIs are required.

## 10. Repository & Platform Considerations
- Shared rendering logic should stay in the Phoenix view or component layer so both runtime surfaces and preview surfaces consume the same implementation for the image-bearing regions without duplicating markup.
- Domain authorization and institution scoping must remain on the server side; preview UI should not become the source of truth for access control.
- Primary verification should use targeted LiveView or view-layer tests for rendering parity, mockup-gallery states, hover and modal behavior, plus supporting backend tests where shared rendering contracts need explicit coverage.
- Because subsequent implementation will touch shared UI behavior, default review expectations should include security and performance review plus UI and Elixir review where applicable.
- Jira issue `MER-4052` remains the implementation tracking reference for this work item.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
Telemetry is not required for this work item. Success is established by matching the MER-4052 acceptance criteria and Figma interaction states for no-image, uploaded-gallery, hover, and modal-carousel behavior while preserving runtime image-presentation parity across the three student contexts.

## 13. Risks & Mitigations
- Shared-component extraction could regress existing student surfaces: add targeted regression coverage for each destination surface before or alongside preview wiring.
- Existing contexts may have hidden markup or styling differences that make shared extraction harder than expected: define explicit shared boundaries per context and keep context-specific wrapper behavior outside the reusable unit.
- Gallery and modal interactions could drift from the ticketed design if implemented as ad hoc UI: use the MER-4052 Figma nodes as the behavioral reference and reuse existing modal patterns where practical.
- Responsive parity may diverge if preview and runtime do not share the same styling hooks: reuse the same classes, structure, and breakpoints rather than preview-specific approximations.
- Exact full-page fidelity is difficult to preserve because the preview is rendered inline, scaled down, inert, and hosted outside the destination page's normal routing, viewport, and styling context: prioritize reuse of the image-bearing runtime seams and keep the surrounding preview shell small and explicit so future maintenance is localized.

## 14. Open Questions & Assumptions
### Open Questions
- Can the existing certificate-preview modal be reused directly, or does it need targeted extension to support the MER-4052 carousel and sizing behavior?

### Assumptions
- Existing template cover-image fields already provide the data needed by all three supported contexts.
- No database migration is required for this feature.
- Existing template-management permissions are sufficient to gate preview access.
- The destination student surfaces can be refactored to shared rendering units without changing their user-visible behavior.
- Exact page-level parity outside the image-bearing regions may require representative shell markup in preview mode because some destination controls, breakpoints, and page chrome depend on runtime-only page context that is not practical to mount inside Template Overview.
- The completed template terminology work means this feature should not include unrelated wording cleanup beyond the local copy directly touched by the cover-image section.
- QA parity validation should use `375px`, `768px`, and `1280px` as the required viewport matrix, aligning with the repository's mobile sanity viewport plus standard `md` and `xl` Tailwind breakpoints; Student Welcome checks at `1280px` should also satisfy the runtime `hvxl` onboarding layout behavior.

## 15. QA Plan
- Automated validation:
  - LiveView or view-layer coverage proving each preview context reuses the same image-bearing rendering unit as its corresponding destination surface.
  - UI coverage for the no-image state to confirm that no mockup gallery is rendered before a cover image is available.
  - UI coverage for the uploaded-image state to confirm the large selected mockup and three context mockups are rendered in the expected section below Paywall Settings.
  - UI coverage for hover styling and modal-carousel navigation behavior.
  - Authorization tests confirming preview controls and direct access remain unavailable to unauthorized users.
  - Regression tests for missing or invalid image data to confirm fallback behavior matches the destination surfaces.
- Manual validation:
  - Compare preview and runtime image presentation for My Course, Course Picker, and Welcome at `375px`, `768px`, and `1280px`.
  - Verify no mockups appear before a cover image is chosen.
  - Verify the uploaded-image state matches the Figma gallery layout, including hover drop shadow on mockups and scaled full-context thumbnail compositions rather than narrow responsive reflow.
  - Verify clicking each mockup opens the modal carousel and that carousel controls move among all three mockups.
  - Verify keyboard navigation, focus treatment, and accessible labeling for preview and modal controls.
  - Verify that changes to a shared image-bearing runtime rendering unit are reflected in preview without additional preview-only edits.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
