# Add Containers — Functional Design Document

## 1. Executive Summary

This feature extends the Template Customize Content (remix) page to support creating new course structure containers (units, modules, sections) directly within a blueprint section. The design introduces a `container_scope` enum on revisions to isolate template-created containers from project-level authoring views. Container creation follows the existing authoring pattern (Resource + Revision + PublishedResource) but extends it to cover all publications for the project — not just the working one — so that publishing and diffing infrastructure works correctly. The remix LiveView gains new event handlers for container creation, the Add Materials modal gains duplicate filtering, and the save flow gains a structured unsaved-changes modal and confirmation feedback.

The design splits into two PRs: PR1 (backend + minimal frontend) covers the data model, container creation service, scope-filter audit, and functional create buttons. PR2 (frontend polish) covers the unsaved-changes modal, saving indicator, confirmation banner, Add Materials duplicate filtering UX, and design system updates.

## 2. Requirements & Assumptions

### Functional Requirements
- FR-001: Create container buttons at appropriate hierarchy levels
- FR-002: Container creation with `container_scope = :blueprint` + published_resources across all publications
- FR-003: Scope isolation — blueprint containers invisible to project-level views
- FR-004: Add materials within newly created containers
- FR-005: Add Materials modal duplicate filtering + description text
- FR-006: Unsaved changes modal with save/discard options
- FR-007: Saving indicator + confirmation banner
- FR-008: Design system styling updates

### Non-Functional Requirements
- Container creation p95 <= 1000ms
- Atomic transactions — no partial container state on failure
- WCAG 2.1 AA for new UI components

### Explicit Assumptions
- `Oli.Authoring.Course.create_and_attach_resource/2` can be reused for template container creation with the addition of `container_scope` on the revision attrs
- `ChangeTracker.track_revision/2` handles the working publication; we manually upsert to published publications
- The existing `rebuild_section_curriculum` save flow handles new containers without modification once they exist as resources with published_resource mappings
- `HierarchyNode` does not need schema changes — new containers get nodes like any other container

### Requirements Traceability
- Source of truth: `docs/exec-plans/current/epics/product_overhaul/add_containers/requirements.yml`

## 3. Torus Context Summary

### What We Know
- **Container creation (authoring)**: `ContainerEditor.add_new/4` at `lib/oli/authoring/editing/container_editor.ex:109` wraps Resource + Revision creation, ChangeTracker upsert, and parent container append in a single `Repo.transaction`.
- **ChangeTracker**: `lib/oli/publishing/tracker.ex:14` — `track_revision/2` upserts PublishedResource only to the **working** (unpublished) publication. For template containers, we need to cover ALL publications.
- **No `get_all_publications_for_project` function exists** — must be written. Nearest: `project_working_publication/1` (line 516) and `get_latest_published_publication_by_slug/1` (line 549).
- **Remix state**: `Oli.Delivery.Remix` (`lib/oli/delivery/remix.ex`) manages in-memory `State` struct with hierarchy, available_publications, pinned_project_publications. Pure state transitions, persistence via `Sections.rebuild_section_curriculum/3`.
- **HierarchyNode**: `lib/oli/delivery/hierarchy/hierarchy_node.ex` — ephemeral struct with `uuid`, `resource_id`, `revision`, `children`, `section_resource`, `numbering`. Container vs page determined by `revision.resource_type_id`.
- **Add Materials preselection**: Already implemented via `preselected` list in HierarchyPicker (`lib/oli_web/live/delivery/remix_section.ex:427-433`). Currently disables items; ticket requires hiding them entirely.
- **BeforeUnloadListener**: `assets/src/hooks/before_unload.ts` — browser-level `beforeunload` listener. Ticket requires replacing with a structured LiveView modal.
- **Revision.scope collision**: Existing `scope` field at `lib/oli/resources/revision.ex:69` (`:embedded | :banked` for activity scoping). New field must be named `container_scope`.

### Unknowns to Confirm
- Whether `create_and_attach_resource/2` creates a ProjectResource record that might cause the container to appear in project views even with `container_scope` filtering (it does — audit needed).
- Exact hierarchy level → container type mapping for button labels.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

**New module: `Oli.Delivery.Remix.ContainerCreation`** — Service module for creating containers in the template remix context. Has two responsibilities: building in-memory draft nodes and materializing them to the database at save time.

