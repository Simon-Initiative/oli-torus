# Image Preview - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/product_overhaul/image_preview/prd.md`
- FDD: `docs/exec-plans/current/epics/product_overhaul/image_preview/fdd.md`

## Scope
Deliver MER-4052 cover-image previews on Template Overview by extending the existing Cover Image section to support the no-image state, uploaded gallery, thumbnail hover treatment, and modal carousel while reusing real learner-facing rendering seams for My Course, Course Picker, and Student Welcome. The implementation must preserve existing template-management authorization, avoid schema or telemetry work, and verify parity at `375px`, `768px`, and `1280px`.

## Clarifications & Default Assumptions
- The Template Overview LiveView remains the owner of page state, upload behavior, and preview interaction state.
- The Cover Image section continues to live below Paywall Settings; this is not a separate route or separate authoring app.
- The implementation should use `OliWeb.Components.Modal` for the new preview modal even if `DetailsLive` still carries deprecated modal support for unrelated behavior.
- No feature flag, migration, telemetry, or background job work is required.
- QA parity sign-off uses `375px`, `768px`, and `1280px`; Student Welcome checks at `1280px` must satisfy the runtime `hvxl` onboarding behavior.
- If a reusable certificate-preview carousel helper appears during implementation and matches the requirements cleanly, it may replace a feature-specific modal body; otherwise the feature keeps its own modal content built on the shared modal primitive.

## Phase 1: Baseline the Existing Cover Image Surface
- Goal: Establish a regression harness around the current Template Overview Cover Image section and learner-facing preview seams before UI changes begin.
- Tasks:
  - [ ] Inventory the current Template Overview Cover Image rendering path in `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` and `OliWeb.Products.Details.ImageUpload`.
  - [ ] Inventory the runtime rendering contracts for `OliWeb.Workspaces.Student.course_card/1`, `OliWeb.Common.CardListing.render/1`, and `OliWeb.Delivery.StudentOnboarding.Intro.render/1`.
  - [ ] Capture the current no-image and existing upload-section behavior in targeted tests so the refactor starts from a stable baseline.
  - [ ] Identify the runtime-only dependencies that will need preview-safe seams, especially My Course card navigation and inline instructor lookup.
  - [ ] Record the required viewport matrix (`375px`, `768px`, `1280px`) in the phase verification notes and QA checklist.
- Testing Tasks:
  - [ ] Extend or add baseline tests around Template Overview Cover Image rendering and current fallback behavior.
  - [ ] Extend or add baseline tests for the three learner-facing rendering seams before preview-mode changes.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs test/oli_web/live/workspaces/student_test.exs`
- Definition of Done:
  - The affected rendering boundaries are explicit.
  - Baseline tests exist for the current Cover Image area and the learner-facing seams.
  - The preview-risky runtime dependencies are identified before UI refactor work begins.
- Gate:
  - Gate A: baseline tests are green and the runtime seam inventory is complete.
- Dependencies:
  - None.
- Parallelizable Work:
  - Template Overview baseline tests and learner-facing seam inventory can be developed in parallel.

## Phase 2: Rebuild the Cover Image Area for Gallery States
- Goal: Replace the old upload-only Cover Image UI with the ticketed no-image and uploaded-gallery states in Template Overview.
- Tasks:
  - [ ] Refactor `OliWeb.Products.Details.ImageUpload` so it can render the no-image state and the uploaded-image gallery state without breaking existing upload behavior.
  - [ ] Update upload affordance styling to match the design-system direction in MER-4052.
  - [ ] Add a large selected preview region and three thumbnail slots beneath the upload area.
  - [ ] Keep the gallery hidden when no cover image is available.
  - [ ] Add the hover-state classes and DOM hooks needed for the thumbnail drop-shadow behavior.
  - [ ] Preserve localization-ready labels and helper text in the new UI.
- Testing Tasks:
  - [ ] Add LiveView tests for:
    - no-image state with no gallery (`AC-006`)
    - uploaded-image state with selected preview plus three thumbnails (`AC-005`, `AC-007`)
    - Cover Image section still positioned beneath Paywall Settings (`AC-005`)
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs`
- Definition of Done:
  - Template Overview shows the correct upload-only state before image selection.
  - Template Overview shows the correct gallery structure after image upload or when an existing cover image is present.
  - Hover-state hooks and styling are wired into the new gallery structure.
- Gate:
  - Gate B: no-image and uploaded-gallery states are green in LiveView tests and match the ticket structure.
- Dependencies:
  - Phase 1 Gate A.
- Parallelizable Work:
  - Upload-surface refactor and thumbnail hover-state styling can proceed in parallel once the gallery structure is agreed.

## Phase 3: Implement Preview Wrappers and Runtime-Safe Seams
- Goal: Connect the gallery items to real learner-facing renderers through preview wrappers and only the minimal runtime seams needed for safe inline rendering.
- Tasks:
  - [ ] Create `OliWeb.Products.ImagePreview` as the gallery and preview orchestration module.
  - [ ] Create wrapper components for My Course, Course Picker, and Student Welcome.
  - [ ] Add or refactor the minimal runtime-safe seams required:
    - My Course card: suppress navigation and runtime instructor lookup in preview mode.
    - Course Picker card listing: disable selection behavior in preview mode.
    - Student Welcome: confirm wrapper-provided assigns are sufficient without additional seam work.
  - [ ] Ensure all three wrappers use the same underlying image fallback path as runtime (`AC-004`, `AC-011`).
  - [ ] Keep runtime defaults backward compatible when preview-mode inputs are absent.
