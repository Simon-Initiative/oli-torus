# Keep activity resource IDs in authoring page content

## Goal and scope

Keep the persisted `activity_id` in the JSON sent to and saved by authoring editors. Remove the activity-reference slug/ID translation in `lib/oli/authoring/editing/page_editor.ex`. This is one coordinated change suitable for one PR.

The reference contract becomes:

```json
{ "type": "activity-reference", "id": "content-node-id", "activity_id": 123, "children": [] }
```

`id` remains the content-node identity; `activity_id` is the numeric activity **resource** ID, not a revision ID. Nested references use the same contract.

Keep revision slugs in activity metadata where still used, notably the activity history URL in `assets/src/components/activity/InlineActivityEditor.tsx` and adaptive sequence metadata. Do not refactor activity-bank state, adaptive navigation, objective attachments, publication resolution, or API routing merely to remove all occurrences of `activitySlug`.

## 1. Backend contract

- [x] In `lib/oli/authoring/editing/page_editor.ex`, return `revision.content` directly from `create_context/3`; delete `convert_to_activity_slugs/2`.
- [x] Remove `convert_to_activity_ids/1` and its call from `edit/4`. Pass the ID-based update through learning-objective normalization, feature validation, reference resurrection/deletion, and revision persistence. Replace references to `converted_update` with the appropriate original/normalized update without changing existing ordering or behavior.
- [x] Preserve the existing failure behavior for invalid references: add a small validation-only step for supplied content, traversing nested activity references and rejecting absent/non-integer IDs and unknown resources with `{:error, :not_found}`. Batch the existence check; do not resolve slugs or rewrite content. Preserve deleted-activity references needed for undo/resurrection. Use existing project/publication activity resolution where suitable, rather than admitting references outside the project's working publication.
- [x] Keep updates without `content` working. Keep lock/authorization checks, publication selection, and revision creation intact.
- [x] Leave auxiliary activity metadata (`activities`, `activityContexts`, `activitySlug`) intact. The `activities` dictionary can remain slug-keyed: adaptive initialization enumerates its values, and the basic page editor builds its own context index. Rekeying it would expand the public context contract without helping eliminate the conversion.
- [x] Do not delete `Resources.map_resource_ids_from_slugs/1` merely because this caller disappears; first check other callers.

Verification: load/save nested references with the same numeric IDs; verify new revisions, removal/undo, unknown-ID rejection, and title/objectives-only edits. Assert context content contains `activity_id` without an added `activitySlug` for canonical stored references.

## 2. Basic React page editor

- [x] In `assets/src/data/content/resource.ts`, replace `ActivityReference.activitySlug` with `activity_id: ResourceId`.
- [x] In `assets/src/apps/page-editor/PageEditor.tsx`, key `activityContexts` and `activityPersistence` by `String(context.activityId)`. Update initialization, pending-save setup, edits, LTI prepare/save lookups, insertion, duplication matching, and activity undo lookups consistently.
- [x] Keep string keys in the existing Immutable maps/callbacks and undo records. Stringifying a resource ID at a lookup boundary avoids widening mixed page-node/activity undo identifiers or changing all shared prop types. Avoid iterating numeric Immutable keys through `Object.keys`; retaining string keys prevents that mismatch.
- [x] Update reference lookups to `String(contentItem.activity_id)` in:
  - `assets/src/components/resource/editors/ActivityEditor.tsx`
  - `assets/src/components/resource/editors/ContentOutline.tsx`
  - `assets/src/components/resource/editors/dragndrop/utils.ts`
  - `assets/src/components/resource/editors/dragndrop/handlers/focus.ts`
- [x] In the resource `ActivityEditor`, send the same ID-derived string key to edit/undo callbacks; continue passing the real metadata `activitySlug` to `InlineActivityEditor` for its history link.
- [x] In `assets/src/components/content/add_resource_content/AddActivity.tsx`, construct references with `activity_id: result.resourceId`; keep both identity metadata fields in the separate activity context.
- [x] In page duplication, use `origContext.activityId` from the enclosing callback to find the original node and `newContext.activityId` for the new reference. Leave the shared `createCopy` callback and `assets/src/apps/bank/ActivityBank.tsx` unchanged; the bank still uses its existing slug-keyed state.
- [x] Check drag/move/drop handlers, nested group/survey/report/alternative editors, and outline prop forwarding for indirect assumptions. Their string-keyed map types can stay unchanged. Drag payload references should naturally carry `activity_id`; avoid unrelated repairs to existing cross-project drop behavior.

