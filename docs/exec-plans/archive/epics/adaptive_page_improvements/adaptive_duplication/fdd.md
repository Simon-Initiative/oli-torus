# Functional Design Document: Adaptive Page Duplication

## 1. Executive Summary

Adaptive page duplication needs a dedicated authoring-path implementation because adaptive pages do not behave like ordinary page duplication. The page revision stores an ordered deck of screen references, while each duplicated adaptive screen may also contain resource-id-bearing references that must be remapped after copy. The design in this document introduces a standalone server-side module, `AdaptiveDuplication`, that performs a transactional, set-based duplication of an adaptive page and all referenced adaptive screens, then rewrites resource-id references before the new page is attached back into the project.

The key design choice is to treat "single query" as "single bulk phase per table and rewrite step," not "one SQL statement for the entire workflow." A literal one-statement copy across `resources`, `project_resources`, and `revisions` is possible with hand-written SQL CTEs, but it would be harder to maintain and reason about than a single transaction containing a small number of set-based inserts and updates. The accepted design therefore uses one transaction with one bulk insert into `resources`, one bulk insert into `project_resources`, one bulk insert into `revisions`, one bulk insert into `published_resources` for the current working publication, one bulk update for changed duplicated screen revisions, one bulk insert triplet for the page copy, and one update for the new page revision. This satisfies the performance intent behind FR-003 and AC-004 while keeping the implementation auditable.

This design fulfills FR-001, FR-002, FR-003, FR-004, FR-005, and FR-006. Acceptance criteria are covered explicitly through the algorithm, rewrite surface inventory, transaction boundaries, feature gating, and verification strategy in AC-001 through AC-010.

## 2. Requirements & Assumptions

### 2.1 Requirements Snapshot

- FR-001: Adaptive page duplication must create a new adaptive page plus duplicated adaptive screens rather than pointing at the original screens.
- FR-002: Page-level sequence mapping must remain valid after duplication.
- FR-003: Duplication must use bulk, set-based persistence rather than N-per-screen inserts.
- FR-004: Adaptive screen content must be remapped anywhere duplicated screen resource ids are referenced.
- FR-005: The capability must be gated behind an adaptive authoring feature flag.
- FR-006: Existing non-adaptive page duplication behavior must remain unchanged.

### 2.2 Assumptions

- The entry point receives a `project` and adaptive page `resource_id`, per product direction, and resolves the current authoring-head page revision from that resource.
- The source page is an authoring-page resource whose content has `advancedDelivery: true`, `model[0].type = "group"`, and `model[0].layout = "deck"`. If not, the adaptive duplication module exits with a structured non-adaptive error and the caller falls back to the existing path.
- The source adaptive page references adaptive screens through `activity-reference` children whose `activity_id` values are screen resource ids and whose `custom.sequenceId` / `custom.sequenceName` values are retained unchanged in the duplicate.
- The user-visible requirement is bulk duplication, not a hard requirement for a single SQL statement across all touched tables. The implementation should favor deterministic set-based inserts inside one transaction.
- Only authoring-head resources in the same project are in scope. Published artifacts, section attempts, and delivery data are unaffected.
- This FDD assumes the canary rollout feature `adaptive_duplication` described in the PRD remains the gating mechanism.

## 3. Repository Context Summary

Adaptive pages are represented as deck-layout pages whose sequence list lives in page JSON. The server already extracts this page-level screen mapping in `Oli.Conversation.AdaptivePageContextBuilder`, and the delivery path resolves the deck children by `activity-reference.activity_id` via `Oli.Delivery.ActivityProvider`. On the client side, adaptive navigation and state scoping primarily use `sequenceId`, while server-side loading, attempts, and cross-screen evaluation still rely on actual screen `resource_id` values.

The current generic duplication path in `Oli.Authoring.Editing.ContainerEditor` deep-copies `activity-reference` children one by one through existing activity creation helpers. That approach is acceptable for ordinary pages, but it is the wrong primitive for adaptive duplication because it does not provide an efficient old-to-new screen resource map, and it makes it difficult to perform a full second-pass remap of adaptive-only resource-id references.

The repository already contains strong precedents for the required mechanics:

- bulk `insert_all` resource and revision creation patterns in `Oli.Interop.Ingest.Processor.Common`
- internal activity-reference rewiring logic in `Oli.Interop.Ingest.Processor.InternalActivityRefs`
- adaptive link and page-link rewiring logic in `Oli.Interop.Ingest.Processor.Rewiring` and `Oli.Interop.RewireLinks`

