# Add Containers — PRD

## 1. Overview
Feature Name: Add Containers

Summary: Enable template authors and admins to create new course structure containers (units, modules, sections) directly within the Template Customize Content (remix) page, while enforcing strict scope isolation so that template-created containers never leak into project-level authoring views or unrelated template/section contexts. The feature also enhances the Add Materials modal with duplicate filtering, introduces an unsaved-changes confirmation modal, and updates the page to use the new design system and sidebar navigation.

Links: `docs/exec-plans/current/epics/product_overhaul/overview.md`, `docs/exec-plans/current/epics/product_overhaul/plan.md`, `docs/exec-plans/current/epics/product_overhaul/add_containers/informal.md`, ticket `MER-4057`

## 2. Background & Problem Statement
- Current behavior / limitations:
  - The Template Customize Content page (remix) allows adding existing materials from published projects but provides no way to create new structural containers (units, modules, sections). Authors must create containers in the authoring project and then add them via remix, which conflates project-level and template-level structure.
  - The Add Materials modal does not filter out resources already present in the curriculum, allowing potential duplicate additions.
  - The current unsaved-changes behavior uses a browser `beforeunload` listener but lacks a structured confirmation modal with save/discard options.
  - The page styling predates the new design system.
- Affected users/roles:
  - Authors managing course section templates.
  - Institution admins with template management permissions.
- Why now:
  - Epic `MER-4032` requires template workflow modernization. Lane 5 (Template Structure Extensibility) depends on Lane 4 (Remix/Publishing Correctness Stabilization) and enables future template-scoped structure evolution. The `add_containers` feature is the sole ticket in Lane 5.

## 3. Goals & Non-Goals
- Goals:
  - Add "Create Unit," "Create Module," and "Create Section" buttons at the appropriate hierarchy levels on the Template Customize Content page.
  - Create new containers as project resources with a `container_scope = :blueprint` revision attribute, ensuring they appear only in the template remix context.
  - Create published_resource records across all existing publications (up to and including the unpublished/working publication) so publishing and diffing infrastructure works correctly.
  - Filter duplicate pages from the Add Materials modal so resources already in the curriculum are not selectable.
  - Replace the browser-level unsaved-changes listener with a structured modal offering "Save changes" and "Leave without saving" options.
  - Show a loading indicator with "Saving" text during save, and a confirmation banner on completion.
  - Update page styling to use the new design system components per Figma designs.
  - Integrate the new authoring sidebar navigation where appropriate.
- Non-Goals:
  - Allowing instructors to create containers during course section remix (future extension once template isolation is verified).
  - Renaming or editing container titles within the remix page (follows existing revision model but is out of scope for this ticket).
  - Changing the core publishing or remix save pipeline beyond what is needed for container creation.
  - Building a custom container creation UI separate from the existing remix page.

## 4. Users & Use Cases
- Primary Users / Roles:
  - Author with template edit/manage permissions (product_creator role in remix).
  - Institution admin with template management permissions.
- Use Cases:
  - An author navigates to Template Customize Content and clicks "Create Module" to add a new module inside the current container. The module appears in the hierarchy with a default title and the author can immediately add materials to it.
  - An author creates a new unit at the top level of the curriculum, then navigates into it and creates modules within it.
  - An author clicks "Add Materials," and the modal shows only resources not already present in the curriculum, with a description stating "Resources can only be added to the curriculum once."
  - An author makes changes (adds containers, adds materials, reorders) and attempts to navigate away. An "Unsaved Changes" modal appears with options to save or leave without saving.
  - An author saves changes and sees a "Saving" loading indicator followed by a confirmation banner.
  - An author opens Template Customize Content with no unsaved changes and navigates away without any modal appearing.
  - A project-level author views the authoring curriculum and does NOT see template-created containers (container_scope = :blueprint) — only project-scope containers appear.

## 5. UX / UI Requirements
- Key Screens/States:
  - Customize Content page displays "Create Unit," "Create Module," or "Create Section" button(s) appropriate to the current hierarchy level for authorized users.
  - Newly created container appears immediately in the hierarchy with a default title and is expandable.
  - Add Materials modal displays description: "Resources can only be added to the curriculum once." and filters out resources already in the curriculum.
  - Unsaved Changes modal appears on navigation attempt with pending changes, offering "Save changes" and "Leave without saving."
  - Saving state shows a loading indicator with "Saving" text.
  - Save completion shows a confirmation banner.
