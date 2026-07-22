# Remix Product Sources - Functional Design Document

## 1. Executive Summary
Delivery remix currently models Add Materials sources as project publications. This design adds an explicit remix source boundary that can represent both project publications and product templates while preserving the existing publication/resource add and save path. Product sources are authorized through community product visibility, rendered with their own Product/Template labels, loaded from the product section hierarchy, and resolved back to publication/resource pairs only when materials are added.

The key implementation choice is deliberately narrow: introduce source discovery and source selection contracts before `Remix.add_materials/2`, not a rewrite of hierarchy persistence. This satisfies `FR-001` through `FR-008` and keeps existing project-source behavior covered by `AC-004`.

## 2. Requirements & Assumptions
- Functional requirements:
  - Support explicit Project and Product/Template remix sources (`FR-001`, `AC-001`, `AC-008`).
  - Authorize product sources through community product associations without exposing the base project as a project source (`FR-002`, `AC-002`).
  - Render product source content from visible product section resources only (`FR-003`, `AC-003`).
  - Preserve existing project publication source behavior (`FR-004`, `AC-004`).
  - Resolve selected product source nodes to the correct pinned publications before adding materials (`FR-005`, `AC-005`).
  - Keep unavailable-source and shared-resource protections across source types (`FR-006`, `AC-006`).
  - Add aggregate observability for source selection and add outcomes (`FR-007`, `AC-007`).
  - Provide end-to-end scenario coverage, extending the scenario DSL if needed (`FR-008`, `AC-009`).
- Non-functional requirements:
  - Do not grant project authoring or broad project browsing permission from product access.
  - Avoid N+1 source and page queries in normal source listing and selection.
  - Preserve LiveView accessibility expectations for source selection, search, paging, and error states.
  - Do not log raw content payloads or sensitive user/LMS identifiers in new telemetry.
- Assumptions:
  - Products are `Section` records with `type: :blueprint`.
  - Product source hierarchy should come from `Oli.Publishing.DeliveryResolver.full_hierarchy(product.slug)`.
  - The existing `sections_projects_publications` rows remain the source of truth for resolving section resources after save.
  - Instructors may select from a product and its base project in the same add operation when independently authorized, subject to existing conflict validation.
  - Admin authors editing real course sections (`type: :enrollable`) use a scoped admin Remix initializer that includes active product/template sources through admin authority.
  - Section-scoped hidden instructor users used for admin delivery access on real course sections are treated, within Remix source discovery only, as members of all active communities for project and product/template source visibility. This does not mutate community membership or change generic source discovery outside Remix.
  - When both an admin author and a section-scoped hidden instructor are present for a real course section, Remix mounts through the hidden instructor path so course customization follows instructor-source semantics.
  - No feature flag is required; rollout follows the normal deployment path.

## 3. Repository Context Summary
- What we know:
  - `Oli.Delivery.Remix.State` currently stores `available_publications`, and `Oli.Delivery.Remix.init/2` populates it from `Publishing.retrieve_visible_publications/2` for users and `Publishing.available_publications/2` for authors.
  - `OliWeb.Delivery.RemixSection` owns Add Materials modal state, source listing, source selection, page search/sort/paging, and calls `Remix.add_materials/2`.
  - `OliWeb.Common.Hierarchy.Publications.TableModel` renders current source rows as publications and displays `publication.project.title`.
  - `Oli.Delivery.Hierarchy.add_materials_to_hierarchy/4` already accepts `{publication_id, resource_id}` selections and should stay unchanged unless product-source selection proves it cannot supply those tuples.
  - `Oli.Groups.list_community_associated_publications_and_products/2` and `Oli.Publishing.retrieve_visible_sources/2` already expose a product-aware visibility path used elsewhere in the product.
  - `section_resources.hidden` marks hidden product resources, and `DeliveryResolver.full_hierarchy/1` builds section/product hierarchies from section resources.
  - Scenario infrastructure already supports products, sections, customization, and project-source remix, but current docs do not show community product visibility or product-source remix authorization directives.
- Unknowns to confirm:
  - Whether existing scenario directives can express community membership, product association, and source visibility assertions without extension. The implementation plan should explicitly check this before coding scenario assertions.
  - Whether an existing telemetry namespace exists for delivery remix. If not, add a small `[:oli, :delivery, :remix, ...]` event family.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
Add a new domain module under `lib/oli/delivery/remix/source.ex` and companion query/resolution functions in `Oli.Delivery.Remix` or a nested `Oli.Delivery.Remix.Sources` module.