Those patterns justify a dedicated duplication module that combines authoring-specific duplication orchestration with existing or extracted JSON rewiring helpers.

## 4. Proposed Design

### 4.1 Module Boundary

Introduce a standalone server-side module under the authoring editing layer:

- `Oli.Authoring.Editing.AdaptiveDuplication`

This module owns adaptive-page-specific duplication only. It is invoked by the existing page duplication flow after the caller determines that the target page is adaptive and the feature flag is enabled. The existing duplication path remains the default for non-adaptive pages, satisfying FR-006 and AC-010.

### 4.2 Top-Level API

Expose a single top-level function:

```elixir
duplicate(project, adaptive_page_resource_id, opts \\ [])
```

Expected responsibilities:

- resolve the source page revision from the provided page resource id
- validate adaptive shape and feature-flag eligibility
- duplicate all referenced adaptive screens in bulk
- remap duplicated screen revisions in bulk where needed
- duplicate the page resource and rewrite its sequence map
- attach the duplicated page into the project using the existing authoring/container mechanisms
- return the duplicated page revision or a structured error

The API intentionally takes a page resource id rather than a page revision id because the operation is conceptually "duplicate this adaptive page in the project," not "duplicate this historical revision." That keeps the contract aligned with the user workflow and with AC-001.

### 4.3 Algorithm Overview

The duplication algorithm is:

1. Resolve and validate the source page.
2. Read page content and collect the ordered `activity-reference` children from the deck.
3. Bulk duplicate the referenced screen resources and their head revisions, producing an `old_resource_id => new_resource_id` map.
4. Fetch the newly duplicated screen revisions, rewrite any duplicated-screen resource references in memory, and bulk update only the revisions whose content changed.
5. Duplicate the adaptive page resource and initial revision.
6. Rewrite the duplicated page revision so its `activity-reference.activity_id` values and any other duplicated-screen resource references point at the new screen resource ids.
7. Attach the new page into the project/container and return it.

All steps occur in one transaction. Any mismatch in inserted row counts, missing source screen revisions, or invalid rewrite state causes rollback, satisfying AC-004 and AC-009.

### 4.4 Step 1: Resolve And Validate Source Page

The module loads the authoring-head page revision for the supplied page resource id and verifies:

- the resource belongs to the given project
- the feature flag is enabled for the project and actor context, per FR-005 and AC-008
- the page content is adaptive (`advancedDelivery: true`)
- the top-level model is a deck group

If any validation fails, the module returns an explicit error and does not mutate storage.

### 4.5 Step 2: Extract Ordered Screen References

The module traverses the page content and extracts each deck child with:

- `type == "activity-reference"`
- `activity_id`
- `custom.sequenceId`
- `custom.sequenceName`

The extracted list is used in two ways:

- as the authoritative ordered screen listing for rebuilding the duplicated page content
- as the source of the unique screen resource ids to duplicate

`sequenceId` and `sequenceName` are preserved as-is. They are the runtime screen key and display label respectively, and there is no evidence that adaptive duplication requires regenerating them. Preserving them avoids unnecessary churn and satisfies FR-002 and AC-002.

### 4.6 Step 3: Bulk Duplicate Adaptive Screens

This step replaces the current per-screen `ActivityEditor.create` style behavior with a set-based bulk duplication phase.

#### Accepted approach

Inside the transaction, perform:

- one bulk insert into `resources` for all duplicated screens
- one bulk insert into `project_resources` for the new screen resources
- one bulk insert into `revisions` for the duplicated initial screen revisions
- one bulk insert into `published_resources` for the current working publication so standard authoring resolution can load the duplicated screens

Each inserted revision initially carries content identical to the source screen revision. No remapping is done in the insert payload itself. The primary output of this phase is:

- `screen_resource_map :: %{old_screen_resource_id => new_screen_resource_id}`

Secondary outputs may include:

- `screen_revision_map :: %{old_screen_resource_id => new_screen_revision_id}`
- ordered tuples binding source screen ids to duplicated revision ids for later bulk update assembly

#### Why not a literal one-statement SQL copy

Three-table insertion with generated ids and deterministic old-to-new pairing is feasible with raw SQL CTEs, but it adds complexity without changing the observable requirements. The design requirement that matters is AC-004: avoid N-per-screen insert/update behavior. A transactional, set-based three-query copy phase is the maintainable interpretation of that requirement.

### 4.7 Step 4: Remap Duplicated Screen Revisions