- Navigation & Entry Points:
  - Entry point is the existing Template Customize Content page (product remix route).
  - Create container actions are inline on the page, not in a separate modal.
- Accessibility:
  - Create container buttons are keyboard accessible with descriptive accessible names.
  - Unsaved Changes modal traps focus and is dismissible via keyboard.
  - Saving state and confirmation banner are announced to assistive technologies via live regions.
- Internationalization:
  - All new labels/messages are localizable via existing i18n/gettext pipeline; no hard-coded user-visible strings.
- Figma Designs:
  - Customize Content: `https://www.figma.com/design/GQm0yUEwFNbzznfpvV1eSM/V30-Products--Templates--Design?node-id=275-13521`
  - Add Materials Modal: `https://www.figma.com/design/GQm0yUEwFNbzznfpvV1eSM/V30-Products--Templates--Design?node-id=275-13620`
  - Unsaved Changes Modal: `https://www.figma.com/design/GQm0yUEwFNbzznfpvV1eSM/V30-Products--Templates--Design?node-id=275-13723`
  - Saving Confirmation: `https://www.figma.com/design/GQm0yUEwFNbzznfpvV1eSM/V30-Products--Templates--Design?node-id=339-5939`

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Performance & Scale: Container creation (resource + revision + published_resources + section_resource update) p95 <= 1000ms; Add Materials modal filtering should not add perceptible latency beyond current behavior.
- Reliability: Container creation is atomic — if any step fails (resource, revision, published_resources, section_resource), the entire operation rolls back with no partial state. Save operation (rebuild_section_curriculum) maintains existing reliability guarantees.
- Security & Privacy: Server-side authorization required for every container creation action; `container_scope` filtering enforced in all project-level resource queries to prevent cross-scope leakage; tenant and section scoping maintained.
- Compliance: WCAG 2.1 AA for new buttons, modals, saving state, and confirmation banner.

## 9. Data Model & APIs
- Ecto Schemas & Migrations:
  - Add `container_scope` field to `revisions` table: `Ecto.Enum` with values `[:project, :blueprint, :section]`, default `:project`.
  - No changes to `section_resources` schema.
  - No changes to `published_resources` schema.
- Context Boundaries:
  - `Oli.Delivery.Remix` owns the in-memory hierarchy state transitions, extended with container creation.
  - `Oli.Publishing` handles published_resource upsert across publications.
  - `Oli.Authoring.Course` handles resource + revision creation (reused from authoring).
  - `Oli.Delivery.Sections` handles `rebuild_section_curriculum` persistence.
  - Remix LiveView (`OliWeb.Delivery.RemixSection`) handles UI events and modal management.
- APIs / Contracts:
  - New function in `Oli.Delivery.Remix`: `create_container/3` taking `(state, container_type, title)` — creates resource + revision (with `container_scope`), published_resources across all publications, and adds to hierarchy. Returns `{:ok, State.t()}` or `{:error, reason}`.
  - Add Materials modal: filter function that excludes `resource_id` values already present in the flattened hierarchy.
  - Unsaved Changes modal: handled entirely in LiveView with existing `has_unsaved_changes` state.
- Permissions Matrix:

| Role | Allowed Actions | Notes |
|---|---|---|
| Author with template manage rights (product_creator) | Create containers, add materials, save/cancel, all remix operations | Scoped to template permissions |
| Institution Admin | Create containers, add materials, save/cancel, all remix operations | Must be authorized for template section institution |
| Instructor | Not allowed to create containers | Instructor remix does not include container creation in v1 |
| Student | Not allowed | No access to remix page |

## 10. Integrations & Platform Considerations
- LTI 1.3: No launch protocol changes; container creation is an authoring-time operation.
- GenAI: Not applicable.
- External services: No new external service integration.
- Caching/Perf: Section cache cleared on save via existing `rebuild_section_curriculum` flow; no new caches introduced.
- Multi-tenancy: Container creation inherits project/institution scoping from the template section context; `container_scope` filtering prevents cross-tenant container visibility.

