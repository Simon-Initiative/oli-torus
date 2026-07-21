# Remix Product Sources - Delivery Plan

Scope and reference artifacts:
- PRD: `docs/exec-plans/current/remix-product-sources/prd.md`
- FDD: `docs/exec-plans/current/remix-product-sources/fdd.md`
- Requirements: `docs/exec-plans/current/remix-product-sources/requirements.yml`

## Scope
Deliver product/template remix sources for the delivery Add Materials flow while preserving existing project-publication remix behavior. The implementation must keep the existing section save and publication/resource persistence boundary, authorize product sources through community product visibility, render product content from the product section hierarchy, and add targeted observability and automated coverage for `FR-001` through `FR-008`.

Out of scope:
- database migrations or persistence of product source identity
- authoring publication semantic changes
- product/community administration workflow changes
- a new React application or redesign of the delivery remix page
- feature-flag rollout unless implementation discovers an operational risk not present in the PRD/FDD

## Clarifications & Default Assumptions
- Product/template sources are delivery `Section` records with `type: :blueprint`; product access is enough to remix from that product's curated content but does not imply access to its base project (`FR-002`, `AC-002`).
- Product-source hierarchy comes from the product section and visible `section_resources`, not from the raw base project publication (`FR-003`, `AC-003`).
- Selected materials continue to become `{publication_id, resource_id}` tuples before `Remix.add_materials/2`, preserving current conflict validation and save behavior (`FR-004`, `FR-005`, `AC-004`, `AC-005`).
- `Oli.Delivery.Remix.State` should use `available_sources` as the long-term source-of-truth for authorized remix sources. Do not keep `available_publications` as a denormalized compatibility field; replace existing publication lookups with helpers derived from `available_sources`.
- Product and base project selections may coexist only when the actor is independently authorized for both; existing shared-resource conflict checks remain the arbiter (`FR-006`, `AC-006`).
- Telemetry should use aggregate metadata only and must not include raw content, resource titles, user emails, LMS context identifiers, or LiveView params (`FR-007`, `AC-007`).
- Scenario DSL capability is unknown. The implementation must check current `Oli.Scenarios` directives before deciding whether to use `build_scenario` only or extend the DSL with `extend_scenario` (`FR-008`, `AC-009`).
- Admin authors customizing real course sections should get a scoped admin Remix source set that includes product/template sources.
- Section-scoped hidden instructor users used for admin delivery access on real course sections should be treated, within Remix source discovery only, as members of all active communities for project and product/template source visibility.
- When both an admin author and a section-scoped hidden instructor are present for a real course section, Remix should prefer the hidden instructor match over the admin-author match.

## Estimate
Estimated engineering effort: 9-15 developer days.

Estimated calendar duration: 2-3 weeks for one engineer, assuming normal review turnaround and no major scenario DSL expansion. With a second engineer taking LiveView tests or scenario work after Phase 1, the likely calendar duration is 1.5-2.5 weeks.

Estimate by phase:
- Phase 1: Source Model, Discovery, and Publication Lookup Cleanup: 2-3.5 days
- Phase 2: Product Source Hierarchy and Page Resolution: 2-3.5 days
- Phase 3: LiveView Add Materials Picker: 1.5-2.5 days
- Phase 4: Add Flow, Telemetry, and Review Hardening: 1.5-2.5 days
- Phase 5: Scenario Coverage and DSL Extension Check: 1-2.5 days
- Phase 6: Final Verification and Release Readiness: 0.5-1 day

Estimate drivers:
- Existing product-aware visibility helpers and the current publication/resource add boundary should keep the implementation contained.
- Removing `available_publications` avoids long-term denormalized state, but adds cleanup work in `Remix.add_materials/2`, conflict validation, pinned-publication updates, LiveView modal setup, and scenario/test helpers.
- Product-source page search and hidden-resource filtering may require careful Ecto query work to avoid N+1 regressions.
- LiveView event and assign changes are moderate risk because existing modal behavior, selection state, pagination, and error handling must remain stable.
- Scenario coverage is the largest uncertainty. If existing directives can express community product visibility and source assertions, Phase 5 should stay near the low end. If DSL extension is required, expect the high end.
- Manual validation requires realistic community, product, and section setup for `TRIAGE-135`, which may expose fixture/setup gaps not visible in unit tests.