`Oli.Delivery.Remix.Source` is a plain struct used by the domain and LiveView:

```elixir
%Oli.Delivery.Remix.Source{
  key: "project:123" | "product:456",
  type: :project | :product,
  title: String.t(),
  publication_id: integer() | nil,
  project_id: integer() | nil,
  product_id: integer() | nil,
  product_slug: String.t() | nil,
  pinned_publications: %{integer() => Publication.t()}
}
```

Project sources set `publication_id`, `project_id`, and `pinned_publications` with a single project publication. Product sources set `product_id`, `product_slug`, and `pinned_publications` from `Sections.get_pinned_project_publications(product.id)`. Product source rows use `title` from the product section.

`Remix.init/2` populates both `available_sources` and `available_publications`:
- `available_sources` drives UI listing and selection.
- `available_publications` remains a flattened publication list used by existing validation and add paths.

The LiveView source table should be renamed conceptually from publications to sources. A file rename is optional, but the rendered table should work from `%Remix.Source{}` rows and include a visible type label for `AC-008`.

### 4.2 State & Data Flow
Initial state:
1. `Remix.init(section, user_or_author)` preloads the target section institution.
2. Source discovery returns a list of authorized `%Source{}` values.
3. `available_publications` is derived from source pinned publications and project source publications, then passed through target-section pin precedence.
4. `Remix.State` stores `available_sources`, `available_publications`, `pinned_project_publications`, and current hierarchy.

Source picker flow:
1. Add Materials opens with `modal_assigns.sources`.
2. Search/paging filters `source.title` and optionally `source.type`.
3. Selecting a source uses `source.key`, not a bare publication id.
4. Project source selection loads the existing publication hierarchy.
5. Product source selection loads `DeliveryResolver.full_hierarchy(source.product_slug)` and filters hidden nodes for page search/browse.

Selection flow:
1. Selection remains `{publication_id, resource_id}` once a user selects a concrete page or container.
2. For project source nodes, `publication_id` is the selected source publication id.
3. For product source nodes, `publication_id` is resolved from the selected hierarchy node's `project_id` via `source.pinned_publications`.
4. If no pinned publication exists for a selected product node project, the add operation fails with `:unavailable_publication`.

Add flow:
1. `AddMaterialsModal.add` passes the resolved publication/resource tuples into `Remix.add_materials/2`.
2. Existing validation checks publication availability and project-resource conflicts.
3. Existing hierarchy add and save paths persist section resources and `sections_projects_publications`.

### 4.3 Lifecycle & Ownership
- `Oli.Delivery.Remix` owns source discovery, source resolution, and add validation.
- `Oli.Publishing` and `Oli.Groups` retain visibility query responsibilities; add new helper functions there only when the source discovery query cannot be expressed cleanly in Remix.
- `OliWeb.Delivery.RemixSection` owns modal assign updates and calls domain helpers for source hierarchy/page data.
- `OliWeb.Common.Hierarchy.HierarchyPicker` remains a reusable rendering component; its props should be adjusted only as needed to accept sources instead of publications.
- `Oli.Scenarios` owns workflow coverage. If current directives cannot set up community product visibility and assert available remix sources, extend the DSL in a narrow way.

### 4.4 Alternatives Considered
1. Add product base project publications to `available_publications`.
   - Rejected because it exposes raw project content and fails product-curation requirements in `AC-003`.
2. Rewrite remix add/save to persist product source identity directly.
   - Rejected for this work item because delivery resolution already depends on project publication pins, and source identity is only needed before selection is resolved.
3. Introduce `Remix.Source` before selection and keep existing publication/resource add.
   - Selected because it satisfies source authorization and UI requirements while limiting changes to discovery, selection, and product page browsing.

## 5. Interfaces
- `Oli.Delivery.Remix.Source`
  - New struct for Add Materials source rows and source resolution.
  - Required fields: `key`, `type`, `title`, `pinned_publications`.
  - Project-only fields: `publication_id`, `project_id`.
  - Product-only fields: `product_id`, `product_slug`.
- `Oli.Delivery.Remix.init/2`
  - Extend `State` with `available_sources`.
  - Preserve `available_publications` for compatibility.
- `Oli.Delivery.Remix.source_hierarchy(source_key, state)`
  - Returns `{:ok, source, hierarchy}` or `{:error, :unavailable_source}`.
  - Uses publication hierarchy for project sources and delivery hierarchy for product sources.
