# Image Preview - Functional Design Document

## 1. Executive Summary
This design adds ticket-accurate cover-image mockups to Template Overview by extending the existing cover-image upload area in `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` and reusing the real learner-facing rendering seams that already exist for the image-bearing portions of My Course, Course Picker, and Student Welcome. The selected implementation is a small Template Overview-owned gallery and modal flow: the page renders one large selected preview plus three thumbnail previews after a cover image exists, applies the Figma hover treatment on thumbnails, and opens a modal carousel when a thumbnail is clicked. The top selected preview shows the full uploaded asset, while the three context thumbnails render scaled-down full-context compositions of the learner-facing surfaces rather than allowing those surfaces to responsively reflow into the thumbnail width. The previews are a hybrid: reused runtime image-bearing components sit inside thin preview wrappers and a maintained preview shell that supplies representative surrounding page chrome, inert behavior, and scrolled framing where fully mounting the destination page would be brittle or impractical. No schema changes, feature flags, or new telemetry are required.

## 2. Requirements & Assumptions
- Functional requirements:
  - `FR-001` (`AC-001`, `AC-002`, `AC-003`): render cover-image previews for My Course, Course Picker, and Student Welcome using production-equivalent image presentation within a representative page context.
  - `FR-002` (`AC-004`): reuse shared runtime rendering units for the image-bearing regions so preview and destination surfaces remain synchronized where it matters most.
  - `FR-003` (`AC-005`): place the Cover Image section below Paywall Settings and use the MER-4052 upload affordance styling.
  - `FR-004` (`AC-006`, `AC-007`): render no preview gallery before upload and a three-preview gallery after upload.
  - `FR-005` (`AC-008`): apply the Figma hover-state drop shadow to preview thumbnails.
  - `FR-006` (`AC-009`): open a modal carousel from thumbnail click and allow navigation across all three previews.
  - `FR-007` (`AC-010`): preserve existing template-management authorization and institution scoping.
  - `FR-008` (`AC-011`, `AC-012`): preserve fallback behavior and responsive parity with the learner-facing surfaces.
- Non-functional requirements:
  - No new database schema, migration, background job, or external integration.
  - No new telemetry instrumentation for this feature.
  - No new obvious N+1 queries or repeated data fetch loops during preview rendering.
  - Keyboard access, visible focus, semantic modal behavior, and responsive layout must remain aligned with WCAG 2.1 AA expectations and the linked Figma states.
- Assumptions:
  - The existing template/product section record already contains the data needed to render all three preview contexts.
  - Template terminology work has already been completed elsewhere and is not an implementation objective of this story.
  - The learner-facing components can accept narrowly scoped preview-only inputs or wrapper-provided defaults without changing runtime behavior.
  - `MER-4052` and Figma nodes `275:11413`, `363:6938`, and `334:4814` are the design source of truth for layout and interaction details.
  - QA parity validation will use `375px`, `768px`, and `1280px` as the required viewport matrix because those sizes align with the repository's standard Tailwind breakpoints (`md`, `xl`) plus a mobile sanity viewport; Student Welcome parity at `1280px` should also satisfy the runtime `hvxl` onboarding breakpoint.

## 3. Repository Context Summary
- What we know:
  - `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive` already owns the Template Overview page and renders the Cover Image section below Paywall Settings.
  - `OliWeb.Products.Details.ImageUpload` already owns the upload widget and is the natural insertion point for no-image versus uploaded-image preview states.
  - `OliWeb.Workspaces.Student.course_card/1` renders the My Course card and currently pulls image, dates, instructors, progress, and link behavior from a section-like assign.
  - `OliWeb.Common.CardListing.render/1` renders the Course Picker card UI from `model.rows`.
  - `OliWeb.Delivery.StudentOnboarding.Intro.render/1` renders the Student Welcome intro hero and text from a section-like assign.
  - `OliWeb.Components.Modal` is the supported modal primitive for new modal work; `OliWeb.Common.Modal` is explicitly deprecated even though `DetailsLive` still uses it today.
  - The current `course_card/1` implementation performs runtime-only work inline, including instructor lookup and navigation behavior, so preview rendering cannot call it blindly without a small seam or wrapper.
- Unknowns to confirm:
  - Whether `course_card/1` should gain explicit preview attrs or whether a dedicated wrapper component should fully own preview-safe composition around shared lower-level elements.
  - Whether the existing certificate-settings UI has any reusable carousel-specific helper beyond the general modal primitive. Current repository waypointing did not reveal a dedicated certificate preview carousel implementation.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