Verification: load and edit an existing activity; add, duplicate, reorder, remove and undo; render nested references and outline labels; confirm deferred activity saves and LTI saves still target `activityId`, and history links still use slugs. No reference operation should require looking up an activity by slug.

## 3. Adaptive authoring: required shared-payload compatibility

The adaptive editor consumes the same `PageEditor.create_context/3` output and saves through the same page API. It currently reconstructs `resourceId` by matching `activitySlug`, then strips `resourceId` before saving. Changing only the basic editor would break this path.

- [x] In `assets/src/apps/authoring/store/page/actions/initializeFromContext.ts`, hydrate sequence entries from `activity_id`: set internal `resourceId` directly and recover any required internal `activitySlug` metadata by matching activity resource IDs. Remove the slug-based resource-ID lookup. Keep sequence IDs, layer references, and navigation semantics intact.
- [x] Ensure all new sequence entries include `activity_id` when created in:
  - `assets/src/apps/authoring/store/page/actions/initializeFromContext.ts` (blank lesson bootstrap)
  - `assets/src/apps/authoring/components/SequenceEditor/SequenceEditor.tsx` (new and copied entries)
  - `assets/src/apps/authoring/components/Flowchart/flowchart-actions/add-screen.ts`
  - `assets/src/apps/authoring/components/Flowchart/flowchart-actions/duplicate-screen.ts`
- [x] In `assets/src/apps/authoring/store/page/actions/savePage.ts`, extend the existing recursive serialization pass: emit `activity_id` from the reference's numeric internal `resourceId`, remove reference-level `activitySlug`, and continue stripping internal `resourceId`. Keep this adaptation local to the existing save boundary; no new generalized identity abstraction.
- [x] Leave activity records, adaptive sequence navigation, `custom.layerRef`, sequence identifiers, and delivery state slug metadata alone. Those are separate from the page-reference wire contract.

Verification: load/save an existing adaptive lesson; bootstrap a blank lesson; add/copy a screen in both sequence and flowchart editors; reload and verify ordering, layers, and navigation. The resulting page payload must retain numeric `activity_id` on every reference, including nested references.

## 4. Producers, fixtures, and regression coverage

- [x] Update page-edit fixtures that currently submit slug references in:
  - `test/oli/editing/page_editor_test.exs`
  - `test/oli/editing/activity_editor_test.exs`
  - `test/oli/editing/objective_editor_test.exs`
  - `test/oli/authoring/learning_objectives/page_element_test.exs`
  - `test/oli_web/controllers/activity_controller_test.exs`
  - `test/oli_web/controllers/api/lti_controller_test.exs`
  - `test/oli_web/controllers/api/lti_controller_integration_test.exs`
  - `test/oli_web/controllers/lti_controller_test.exs`
  - `test/oli/publishing_test.exs` (page-edit inputs only)
- [x] Update the existing activity-editor round-trip assertion that currently checks slug translation and slug-keyed content lookup. Assert the resource ID survives save/load and matches the resource ID in the accompanying activity metadata.
- [x] Update frontend reference fixtures and lookup expectations in `assets/test/page_editor/nested_lti_configuration_test.tsx`, `assets/test/page_editor/lti_save_test.tsx`, and `assets/test/data/content/learningObjectives_test.ts`. Keep metadata slugs where still required.
- [x] In `assets/test/activity_schemas/adaptive_page_schema_test.ts`, model the new ID-based outgoing payload instead of simulating the removed backend slug conversion. Update affected adaptive diagnostics/authoring fixtures where they represent page references.
- [x] Inspect `lib/oli/google_docs/import.ex` and `lib/oli/torus_doc/page_converter.ex`: both already emit `activity_id` plus redundant reference-level `activitySlug`. Remove that redundant field from canonical reference construction and update its direct assertions in `test/oli/torus_doc/page_converter_test.exs`, `test/oli/torus_doc/page_with_activity_test.exs`, and `test/oli/scenarios/edit_page_virtual_id_test.exs`; adjust `lib/oli/torus_doc/mcq_demo.exs` display accordingly. Preserve virtual-ID and inline-activity resolution behavior.
- [x] Preserve tests intentionally exercising legacy publishing/schema compatibility (`activitySlug`-only malformed/legacy content). Those are not editor fixtures and should not be mechanically rewritten. Likewise, leave delivery activity metadata and adaptive navigation slug fixtures intact.
- [x] Add focused behavioral coverage for ID-based page context/save, nested references, invalid IDs, basic editor lookup/duplication/undo, and adaptive load/save. Prefer extending existing tests over introducing new test infrastructure or mirrored implementation tests.