- `Oli.Delivery.Remix.source_pages(source_key, state, params)`
  - Returns `{total_count, [%HierarchyNode{}]}` for All pages mode.
  - Project implementation delegates to `Publishing.get_published_pages_by_publication/2`.
  - Product implementation queries visible product `section_resources` for pages, applies `exclude_resource_ids`, search, sort, limit, and offset.
- `Oli.Delivery.Remix.selection_tuple(source, node_or_resource_id)`
  - Returns `{:ok, {publication_id, resource_id}}` or `{:error, :unavailable_publication}`.
- LiveView events:
  - Replace or wrap `"HierarchyPicker.select_publication"` with a source-oriented event such as `"HierarchyPicker.select_source"`.
  - Keep backwards-compatible event naming only if renaming would create unnecessary churn.
- Scenario DSL:
  - If needed, add directives/assertions for community creation, product/community association, instructor membership, and available remix source assertions.

## 6. Data Model & Storage
- No database migration is required.
- Existing storage remains:
  - `communities_visibilities.project_id` for project access.
  - `communities_visibilities.section_id` for product access.
  - `sections_projects_publications` for target and product pinned publications.
  - `section_resources` for product/section hierarchy and hidden flags.
- `Remix.State` adds an in-memory `available_sources` field.
- Product-source page search uses `section_resources` as the product source listing data, not `published_resources` alone.

## 7. Consistency & Transactions
- Source discovery is read-only and does not require a transaction.
- Add Materials remains an in-memory hierarchy mutation until save.
- `Remix.save/2` remains the persistence transaction boundary and should continue to rebuild section resources and pin publications atomically through existing section rebuild logic.
- Product-source selections must resolve publication ids before mutation so existing conflict validation and pinning remain consistent.
- If a source product changes between modal open and add, the add should fail closed when selected resource/project publications cannot be resolved.

## 8. Caching Strategy
- No new cache is required.
- Source lists are stored in LiveView assigns for the session, matching current source table behavior.
- Product hierarchy and page results can be loaded on selection/search events. Avoid persistent caching until profiling shows a need.

## 9. Performance & Scalability Posture
- Source discovery should use set-based queries and preload required projects/products/publications to avoid per-row lookups.
- Product page browsing should query `section_resources` directly with filters, sorting, limit, and offset rather than building a full flattened hierarchy for All pages mode.
- Product curriculum mode may use `DeliveryResolver.full_hierarchy/1` because it is loaded only for the selected source.
- Filtering source rows in memory is acceptable for parity with current behavior, but implementation should keep the option to move filtering into SQL if source counts become large.
- Performance review should inspect query plans for source discovery and product page search.

## 10. Failure Modes & Resilience
- Unauthorized product source appears: prevent by deriving sources only from authorized visibility queries and add regression tests for product-only access not exposing base project sources.
- Admin author cannot see product/template sources while customizing a real course section: initialize admin/enrollable Remix through the admin source policy rather than the generic author initializer, and keep the policy out of product-template editing.
- Source disappears after modal open: return `:unavailable_source` or `:unavailable_publication`, clear selection, and show the existing unavailable materials error style.
- Product source contains a resource whose project publication is not pinned: fail the selection/add path with `:unavailable_publication`.
- Shared-resource conflict across product and project selections: let existing `validate_no_shared_project_resources/2` reject based on resolved publication ids.
- Hidden product resources appear in search: product page query must filter `section_resources.hidden == false`; LiveView tests should cover this.
- Telemetry emit failure: telemetry calls must be non-blocking and must not affect add behavior.

## 11. Observability
- Emit aggregate telemetry when a source is selected:
  - Event: `[:oli, :delivery, :remix, :source_selected]`
  - Measurements: `%{count: 1}`
  - Metadata: `%{source_type: :project | :product}`
- Emit aggregate telemetry when Add Materials completes or fails:
  - Event: `[:oli, :delivery, :remix, :add_materials]`
  - Measurements: `%{selection_count: non_neg_integer()}`
  - Metadata: `%{source_types: [:project | :product], outcome: :ok | :shared_project_resources | :selected_projects_share_resources | :unavailable_publication | :unavailable_source}`
- Do not include resource titles, content bodies, user email, LMS context ids, or raw params in telemetry metadata.
- Keep existing LiveView flash/error behavior for user-visible failures.