**`build_draft/4`** — Creates an in-memory HierarchyNode with a deterministic negative ID. No database writes.

The negative ID is derived from the current hierarchy: `min(smallest_existing_resource_id, 0) - 1`. This produces sequential IDs (-1, -2, -3, ...) that are predictable and easy to debug. Safe even if drafts are removed and recreated — validated across 6 scenarios (see section 4.5).

```elixir
def build_draft(hierarchy, project, title, container_scope \\ :blueprint) do
  # Deterministic negative ID: smallest existing ID (clamped to 0) minus 1
  all_ids = hierarchy |> Hierarchy.flatten_hierarchy() |> Enum.map(& &1.resource_id)
  next_id = min(Enum.min(all_ids, fn -> 0 end), 0) - 1

  draft_revision = %Revision{
    id: next_id,
    resource_id: next_id,
    resource_type_id: ResourceType.id_for_container(),
    container_scope: container_scope,
    title: title,
    children: [],
    content: %{"model" => [], "version" => "0.1.0"}
  }

  %HierarchyNode{
    uuid: Oli.Utils.uuid(),
    resource_id: next_id,
    revision: draft_revision,
    project_id: project.id,
    children: [],
    section_resource: nil,
    finalized: false
  }
end
```

**`materialize/3`** — Called at save time. Walks the hierarchy, finds nodes with `resource_id < 0`, creates real Resource + Revision + PublishedResources, and swaps the IDs.

```elixir
def materialize(hierarchy, project, author) do
  draft_nodes = find_draft_nodes(hierarchy)

  Enum.reduce(draft_nodes, hierarchy, fn draft, acc ->
    {:ok, %{resource: resource, revision: revision}} =
      persist_draft(project, draft.revision, author)

    updated_node = %HierarchyNode{draft |
      resource_id: resource.id,
      revision: revision
    }

    Hierarchy.find_and_update_node(acc, updated_node)
  end)
end

defp find_draft_nodes(hierarchy) do
  Hierarchy.flatten_hierarchy(hierarchy)
  |> Enum.filter(& &1.resource_id < 0)
end
```

**Why draft detection works:** `resource_id < 0` is the marker. Real database IDs are always positive (Postgres auto-increment). IDs are deterministic and sequential (-1, -2, -3, ...) derived from `Enum.min` of existing IDs, making debugging straightforward. ID reuse after draft removal is safe — validated across numbering maps, purge_duplicate_resources, save flow, and LiveView state (6 scenarios, all pass).

**Why drafts are inert between create and save:** Every remix operation (finalize, select_active, add_materials, reorder, move, remove, render) uses `uuid` for node identification — not `resource_id`. The negative IDs sit on the struct but no code reads them until save. Validated across 18 code paths (see section 4.5).

**Extended: `Oli.Delivery.Remix`** — New `create_container/3` function.

Responsibilities:
- Call `ContainerCreation.build_draft/4` with hierarchy to create in-memory node (no DB writes)
- Append node to `active.children`
- Finalize hierarchy (renumber)
- Return updated `State`

**Extended: `OliWeb.Delivery.RemixSection`** — New event handlers.

Responsibilities:
- `"create_container"` event → delegate to `Remix.create_container/3`
- Update socket assigns (`hierarchy`, `active`, `has_unsaved_changes`)
- Render create buttons conditionally based on hierarchy level

**Extended: `Oli.Publishing`** — New `get_all_publications_for_project/1` function.

**Modified: `Oli.Publishing.AuthoringResolver`** — Add `container_scope = :project` filter to project-level queries.

### 4.2 State & Message Flow

**Container Creation Flow (in-memory only — no DB writes):**

1. User clicks "Create Module" button on remix page
2. LiveView receives `"create_container"` event with `%{"type" => "module"}`
3. LiveView calls `Remix.create_container(state, container_type, default_title)`
4. `Remix.create_container` calls `ContainerCreation.build_draft/3` — creates an in-memory HierarchyNode with a negative temporary `resource_id` and an in-memory `%Revision{}` struct. **No database writes.**
5. Appends draft node to `active.children`, finalizes hierarchy
6. LiveView updates socket: `hierarchy`, `active`, `has_unsaved_changes: true`
7. UI re-renders with new container in the list