After the duplicated screen revisions exist, the module loads their content and rewrites any resource-id-bearing fields that can point at duplicated adaptive screens. Only changed revisions are included in the bulk update set. This satisfies FR-004 and AC-005.

#### Rewrite surfaces in adaptive screen content

The remapper must inspect, at minimum, these fields:

1. `authoring.flowchart.paths[*].destinationScreenId`
   This is an authored screen-to-screen navigation target stored as a resource id. If it points to one of the original duplicated screens, it must be replaced with the mapped new resource id.

2. `authoring.activitiesRequiredForEvaluation[*]`
   This compiled evaluation dependency list stores screen resource ids, not `sequenceId` values. Any entry pointing at a duplicated original screen must be rewritten.

3. Adaptive rich-text or part-link nodes that store internal resource references under `idref`
   This includes authored links represented as nodes such as `%{"tag" => "a", "idref" => ...}` in adaptive authoring structures.

4. Adaptive node payloads and embedded components that store internal resource references under `resource_id`
   This includes known internal page/screen link payloads and iframe-style adaptive nodes where the resource-bearing field is `resource_id`.

5. Any nested `activity-reference.activity_id` nodes if an adaptive activity payload happens to embed them
   This is defensive and keeps the remapper robust even if adaptive authoring grows additional nested structures later.

The module should not rewrite:

- `custom.sequenceId`
- `custom.sequenceName`
- runtime-only delivery state keys
- arbitrary ids that are not project resource ids

#### Reuse vs extraction

Where practical, the JSON rewiring helpers already used by interop ingest should be extracted or wrapped rather than reimplemented. That is the preferred implementation path because it reduces drift across authoring paths. The FDD therefore recommends a small internal remapping helper layer shared with or derived from:

- internal activity-ref rewiring
- adaptive link/page-link rewiring

### 4.8 Step 5: Duplicate And Rewrite The Adaptive Page

Once the duplicated screens are fully remapped, the module duplicates the page resource itself:

- insert new page `resource`
- insert new page `project_resource`
- insert new initial page `revision`

The new page revision is initially copied from the source page revision unchanged. The module then rewrites the duplicated page revision content so that:

1. every deck child `activity-reference.activity_id` pointing at an original screen now points at the duplicated screen resource id
2. any other nested resource-id-bearing references in page content that point at duplicated screens are also rewritten

The page rewrite is the authoritative place where the adaptive page’s screen-to-sequence listing is re-established for the duplicate, satisfying FR-001, FR-002, AC-001, AC-002, and AC-006.

### 4.9 Page-Level Rewrite Surfaces

The page remapper must inspect, at minimum, these locations in page content:

1. `model[0].children[*]` where `type == "activity-reference"`
   Rewrite `activity_id` using the screen resource map.

2. Nested adaptive link structures under rich-text or custom nodes storing duplicated-screen references as `idref`
   Rewrite only when the referenced resource id appears in the screen resource map.

3. Nested adaptive component payloads storing duplicated-screen references as `resource_id`
   Rewrite only when the referenced resource id appears in the screen resource map.

The page remapper preserves:

- deck order
- `custom.sequenceId`
- `custom.sequenceName`

### 4.10 Container Integration

The adaptive duplication module should return a new page revision ready for insertion into the authoring container. The existing higher-level duplication flow remains responsible for deciding where in the container tree the duplicate is placed and for emitting any existing authoring notifications or broadcasts.

This keeps the adaptive module focused on duplication correctness rather than UI placement concerns.

## 5. Interfaces

### 5.1 Primary Interface

`Oli.Authoring.Editing.AdaptiveDuplication.duplicate/3`

Inputs:

- `%Project{}`
- adaptive page `resource_id`
- optional execution context, such as actor or placement metadata

Outputs:

- `{:ok, duplicated_page_revision, metadata}`
- `{:error, reason}`

Suggested metadata:

- duplicated page resource id
- duplicated screen count
- changed duplicated screen revision count
- `old_to_new_screen_resource_ids`

### 5.2 Internal Helper Interfaces

Recommended helper seams:

- `extract_adaptive_screen_refs(page_content)`
- `bulk_duplicate_resources_and_revisions(project, source_resource_ids, source_revisions, type)`
- `remap_adaptive_screen_content(content, screen_resource_map)`
- `remap_adaptive_page_content(content, screen_resource_map)`
- `bulk_update_revision_contents(changed_revision_updates)`

These helpers may remain private to the module or move into dedicated persistence/rewiring collaborators if the implementation becomes large.