## 12. Security & Privacy
- Product access authorizes only the product source and visible product section resources; it does not authorize the base project as a project source (`AC-002`).
- Product source hierarchy must be loaded from the product section to preserve product removals and hidden state (`AC-003`).
- Source discovery must include institution-associated and directly associated communities consistently with existing visibility behavior.
- Do not expose unpublished project resources; resolved publication ids must be published/pinned publications.
- All LiveView events that receive a source key must look up that source in `state.available_sources`; never trust a client-submitted id directly.
- Logs and telemetry must avoid raw content and sensitive identifiers.

## 13. Testing Strategy
- Domain tests:
  - `Remix.init/2` returns Product/Template sources for product-only community access and does not include the base project as a Project source (`AC-001`, `AC-002`, `AC-008`).
  - Product source selection resolves visible hierarchy nodes through product pinned publications (`AC-003`, `AC-005`).
  - Mixed product and base project selections are accepted or rejected only by existing conflict rules (`AC-006`).
  - Existing `test/oli/delivery/remix/*` project-source behavior continues to pass (`AC-004`).
- LiveView tests:
  - Add Materials source picker displays source titles and Project/Product Template labels (`AC-008`).
  - Selecting a product source renders the curated product hierarchy and excludes hidden resources from All pages search (`AC-003`).
  - Unavailable source/publication errors use existing Add Materials error presentation (`AC-006`).
- Scenario tests:
  - Add or extend `Oli.Scenarios` coverage for the `TRIAGE-135` workflow: two products in a community, no projects in that community, instructor membership, target section from one product, remix from the other product, final structure assertion (`AC-001`, `AC-002`, `AC-009`).
  - If current DSL cannot express community visibility/source availability, add narrow directives/assertions rather than relying only on factories.
- Observability tests:
  - Assert telemetry events are emitted with source type/outcome metadata and without raw content payloads (`AC-007`).
- Required commands:
  - `mix test test/oli/delivery/remix`
  - Targeted groups/publishing tests affected by source discovery.
  - Targeted LiveView test module for delivery remix.
  - Targeted scenario test module and scenario validation.
  - `mix format`.

## 14. Backwards Compatibility
- Existing project-source flows remain available and continue to resolve to the same publication/resource tuples.
- Existing section save behavior and `sections_projects_publications` persistence remain unchanged.
- Existing product/community association records remain valid; no migration or backfill is needed.
- Any LiveView event rename should be contained within the Add Materials component; external routes and user navigation remain unchanged.

## 15. Risks & Mitigations
- Product source exposes raw project content: load product sources from `DeliveryResolver.full_hierarchy(product.slug)` and visible `section_resources`, not the base project hierarchy.
- Source abstraction duplicates `retrieve_visible_sources/2` behavior: reuse existing Groups/Publishing visibility queries where possible and add tests around product-only visibility.
- Product source contains remixed material from multiple projects: resolve each selected node through the product source's `pinned_publications` map.
- Large source lists or page searches become slow: keep pagination, add set-based product page query, and review query shape for N+1s.
- Scenario DSL expansion grows too broad: add only the minimum community/product visibility and source assertion support needed for `AC-009`.

## 16. Open Questions & Follow-ups
- Confirm whether current scenario DSL can model community product visibility and available source assertions; if not, add a narrow extension before writing the end-to-end scenario.
- Confirm exact visual treatment for source type labels with design/product if a Figma artifact becomes available. The FDD requires a visible Project or Product/Template label but does not prescribe final styling.
- Consider renaming `OliWeb.Common.Hierarchy.Publications.TableModel` after implementation if source terminology remains stable. This is optional and should not block the feature.

## 17. References
- PRD: `docs/exec-plans/current/remix-product-sources/prd.md`
- Requirements: `docs/exec-plans/current/remix-product-sources/requirements.yml`
- Jira: `TRIAGE-135`
- Architecture: `ARCHITECTURE.md`
- Backend guidance: `docs/BACKEND.md`
- Frontend guidance: `docs/FRONTEND.md`
- Testing guidance: `docs/TESTING.md`
- Design guidance: `docs/DESIGN.md`
- Operations guidance: `docs/OPERATIONS.md`
- Publication model: `docs/design-docs/publication-model.md`
- High-level design: `docs/design-docs/high-level.md`
- Scenario product docs: `test/support/scenarios/docs/products.md`
- Scenario section/remix docs: `test/support/scenarios/docs/sections.md`
- Current remix domain: `lib/oli/delivery/remix.ex`
- Current remix LiveView: `lib/oli_web/live/delivery/remix_section.ex`
- Community visibility: `lib/oli/groups.ex`
- Publishing source visibility: `lib/oli/publishing.ex`