## Phase 1: Source Model, Discovery, and Publication Lookup Cleanup
- Goal: Introduce the domain source abstraction and populate authorized project and product sources without changing add/save behavior (`FR-001`, `FR-002`, `FR-004`, `AC-001`, `AC-002`, `AC-004`, `AC-008`).
- Tasks:
  - [ ] Add `Oli.Delivery.Remix.Source` with project and product fields described in the FDD.
  - [ ] Replace `Oli.Delivery.Remix.State.available_publications` with `available_sources` as the only stored list of authorized remix sources.
  - [ ] Build source discovery for user/institution and author/institution paths using existing `Oli.Publishing` and `Oli.Groups` visibility helpers where possible.
  - [ ] Add `Remix.publication_by_id/1`, `Remix.available_publications/1`, or equivalent private/public helpers that derive publication lookup indexes from `available_sources`.
  - [ ] Apply existing target-section pin precedence while constructing source pinned-publication data, not by maintaining a second denormalized state field.
  - [ ] Update `Remix.add_materials/2`, conflict validation, canonical ordering, and pinned-publication updates to use source-derived publication lookup helpers.
  - [ ] Update LiveView modal setup and table seeding to read source rows from `state.available_sources`.
  - [ ] Update tests and scenario helper setup that directly assert or mutate `state.available_publications`.
  - [ ] Ensure product-only community visibility yields Product/Template sources and does not yield the base project as a Project source.
  - [ ] Keep existing administrator/all-publication initialization behavior stable for current project-source workflows.
- Testing Tasks:
  - [ ] Add ExUnit domain tests for product-only community visibility, mixed project/product visibility, and unchanged project-only source discovery.
  - [ ] Add a regression assertion that source rows carry Project or Product/Template type data for UI rendering.
  - [ ] Add regression coverage proving source-derived publication lookup rejects unavailable publication ids and still maps publication ids to project ids for conflict validation.
  - Command(s): `mix test test/oli/delivery/remix`
- Definition of Done:
  - `Remix.init/2` returns source data for project and product cases without storing `available_publications` in `Remix.State`.
  - All existing publication-id validation, canonical ordering, and pinned-publication update behavior is backed by source-derived lookup helpers.
  - Product access is scoped to the product source and does not grant base project source access.
  - Existing project publication source tests pass or have been updated only for the new explicit source shape.
- Gate:
  - Source discovery and source-derived publication lookup tests cover `AC-001`, `AC-002`, `AC-004`, and `AC-008`.
- Dependencies:
  - PRD, FDD, and requirements are present.
- Parallelizable Work:
  - Domain source struct and source-discovery tests can be developed in parallel with UI label styling exploration, but LiveView wiring waits for this phase's source contract and lookup helper shape.

## Phase 2: Product Source Hierarchy and Page Resolution
- Goal: Load product-source browsing data from curated product section content and resolve selected product nodes to pinned publications (`FR-003`, `FR-005`, `FR-006`, `AC-003`, `AC-005`, `AC-006`).
- Tasks:
  - [ ] Add `Remix.source_hierarchy/2` or equivalent helper that looks up the submitted source key from `state.available_sources`.
  - [ ] Implement project-source hierarchy loading through the existing publication hierarchy path.
  - [ ] Implement product-source hierarchy loading through `Oli.Publishing.DeliveryResolver.full_hierarchy(product.slug)` or the established delivery resolver boundary.
  - [ ] Add product-source all-pages query support from product `section_resources`, filtering hidden resources and target-section resource ids, with search, sort, limit, and offset.
  - [ ] Add `Remix.selection_tuple/2` or equivalent resolution so product source nodes map through the product source's pinned publication map.
  - [ ] Ensure product-source selection resolution feeds the same source-derived publication lookup path used by project-source selections.
  - [ ] Fail closed with `:unavailable_source` or `:unavailable_publication` when the source key or pinned publication cannot be resolved.
  - [ ] Inspect query shape for product page listing to avoid per-row publication, section, or revision lookups.
- Testing Tasks:
  - [ ] Add domain tests for product hierarchy loading, hidden-resource exclusion, target-section exclusion, and page search.
  - [ ] Add domain tests for product selections from single-project and multi-project product sources.
  - [ ] Add conflict tests proving mixed source selections still use existing shared-resource protections.
  - Command(s): `mix test test/oli/delivery/remix`
- Definition of Done:
  - Product-source browsing reflects curated product content and visible resources only.
  - Product selections resolve to the correct publication/resource tuples before mutation.
  - Unavailable and conflicting selections do not mutate the target hierarchy.
- Gate:
  - Domain tests cover `AC-003`, `AC-005`, and `AC-006`, including the product-only and mixed-source paths.
- Dependencies:
  - Phase 1 source contract and state fields.
- Parallelizable Work:
  - Product all-pages query tests can be written alongside hierarchy resolver tests after the source factory/setup path is available.

