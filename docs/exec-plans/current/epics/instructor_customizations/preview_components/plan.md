# Preview Components - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/epics/instructor_customizations/preview_components/prd.md`
- FDD: `docs/exec-plans/current/epics/instructor_customizations/preview_components/fdd.md`

## Scope
Deliver `MER-5618` as the Core-UI slice that introduces first-class `preview` activity rendering for the seven Jira-supported activity types in Instructor View, provides the new read-only preview UI for those activities, preserves legacy Instructor View fallback for unsupported activities on mixed pages, and leaves remove/restore behavior to later tickets.

## Clarifications & Default Assumptions
- Jira scope is authoritative: this plan covers only Multiple Choice, Check All That Apply, Multi Input, Image Hotspot, Likert, Ordering, and Directed Discussion.
- Fallback is per activity, not per page.
- `preview` follows the same normalized bundle naming convention as existing modes: `<id>_preview.js`.
- `Likert` expanded remains the only unresolved visual detail; implementation should use the shared preview pattern conservatively unless design clarifies it first.
- No feature flag is planned for this work item.

### Requirements Traceability
- `FR-001`, `AC-001`:
  - covered by Phases 1 and 2 through manifest, registration, bundle, summary, and renderer changes that add first-class preview mode support
- `FR-002`, `AC-002`, `AC-003`, `AC-004`, `AC-005`:
  - covered by Phases 3 and 4 through shared preview UI and per-activity preview implementations for the seven supported types
- `FR-003`, `AC-007`, `AC-008`:
  - covered by Phases 3 and 4 through read-only preview components and explicit avoidance of authoring controls and mutation surfaces
- `FR-004`, `AC-009`:
  - covered by Phases 2 and 5 through per-activity fallback behavior and mixed-page verification
- `FR-005`, `AC-010`:
  - covered by Phases 2, 4, and 5 through side-effect-free preview rendering and regression checks around Instructor View behavior
- `FR-006`, `AC-011`:
  - covered by Phases 1, 2, and 5 through additive preview metadata and backwards-compatible route behavior
- `AC-006`:
  - covered by Phase 4 through Multi Input and other multi-part preview behavior tied to selected parts

## Phase 1: Registration And Bundle Infrastructure
- Goal: add preview mode as a first-class third activity mode in manifests, registrations, and bundle generation without changing existing authoring or delivery behavior.
- Tasks:
  - [x] Add nullable `preview_script` and `preview_element` columns to `activity_registrations`.
  - [x] Extend `Oli.Activities.ActivityRegistration` schema, changeset, and registration write path for preview metadata.
  - [x] Extend `Oli.Activities.Manifest` parsing to accept optional `preview` mode specifications.
  - [x] Update `Oli.Activities.register_activity/2` and related projections to persist normalized preview bundle names as `<id>_preview.js`.
  - [x] Update `assets/webpack.config.js` entry discovery so activities with `manifest.preview` emit preview bundles in addition to existing authoring/delivery bundles.
  - [x] Add `preview` blocks to the seven in-scope local activity manifests.
- Testing Tasks:
  - [x] Add Elixir tests for manifest parsing and activity registration preview fields.
  - [x] Add build-path coverage or assertions for preview bundle entry generation.
  - Command(s): `mix test test/oli/activities`, `mix test test/oli_web`, `cd assets && yarn test`
- Definition of Done:
  - preview metadata can be parsed, persisted, and retrieved for supported activities
  - preview bundles are emitted for supported activities without regressing authoring or delivery bundles
- Gate:
  - all registration and manifest tests pass, and no existing activity registration behavior regresses
- Dependencies:
  - none
- Parallelizable Work:
  - preview manifest additions across the seven activity directories can be split while shared registration and webpack work is in progress