**Between create and save:** All remix operations (reorder, move, remove, add_materials, select_active, finalize, render) use `uuid` for node identification — not `resource_id`. The negative temporary IDs sit inert on the struct. No code reads them.

**Save Flow (materialize drafts, then persist):**
8. User clicks "Save" → LiveView reads `current_author` from socket assigns (set by `on_mount` hook) and calls `Remix.save(state, author)`. The author is the person clicking Save, not the project owner — correct for revision authorship attribution.
9. `Remix.save/2` calls `ContainerCreation.materialize/3` — walks hierarchy, finds nodes with `resource_id < 0`. If drafts exist but author is nil, returns `{:error, :author_required_for_materialization}`. For each draft:
   a. Creates Resource + Revision (with `container_scope`) + ProjectResource via `Repo.transaction`
   b. Creates PublishedResource records across ALL publications
   c. Swaps negative IDs for real ones in the hierarchy via `Hierarchy.find_and_update_node` (uuid-based, safe)
10. `Remix.save` calls `Sections.rebuild_section_curriculum/3` with the fully materialized hierarchy
11. `rebuild_section_curriculum` collapses hierarchy to SectionResource records, upserts all, clears cache

**Cancel Flow (zero cleanup):**
- User clicks "Cancel" or closes browser → in-memory hierarchy discarded
- **Nothing was written to the database** — zero orphaned records

**Unsaved Changes Flow (PR2):**
1. User attempts navigation with `has_unsaved_changes: true`
2. LiveView intercepts navigation (via `handle_event` on sidebar links or `handle_info` for LiveView navigation)
3. Shows "Unsaved Changes" modal with two buttons
4. "Save changes" → calls `Remix.save(state, author)` then navigates
5. "Leave without saving" → navigates directly

### 4.3 Supervision & Lifecycle

No new OTP processes. Container creation is a purely in-memory operation within the LiveView process — no database writes until save. The remix state lifecycle is unchanged: initialized on mount, mutated via event handlers, persisted on save, discarded on cancel/navigation. Draft nodes (negative `resource_id`) are materialized to real database records inside `Remix.save/2` before `rebuild_section_curriculum` runs.

### 4.4 Alternatives Considered

**Alternative 1: Create containers only in the SectionResource tree (no project-level Resource/Revision).**
Rejected because: Publishing and diffing infrastructure depends on resources existing in the publication. Without PublishedResource mappings, the container would not survive re-publishing or section updates. Darren explicitly specified creating project-level resources.

**Alternative 2: Reuse `ChangeTracker.track_revision/2` and only create PublishedResource in the working publication.**
Rejected because: Darren's guidance explicitly requires PublishedResource records in ALL publications up to and including the unpublished one. Without this, publication-time diffing would not recognize the container.

**Alternative 3: Add `container_scope` to the existing `scope` field (extend the enum).**
Rejected because: The existing `scope` field has semantic meaning for activity scoping (`:embedded | :banked`). Overloading it would conflate two unrelated concepts and risk breaking activity provider logic.

### 4.5 Container Persistence Strategy — Decision: Draft Entities (Approach B)

Two approaches were evaluated for when to persist container resources (Resource + Revision + PublishedResources) to the database. **Approach B was chosen** based on architectural consistency and the principle that uncommitted user actions should leave no trace in the database.

#### Approach A: Immediate Persistence (persist at create time)

When the user clicks "Create Module," `ContainerCreation.create/4` runs a `Repo.transaction` that immediately creates Resource + Revision + PublishedResources in the database. The HierarchyNode references these real database records. On save, `rebuild_section_curriculum` creates SectionResources that reference the already-existing resources.

```
User clicks "Create Module"
  → Repo.transaction: Resource + Revision + PublishedResources created in DB
  → HierarchyNode built with real resource_id
  → Appended to in-memory hierarchy

User clicks "Save"
  → rebuild_section_curriculum creates SectionResources (references existing resources)

User clicks "Cancel"
  → In-memory hierarchy discarded
  → Resource + Revision + PublishedResources remain in DB (orphaned)
  → Orphans are invisible (no SectionResource points to them, container_scope: :blueprint filtered from project views)
```

