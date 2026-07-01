# Preview Components - Functional Design Document

## 1. Executive Summary
`MER-5618` introduces a first-class activity `preview` rendering path for the seven Jira-scoped activity types in Instructor View while preserving the current authoring-derived `instructor_preview` path for all unsupported activities. The design extends activity manifests, persisted registrations, activity summaries, and the Instructor View rendering pipeline so supported activities can mount dedicated preview web components and unsupported activities can continue mounting legacy authoring components on the same page. This keeps the architectural shift in `MER-5618` narrowly focused on rendering and shared preview UI, while deferring operational customization behavior such as remove/restore to `MER-5639`, `MER-5620`, and related follow-up tickets.

## 2. Requirements & Assumptions
- Functional requirements:
  - introduce `preview` as a distinct rendering mode for the supported `MER-5618` activity set
  - render the new collapsed-by-default instructor-facing question UI for the seven Jira-scoped activity types
  - allow mixed pages where supported activities use preview mode and unsupported activities remain on the legacy Instructor View rendering path
  - expose answer key, hints, explanation, participation details, points, and learning objectives per the PRD and Figma references
  - establish a stable preview-side contract for later customization work without shipping backend enable/disable behavior here
- Non-functional requirements:
  - remain read-only and avoid learner attempts, submissions, or analytics side effects
  - preserve existing Instructor View authorization boundaries
  - avoid material load-time regressions on mixed pages
  - maintain keyboard accessibility, visible focus, and readable structure for screen readers
- Assumptions:
  - Jira scope is authoritative: only the seven named activity types must migrate in this work item
  - the fallback boundary is per activity, not per page
  - `Likert` expanded remains the only unresolved design gap and will be implemented from a clarified design or from a conservative shared pattern agreed during implementation
  - preview contract fields needed for future customization can be introduced now as read-only metadata, but no persistence or mutation semantics belong in this story

### 2.1 Requirements Traceability
- `FR-001`, `AC-001`:
  - first-class preview mode is introduced through manifest, registration, activity-summary, and renderer changes that prefer preview metadata over authoring metadata for supported activities
- `FR-002`, `AC-002`, `AC-003`, `AC-004`, `AC-005`:
  - the browser-side design introduces shared preview chrome plus per-activity preview components for exactly the seven Jira-scoped activity types, with collapsed-by-default details and activity-specific detail tabs/panels
- `FR-003`, `AC-007`, `AC-008`:
  - preview components remain read-only and intentionally avoid authoring controls, authoring editors, and authoring mutation flows
- `FR-004`, `AC-009`:
  - mixed pages keep unsupported activities on the existing legacy Instructor View path rather than failing or forcing migration
- `FR-005`, `AC-010`:
  - Instructor View preview rendering is read-only and must not create learner-side attempts, progress, submissions, or analytics side effects
- `FR-006`, `AC-011`:
  - preview metadata is additive and backwards-compatible so delivery and authoring continue using their existing rendering behavior after preview support is added
- `AC-006`:
  - activities with multiple parts or selections, especially Multi Input, must bind answer-key rendering and points display to the currently selected part

## 3. Repository Context Summary
- What we know:
  - `lib/oli_web/controllers/page_delivery_controller.ex` currently builds page-preview `ActivitySummary` values using `authoring_script` and `authoring_element` and renders the page with `mode: :instructor_preview`.
  - `lib/oli/rendering/activity/html.ex` and `lib/oli/rendering/activity/plaintext.ex` currently select `authoring_element` whenever the rendering mode is `:instructor_preview`.
  - `lib/oli/activities/manifest.ex`, `lib/oli/activities.ex`, and `lib/oli/activities/activity_registration.ex` currently model only `authoring` and `delivery` activity modes.
  - `assets/webpack.config.js` auto-discovers activity entries from each `manifest.json`, but today only emits `*_authoring.js` and `*_delivery.js`.
  - frontend activity types already reserve `'preview'` in `assets/src/components/activities/types.ts`, so the browser-side naming can align to `preview` rather than inventing a new mode string.
  - existing authoring components already contain `mode === "instructor_preview"` branches, but those branches are exactly the coupling this ticket is meant to reduce for the supported activity set.
  - `docs/exec-plans/current/epics/instructor_customizations/preview_components/design/preview_question_ui.md` recommends a feature-local shared preview library under `assets/src/components/activities/common/preview/`.