## 6. Data Model & Storage

No new tables are required. The feature operates against existing authoring tables:

- `resources`
- `project_resources`
- `revisions`
- `published_resources`

The key storage behavior is:

- source screen resources remain unchanged
- new screen resources are created in the same project
- new screen revisions initially copy source content, then only the changed duplicated revisions are updated
- new duplicated screen revisions are also added to the current working publication mappings used by authoring resolution
- the new page resource and revision are created after the screen duplication/remap phase succeeds

This design preserves the existing resource/revision model and avoids any schema migration.

### 6.1 Stored Identity Rules

- `sequenceId` remains page-content metadata and is preserved verbatim.
- `sequenceName` remains page-content metadata and is preserved verbatim.
- actual adaptive screen identity for persistence and evaluation remains the duplicated screen `resource_id`.

That distinction is critical because server evaluation and delivery lookup paths depend on real resource ids, not only on sequence ids.

## 7. Consistency & Transactions

The entire workflow runs inside one `Repo.transaction`.

Transactional guarantees:

- no duplicated screen is left orphaned without its page if the workflow fails
- no rewritten screen revisions are committed unless the page duplicate also succeeds
- no page duplicate is committed if any screen mapping or rewrite step fails

Validation checks inside the transaction should include:

- inserted screen resource count equals unique source screen count
- inserted screen revision count equals unique source screen count
- every source screen id has a mapped duplicated screen id
- every duplicated screen revision slated for update still belongs to the expected duplicated resource
- page duplicate exists before the page rewrite update is issued

Any mismatch must raise or return an error that causes rollback. This directly supports AC-004, AC-005, AC-006, and AC-009.

## 8. Caching Strategy

No cache layer is introduced or required.

The operation is an authoring-side write transaction with deterministic inputs. All necessary source content should be read directly from the database at the start of the transaction. Existing cache behavior elsewhere in the application does not need special invalidation logic beyond whatever current authoring revision updates already trigger.

## 9. Performance & Scalability Posture

The design explicitly avoids the current N-per-screen duplication pattern. Performance posture is:

- one read phase for the source page and source screen revisions
- one set-based insert phase for duplicated screen resources and revisions
- one set-based update phase for changed duplicated screen revisions only
- one set-based insert phase for the duplicated page resource and revision
- one update for the duplicated page revision content

This is expected to scale predictably with the number of screens in an adaptive page and to materially outperform per-screen duplication, satisfying FR-003 and AC-004.

The implementation should preserve source screen order in memory, but all persistence work should be set-based. If ordering is needed to pair returned resource ids with source ids, the insert payload should carry a deterministic source-order index in memory rather than relying on implicit database ordering.

## 10. Failure Modes & Resilience

Primary failure modes:

- non-adaptive page passed to adaptive duplication
- feature flag disabled
- page references a screen resource whose head revision cannot be resolved
- screen duplication insert counts do not match expectations
- remapper encounters malformed content
- bulk update affects fewer rows than expected
- page duplication insert/update fails

Resilience posture:

- fail fast before any writes when validation errors are known up front
- fail closed and roll back the full transaction on persistence mismatch
- include enough error detail for logs and tests without exposing internals to the authoring UI

Malformed content should be treated as a hard duplication error rather than silently producing a partially broken duplicate.

## 11. Observability

No feature-specific telemetry, metrics, or dashboard work is required for this feature.

The implementation may continue to rely on standard application error handling and existing logs produced by the surrounding authoring stack, but adaptive duplication does not introduce any dedicated observability contract and should not add telemetry as part of scope.

## 12. Security & Privacy

The feature operates entirely on authoring content already accessible to project authors. No new privacy boundary is introduced.

Security expectations:

- authorize duplication against the project and page resource before mutation
- scope all copied resources to the same project
- never duplicate or rewrite resources outside the resolved source project
- do not follow arbitrary external ids embedded in content; only rewrite resource ids that are present in the old-to-new duplicated screen map

Feature gating through the scoped flag is also part of the safety posture because it limits rollout while the adaptive-only path is verified.

## 13. Testing Strategy

Testing should focus on remapping correctness, transactional rollback, and non-adaptive regression coverage.

### 13.1 Unit And Integration Coverage