| Pros | Cons |
|------|------|
| Simple — single code path for create | Orphaned records on cancel or browser crash |
| HierarchyNode always references real DB records | Orphans accumulate over time (tiny but unbounded) |
| No special handling needed at save time | Requires cleanup job if orphans become a concern |
| Proven pattern (matches authoring-side ContainerEditor) | |

**Orphan characteristics:** Invisible to all UIs (no SectionResource = not in any section tree; `container_scope: :blueprint` = filtered from project views). Detectable via: `WHERE container_scope = :blueprint AND resource_id NOT IN (SELECT resource_id FROM section_resources)`.

#### Approach B: Draft Entities (persist at save time)

When the user clicks "Create Module," only an in-memory HierarchyNode is created with a temporary negative `resource_id` and an in-memory `%Revision{}` struct (never persisted). On save, a materialization step finds all draft nodes, creates real Resources/Revisions/PublishedResources, swaps the temporary IDs, and then calls `rebuild_section_curriculum`.

```
User clicks "Create Module"
  → Draft Revision struct built in memory (not persisted)
  → Temporary resource_id = -System.unique_integer([:positive])
  → HierarchyNode built with draft data
  → Appended to in-memory hierarchy

User clicks "Save"
  → Materialization: find nodes with negative resource_id
  → For each: Repo.transaction creates Resource + Revision + PublishedResources
  → Swap negative resource_ids with real ones in hierarchy
  → rebuild_section_curriculum creates SectionResources

User clicks "Cancel"
  → In-memory hierarchy discarded
  → Nothing in DB to clean up — zero orphans
```

**Why this works:** All in-memory operations between create and save (finalize, select_active, add_materials, reorder, move, remove, render) use `uuid`, `revision.title`, `revision.resource_type_id`, and `children` — none of them query the database by `resource_id`. Only `collapse_section_hierarchy` (inside save) requires real resource_ids, and we swap them right before that step.

| Pros | Cons |
|------|------|
| Zero orphans on cancel | More complex — two code paths (draft create + materialize at save) |
| Zero orphans on browser crash | Need to track which nodes are drafts (negative resource_id convention) |
| Clean — nothing in DB until user commits | Materialization step adds ~20 lines to save |
| No cleanup job ever needed | New pattern — not used elsewhere in codebase |
| | Draft Revision struct must have all fields that hierarchy operations read |

**Draft detection:** Nodes with `resource_id < 0` are drafts. Simple integer check.

#### Summary

| | Approach A (Immediate) | Approach B (Draft) |
|---|---|---|
| Orphans on cancel | Yes | None |
| Orphans on crash | Yes | None |
| Complexity | Low | Medium |
| Code paths | One | Two (draft + materialize) |
| Risk | Low (proven pattern) | Medium (new pattern) |
| Save performance | Faster (resources already exist) | Slightly slower (creates resources at save time) |
| Cleanup needed | Eventually (if orphans accumulate) | Never |

## 5. Interfaces

### 5.1 HTTP/JSON APIs
No new HTTP endpoints. Container creation is handled entirely through LiveView events.

### 5.2 LiveView

**New events on `OliWeb.Delivery.RemixSection`:**

| Event | Params | Effect |
|-------|--------|--------|
| `"create_container"` | `%{"type" => "unit"\|"module"\|"section"}` | Creates draft container in-memory, adds to hierarchy, sets unsaved changes |
| `"show_unsaved_changes_modal"` | `%{"target" => url}` | Shows unsaved changes modal with navigation target (PR2) |
| `"unsaved_changes_save"` | none | Saves then navigates to target (PR2) |
| `"unsaved_changes_leave"` | none | Navigates without saving (PR2) |

**New assigns:**

| Assign | Type | Purpose |
|--------|------|---------|
| `saving` | boolean | Whether save is in progress (PR2) |
| `show_confirmation` | boolean | Whether to show save confirmation banner (PR2) |
| `pending_navigation_target` | string \| nil | Target URL for unsaved changes modal (PR2) |

### 5.3 Processes
No new processes.

## 6. Data Model & Storage

### 6.1 Ecto Schema Changes

**Migration: Add `container_scope` to `revisions` table**

```elixir
def change do
  alter table(:revisions) do
    add :container_scope, :string, default: "project", null: false
  end
end
```

Field definition in `lib/oli/resources/revision.ex`:
```elixir
field :container_scope, Ecto.Enum,
  values: [:project, :blueprint, :section],
  default: :project
```