## 11. Feature Flagging, Rollout & Migration
- No feature flags for v1. Container creation is available to all authorized template remix users once deployed.
- Migration adds `container_scope` column with default `:project`, which is backward-compatible — all existing revisions implicitly have project scope.

## 12. Success Metrics
- KPIs:
  - 0 instances of template-created containers appearing in project-level authoring views (scope isolation verified).
  - 0 duplicate resources selectable in Add Materials modal after filtering.
  - >= 95% container creation success rate for authorized users.

## 13. Risks & Mitigations
- Scope leakage: Template-created containers (container_scope = :blueprint) could appear in project-level authoring views if queries are not updated -> Audit all project-level container/resource queries and add `container_scope = :project` filter; add regression tests verifying isolation.
- Published resource coverage: New containers need published_resource records in ALL publications, not just the working one -> Enumerate all publications for the project and upsert published_resources in a single transaction; add tests verifying coverage across multiple publications.
- Hierarchy state complexity: Adding container creation to the in-memory remix state increases state transition surface -> Follow existing Remix module patterns (pure state transitions + explicit finalization); add unit tests for each new transition.
- Design system migration scope creep: Restyling the entire page could balloon scope -> Focus styling changes on new components (create buttons, unsaved changes modal, confirmation banner) and areas immediately surrounding them; defer full page restyling if it exceeds ticket scope.

## 14. Open Questions & Assumptions
- Assumptions:
  - Container creation uses the same `Oli.Authoring.Course.create_and_attach_resource/2` pattern as authoring-side container creation, with the addition of `container_scope` on the revision.
  - Published_resource records must exist in ALL publications (published + unpublished) for a project so that publishing diffing works correctly (per Darren's technical guidance).
  - The existing `rebuild_section_curriculum` save flow handles new containers without modification once they exist as resources with published_resource mappings.
  - Custom labels / numbering conventions determine which create button labels appear at each hierarchy level.
- Open Questions:
  - Should newly created containers have an editable title inline, or use a generated default title (e.g., "New Module 1")?
  - Should the new authoring sidebar navigation integration be part of this ticket or a separate effort?
  - What is the exact mapping of hierarchy level to allowed container types (e.g., can a module contain a sub-module, or only sections)?

## 15. Timeline & Milestones (Draft)
- Milestone 1: Migration + `container_scope` field + scope-filter query audit.
- Milestone 2: Backend container creation service (resource + revision + published_resources + hierarchy integration).
- Milestone 3: UI — create container buttons + Add Materials duplicate filtering.
- Milestone 4: UX polish — unsaved changes modal, saving indicator, confirmation banner, design system updates.

## 16. QA Plan
- Automated:
  - Container creation tests: resource, revision (with container_scope), published_resources across all publications, section_resource hierarchy update.
  - Scope isolation tests: project-level queries exclude blueprint-scoped containers; template-level queries include both project and blueprint scoped containers.
  - Add Materials duplicate filtering tests: resources already in curriculum are excluded from modal selections.
  - Unsaved changes modal tests: appears on navigation with pending changes, does not appear without changes, save/discard paths work correctly.
  - Authorization tests: only product_creator and admin roles can create containers.
- Manual:
  - Verify create unit/module/section buttons appear at correct hierarchy levels.
  - Verify newly created container appears in hierarchy and can have materials added.
  - Verify Add Materials modal shows "Resources can only be added to the curriculum once" and filters duplicates.
  - Verify unsaved changes modal appears on page leave with changes, with working save/discard.
  - Verify saving indicator and confirmation banner.
  - Verify template-created containers do NOT appear in project authoring curriculum.
  - Verify styling matches Figma designs.
- Performance Verification:
  - Measure container creation latency in staging; confirm p95 target compliance.

## 17. Definition of Done
- [ ] All FRs mapped to ACs in requirements.yml
- [ ] Validation checks pass
- [ ] Open questions triaged
- [ ] Scope isolation verified (template containers never appear in project authoring views)
- [ ] Published resource coverage verified across all publications
- [ ] Design system updates match Figma designs for new components

## Decision Log
- 2026-03-30: Renamed proposed `scope` field to `container_scope` to avoid collision with existing `Revision.scope` field (`:embedded | :banked` for activity scoping at `lib/oli/resources/revision.ex:69`). Evidence: grep for `field :scope` in revision.ex. Impact: All spec documents and implementation must use `container_scope` consistently.
