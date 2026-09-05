# Remix Product Sources - Product Requirements Document

## 1. Overview
This work item improves the delivery course remix experience so instructors can add materials from both project publications and product templates they are authorized to use through communities. The remix source model should represent projects and products explicitly, preserving the current publication-based safety model while allowing product templates to act as curated content sources.

The primary user value is reducing manual support work and enabling instructors to remix approved product content without requiring administrators to expose the full underlying source project to the instructor's community.

## 2. Background & Problem Statement
Jira ticket `TRIAGE-135` reports that the delivery course remix tool only sees projects, not templates. Many instructors receive access through communities that include products/templates but not the projects those products are based on. In that setup, instructors can build courses from approved products but cannot use Manage > Configure Content > Add Materials to add content from another approved product unless the source project is also added to the community.

The current remix flow is publication-centric: available sources are publications, source rows display project titles, and selections are represented as publication/resource pairs. Products are delivery `Section` records with their own curated hierarchy, title, removals, hidden resources, and possible remixed material from multiple projects. Treating a product as only its base project publication would expose the wrong source boundary and could show materials that were intentionally omitted from the cleaned-up product.

## 3. Goals & Non-Goals
### Goals
- Allow instructors to discover and remix from products/templates that their user or institution can access through communities.
- Preserve current project-publication remix behavior for users who can access projects directly.
- Keep authorization scoped to the source the actor can access: product access should not imply broad project access.
- Use a first-class remix source model that can represent project publications and product sections.
- Load product source hierarchies from the product's delivery hierarchy so the picker reflects curated product content.
- Keep existing publication pinning, resource conflict protection, and section save behavior intact unless a source abstraction requires a targeted change.

### Non-Goals
- Redesigning the full catalog, course creation, or product management experience is out of scope.
- Changing community administration workflows for associating projects and products is out of scope.
- Automatically cloning or creating new products for instructors is out of scope.
- Changing authoring publication semantics, major update behavior, or learner delivery behavior is out of scope except where required to support product-source remix.
- Granting instructors authoring access to source projects is out of scope.

## 4. Users & Use Cases
- Instructors: add materials from another approved product into a delivery course without asking support to manually remix content.
- Product and course administrators: grant communities access to products without also exposing the source projects.
- Support staff: reduce one-off manual content remix requests for instructors who already have product access.
- Authors and product creators: maintain cleaned-up product templates as the safe remix source instead of exposing raw project content.

## 5. UX / UI Requirements
- The Add Materials source picker must list accessible project sources and product/template sources in a way that clearly identifies the source title.
- Each source picker row must visually label the source type as Project or Product/Template.
- Product sources must display the product/template title, not only the base project title.
- Selecting a product source must show the product's curated curriculum and page list, excluding content already present in the target section.
- Product-source page search and browsing must include only visible product section resources.
- The Add Materials modal must preserve existing selection, pagination, search, sorting, and error behavior where applicable.
- Error messages for unavailable sources or shared-resource conflicts must remain understandable to instructors and must not expose internal project or publication implementation details.
- The interaction remains a Phoenix LiveView flow; no new React application is required.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Security: product community access must authorize only the product source and its curated hierarchy, not unrestricted source project browsing.
- Reliability: existing section remix saves, pinned publication updates, and major update behavior must remain stable for existing project-source use cases.
- Performance: source listing and product hierarchy loading should avoid avoidable N+1 queries and should remain bounded by existing table pagination/search behavior.
- Accessibility: the Add Materials modal must preserve keyboard and screen-reader usable controls for source selection, search, table pagination, and add/cancel actions.
- Maintainability: source discovery and source hierarchy resolution should live in domain/service boundaries, with LiveView handling rendering and event orchestration.
- Privacy: telemetry and logs must not include raw learner content, unpublished content bodies, or sensitive LMS/user identifiers beyond existing operational conventions.

## 9. Data, Interfaces & Dependencies
- Relevant domain areas include `lib/oli/delivery/remix.ex`, `lib/oli/delivery/hierarchy.ex`, `lib/oli/delivery/sections.ex`, `lib/oli/publishing.ex`, and `lib/oli/groups.ex`.
- Relevant LiveView areas include `lib/oli_web/live/delivery/remix_section.ex`, `lib/oli_web/live/delivery/remix/add_materials_modal.ex`, and `lib/oli_web/live/delivery/publications_table_model.ex`.
- Community product visibility is represented by `communities_visibilities.section_id`; community project visibility is represented by `communities_visibilities.project_id`.
- Product templates are `Section` records with `type: :blueprint` and delivery hierarchies resolvable through the delivery resolver.
- Existing publication/resource selection and save behavior may remain the persistence boundary, but the UI and authorization layers need an explicit source abstraction for project and product sources.
- The Jira source of record is `TRIAGE-135`.