**Impact on `create_revision_from_previous`** (`lib/oli/resources.ex:314`):
Add `container_scope: previous_revision.container_scope` to the copied fields map so scope is preserved across revision edits.

### 6.2 New Function: `Publishing.get_all_publications_for_project/1`

```elixir
def get_all_publications_for_project(project_id) do
  Repo.all(
    from pub in Publication,
      where: pub.project_id == ^project_id,
      select: pub
  )
end
```

### 6.3 Query Performance

**Scope filter addition:** Adding `where rev.container_scope == :project` to `AuthoringResolver` queries. This is a simple equality check on a new column. For performance, consider an index:

```sql
CREATE INDEX index_revisions_container_scope ON revisions (container_scope);
```

However, since this column is only filtered in project-level queries (which already join through PublishedResource and are bounded by publication), the existing indexes may suffice. Monitor query plans before adding.

## 7. Consistency & Transactions

**Two-phase approach:** Container creation is split into an in-memory phase (draft creation) and a persistence phase (materialization at save time).

**Phase 1 — Draft creation (no transaction needed):**
`ContainerCreation.build_draft/3` builds an in-memory struct. No database writes, no transaction.

**Phase 2 — Materialization (inside save):**
`ContainerCreation.materialize/3` runs inside `Remix.save/2`, before `rebuild_section_curriculum`. Uses a **single** `Repo.transaction` wrapping ALL draft materializations. This is critical: if draft A materializes but draft B fails, the entire transaction rolls back — including draft A's records. No partial materialization, no orphaned records.

```elixir
def materialize(hierarchy, project, author) do
  draft_nodes = find_draft_nodes(hierarchy)

  # Single transaction for ALL drafts — partial failure rolls back everything
  Repo.transaction(fn ->
    Enum.reduce(draft_nodes, hierarchy, fn draft, acc ->
      with {:ok, %{resource: resource, revision: revision}} <-
             persist_single_draft(project, draft.revision, author),
           publications <- Publishing.get_all_publications_for_project(project.id),
           :ok <- upsert_all_published_resources(publications, revision) do
        updated_node = %HierarchyNode{draft |
          resource_id: resource.id,
          revision: revision
        }
        Hierarchy.find_and_update_node(acc, updated_node)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end)
end
```

All-or-nothing: If any draft's materialization fails, the entire transaction rolls back. Zero new records for any draft. The user can retry save.

**Cancel invariant:** If save is never called, no database writes occur. The draft nodes are discarded with the in-memory state. Zero orphaned records.

**Idempotency:** Container creation is not idempotent — each click creates a new draft node with a unique negative ID. This is intentional (users may want multiple modules). The save operation (`rebuild_section_curriculum`) uses upsert semantics with `conflict_target: [:section_id, :resource_id]`, which handles repeated saves correctly.

## 8. Caching Strategy

No new cache layers. Existing section cache is cleared by `rebuild_section_curriculum` on save. The container exists only in the in-memory hierarchy until save is triggered.

## 9. Performance and Scalability Plan

### 9.1 Budgets
- Container creation (draft): instant — no DB, just struct building
- Save with materialization: p95 <= 1000ms per draft node (includes Resource + Revision + N PublishedResource upserts + rebuild_section_curriculum)
- N is typically 2-5 publications per project (working + published versions)
- Each PublishedResource upsert is a single row insert/update

### 9.2 Hotspots & Mitigations
- **Many publications**: A project with many publications (e.g., 10+) would require 10+ PublishedResource inserts per container creation. Mitigate with batch insert if needed, but this is unlikely to be a practical concern.
- **Large hierarchies**: Hierarchy finalization (renumbering) is O(n) where n = total nodes. Existing performance is acceptable for current hierarchy sizes.

## 10. Failure Modes & Resilience

| Failure | System Response |
|---------|----------------|
| Materialization fails during save | Transaction rolls back, no partial state. LiveView shows error flash. Draft nodes remain in memory — user can retry save. |
| Save never triggered (cancel or browser close) | Draft nodes discarded with in-memory state. **No database writes occurred — zero orphaned records.** |
| Unsaved changes modal dismissed without action | No state change. User remains on page with pending changes. Draft nodes still in memory. |
| Browser crash with unsaved changes | Draft nodes lost (in-memory only). No database cleanup needed. Same behavior as current remix flow for any unsaved changes. |
| Multiple draft containers created, materialization fails midway | All materializations wrapped in a single `Repo.transaction` — if any draft fails, everything rolls back. Zero orphaned records. User can retry save. |

