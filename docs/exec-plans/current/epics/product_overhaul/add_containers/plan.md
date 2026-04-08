# Add Containers — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/exec-plans/current/epics/product_overhaul/add_containers/prd.md`
- FDD: `docs/exec-plans/current/epics/product_overhaul/add_containers/fdd.md`

## Scope

Enable template authors to create new containers (units/modules/sections) on the Customize Content page with `container_scope = :blueprint` isolation, plus UI improvements (Add Materials filtering, unsaved changes modal, saving feedback, design system updates). Two PRs: PR1 = backend + functional UI, PR2 = frontend polish.

## Non-Functional Guardrails
- Container creation p95 <= 1000ms
- Zero scope leakage (blueprint containers never in project views)
- Atomic transactions — no partial container state
- WCAG 2.1 AA for new components

## Clarifications & Default Assumptions
- Container creation uses `Oli.Authoring.Course.create_and_attach_resource/2` with `container_scope: :blueprint` in revision attrs
- PublishedResource records created in ALL publications (not just working) per Darren's guidance
- Container type (unit/module/section) determined by hierarchy depth, not by an explicit type field
- Auto-generated default title (e.g., "Module 1", "Module 2") — always sequentially numbered, inline editing is out of scope
- Instructor remix container creation (`container_scope: :section`) is future work
- No feature flags — migration is backward-compatible
- `create_revision_from_previous` must copy `container_scope` to preserve scope across edits
- Export/import handles new field via default value (`:project` for imported content)

## Requirements Traceability
- Source of truth: `docs/exec-plans/current/epics/product_overhaul/add_containers/requirements.yml`

---

## PR1: Backend + Functional UI

### Phase 1: Data Model & Scope Filter Audit

**Goal:** Add `container_scope` to revisions and update project-level queries to filter by scope.

**Tasks:**
- [ ] Create migration adding `container_scope` column to `revisions` table (string, default "project", not null)
- [ ] Add `container_scope` field to `Oli.Resources.Revision` schema as `Ecto.Enum` with values `[:project, :blueprint, :section]`
- [ ] Update `Oli.Resources.create_revision_from_previous/2` (`lib/oli/resources.ex:314`) to copy `container_scope` from previous revision
- [ ] Add `container_scope = :project` filter to `AuthoringResolver.all_revisions_in_hierarchy/1` (`lib/oli/publishing/authoring_resolver.ex:191`)
- [ ] Add `container_scope = :project` filter to `AuthoringResolver.revisions_of_type/2` (`lib/oli/publishing/authoring_resolver.ex:174`)
- [ ] Add `container_scope = :project` filter to `AuthoringResolver.full_hierarchy/1` (via `all_revisions_in_hierarchy`)
- [ ] Add `container_scope = :project` filter to `AuthoringResolver.all_revisions/1` (`lib/oli/publishing/authoring_resolver.ex:159`)
- [ ] Add `container_scope = :project` filter to `Publishing.query_unpublished_revisions_by_type/2` (`lib/oli/publishing.ex:111`)
- [ ] Add private `all_publication_ids/1` in `ContainerCreation` (returns IDs only)
- [ ] Audit remaining queries from FDD Appendix A and apply filters as needed

**Testing Tasks:**
- [ ] Test: migration runs and rolls back cleanly
- [ ] Test: existing revisions have `container_scope: :project` after migration
- [ ] Test: `create_revision_from_previous` preserves `container_scope`
- [ ] Test: `AuthoringResolver.full_hierarchy/1` excludes `:blueprint` scoped containers
- [ ] Test: `AuthoringResolver.revisions_of_type/2` with container type excludes `:blueprint` scoped
- [ ] Test: `Publishing.query_unpublished_revisions_by_type/2` excludes `:blueprint` scoped
- [ ] Test: `materialize/3` creates PublishedResource records for ALL publications (tested indirectly)

**Definition of Done:**
- [ ] Migration passes
- [ ] All scope filter tests pass
- [ ] Project hierarchy excludes blueprint containers

**Gate:** All scope isolation tests green before proceeding to container creation.

**Dependencies:** None.

**Parallelizable Work:** None — Phase 2 depends on the data model.

---

### Phase 2: Draft Creation + Materialization Service

**Goal:** Implement `ContainerCreation` module with two functions: `build_draft/4` (in-memory) and `materialize/3` (DB at save time). No database writes during container creation — only at save.