- Unknowns to confirm:
  - final expanded-state treatment for `Likert`
  - final naming of the preview bundle and persisted registration fields, although the architectural need for third-mode registration is already clear

## 4. Proposed Design
### 4.1 Component Roles & Interactions
- Activity manifest and registration layer:
  - extend activity manifests to optionally declare a `preview` mode specification with `element` and `entry`
  - extend `Oli.Activities.Manifest`, `Oli.Activities.register_activity/2`, and `Oli.Activities.ActivityRegistration` so preview metadata can be parsed, persisted, and surfaced for supported activities
  - keep preview fields nullable so unsupported activities and LTI/advanced activities do not require migration in this story
- Instructor View summary-building layer:
  - extend `Oli.Rendering.Activity.ActivitySummary` with `preview_script`, `preview_element`, and `preview_context`
  - update `render_page_preview/3` in `page_delivery_controller.ex` to populate these fields from the activity registration and page context
  - compute `preview_context` server-side so preview components receive explicit read-only metadata rather than inferring from authoring stores
- Rendering layer:
  - update `Oli.Rendering.Activity.Html` so `:instructor_preview` renders `preview_element` when it exists, and otherwise falls back to `authoring_element`
  - preserve legacy behavior for unsupported activities by allowing a missing `preview_element` to use the existing authoring path
  - mirror the same fallback rule in `Oli.Rendering.Activity.Plaintext` so textual render paths remain coherent
- Browser-side preview layer:
  - introduce `PreviewElement.ts` and `PreviewElementProvider.tsx` as the preview-mode equivalent of the existing authoring and delivery base components
  - add a feature-local shared preview library under `assets/src/components/activities/common/preview/` for the reusable card, header, details toggle, tabs, panels, and read-only supporting surfaces
  - add per-activity preview entries and preview components only for the seven scoped activity types
- Page template / bundle injection layer:
  - update Instructor View script injection so the page includes the union of scripts actually required by that page's rendered activities
  - for supported activities this means `preview_script`; for fallback activities it remains `authoring_script`
  - dedupe at the page level to avoid redundant bundle tags

### 4.2 State & Data Flow
1. `render_page_preview/3` resolves page activities and registrations.
2. For each activity, the controller builds an `ActivitySummary` containing:
   - existing model and bibliography data
   - legacy authoring and delivery element/script fields
   - optional preview element/script fields from registration
   - preview context built from section, page, activity, points, and learning objectives
3. The controller renders page content in `mode: :instructor_preview`.
4. `Oli.Rendering.Activity.Html` inspects each summary:
   - if `preview_element` is present, emit that custom element with `mode="preview"` and an encoded `previewcontext`
   - if `preview_element` is absent, emit the existing authoring element with `mode="instructor_preview"` and `authoringcontext`
5. The Instructor View template includes the page's union of preview and fallback scripts so all emitted custom elements can register.
6. Preview components manage only local read-only UI state such as collapsed/expanded sections, selected tabs, and selected Multi Input part.

### 4.3 Lifecycle & Ownership
- Backend ownership:
  - activity registration parsing, persistence, and retrieval remain in `lib/oli/activities`
  - preview context assembly belongs in the delivery/controller pipeline because it depends on section/page/activity facts already owned server-side
  - render-mode selection belongs in `lib/oli/rendering/activity`
- Frontend ownership:
  - shared preview chrome and local UI state belong in the activities React layer
  - activity-specific answer-key or participation presentation belongs in each activity directory
  - preview components must remain read-only and must not own future customization persistence rules
- Future-ticket ownership:
  - `MER-5639` owns backend enable/disable APIs, validation, persistence, and read models
  - `MER-5620` and later tickets consume the preview contract to add visible customization controls

### 4.4 Alternatives Considered
- Continue branching inside authoring components:
  - rejected because it increases coupling between authoring and instructor preview and perpetuates the exact pattern this story is intended to replace