## 11. Security & Privacy

- **Authorization**: Container creation inherits existing remix mount authorization (`is_author_of_blueprint?` OR `at_least_content_admin?`). No new authorization checks needed beyond what mount already enforces.
- **Server-side enforcement**: All container creation happens via LiveView event handlers, which require an authenticated, authorized session. No direct HTTP endpoints exposed.
- **Scope isolation**: `container_scope` filtering in `AuthoringResolver` queries prevents blueprint containers from leaking to project-level views. Regression tests must verify this.
- **Tenant isolation**: Container is created in the section's `base_project`, which is already scoped to the institution. No cross-tenant concerns.

## 12. Testing Strategy

### Unit Tests
- `Oli.Delivery.Remix.ContainerCreation.create/4`:
  - Creates Resource with correct resource_type (container)
  - Creates Revision with `container_scope: :blueprint`
  - Creates PublishedResource records for ALL publications
  - Rolls back completely on any failure
- `Oli.Delivery.Remix.create_container/3`:
  - Returns updated State with new container in hierarchy
  - Sets `has_unsaved_changes: true`
  - Container appears at correct position in active.children

### Scope Isolation Tests
- `AuthoringResolver.full_hierarchy/1` excludes `container_scope: :blueprint` revisions
- `AuthoringResolver.revisions_of_type/2` with container type excludes blueprint-scoped containers
- `Publishing.query_unpublished_revisions_by_type/2` with container type excludes blueprint-scoped containers
- Template remix `DeliveryResolver.full_hierarchy/1` includes both project and blueprint containers (via SectionResource tree — no change needed)

### Integration Tests
- Full flow: Create container → add materials to it → save → verify SectionResource tree includes new container
- Full flow: Create container → cancel → verify no SectionResource exists for container
- Verify published_resource coverage across all publications after container creation

### LiveView Tests
- Create container button appears at correct hierarchy levels
- Click creates container and appears in list
- Save/cancel after container creation works correctly
- Add Materials modal hides already-present resources (PR2)
- Unsaved changes modal appears on navigation with pending changes (PR2)

## 13. Backwards Compatibility

- **Migration**: Adding `container_scope` with default `:project` is backward-compatible. All existing revisions implicitly have project scope.
- **Query changes**: Adding `WHERE container_scope = :project` to project-level queries only narrows results. Since no `:blueprint` or `:section` scoped revisions exist before this feature, queries return identical results after migration.
- **Export/Import**: `lib/oli/interop/export.ex` exports revision fields. The new `container_scope` field will be included in exports. Import (`lib/oli/interop/ingest/processor/hierarchy.ex`) creates containers with default scope (`:project`), which is correct for imported content.
- **`create_revision_from_previous`**: Must copy `container_scope` to preserve scope across revision edits. This is a required change in `lib/oli/resources.ex:314`.

## 14. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Scope filter audit misses a query | Comprehensive test suite verifying blueprint containers don't appear in project views. Grep-based audit of all `ResourceType.id_for_container` and `resource_type_id` references. |
| Published publications diverge after container creation | Transaction ensures all PublishedResource records are created atomically. Test verifies record count matches publication count. |
| Orphaned resources from unsaved container creation | Harmless — resources without SectionResource entries are invisible. Could add periodic cleanup if volume becomes a concern. |
| `create_revision_from_previous` not updated to copy `container_scope` | Regression test: create blueprint container, edit its title, verify new revision retains `container_scope: :blueprint`. |

## 15. Open Questions & Follow-ups