## Phase 2: Instructor View Rendering Pipeline
- Goal: teach Instructor View to render supported activities through preview components while preserving legacy fallback per activity.
- Tasks:
  - [x] Extend `Oli.Rendering.Activity.ActivitySummary` with `preview_script`, `preview_element`, and `preview_context`.
  - [x] Update `render_page_preview/3` in `lib/oli_web/controllers/page_delivery_controller.ex` to populate preview fields and derive a page-level union of required scripts.
  - [x] Update `Oli.Rendering.Activity.Html` to emit preview elements with `mode="preview"` and `previewcontext` when preview metadata exists, falling back to legacy authoring elements otherwise.
  - [x] Mirror the same supported/fallback selection rule in `Oli.Rendering.Activity.Plaintext`.
  - [x] Ensure the Instructor View template injects preview and fallback scripts coherently for mixed pages.
  - [x] Add warning logs or equivalent operational visibility when a Jira-scoped supported activity renders without preview metadata.
- Testing Tasks:
  - [x] Add Elixir tests proving supported activities use preview elements and unsupported ones use legacy authoring elements.
  - [x] Add mixed-page tests proving the script list includes the correct union of preview and fallback bundles.
  - [x] Add regression tests proving authoring and delivery routes continue using their existing paths.
  - Command(s): `mix test test/oli/rendering`, `mix test test/oli_web/controllers`, `mix test test/oli_web`
- Definition of Done:
  - Instructor View can render preview-backed and legacy activities on the same page
  - render pipeline remains additive and does not alter authoring or delivery behavior
- Gate:
  - controller and renderer tests pass for supported, unsupported, and mixed-page cases
- Dependencies:
  - Phase 1
- Parallelizable Work:
  - preview context assembly and page-level script selection can proceed in parallel with plaintext/renderer fallback updates once the new summary fields exist

## Phase 3: Shared Preview UI Foundation
- Goal: establish the shared preview React surface and the reusable read-only components needed by all seven activities.
- Tasks:
  - [x] Create `PreviewElement.ts` and `PreviewElementProvider.tsx`.
  - [x] Create the shared preview-local library under `assets/src/components/activities/common/preview/`.
  - [x] Implement common preview chrome:
    - [x] card shell
    - [x] header with activity type, title, and points
    - [x] details accordion toggle
    - [x] tabs/panel primitives
    - [x] learning objective list
    - [x] shared read-only panel styles for answer key, hints, explanation, and participation surfaces
  - [x] Ensure the shared preview primitives remain feature-local and do not depend on authoring-only providers or controls.
  - [x] Add accessibility support for keyboard operation, focus visibility, and semantic structure in the shared preview primitives.
- Testing Tasks:
  - [x] Add Jest tests for accordion/tabs/local state and shared preview rendering behavior.
  - [x] Add targeted accessibility assertions where practical for the shared primitives.
  - Command(s): `cd assets && yarn test`
- Definition of Done:
  - the project has a reusable preview foundation that can host all seven scoped activity previews
  - no shared preview primitive depends on authoring mutation flows
- Gate:
  - shared preview tests pass and primitives support the Figma-derived common interaction pattern
- Dependencies:
  - Phase 2 for final rendered contract, though initial component work can begin once the preview context shape is stable enough
- Parallelizable Work:
  - shared preview shell, tabs, and learning-objective surfaces can be developed concurrently once `PreviewElementProvider` exists

## Phase 4: Activity Preview Implementations
- Goal: implement the seven supported activity previews on top of the shared preview foundation.
- Tasks:
  - [ ] Add preview entrypoints and preview components for:
    - [ ] Multiple Choice
    - [ ] Check All That Apply
    - [ ] Multi Input
    - [ ] Image Hotspot
    - [ ] Likert
    - [ ] Ordering
    - [ ] Directed Discussion
  - [ ] Reuse safe readonly delivery/stem rendering where appropriate without pulling in learner-attempt or authoring-only behavior.
  - [ ] Implement activity-specific expanded details behavior:
    - [ ] answer key, hints, and explanation for MCQ, CATA, Ordering, Hotspot, and applicable Multi Input parts
    - [ ] participation and hints for Directed Discussion
    - [ ] selected-part-sensitive details for Multi Input
    - [ ] conservative shared-pattern implementation for `Likert` expanded unless design clarifies it first
  - [ ] Ensure preview UI excludes authoring controls, editors, and mutation surfaces.