- Flip the whole page to preview-or-legacy as a single mode:
  - rejected because Jira and the PRD require mixed pages to work when only some activities are migrated
- Build preview entirely from the existing delivery components:
  - rejected because several preview details are instructor-specific, read-only, and structurally different from learner delivery, especially answer-key tabs and Directed Discussion participation settings
- Avoid persisting preview metadata and derive bundle names conventionally:
  - rejected because the current system persists script/element metadata in registrations and uses that data broadly; adding preview as a real third mode is simpler and more explicit than introducing one-off naming inference only for Instructor View

## 5. Interfaces
- Activity manifest JSON:
  - add optional top-level `preview` with the same shape as `authoring` and `delivery`
  - example:
    ```json
    {
      "preview": {
        "element": "oli-multiple-choice-preview",
        "entry": "./preview-entry.ts"
      }
    }
    ```
  - as with `authoring` and `delivery`, the manifest `entry` remains a source-file pointer while persisted registration metadata uses the normalized emitted bundle name `<id>_preview.js`
- Persisted activity registration:
  - add nullable `preview_script` and `preview_element` columns to `activity_registrations`
  - expose them through `Oli.Activities.ActivityRegistration`
- `Oli.Activities.Manifest`:
  - add `:preview` field parsed from the manifest when present
- `Oli.Rendering.Activity.ActivitySummary`:
  - add `:preview_script`, `:preview_element`, and `:preview_context`
- Rendered preview custom element contract:
  - required attributes:
    - `mode="preview"`
    - `model`
    - `activityId`
    - `section_slug`
    - `activity_id`
    - `bib_params`
    - `previewcontext`
  - fallback authoring path continues using the existing `authoringcontext` contract
- Preview context v1:
  - exact field names are finalized in implementation, but the shape must include:
    - activity identity and DOM identity
    - page and section identity needed by later customization actions
    - read-only display metadata such as title, points, and learning objectives
    - neutral future-facing customization target data
  - must exclude:
    - persisted enabled state transitions
    - warning state about attempts
    - bank selection/candidate management payloads
    - global counters
- Instructor View script selection:
  - add a page-level function that derives the unique script list from rendered activity summaries, preferring `preview_script` when present and otherwise using `authoring_script`

## 6. Data Model & Storage
- Database changes:
  - migration to add `preview_script` and `preview_element` nullable string columns to `activity_registrations`
  - no new tables and no backfill beyond leaving existing registrations null for preview fields
- Ecto changes:
  - update `Oli.Activities.ActivityRegistration` schema, cast list, and validation rules so preview fields are optional
  - keep existing authoring and delivery fields required
- In-memory data changes:
  - extend `Oli.Activities.Manifest`
  - extend `Oli.Rendering.Activity.ActivitySummary`
- No domain persistence changes for instructor customization state are included in this story

## 7. Consistency & Transactions
- Registration updates remain part of the existing activity-registration write path and use the same Repo transaction semantics already in place for registration creation and updates.
- Preview rendering itself is read-only request-time assembly and does not require new transaction boundaries.
- Because `MER-5618` does not write customization state, there are no new cross-request consistency guarantees beyond correct selection of preview versus fallback render paths.

## 8. Caching Strategy
- No new cache layer is required.
- Existing request-time activity resolution and registration lookup should continue to be used.
- Page-level script list derivation should be done from already-resolved summaries in memory rather than by adding additional database queries.

## 9. Performance & Scalability Posture
- The design avoids per-activity extra fetches by building preview context from data already resolved during page-preview assembly.
- Mixed pages should only pay for the script bundles actually needed by their activities.
- Shared preview primitives reduce duplicate client code across the seven activities and help keep preview bundles smaller than copying full authoring surfaces.
- No new background jobs, polling, or live channels are introduced.

## 10. Failure Modes & Resilience
- Supported activity is missing preview registration data:
  - development and test should fail via targeted coverage and explicit assertions
  - runtime fallback can still render the authoring path if preview metadata is absent, but this should be treated as a misconfiguration and logged
- Unsupported activity has no preview metadata:
  - expected behavior; render legacy authoring preview without warning
- Preview component JS bundle is missing:
  - browser registration will fail for that custom element; AppSignal/logging and targeted tests should make this visible
  - the server-side page still renders, limiting blast radius to the affected activity UI