## Phase 3: LiveView Add Materials Picker
- Goal: Update the Add Materials LiveView flow to render, search, page, select, and add explicit sources with accessible Project and Product/Template labels (`FR-001`, `FR-003`, `FR-004`, `FR-006`, `AC-003`, `AC-004`, `AC-006`, `AC-008`).
- Tasks:
  - [ ] Update `OliWeb.Delivery.RemixSection` modal assigns to pass sources instead of treating every row as a publication.
  - [ ] Update or rename `OliWeb.Common.Hierarchy.Publications.TableModel` so source rows render source title and visible type labels.
  - [ ] Replace or wrap the publication-selection LiveView event with a source-key event and validate all submitted source keys against `state.available_sources`.
  - [ ] Wire curriculum browsing and all-pages search to the domain helpers from Phase 2.
  - [ ] Preserve existing modal selection, pagination, search, sorting, cancel, add, and error behavior.
  - [ ] Keep the interaction in Phoenix LiveView and preserve keyboard/screen-reader usable controls.
- Testing Tasks:
  - [ ] Add LiveView tests for source picker rows showing Project and Product/Template labels.
  - [ ] Add LiveView tests for selecting a product source and seeing curated product content without hidden resources in all-pages search.
  - [ ] Add LiveView tests for unavailable source/publication errors and shared-resource errors using the existing error presentation.
  - Command(s): targeted `mix test` for the delivery remix LiveView test module.
- Definition of Done:
  - Instructors can select project and product sources from the modal, and the displayed source title/type matches the actual authorized source.
  - Existing project-source UX remains functionally unchanged.
  - Product-source errors are understandable and do not expose internal publication implementation details.
- Gate:
  - LiveView tests cover `AC-003`, `AC-006`, and `AC-008`; project-source regression coverage for `AC-004` remains green.
- Dependencies:
  - Phases 1 and 2 domain helpers.
- Parallelizable Work:
  - Table model rendering tests and LiveView event tests can proceed in parallel once modal assign shape is agreed.

## Phase 4: Add Flow, Telemetry, and Review Hardening
- Goal: Complete add-materials integration, aggregate observability, and non-functional hardening for authorization, performance, and privacy (`FR-005`, `FR-006`, `FR-007`, `AC-005`, `AC-006`, `AC-007`).
- Tasks:
  - [ ] Ensure `AddMaterialsModal.add` passes resolved publication/resource selections into `Remix.add_materials/2`.
  - [ ] Preserve `Oli.Delivery.Hierarchy.add_materials_to_hierarchy/4`, `Remix.save/2`, and `sections_projects_publications` persistence unless implementation proves a targeted add/save change is required.
  - [ ] Confirm no call sites still depend on `state.available_publications`; remove stale aliases, struct fields, tests, and assigns.
  - [ ] Emit aggregate telemetry for source selection with source type metadata only.
  - [ ] Emit aggregate telemetry for add success and failure outcomes with selection counts and source type summaries only.
  - [ ] Add no-op-safe telemetry calls so observability cannot block add behavior.
  - [ ] Review source discovery and product page queries for authorization scoping, N+1 behavior, and bounded paging.
  - [ ] Ensure intentional logs in tests are captured with `@tag capture_log: true` or `capture_log(...)` if introduced.
- Testing Tasks:
  - [ ] Add tests for telemetry event names, measurements, and allowed metadata.
  - [ ] Add tests for successful product-source add recording the expected publication for delivery resolution.
  - [ ] Add tests that failed add attempts do not mutate the target hierarchy.
  - Command(s): `mix test test/oli/delivery/remix`; targeted telemetry and LiveView test modules.
- Definition of Done:
  - Product-source add operations append expected hierarchy nodes and preserve delivery resolution.
  - Failure outcomes are observable and safe.
  - Privacy-sensitive content and identifiers are absent from new telemetry and logs.
- Gate:
  - Tests cover `AC-005`, `AC-006`, and `AC-007`; security and performance concerns are ready for review.
- Dependencies:
  - Phases 1 through 3.
- Parallelizable Work:
  - Telemetry tests can be written in parallel with add-flow integration once outcome names are finalized.

## Phase 5: Scenario Coverage and DSL Extension Check
- Goal: Add end-to-end workflow coverage for `TRIAGE-135`, extending `Oli.Scenarios` only if the existing DSL cannot express community product-source remix (`FR-008`, `AC-001`, `AC-002`, `AC-009`).
- Tasks:
  - [ ] Inspect existing scenario directives and docs for community creation, product association, instructor membership, source visibility, and delivery remix assertions.
  - [ ] If current directives are sufficient, use `build_scenario` to author the community product-source remix scenario.
  - [ ] If current directives are insufficient, use `extend_scenario` to add the narrowest directives/assertions needed, then use `build_scenario` for the scenario.
  - [ ] Create a scenario with two products in a community, no project community visibility, instructor membership, a target section from one product, remix from the other product, and final structure assertions.
  - [ ] Keep the scenario focused on workflow integration rather than duplicating all LiveView rendering cases.