## 10. Repository & Platform Considerations
- Torus is a Phoenix application with LiveView for this interaction; domain rules belong under `lib/oli/` and UI orchestration belongs under `lib/oli_web/`.
- The publication model is central: delivery sections should resolve materials against pinned publications rather than mutable authoring state.
- Tests should prioritize ExUnit domain coverage and LiveView tests for source selection behavior. Scenario coverage is required for the end-to-end community product access and product-source remix workflow; if current scenario directives cannot express that workflow, the scenario DSL should be extended as part of this work.
- Code review should include security and performance by default, plus Elixir and UI review because this work affects Ecto authorization queries, LiveView state, and instructor-facing UI.
- Documentation paths in planning artifacts should remain repository-relative.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item

## 12. Telemetry & Success Metrics
- Emit or extend aggregate telemetry for Add Materials source selection and add outcomes if an existing remix telemetry boundary is available.
- Track successful product-source add operations, unavailable-source failures, and shared-resource conflict failures as aggregate operational signals.
- Success is indicated by instructors with product-only community access being able to add materials from approved products without support intervention.
- Regression success is indicated by existing project-source remix tests continuing to pass and no increase in remix save or source-selection errors in AppSignal/log monitoring after release.

## 13. Risks & Mitigations
- Risk: product access could accidentally expose raw project content. Mitigation: load product-source hierarchy from the product section, not from the base project publication alone.
- Risk: product hierarchies may include resources from multiple projects. Mitigation: source nodes must carry enough project/publication information to resolve each selected resource through the product's pinned publications.
- Risk: existing conflict checks may treat product and project sources inconsistently. Mitigation: keep conflict validation based on resolved project/publication/resource data and add targeted tests for mixed source cases.
- Risk: query complexity could grow when listing both products and projects. Mitigation: use existing product-aware visibility queries as a starting point and verify query shape in review.
- Risk: UI labels could confuse instructors if projects and products share similar names. Mitigation: use source titles that reflect the actual accessible source and include a visible source type label for Project or Product/Template rows.

## 14. Open Questions & Assumptions
### Open Questions
- No unresolved product-scope questions remain from initial intake.

### Assumptions
- Product/template access through a community is sufficient authorization to remix from that product's curated content.
- Product-source remix should use the product's current delivery hierarchy, including product-level customizations and removals.
- Product-source page search and browsing should include only visible product section resources.
- Instructors may select materials from a product and its base project in the same add operation when they independently have access to both, if allowing that keeps the implementation simpler and existing conflict checks still pass.
- Source picker rows should identify whether each source is a Project or Product/Template.
- Existing pinned publication records remain the correct persistence mechanism for resolving remixed resources after save.
- A feature flag is not required because the work corrects an authorization/source-model gap in an existing critical workflow.
- `TRIAGE-135` remains the issue-tracking source for this intake until a linked internal engineering ticket is created.

## 15. QA Plan
- Automated validation:
  - Add ExUnit coverage for community product visibility feeding remix source discovery.
  - Add domain tests for resolving product-source selected nodes to the correct publication/resource pairs.
  - Add LiveView tests for Add Materials source listing, product source selection, selection persistence, and add behavior.
  - Add or extend `Oli.Scenarios` coverage for the end-to-end community product access and product-source remix workflow.
  - Run targeted tests for `test/oli/delivery/remix/*`, relevant publishing/groups tests, and affected LiveView tests.
  - Run `mix format` and targeted `mix test` commands before review.
- Manual validation:
  - Reproduce `TRIAGE-135`: create a community with two products and no projects, add an instructor, build a course, and verify Add Materials can use the other product.
  - Verify a product-only instructor cannot browse unrelated source projects.
  - Verify existing project-source remix still behaves as before for users with direct project access.
  - Inspect source picker labels and error messages for clarity.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
- [ ] Product-only community access can be used as a remix source without project community access
- [ ] Existing project-source remix behavior remains covered and unchanged
- [ ] End-to-end scenario coverage exists for community product access and product-source remix, including any needed scenario DSL extensions
- [ ] Security, performance, Elixir, UI, and requirements review scopes are satisfied