## Completion and integration checks

- [x] Run the affected ExUnit files above plus `test/oli_web/controllers/api/resource_controller_test.exs`, relevant Google Docs import tests, and the existing adaptive-authoring integration tests. Run affected frontend page-editor, editor-content, adaptive-authoring, and schema Jest tests.
- [x] Run `yarn check-types` from `assets`, focused lint/format checks for changed frontend files, and `mix format --check-formatted` for changed Elixir files. The full `mix test` is tracked separately below. Do not modify shared test setup for this change.
- [x] Verify saved JSON and loaded context for both editor families: numeric `activity_id` remains stable through page/activity revision changes; objectives, bank criteria, and history links continue working.
- [x] Search remaining `activitySlug` references and classify them: valid metadata/navigation/history/legacy compatibility versus accidental page-reference dependence. Confirm both backend conversion helpers and their calls are gone.
- [x] Perform final independent review following `docs/CODEREVIEW.md`, covering security, performance, Elixir, and TypeScript; add UI review if interaction changes warrant it. Check reference validation, deleted-activity resurrection, and absence of per-reference queries.

No database migration is needed: canonical persisted page references already use `activity_id`. Ship frontend/backend together. Existing editor tabs running the previous bundle will still submit slug-only references and will need a reload after deployment; do not retain a slug-to-ID fallback as part of this cleanup.

No unresolved implementation decisions are required for this plan. Mixed-version compatibility across deployment is the only operational caveat; a requirement to support old open tabs would need a separately agreed transition period.

## Implementation notes and verification

- Basic references and editor lookup/persistence keys now use resource IDs. Slugs remain separate history/navigation metadata; the auxiliary server activity dictionary remains unchanged.
- Adaptive hydration copies Redux-frozen bootstrap groups and uses `resourceId` when assimilating server-shaped activity metadata (which lacks `activityId`). Regression cases cover grouped, blank, and ungrouped lessons.
- The canonical adaptive payload guide and current MCP expansion reference-policy description were reconciled with the new contract. Legacy schema acceptance remains unchanged.
- Final focused backend run: **296 tests, 0 failures**, covering every changed backend test plus both resource controllers and Google Docs imports. ExUnit output contained only normal progress and summary.
- Final focused frontend run: **27 suites / 136 tests passed**, including adaptive load/save, nested rendering, LTI saves, editing, duplication and undo. `yarn check-types`, focused ESLint, Prettier, Elixir formatting, and `git diff --check` pass. Node checks used installed Node 24.20.0 through `ASDF_NODEJS_VERSION`, preserving the user's `.tool-versions` edit.
- Full suite on an isolated database: **26 doctests, 10,586 tests, 10 failures (75 excluded)**. Failures occur in untouched resource/publisher/brand/institution count tests and LTI keyset mock expectations. A separate 40-test run of the implicated inventory/LTI tests plus secure-assessment concurrency tests passes in isolation, supporting an existing order-dependent test-isolation issue. The full run also emits an unrelated instructor-dashboard database-ownership log. Full-suite cleanliness remains a verification limitation; no shared test support or unrelated application code was modified.
- Independent security, performance, Elixir and UI reviews returned no findings. TypeScript review found the ungrouped adaptive assimilation issue described above; it was fixed, covered by a regression test, and confirmed resolved by the reviewer. No findings remain.
- No browser smoke test was performed. No commit or deployment was requested. Existing editor tabs need a reload when this coordinated frontend/backend change is deployed.