- Preview context shape drift:
  - mitigate by centralizing preview context assembly and adding targeted tests around emitted attributes
- Likert expanded design remains unresolved at implementation time:
  - implement the shared accordion/tabs pattern conservatively and document any design-confirmation follow-up before merge

## 11. Observability
- Reuse existing AppSignal/error logging for render-time exceptions and missing custom-element registration failures.
- Add targeted warning logs when a Jira-scoped preview activity is rendered in `:instructor_preview` without preview metadata, because that indicates an incomplete migration rather than an expected fallback.
- No new product analytics event is required in this story because preview must remain read-only and must not behave like learner delivery.
- If implementation needs a lightweight operational signal, prefer a small telemetry event or structured log around preview-versus-fallback selection at the page level rather than per-interaction browser analytics.

## 12. Security & Privacy
- Instructor View authorization remains unchanged and continues to be enforced by existing controller/session checks.
- Preview context must only include data already appropriate for Instructor View and must not leak student attempt payloads or authoring-only mutable controls.
- Preview components must not expose mutation endpoints or learner submission hooks.
- No new sensitive storage is introduced.

## 13. Testing Strategy
- Elixir tests:
  - manifest parsing tests for optional preview mode
  - activity registration tests covering preview fields
  - page-preview controller/render tests proving:
    - supported activities emit preview elements and preview scripts
    - unsupported activities emit legacy authoring elements and authoring scripts
    - mixed pages include the correct union of scripts
  - renderer tests for `Oli.Rendering.Activity.Html` and `Plaintext` fallback behavior
- TypeScript/Jest tests:
  - shared preview primitive tests for accordion/tabs/local state where logic is isolated
  - Multi Input preview tests proving the expanded details region changes with selected part/input type
  - Directed Discussion preview tests proving only participation and hints surfaces are shown
- Manual validation:
  - confirm the seven supported activities match the referenced Figma states
  - confirm unsupported activities still render on mixed pages
  - confirm no edit controls, learner attempts, or submission side effects occur

## 14. Backwards Compatibility
- Delivery and authoring routes keep using existing registration fields and rendering behavior.
- Unsupported activities keep their current Instructor View experience because preview fields are optional and fallback is per activity.
- Existing activity manifests without `preview` remain valid.
- Existing persisted registrations remain valid after the nullable-column migration.

## 15. Risks & Mitigations
- Rendering-path sprawl:
  - mitigate by making preview a first-class third mode in registration and summary data instead of ad hoc branching
- Mixed-page regressions:
  - mitigate with page-level tests that exercise supported and unsupported activities together
- Over-reuse of authoring components:
  - mitigate by centralizing shared preview chrome in `activities/common/preview/` and explicitly avoiding authoring-only widgets
- Likert design ambiguity:
  - mitigate by tracking it as a follow-up confirmation and keeping the rest of the architecture independent from that single activity's exact expanded layout
- Future customization coupling:
  - mitigate by introducing only a neutral preview context v1 and keeping mutation semantics out of this story

## 16. Open Questions & Follow-ups
- What is the approved expanded-state treatment for `Likert`?
- Follow-up for `MER-5620`:
  - reuse the preview context v1 contract rather than introducing a second instructor-customization rendering mode
- Follow-up for implementation:
  - if the existing page-preview template hardcodes authoring-script collection assumptions, update that template alongside the controller so mixed preview pages stay coherent

## 17. References
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/informal.md`
- `docs/exec-plans/current/epics/instructor_customizations/preview_components/design/preview_question_ui.md`
- `docs/exec-plans/current/epics/instructor_customizations/overview.md`
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`
- `lib/oli_web/controllers/page_delivery_controller.ex`
- `lib/oli/rendering/activity/html.ex`
- `lib/oli/rendering/activity/plaintext.ex`
- `lib/oli/rendering/activity/activity_summary.ex`
- `lib/oli/activities.ex`
- `lib/oli/activities/manifest.ex`
- `lib/oli/activities/activity_registration.ex`
- `assets/webpack.config.js`
- `assets/src/components/activities/types.ts`