- unit tests for adaptive page screen-ref extraction
- unit tests for page-content remapping of `activity-reference.activity_id`
- unit tests for screen-content remapping of `authoring.flowchart.paths[*].destinationScreenId`
- unit tests for screen-content remapping of `authoring.activitiesRequiredForEvaluation[*]`
- unit tests for adaptive nested `idref` and `resource_id` rewrite surfaces
- integration tests for full adaptive page duplication producing a new page plus new screen resources
- transaction rollback tests when one bulk phase fails
- regression tests proving ordinary page duplication still uses the existing path unchanged

### 13.2 Acceptance Criteria Coverage

- AC-001: duplicated adaptive page has a new page resource and duplicated screen resources
- AC-002: duplicated page retains the same ordered `sequenceId` / `sequenceName` listing while pointing at new screen resource ids
- AC-003: source page and source screens remain unchanged
- AC-004: duplication performs set-based persistence rather than per-screen inserts
- AC-005: duplicated screen revisions rewrite all known duplicated-screen resource references
- AC-006: duplicated page revision rewrites all page-level screen references
- AC-007: attempts and delivery for the duplicate resolve through the duplicated screen resource ids
- AC-008: feature flag gates the adaptive path
- AC-009: any failure rolls back all adaptive duplication writes
- AC-010: non-adaptive duplication behavior remains unchanged

### 13.3 Delivery-Facing Confidence Checks

Although the feature is authoring-side, one end-to-end confidence test should confirm that a duplicated adaptive page still builds adaptive context and can resolve the duplicated screen sequence through the standard delivery and conversation builders. That specifically protects AC-007.

## 14. Backwards Compatibility

The design is additive and isolated.

- non-adaptive duplication keeps using the existing path
- adaptive duplication is gated behind a feature flag
- no schema changes are required
- no published content or delivery attempts are mutated

This keeps rollout risk low while preserving existing authoring behavior.

## 15. Risks & Mitigations

### 15.1 Risk: Incomplete Rewrite Surface Inventory

Adaptive content may contain additional resource-id-bearing structures beyond the known fields.

Mitigation:

- centralize remapping logic in one module
- reuse existing interop rewiring helpers where possible
- add targeted tests from known adaptive payload fixtures
- fail closed on malformed or ambiguous structures

### 15.2 Risk: Over-Literal "Single Query" Interpretation

A hand-written SQL mega-query could become fragile and opaque.

Mitigation:

- define success in terms of set-based, non-N-plus-1 persistence
- keep the workflow transactional
- use a small number of bulk queries with explicit row-count assertions

### 15.3 Risk: Sequence Identity Drift

Regenerating `sequenceId` values would break navigation and state assumptions.

Mitigation:

- preserve `sequenceId` and `sequenceName` verbatim during duplication
- rewrite only real resource-id-bearing fields

### 15.4 Risk: Hidden Cross-Screen Evaluation Breakage

If `activitiesRequiredForEvaluation` is not rewritten, server evaluation could look up the original screens.

Mitigation:

- treat that field as a first-class required rewrite surface
- include explicit tests for multi-screen rule evaluation dependencies

## 16. Open Questions & Follow-ups

- Should the final implementation extract shared JSON rewiring helpers from interop into a more neutral module, or should adaptive duplication call those helpers through a thin compatibility wrapper?
- Are there any adaptive activity payload variants in production that store duplicated-screen references under additional keys beyond `destinationScreenId`, `activity_id`, `idref`, and `resource_id`?
- Should the module attach the duplicated page into the container directly, or should that remain fully owned by the caller after the duplication transaction returns?
- If future requirements allow duplicating only a subset of adaptive screens, the current all-screens copy contract would need a broader mapping model. That is out of scope here.

## 17. References

- `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_duplication/prd.md`
- `docs/exec-plans/current/epics/adaptive_page_improvements/adaptive_duplication/requirements.yml`
- `lib/oli/authoring/editing/container_editor.ex`
- `lib/oli/conversation/adaptive_page_context_builder.ex`
- `lib/oli/delivery/activity_provider.ex`
- `lib/oli/delivery/attempts/activity_lifecycle/evaluate.ex`
- `lib/oli/interop/ingest/processor/common.ex`
- `lib/oli/interop/ingest/processor/internal_activity_refs.ex`
- `lib/oli/interop/ingest/processor/rewiring.ex`
- `lib/oli/interop/rewire_links.ex`
- `test/oli/conversation/adaptive_page_context_builder_test.exs`
- `test/oli/interop/rewire_links_test.exs`
- `assets/src/apps/authoring/store/groups/layouts/deck/actions/updateActivityRules.ts`
- `assets/src/apps/delivery/store/features/groups/actions/deck.ts`