**Tasks:**
- [ ] Create `Oli.Delivery.Remix.ContainerCreation` module
- [ ] Implement `build_draft/4` accepting `(hierarchy, project, title, opts \\ [])`:
  - Derive deterministic negative ID from hierarchy: `min(Enum.min(ids), 0) - 1`
  - Build in-memory `%Revision{}` struct with negative `id` and `resource_id`, `container_scope` from opts (default `:blueprint`)
  - Build `%HierarchyNode{}` with the draft revision
  - No database writes
- [ ] Implement `materialize/3` accepting `(hierarchy, project, author)`:
  - Walk hierarchy, find nodes with `resource_id < 0`
  - Inside a **single** `Repo.transaction` for all drafts:
    - For each: call `Course.create_and_attach_resource/2`, then batch insert via `Repo.insert_all` for ALL publications
    - Swap negative IDs for real ones via `Hierarchy.find_and_update_nodes` (batch, single traversal)
  - Return `{:ok, materialized_hierarchy}` or `{:error, reason}`
- [ ] Add `Oli.Delivery.Remix.create_container/4` function:
  - Calls `ContainerCreation.build_draft/4` (no DB writes)
  - Appends draft node to `active.children`
  - Finalizes hierarchy
  - Returns bare `%State{}` with `has_unsaved_changes: true`
- [ ] Update `Remix.save/2` to call `ContainerCreation.materialize/3` before `rebuild_section_curriculum`, using `with` for error propagation
- [ ] Determine default title generation based on hierarchy level and existing CustomLabels

**Testing Tasks:**
- [ ] Test: `build_draft/4` returns HierarchyNode with deterministic negative IDs
- [ ] Test: `build_draft/4` produces unique sequential IDs (-1, -2, -3)
- [ ] Test: `build_draft/4` has zero DB footprint
- [ ] Test: `build_draft/4` supports `container_scope` parameter
- [ ] Test: `materialize/3` replaces draft nodes with real DB records
- [ ] Test: `materialize/3` creates PublishedResource for ALL publications
- [ ] Test: `materialize/3` preserves order across multiple drafts
- [ ] Test: `materialize/3` leaves non-draft nodes unchanged
- [ ] Test: `Remix.create_container/4` updates hierarchy state and flags
- [ ] Test: `Remix.create_container/4` — new container is navigable and accepts materials
- [ ] Test: `Remix.save/2` materializes drafts and persists full structure

**Definition of Done:**
- [ ] Draft creation is purely in-memory (zero DB writes)
- [ ] Materialization creates correct records in single transaction
- [ ] Cancel leaves zero trace in database
- [ ] Save + reload cycle preserves container

**Gate:** All ContainerCreation + Remix State tests green before wiring to UI.

**Dependencies:** Phase 1 (data model + scope filters).

**Parallelizable Work:** Phase 3 UI scaffolding can start in parallel once `create_container/4` interface is defined.

---

### Phase 3: UI — Create Container Buttons

**Goal:** Add functional "Create Unit/Module/Section" buttons to the remix page, visible only for blueprint sections.