- **Container title**: Should newly created containers have an editable inline title, or use auto-generated defaults (e.g., "New Module 1")? Recommendation: Use auto-generated default with immediate inline edit capability.
- **Hierarchy depth rules**: Can a module contain sub-modules, or is nesting strictly unit → module → section → page? Need to confirm with Darren/design.
- **Instructor remix extension**: Once template isolation is verified, `container_scope: :section` enables the same feature for instructor remix. This is a future ticket.
- **Orphan cleanup**: Should we add a background job to clean up orphaned resources (created but never saved to a section)? Low priority given they're invisible.
- **Refactor existing Remix test setup**: The existing tests at `test/oli/delivery/remix/ops_test.exs` build hierarchies manually (insert each revision individually). The new `Oli.Test.HierarchyBuilder` provides a composable, declarative alternative. Once validated in the `create_container` tests, consider refactoring `ops_test.exs` and `save_test.exs` to use it. Future work — not part of this ticket.
- **Container title auto-generation**: Currently uses static "New Unit" / "New Module" / "New Section". The authoring-side uses `Oli.Authoring.Editing.Util.new_container_name/2` with `Numbering` to generate proper sequential titles like "Unit Two", "Module Three". The remix container creation should use the same pattern, deriving the title from the active container's numbering and children count. This requires passing numbering data from the hierarchy into `build_draft`.
- **Consolidate duplicate container queries**: `AuthoringResolver.revisions_of_type/2` (`lib/oli/publishing/authoring_resolver.ex:174`) and `Publishing.query_unpublished_revisions_by_type/2` (`lib/oli/publishing.ex:111`) are nearly identical queries — both join PublishedResource → Revision, filter by working publication + resource_type + not deleted. Both need the `container_scope = :project` filter added independently. Future work: consolidate into a single shared query to avoid maintaining the same filter in two places.

## 16. References

- `docs/exec-plans/current/epics/product_overhaul/add_containers/informal.md`
- `docs/exec-plans/current/epics/product_overhaul/add_containers/prd.md`
- `lib/oli/authoring/editing/container_editor.ex` — Authoring container creation pattern
- `lib/oli/publishing/tracker.ex` — ChangeTracker (working publication only)
- `lib/oli/publishing.ex` — `upsert_published_resource/2`, publication queries
- `lib/oli/publishing/authoring_resolver.ex` — Project-level queries needing scope filter
- `lib/oli/delivery/remix.ex` — Remix state management
- `lib/oli/delivery/hierarchy.ex` — In-memory hierarchy operations
- `lib/oli/delivery/hierarchy/hierarchy_node.ex` — HierarchyNode struct
- `lib/oli_web/live/delivery/remix_section.ex` — Remix LiveView
- `lib/oli/resources/revision.ex:69` — Existing `scope` field (naming collision evidence)
- `lib/oli/resources.ex:314` — `create_revision_from_previous` (must copy `container_scope`)

## 17. Decision Log

### 2026-03-30 — Separate `container_scope` field instead of extending existing `scope`
- Change: Named new field `container_scope` to avoid collision with `Revision.scope` (`:embedded | :banked`).
- Reason: Existing `scope` field is used for activity scoping in `ActivityProvider` and propagated via `create_revision_from_previous`. Extending it would conflate two unrelated concepts.
- Evidence: `lib/oli/resources/revision.ex:69`, `lib/oli/delivery/activity_provider.ex:363`.
- Impact: All spec documents and implementation use `container_scope` consistently.

### 2026-03-30 — Two-PR split: backend-first, then frontend polish
- Change: Split implementation into PR1 (data model + container creation + scope audit + functional buttons) and PR2 (unsaved changes modal, saving indicator, duplicate filtering UX, design system).
- Reason: Reduces risk by validating scope isolation independently before layering UI polish. Backend changes carry the highest risk (data model, query audit); frontend changes are self-contained.
- Impact: PR1 can be reviewed and merged first. PR2 depends on PR1 but not vice versa.

### 2026-03-30 — Upsert PublishedResources across ALL publications, not just working
- Change: Container creation upserts to every publication for the project, not just the working (unpublished) one.
- Reason: Darren's Dec 2024 technical guidance explicitly requires this for publishing/diffing infrastructure to work correctly. The existing `ChangeTracker` only handles the working publication.
- Evidence: Jira comment by Darren Siegel on MER-4057 (2024-12-02).
- Impact: New `get_all_publications_for_project/1` function needed. Transaction must cover all upserts.