- Testing Tasks:
  - [ ] Validate the scenario file with `Oli.Scenarios.validate_file/1`.
  - [ ] Run the targeted ExUnit scenario runner.
  - [ ] Run any new scenario DSL infrastructure tests if directives were extended.
  - Command(s): targeted `mix test` for scenario runner and scenario DSL modules.
- Definition of Done:
  - End-to-end scenario coverage proves product-only community access can drive product-source remix without base project access.
  - Any DSL extension is narrowly scoped, documented in scenario docs, and covered by infrastructure tests.
- Gate:
  - Scenario coverage satisfies `AC-001`, `AC-002`, and `AC-009`.
- Dependencies:
  - Product-source domain and add flow are implemented enough for the scenario to execute.
- Parallelizable Work:
  - DSL capability audit can happen before Phase 4 completes; final scenario execution depends on the add flow.

## Phase 6: Final Verification and Release Readiness
- Goal: Run the complete targeted verification set, update review artifacts, and prepare the implementation for security, performance, Elixir, UI, and requirements review.
- Tasks:
  - [ ] Run `mix format`.
  - [ ] Run targeted domain, LiveView, telemetry, and scenario tests.
  - [ ] Run broader nearby regression tests for groups/publishing visibility if source discovery touched those modules.
  - [ ] Manually validate the `TRIAGE-135` flow: product-only community access, source picker labels, product-source remix, no unrelated base project source, and unchanged project-source remix.
  - [ ] Manually validate the admin-author course-section flow: an admin author can open Remix on an enrollable section and see/select product/template sources.
  - [ ] Manually validate the hidden-instructor course-section flow: the hidden instructor session created for admin delivery access can open Remix on an enrollable section and see/select active-community project and product/template sources.
  - [ ] Confirm no feature flag was introduced or document why a scoped flag became necessary.
  - [ ] Prepare review notes for `.review/security.md`, `.review/performance.md`, `.review/elixir.md`, `.review/ui.md`, and `.review/requirements.md`.
  - [ ] Confirm AppSignal/log monitoring expectations for aggregate source-selection and add-outcome signals.
- Testing Tasks:
  - [ ] Run `mix test test/oli/delivery/remix`.
  - [ ] Run targeted groups/publishing tests affected by visibility changes.
  - [ ] Run targeted delivery remix LiveView tests.
  - [ ] Run targeted scenario tests and scenario validation.
  - [ ] Run `mix format`.
  - Command(s): `mix test test/oli/delivery/remix`; targeted `mix test` for affected groups/publishing, LiveView, telemetry, and scenario modules; `mix format`.
- Definition of Done:
  - All acceptance criteria `AC-001` through `AC-009` have automated or inspection proof.
  - Existing project-source behavior remains covered and passing.
  - Security, performance, Elixir, UI, and requirements review scopes are satisfied.
  - Documentation and planning artifacts use repository-relative paths.
- Gate:
  - Final targeted verification is green, manual validation is recorded, and no unresolved review-blocking risks remain.
- Dependencies:
  - Phases 1 through 5.
- Parallelizable Work:
  - Manual validation notes and review-scope preparation can run while final automated tests execute.

## Parallelization Notes
- Phase 1 and Phase 2 should stay mostly serial because later hierarchy and selection behavior depends on the `Source` contract.
- LiveView rendering tests can be drafted after Phase 1 while Phase 2 product query details are still being finished.
- Telemetry tests can be written as soon as event names and outcome atoms are finalized.
- Scenario DSL capability audit can begin before implementation is complete, but the final scenario should run against the integrated add flow.
- Security and performance review preparation should happen throughout implementation, especially around source-key validation, product-only authorization, hidden-resource filtering, and product page query shape.

## Phase Gate Summary
- Gate 1: Source discovery returns explicit Project and Product/Template sources, removes `state.available_publications`, provides source-derived publication lookup helpers, and covers `AC-001`, `AC-002`, `AC-004`, and `AC-008`.
- Gate 2: Product hierarchy/page resolution uses curated visible product section content, maps selections through pinned publications, and covers `AC-003`, `AC-005`, and `AC-006`.
- Gate 3: LiveView Add Materials source picker renders type labels, validates source keys, preserves existing modal behavior, and covers `AC-003`, `AC-004`, `AC-006`, and `AC-008`.
- Gate 4: Add flow and telemetry are integrated with privacy-safe aggregate metadata and cover `AC-005`, `AC-006`, and `AC-007`.
- Gate 5: Scenario coverage verifies the `TRIAGE-135` product-only community workflow and covers `AC-001`, `AC-002`, and `AC-009`.
- Gate 6: Final targeted tests, formatting, manual validation, and security/performance/Elixir/UI/requirements review readiness are complete for `AC-001` through `AC-009`.