**Tasks:**
- [ ] Add `"create_container"` event handler to `OliWeb.Delivery.RemixSection`
- [ ] Determine button label based on current hierarchy depth (active node's numbering level + CustomLabels)
- [ ] Add create button (`id="create-container-button"`) to `remix_section.html.heex` near the "Add Materials" button
- [ ] Conditionally render button only when `@is_product` is true (blueprint sections only)
- [ ] Wire event handler to `Remix.create_container/4`
- [ ] Update socket assigns after creation (`hierarchy`, `active`, `has_unsaved_changes`, `remix_state`)

**Testing Tasks:**
- [ ] LiveView test: Create button appears for product_creator role (by element ID)
- [ ] LiveView test: Create button does NOT appear for instructor role
- [ ] LiveView test: Button label matches hierarchy level ("Create Unit" at root, "Create Module" inside unit)
- [ ] LiveView test: Clicking create adds container to hierarchy
- [ ] LiveView test: New container is navigable (drill into it)
- [ ] LiveView test: Can add materials to newly created container
- [ ] LiveView test: Creating container enables Save button (unsaved changes)
- [ ] LiveView test: Save after create persists (SectionResource count increases)
- [ ] LiveView test: Cancel after create does not persist
- [ ] LiveView test: Scope isolation — container does NOT appear in project authoring curriculum

**Definition of Done:**
- [ ] Create buttons functional on remix page for blueprint sections only
- [ ] Container creation → save flow works end-to-end in LiveView tests
- [ ] Cancel leaves zero trace in database
- [ ] Scope isolation verified through LiveView

**Gate:** PR1 ready for review.

**Dependencies:** Phase 2 (draft + materialize service).

---

## PR2: Frontend Polish

### Phase 4: Add Materials Duplicate Filtering

**Goal:** Hide resources already in the curriculum from the Add Materials modal and add description text.

**Tasks:**
- [ ] Modify HierarchyPicker to hide (not just disable) resources in `preselected` list
- [ ] Add description text "Resources can only be added to the curriculum once" to AddMaterialsModal header/body
- [ ] Verify preselected list includes resources from ALL containers in hierarchy (uses `flatten_hierarchy`)

**Testing Tasks:**
- [ ] Test: Resources already in curriculum are not shown in modal
- [ ] Test: Description text is rendered
- [ ] Test: Adding a resource, then reopening modal, that resource is now hidden

**Definition of Done:**
- [ ] Duplicate resources hidden from selection
- [ ] Description text visible

**Gate:** Tests green.

**Dependencies:** PR1 merged.

---

### Phase 5: Unsaved Changes Modal + Saving Feedback

**Goal:** Replace browser `beforeunload` with a structured modal; add saving indicator and confirmation banner.

**Tasks:**
- [ ] Create UnsavedChangesModal component with "Save changes" and "Leave without saving" buttons
- [ ] Intercept navigation events when `has_unsaved_changes: true` — show modal instead of navigating
- [ ] "Save changes" → trigger save, then navigate on completion
- [ ] "Leave without saving" → navigate directly, discard in-memory state
- [ ] Add `saving` assign — set to `true` during save, render loading indicator with "Saving" text
- [ ] Add confirmation banner component — shown after successful save (use flash or temporary assign)
- [ ] Keep BeforeUnloadListener as fallback for hard browser navigation (tab close, URL bar)

**Testing Tasks:**
- [ ] LiveView test: Modal appears on navigation with unsaved changes
- [ ] LiveView test: No modal when no unsaved changes
- [ ] LiveView test: "Save changes" persists and navigates
- [ ] LiveView test: "Leave without saving" navigates without persisting
- [ ] LiveView test: Saving indicator shown during save
- [ ] LiveView test: Confirmation banner shown after save

**Definition of Done:**
- [ ] Unsaved changes modal functional
- [ ] Saving indicator and confirmation banner working

**Gate:** Tests green.

**Dependencies:** PR1 merged. Can run in parallel with Phase 4.

---

### Phase 6: Design System Updates

**Goal:** Update Customize Content page styling to match Figma designs.

**Tasks:**
- [ ] Fetch Figma design context for all 4 design nodes (via MCP tools)
- [ ] Update remix page layout/styling to match Customize Content design (node 275-13521)
- [ ] Style Add Materials modal to match design (node 275-13620)
- [ ] Style Unsaved Changes modal to match design (node 275-13723)
- [ ] Style saving confirmation to match design (node 339-5939)
- [ ] Integrate new authoring sidebar navigation if applicable

**Testing Tasks:**
- [ ] Visual comparison against Figma designs
- [ ] Verify responsive behavior
- [ ] Verify accessibility (keyboard navigation, ARIA attributes, focus management)

**Definition of Done:**
- [ ] Styling matches Figma designs
- [ ] Accessibility verified

**Gate:** PR2 ready for review.

**Dependencies:** Phases 4 and 5 complete.

---

## Parallelisation Notes

```
PR1:
  Phase 1 (Data Model) ──→ Phase 2 (Draft + Materialize) ──→ Phase 3 (UI Buttons)

PR2 (after PR1 merged):
  Phase 4 (Add Materials Filtering) ─┐
                                      ├──→ Phase 6 (Design System)
  Phase 5 (Unsaved Changes Modal) ───┘
```

- Phases 4 and 5 can run in parallel within PR2.
- Phase 6 depends on Phases 4 and 5 (needs components to exist before styling).

## Phase Gate Summary

| Gate | From → To | Criteria |
|------|-----------|----------|
| A | Phase 1 → Phase 2 | Scope isolation tests green (6 tests) |
| B | Phase 2 → Phase 3 | Draft + materialize + remix state tests green (11 tests) |
| C | Phase 3 → PR1 Review | End-to-end LiveView tests green (9 tests) |
| D | PR1 Merge → Phases 4+5 | PR1 merged to master |
| E | Phases 4+5 → Phase 6 | Modal and filtering tests green |
| F | Phase 6 → PR2 Review | Styling matches Figma, accessibility verified |

## Decision Log

### 2026-03-30 — Two-PR structure
- Change: Split into PR1 (backend + functional UI) and PR2 (frontend polish).
- Reason: Isolates high-risk backend changes (data model, scope audit) from lower-risk UI improvements. Enables earlier review of critical path.
- Impact: 6 phases across 2 PRs instead of monolithic delivery.