The simplest adequate design is to keep gallery and modal state in Template Overview and introduce one small preview component module responsible for selecting and rendering the three contexts.

- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`
  - Continues to own page authorization, upload lifecycle, and overall page composition.
  - Gains preview UI state assigns such as selected preview context and modal visibility.
  - Renders the preview gallery directly beneath the existing upload area once a cover image is present.
- `OliWeb.Products.Details.ImageUpload`
  - Remains the upload/dropzone surface.
  - Gains an optional slot or sibling render block for preview content so the upload affordance and preview states remain co-located.
- New module: `OliWeb.Products.ImagePreview`
  - Renders the large selected preview, the three thumbnails, and the modal carousel content.
  - Owns context labels and context ordering: My Course, Course Picker, Student Welcome.
  - Delegates actual context rendering to dedicated preview wrappers.
  - Applies the fixed preview-frame sizing and scaling needed so thumbnail previews preserve runtime layout proportions instead of reflowing into the thumbnail column width.
- New wrapper components under `OliWeb.Products.ImagePreview`
  - `MyCoursePreview`
  - `CoursePickerPreview`
  - `StudentWelcomePreview`
  - Each wrapper adapts template data into the contract expected by the corresponding runtime component while disabling runtime-only behavior.
- Existing runtime seams reused:
  - My Course: `OliWeb.Workspaces.Student.course_card/1`
  - Course Picker: `OliWeb.Common.CardListing.render/1`
  - Student Welcome: `OliWeb.Delivery.StudentOnboarding.Intro.render/1`
- Modal primitive:
  - New preview modal work should use `OliWeb.Components.Modal`, even if `DetailsLive` still carries deprecated modal support for unrelated behavior.

This is preferred over embedding full LiveViews or building screenshot mockups because it keeps the preview surface inside the authoring page while still sourcing the most important markup from the real learner-facing components. Full page-level reuse is not the target because the inline preview must be scaled, inert, and embedded outside the destination page's native routing, viewport, and CSS context.

### 4.2 State & Data Flow
1. `DetailsLive.mount/3` loads the template section as it does today.
2. The Cover Image section renders the upload area via `ImageUpload.render`.
3. If the template has no cover image, no preview gallery is rendered.
4. If the template has a cover image, `DetailsLive` renders `OliWeb.Products.ImagePreview` with:
   - the template section record
   - the current context selection
   - modal open/closed state
   - the request context already assigned to the page
5. `OliWeb.Products.ImagePreview` builds a fixed list of three preview items and renders:
   - one large selected preview pane that shows the full uploaded image asset
   - three thumbnail buttons that each contain a scaled full-context composition of the corresponding learner-facing surface
6. Hover styling is applied in the gallery component using the design-system classes selected to match Figma.
7. Clicking a thumbnail updates the selected context and opens the modal when requested.
8. The selected wrapper component maps template data to the corresponding runtime component contract:
   - My Course wrapper provides a preview-safe section-like map and disables link navigation and runtime instructor lookup.
   - Course Picker wrapper provides a one-row `model` and disables card selection click handling.
   - Student Welcome wrapper provides a section-like map with deterministic values for any conditional onboarding bullets.
   - The gallery host provides a fixed inner preview width and scaling factor per context so those reused runtime surfaces preserve their intended proportions in thumbnail form.
   - The gallery host may also provide representative surrounding shell markup, scroll positioning, and inert control chrome where those concerns are needed to frame the reused image-bearing component realistically without mounting the full runtime page.
9. The modal carousel renders the same three wrapper components in modal form and uses next/previous controls plus position indicators.

### 4.3 Lifecycle & Ownership
- State ownership:
  - `DetailsLive` owns modal visibility and selected-context state because the feature is page-local and does not need a separate process.
  - `OliWeb.Products.ImagePreview` owns presentation logic for the gallery and modal but not page authorization or uploads.
- Data ownership:
  - The template section record remains the source of truth for title, description, welcome text, image, and related display values.
- Preview wrappers may derive deterministic placeholder values only for runtime-only fields that are not meaningfully available in Template Overview, such as instructor label or progress.
- Preview wrappers may also provide representative shell-only values for surrounding page furniture that is helpful for context but not the source of truth for image fidelity.
- Lifecycle:
  - No new OTP processes, PubSub subscriptions, cache layers, or background jobs.
  - Preview state lives only for the duration of the Template Overview LiveView session.

### 4.4 Alternatives Considered
- Build custom static mockups for all three contexts.
  - Rejected because it duplicates learner-facing markup and styling, which is the main source of drift this story is trying to avoid.
- Mount the full learner LiveViews inside Template Overview.
  - Rejected because those flows require routing, session, and side effects that are not appropriate for inline authoring preview.
- Reuse the deprecated `OliWeb.Common.Modal` path because `DetailsLive` already imports it.
  - Rejected for new preview work because the repository explicitly marks it deprecated and the supported modal primitive already exists.
- Add telemetry because `harness.yml` enables it by default.
  - Rejected because the PRD and Jira clarification make telemetry out of scope for this feature.

## 5. Interfaces
- `OliWeb.Workspaces.CourseAuthor.Products.DetailsLive`
  - New assigns:
    - `:image_preview_selected_context`
    - `:image_preview_modal_open`
  - New events:
    - `"select_image_preview_context"`
    - `"open_image_preview_modal"`
    - `"close_image_preview_modal"`
    - `"show_next_image_preview"`
    - `"show_previous_image_preview"`
- `OliWeb.Products.ImagePreview.render/1`
  - Inputs:
    - `section`
    - `ctx`
    - `selected_context`
    - `modal_open?`
  - Outputs:
    - gallery markup, thumbnail controls, and modal markup
- Preview wrapper interfaces:
  - `MyCoursePreview.render/1`: accepts a section-like preview struct plus `ctx`; suppresses navigation and runtime-only lookup.
- `CoursePickerPreview.render/1`: accepts a one-row `model`, `ctx`, and a no-op or disabled `selected` action.
- `StudentWelcomePreview.render/1`: accepts a section-like preview struct.
- Expected runtime seams needing small changes:
  - `OliWeb.Workspaces.Student.course_card/1` likely needs optional attrs to disable `href` navigation and use precomputed instructors rather than calling `Sections.get_instructors_for_section/1`.
  - `OliWeb.Common.CardListing.render/1` likely needs an optional disabled-preview mode so cards can render as buttons or inert containers instead of clickable selectors.
  - `OliWeb.Delivery.StudentOnboarding.Intro.render/1` likely needs no interface change beyond wrapper-provided assigns.

## 6. Data Model & Storage
- No schema changes.
- No migrations.
- No new persisted preview records.
- The only new data structures are ephemeral view-layer maps or small structs used to adapt the template section into runtime-component inputs.

## 7. Consistency & Transactions
- Existing cover-image upload behavior remains authoritative and unchanged.
- Preview rendering is read-only and should not create, update, or delete any persisted records.
- Modal and gallery interactions are purely UI state transitions inside the LiveView and do not need transactional behavior.

## 8. Caching Strategy
- N/A for new feature-specific caching.
- Existing browser and CDN behavior for uploaded cover-image assets remains unchanged.
- The design intentionally avoids any screenshot cache or generated preview artifact cache.

## 9. Performance & Scalability Posture
- Performance posture:
  - Rendering the gallery should be bounded to three preview wrappers and should not introduce repeated database queries on thumbnail selection or modal navigation.
  - The My Course preview path must not trigger per-render instructor lookups once preview-safe data is provided.
  - The Course Picker preview path should render from an in-memory single-row model rather than loading broader picker data.
- Scalability posture:
  - All state remains page-local and proportional to three small preview items.
  - No server-side fan-out, background jobs, or external API dependencies are introduced.

## 10. Failure Modes & Resilience
- No cover image present:
  - Intended behavior, not an error. Render upload controls only and no gallery.
- Missing or invalid image URL:
  - Reuse the destination surface fallback path, primarily via `SourceImage.cover_image/1`, so the preview shows the same fallback visuals as runtime.
- Wrapper receives insufficient data:
  - Render a deterministic fallback presentation instead of crashing the LiveView.
- Preview component accidentally triggers navigation or side effects:
  - Prevent by explicit preview mode flags and inert click handling in the reused runtime components.
- Unauthorized access:
  - Remains blocked by existing `DetailsLive` authoring auth and mount behavior.

## 11. Observability
- No new telemetry events are required.
- Existing request logging and ordinary exception reporting remain sufficient for this scope.
- If preview rendering errors surface during implementation, normal logging should include enough context to identify the failing preview context without introducing a feature-specific telemetry requirement.

## 12. Security & Privacy
- Preview remains available only inside the authenticated template-management surface.
- Existing institution and authoring permission checks in `DetailsLive` remain the access-control boundary.
- The design introduces no new cross-tenant lookup paths and no new user-generated payload storage.
- The modal and gallery show only template-owned presentation data already visible to authorized template managers.

## 13. Testing Strategy
- LiveView tests for `DetailsLive`:
  - no-image state renders upload affordance with no gallery (`AC-006`)
  - uploaded-image state renders selected preview plus three thumbnails below Paywall Settings (`AC-005`, `AC-007`)
  - unauthorized users cannot access the preview UI (`AC-010`)
- Component tests for preview wrappers:
  - My Course preview reuses the runtime card seam and does not navigate or issue runtime instructor queries (`AC-001`, `AC-004`)
  - Course Picker preview reuses `CardListing` presentation with non-interactive behavior (`AC-002`, `AC-004`)
  - Student Welcome preview reuses onboarding intro presentation (`AC-003`, `AC-004`)
- UI interaction tests:
  - thumbnail hover state applies the expected class or visual contract (`AC-008`)
  - clicking a thumbnail opens the modal carousel and next/previous controls cycle across all three states (`AC-009`)
- Regression tests:
  - fallback image behavior stays aligned with the three runtime surfaces (`AC-011`)
  - responsive parity checks are covered at `375px`, `768px`, and `1280px` through targeted UI assertions and manual QA (`AC-012`)
- Manual verification:
  - compare gallery and modal against Figma nodes `363:6938` and `334:4814`
  - confirm the three gallery thumbnails behave as scaled full-context compositions rather than narrow-column responsive reflows
  - verify keyboard reachability, focus handling, escape-to-close, and accessible names in the modal and thumbnail gallery

## 14. Backwards Compatibility
- Existing template upload/edit behavior remains unchanged.
- Existing learner-facing routes and components remain the source of truth for their own runtime views.
- The preview shell around those reused components is intentionally maintained preview code and is not expected to inherit every surrounding runtime-page change automatically.
- Any new attrs added to reused runtime components must be optional and preserve existing runtime behavior by default.
- No feature-flag or migration rollout is required; normal deployment is sufficient.

## 15. Risks & Mitigations
- Runtime components may contain hidden assumptions that make inline preview unsafe: add narrow preview-mode attrs or wrapper-owned defaults rather than forking full component markup.
- The gallery could drift from Figma while the embedded preview content stays accurate: keep all gallery and modal structure centralized in one new `OliWeb.Products.ImagePreview` module.
- Thumbnail previews could remain technically shared-rendering but still look wrong if they reflow to the card width: keep scaling and fixed preview-canvas sizing explicit in the gallery host instead of relying on reused runtime components to self-size correctly in narrow containers.
- The My Course card currently performs DB lookups inline: remove or bypass that runtime-only lookup in preview mode so gallery and modal navigation stay cheap and deterministic.
- Using the deprecated modal helper would create new cleanup debt: implement the new preview modal with `OliWeb.Components.Modal`.
- Exact full-page parity can drift because the preview cannot realistically mount every destination route, viewport breakpoint, and interactive control inside Template Overview: isolate that unavoidable approximation to a small preview shell and keep the image-bearing seams shared.

## 16. Open Questions & Follow-ups
- Confirm whether the learner-facing My Course card should be adapted with preview attrs or whether its preview should be factored into a lower-level shared component during implementation.
- If implementation reveals an existing certificate preview carousel helper not found during waypointing, reevaluate reuse before building a feature-specific carousel body.

## 17. References
- `docs/exec-plans/current/epics/product_overhaul/image_preview/prd.md`
- `docs/exec-plans/current/epics/product_overhaul/image_preview/requirements.yml`
- Jira `MER-4052`
- Figma `GQm0yUEwFNbzznfpvV1eSM`, nodes `275:11413`, `363:6938`, `334:4814`
- `lib/oli_web/live/workspaces/course_author/products/details_live.ex`
- `lib/oli_web/live/workspaces/student.ex`
- `lib/oli_web/live/common/card_listing.ex`
- `lib/oli_web/live/delivery/student_onboarding/intro.ex`
- `lib/oli_web/components/modal.ex`