- Testing Tasks:
  - [ ] Add wrapper and seam-focused tests proving:
    - My Course preview renders through the runtime card path without side effects (`AC-001`, `AC-004`)
    - Course Picker preview renders through `CardListing` without selection behavior (`AC-002`, `AC-004`)
    - Student Welcome preview renders through onboarding intro (`AC-003`, `AC-004`)
    - runtime default behavior is unchanged when preview mode is not used
  - Command(s): `mix test test/oli_web/live/workspaces/student_test.exs`
- Definition of Done:
  - All three preview contexts render through wrapper modules that adapt to real learner-facing seams.
  - Minimal runtime seams are in place and backward compatible.
  - Preview rendering does not trigger unwanted navigation or repeated runtime-only queries.
- Gate:
  - Gate C: wrapper and seam tests are green and runtime default behavior remains intact.
- Dependencies:
  - Phase 2 Gate B.
- Parallelizable Work:
  - My Course and Course Picker seam work can proceed in parallel; Student Welcome wrapper verification can run alongside them.

## Phase 4: Add Modal Carousel and Preview Interaction Flow
- Goal: Complete the user interaction layer for opening previews in a modal carousel and moving across all three preview states.
- Tasks:
  - [ ] Add Template Overview-owned preview interaction state for selected preview and modal visibility.
  - [ ] Implement the preview modal using `OliWeb.Components.Modal`.
  - [ ] Add thumbnail click behavior to open the selected preview in the modal (`AC-009`).
  - [ ] Add next/previous controls and position indicators for the modal carousel.
  - [ ] Ensure keyboard access, close behavior, focus handling, and accessible labels are correct.
  - [ ] Confirm modal rendering uses the same preview wrapper content as the gallery so parity stays single-sourced.
- Testing Tasks:
  - [ ] Add interaction tests for:
    - clicking a thumbnail opens the modal (`AC-009`)
    - next/previous controls cycle across all three previews (`AC-009`)
    - modal close and keyboard/escape behavior
    - hover-state assertions where practical (`AC-008`)
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs`
- Definition of Done:
  - The modal carousel opens from the gallery and cycles correctly across all three contexts.
  - Modal interaction and accessibility behavior are covered by tests.
  - Gallery and modal stay wired to the same preview wrapper content.
- Gate:
  - Gate D: modal carousel behavior is test-covered and matches the MER-4052 interaction model.
- Dependencies:
  - Phase 3 Gate C.
- Parallelizable Work:
  - Modal shell implementation and carousel-control tests can run in parallel once the preview wrapper API is fixed.

## Phase 5: Parity, Fallback, and Release Verification
- Goal: Close out the feature with parity, fallback, authorization, and broader regression verification.
- Tasks:
  - [ ] Verify fallback behavior for missing or invalid image data across gallery and modal (`AC-011`).
  - [ ] Verify authorization remains unchanged and unauthorized users cannot access the preview UI (`AC-010`).
  - [ ] Run parity checks at `375px`, `768px`, and `1280px` for My Course, Course Picker, and Student Welcome (`AC-012`).
  - [ ] Confirm the final gallery and modal align with Figma nodes `363:6938` and `334:4814`.
  - [ ] Run targeted and broader regression suites for touched areas.
  - [ ] Update any work-item-local verification notes or QA evidence references needed for handoff.
- Testing Tasks:
  - [ ] Add or finalize regression tests for fallback behavior and authorization.
  - [ ] Execute targeted suites for Template Overview and touched learner-facing components.
  - [ ] Execute broader regression as risk warrants after targeted suites pass.
  - Command(s): `mix test test/oli_web/live/workspaces/course_author/products/details_live_test.exs test/oli_web/live/workspaces/student_test.exs`
  - Command(s): `mix test`
- Definition of Done:
  - Fallback and authorization behavior are verified.
  - Responsive parity is verified at the required viewport matrix.
  - Targeted and broader regression checks are complete.
- Gate:
  - Gate E: release readiness is approved with parity, fallback, authorization, and regression checks complete.
- Dependencies:
  - Phase 4 Gate D.
- Parallelizable Work:
  - Manual parity review and automated regression execution can run in parallel after interaction flow work is complete.

## Parallelization Notes
- Phase 1 can split between Template Overview baseline tests and learner-facing seam inventory.
- Phase 2 can split between upload/gallery markup work and hover-state styling work.
- Phase 3 can split between My Course and Course Picker seam work; Student Welcome wrapper work is mostly independent.
- Phase 4 can split between modal shell construction and carousel-control tests after the wrapper API is stable.
- Phase 5 can split between manual parity review and automated regression execution.

## Phase Gate Summary
- Gate A: baseline tests and runtime seam inventory are complete.
- Gate B: Cover Image section supports correct no-image and uploaded-gallery states.
- Gate C: preview wrappers and minimal runtime-safe seams are complete and backward compatible.
- Gate D: modal carousel interaction flow is complete and test-covered.
- Gate E: fallback, authorization, responsive parity, and regression checks are complete.