- Testing Tasks:
  - [ ] Add Jest tests for activity-specific preview behavior, especially Multi Input selected-part behavior and Directed Discussion participation surfaces.
  - [ ] Add or update integration-level Elixir tests proving supported activities render the intended preview custom elements.
  - Command(s): `cd assets && yarn test`, `mix test test/oli_web`, `mix test test/oli/rendering`
- Definition of Done:
  - all seven scoped activities render through preview mode in Instructor View with the required read-only surfaces
  - Multi Input and Directed Discussion special cases behave as described in the PRD/Figma references
- Gate:
  - supported-activity preview tests pass and no scoped activity still depends on the authoring-derived instructor preview path
- Dependencies:
  - Phases 1 through 3
- Parallelizable Work:
  - individual activity preview implementations can be split across separate work threads once the shared preview foundation is stable

## Phase 5: Mixed-Page Hardening And Regression Verification
- Goal: verify compatibility, side-effect-free behavior, observability, and final scope boundaries before implementation handoff or merge.
- Tasks:
  - [ ] Verify mixed pages with supported and unsupported activities render correctly and load only the required bundles.
  - [ ] Verify Instructor View preview remains side-effect free and does not create learner attempts, progress, submissions, or analytics events.
  - [ ] Verify authoring and delivery routes remain unchanged after preview metadata is introduced.
  - [ ] Verify logs/operational signals are sufficient for missing preview metadata or missing preview bundle failures.
  - [ ] Reconcile any `Likert` expanded implementation notes if design clarification arrives during implementation.
  - [ ] Update docs if final implementation requires any narrow drift from the current FDD/brief assumptions.
- Testing Tasks:
  - [ ] Run the targeted Elixir and Jest suites covering phases 1 through 4.
  - [ ] Perform manual Instructor View validation for each supported type plus at least one mixed page containing unsupported activities.
  - [ ] Run formatting or linting commands required by the touched surfaces.
  - Command(s): `mix test test/oli/rendering test/oli_web test/oli/activities`, `cd assets && yarn test`, `mix format`
- Definition of Done:
  - all scoped acceptance criteria are covered by automated or explicit manual verification
  - mixed-page fallback, backwards compatibility, and no-side-effect behavior are confirmed
- Gate:
  - targeted automated tests pass and manual verification confirms the supported preview experience matches the approved design intent closely enough to ship
- Dependencies:
  - Phases 1 through 4
- Parallelizable Work:
  - manual verification and docs reconciliation can run while final low-risk test fixes or accessibility polish land

## Parallelization Notes
- Phase 1 manifest updates can be parallelized per activity directory once the registration and webpack approach is fixed.
- In Phase 3, shared preview shell, tabs, and supporting panels can proceed concurrently after the base preview element/provider contract is established.
- In Phase 4, the seven preview implementations can be split by activity family:
  - choice-based: MCQ, CATA
  - structured response: Multi Input, Ordering
  - media/discussion: Hotspot, Directed Discussion
  - standalone: Likert
- Mixed-page hardening should not start until preview rendering and at least one unsupported fallback case are both working end to end.

## Phase Gate Summary
- Gate A: preview metadata and bundles are first-class and backwards-compatible.
- Gate B: Instructor View rendering pipeline supports preview and legacy fallback per activity.
- Gate C: shared preview primitives are stable, accessible, and read-only.
- Gate D: all seven scoped activities render through preview mode with required details behavior.
- Gate E: mixed-page compatibility, no-side-effect behavior, and regression checks are complete.