### 2026-03-31 — Draft entities with negative IDs (Approach B chosen over Approach A)
- Change: Container creation builds in-memory draft HierarchyNodes with negative temporary `resource_id` and `revision.id`. Resources are only persisted to the database during `Remix.save/2` (materialization step), not at creation time.
- Reason: Approach A (immediate persistence) creates orphaned Resource/Revision/PublishedResource records when the user cancels or the browser crashes. Approach B maintains the invariant that uncommitted user actions leave no trace in the database, and is architecturally consistent with all other remix operations (reorder, move, remove, add_materials) which are purely in-memory until save.
- Evidence: Deep validation of 18 code paths confirmed that all in-memory remix operations use `uuid` for node identification, not `resource_id`. Negative IDs are inert between create and save. `System.unique_integer([:positive])` guarantees uniqueness per VM. See section 4.5 for full analysis.
- Impact: `ContainerCreation` module has two functions: `build_draft/3` (in-memory) and `materialize/3` (DB at save time). The `Result` struct is no longer needed since `build_draft` returns a `%HierarchyNode{}` directly.

### 2026-04-01 — Blueprint containers must NOT be children of project containers
- Change: Discovered during Phase 1 implementation that blueprint-scoped containers cannot appear in any project container's `children` array. `AuthoringResolver.full_hierarchy` walks `revision.children` to build the tree — if a child's `resource_id` is filtered out by `container_scope = :project`, the lookup returns `nil` and crashes.
- Reason: The scope filter removes the blueprint container from `revisions_by_resource_id`, but the parent's `children` array still references it. The hierarchy builder doesn't handle missing children gracefully.
- Impact: Confirms the design — `ContainerCreation.materialize` creates Resource/Revision/PublishedResources as standalone records in the publication. They are never added to any project container's `children` array. They only appear in the SectionResource tree (via `rebuild_section_curriculum`). This is architecturally correct: blueprint containers exist in the project's publication for publishing/diffing purposes, but are structurally invisible to the project hierarchy.

### 2026-04-06 — Author passed to save/2 from socket assigns, not fetched from project
- Change: `Remix.save/2` now takes the current author as a parameter instead of fetching the project's first author via `List.first(Repo.preload(project, :authors).authors)`. The LiveView passes `socket.assigns[:current_author]` (set by `on_mount` hook). Author defaults to `nil` for backward compatibility with instructor remix (where no drafts exist and author isn't needed). `materialize/3` returns `{:error, :author_required_for_materialization}` if drafts exist but author is nil.
- Reason: The previous approach attributed revision authorship to the project owner, not the person who actually made the change. It also had a nil crash risk if the project had no authors.
- Evidence: `on_mount {OliWeb.AuthorAuth, :mount_current_author}` at `remix_section.ex:47` already sets `current_author` in socket assigns. Instructor sessions may have nil `current_author` but they can't create containers (button hidden for enrollable sections), so no drafts to materialize.
- Impact: Removed TODO comment. Correct revision authorship. Nil-safe for instructor sessions.

## Appendix A: Scope Filter Audit — Queries Requiring `container_scope = :project`

### High Priority (directly list containers or build hierarchy)

| File | Function | Line | Notes |
|------|----------|------|-------|
| `authoring_resolver.ex` | `all_revisions_in_hierarchy` | 191 | Builds project hierarchy — pages + containers |
| `authoring_resolver.ex` | `full_hierarchy` | 244 | Uses `all_revisions_in_hierarchy` |
| `authoring_resolver.ex` | `revisions_of_type` | 174 | When called with container type |
| `publishing.ex` | `query_unpublished_revisions_by_type` | 111 | When called with container type |
| `publishing.ex` | `get_unpublished_revisions_by_type` | 145 | Wrapper for above |
| `resource_editor.ex` | `list` | 24 | Uses `get_unpublished_revisions_by_type` |

### Medium Priority (list all resources, may include containers)

| File | Function | Line | Notes |
|------|----------|------|-------|
| `authoring_resolver.ex` | `all_revisions` | 159 | All resource types for project |
| `authoring_resolver.ex` | `all_pages` | 142 | Pages only — may not need filter, but audit for safety |
| `authoring_resolver.ex` | `get_by_purpose` | 333 | Pages by purpose |
| `publishing.ex` | `get_published_resources_by_publication` | 700 | All resources in publication |

### Not Needed (section-level, already scoped by SectionResource)

| File | Function | Notes |
|------|----------|-------|
| `delivery_resolver.ex` | All functions | Section-level — scoped by SectionResource tree |
| `sections.ex` | `fetch_all_pages`, `fetch_all_modules` | Section-level |
