# Remix LiveView Refactor — Feature Design Document

## 1. Executive Summary

This refactor extracts Remix business logic out of the LiveView (`OliWeb.Delivery.RemixSection`) into a cohesive delivery-context module (`Oli.Delivery.Remix`). The goal is a thin LiveView containing only UI wiring and assigns, while the new module owns state transitions (reorder/move/add/remove/toggle hidden), publication/page querying with filtering/sorting/pagination, and the save/persist workflow. The design preserves current behavior and routes, keeps persistence in `Oli.Delivery.Sections.rebuild_section_curriculum/3`, and consolidates “Remix” domain concerns behind a testable, documented API. No schema changes are needed. The module exposes pure functions for state evolution to simplify unit testing and improve maintainability. Performance stays comparable (batched queries and resolvers are reused). The refactor is incremental and low-risk: introduce the module first, adapt LiveView handlers to delegate, then delete duplicate logic. Key risks are subtle behavior mismatches (ordering, selection, pinned publications) and regression in pagination/sorting; we mitigate by adding a focused unit test suite and keeping existing LiveView integration tests intact. No additional custom telemetry is introduced for Remix; default Phoenix/Ecto/AppSignal instrumentation is sufficient.

## 2. Requirements & Assumptions

- Functional Requirements:
  - Move non-UI logic from `OliWeb.Delivery.RemixSection` into a new or existing `Oli` module (proposed `Oli.Delivery.Remix`).
  - Preserve current UX and LiveView events, routes, and HTML structure.
  - Centralize: initialization (hierarchy/publications/pinned map), selecting/active traversal, reorder/move, add/remove materials, toggle hidden, querying/filtering/sorting publications and pages, and save/persist.
  - Provide a clear API callable by LiveView with pure functions wherever possible.
  - Provide a test plan and add unit tests for the new module.
- Non-Functional Requirements:
  - Latency: interactive operations < 50 ms P95 server-side; save persists within 1–2 s including post-processing.
  - Maintain DB QPS patterns; no new N+1s; preserve batched lookups.
  - Work across nodes in Phoenix clusters.
- Explicit Assumptions:
  - Authorization decisions remain where they are (mount paths); `Oli.Delivery.Remix` consumes already-authorized inputs. Risk: duplicating auth invites drift—module is intentionally auth-agnostic.
  - Persistence continues via `Sections.rebuild_section_curriculum/3`. Risk: behavioral coupling to canonical rebuild; acceptable and desired.
  - “Pinned publications” semantics remain: per-project map influences selection and later updates.
  - `Oli.Delivery.Hierarchy` API remains stable; refactor doesn’t change it.

## 3. Torus Context Summary

- Domains/Contexts: Delivery (`Oli.Delivery.Sections`, `Oli.Delivery.Hierarchy`), Publishing (`Oli.Publishing.*`), Accounts (authors/users), Web LiveViews/components in `OliWeb`.
- Data Model: Resource/Revision; Publication with `PublishedResource`; Section hierarchy persisted via SectionResources and rebuilt with `Sections.rebuild_section_curriculum/3`.
- Runtime & Topology: Phoenix LiveView; resolves via `DeliveryResolver` and `AuthoringResolver`; multi-node Phoenix clusters with PubSub and Depot refresh.
- Relevant modules spotted:
  - LiveView: `lib/oli_web/live/delivery/remix_section.ex`
  - Hierarchy ops: `lib/oli/delivery/hierarchy.ex` and `HierarchyNode`
  - Section rebuild/pinning: `lib/oli/delivery/sections.ex` (`rebuild_section_curriculum/3`, `get_pinned_project_publications/1`)
  - Publishing queries: `Oli.Publishing.*` (visible/available publications, published pages)
  - UI components: `OliWeb.Delivery.Remix.*` modals and actions
- Telemetry: rely on default Phoenix/Ecto/AppSignal; no Remix-specific span events.

## 4. Proposed Design

### 4.1 Component Roles & Interactions
- `Oli.Delivery.Remix` (new context module):
  - Owns the “Remix session state” and exposes pure functions to transition it.
  - Encapsulates initialization from section + actor and computing available/pinned publications.
  - Operations: select active, reorder children, move item, remove item, toggle hidden, add materials (preserve original order from publication), table pagination/filtering/sorting.
  - Persist/save: finalize hierarchy and call `Sections.rebuild_section_curriculum/3`.
- `OliWeb.Delivery.RemixSection` (existing LiveView):
  - Left as UI glue: mount auth branching, assigns, modal show/hide, translating phx events into `Oli.Delivery.Remix` calls, redirect on save/cancel. Rendering/components unchanged.

### 4.2 State & Message Flow
- State owner: LiveView assigns; business state is `Oli.Delivery.Remix.State` managed by the module.
- Flow: mount → `Remix.init/2` → `%State{...}` → event handlers call `Remix.*` → updated state assigned; save calls `Remix.save/1`.
- Backpressure: none needed; operations synchronous and cheap; persistent save via DB transaction.

### 4.3 Supervision & Lifecycle
- No new processes. Plain module functions; LiveView owns ephemeral state lifecycle. Failure isolation through `{:ok, state} | {:error, reason, state}` returns.

### 4.4 Alternatives Considered
- Per-session GenServer: unnecessary complexity; LV already owns state.
- Extending `Hierarchy` with Remix specifics: harms separation; keep `Hierarchy` generic.
- Moving into `Publishing`: not a fit; Remix spans Delivery + Publication and interactive ordering.

## 5. Interfaces

### 5.1 HTTP/JSON APIs
- None changed. Existing routes remain:
  - `/sections/:section_slug/remix`
  - `/products/:section_slug/remix` (product_remix)
  - `/open_and_free/:section_slug/remix`

### 5.2 LiveView
- Events unchanged; LV delegates to `Remix`:
  - select/set_active/keydown → `Remix.select_active/2` or helpers
  - reorder → `Remix.reorder/3`
  - MoveModal.move_item → `Remix.move/3`
  - RemoveModal.remove → `Remix.remove/2`
  - HideResourceModal.toggle → `Remix.toggle_hidden/2`
  - AddMaterialsModal.add → `Remix.add_materials/2`
  - HierarchyPicker.* → `Remix` filter/sort/paginate/update_active functions
  - save → `Remix.save/1`

### 5.3 Processes
- None added (no Registry/GenStage/Broadway). Straight function calls.

## 6. Data Model & Storage

### 6.1 Ecto Schemas
- No schema changes. Use existing: `Section`, `SectionsProjectsPublications`, `Publication`, `PublishedResource`, `SectionResource`.
- Pinned publication map semantics preserved.

### 6.2 Query Performance
- Reuse existing efficient calls:
  - `Publishing.get_published_resources_for_publications/1` (bulk map)
  - `Sections.published_resources_map/1` (publication hierarchy)
  - `Publishing.get_published_pages_by_publication/2` (paging/sorting/filtering)
- Keep maps cached in state for modal lifecycle. Small page sizes by default.

## 7. Consistency & Transactions
- Strong consistency on save via one `Repo.transaction()` inside `Sections.rebuild_section_curriculum/3`.
- Idempotent behavior: repeated save with same finalized hierarchy is effectively a no-op.
- On failure, keep state and surface error; no partial commits.

## 8. Caching Strategy
- No new global caches. Continue depot refresh in rebuild (`SectionResourceDepot`).
- In-session cache: publication hierarchies and maps kept in `%State{}`.
- Multi-node coherence handled by existing depot refresh and PubSub.

## 9. Performance and Scalability Plan

### 9.3 Hotspots & Mitigations
- N+1 risks when building hierarchies: reuse bulk maps.
- Large selections: in-memory sort by original order; UI limits selection size.
- No mailbox growth (no background processes).

## 10. Failure Modes & Resilience
- DB constraint violations: avoided by `Hierarchy.purge_duplicate_resources/1` within rebuild.
- Missing/outdated pinned pub: fall back and keep previous; validate existence on add.
- Query timeouts on large pubs: pagination enforced; increase limits only via config.
- Graceful handling: return `{:error, reason, state}`; leave LV responsive.

## 12. Security & Privacy
- AuthN/AuthZ: unchanged; checks remain in `Mount.for/2` and role gating. `Remix` accepts authorized inputs.
- PII: none new; avoid logging titles if necessary.
- Tenant isolation: respect institution scoping via existing `Publishing.*` calls.

## 13. Testing Strategy
- Unit tests (new):
  - State transitions: reorder, move, remove (incl. last material), toggle hidden.
  - Add materials: preserves publication order; updates pinned map for multiple pubs.
  - Important: Expose all remix operations as Oli.Scenarios remix directives and attributes, and build strictly YAML based scenario driven tests.
  - Filtering/sorting/pagination for pages/publications.
  - Save delegates to `Sections.rebuild_section_curriculum/3` with finalized hierarchy.
  - Property-style: reorder + move preserves multiset of resource_ids.
- Integration tests: keep existing `test/oli_web/live/remix_section_test.exs` unchanged.
- Failure injection: simulate transaction failure; ensure proper error surfacing.

## 14. Backwards Compatibility
- No changes to activity/page content model.
- LiveView UI/DOM and routes unchanged; existing tests should pass.
- Persistence path unchanged.

## 15. Risks & Mitigations
- Behavior drift during extraction → copy logic first, add unit tests, then incrementally clean up.
- Performance regressions → reuse current queries, batch operations, cache maps in state.
- Edge cases (deep nesting/multi-pub) → targeted unit tests.

## 16. Open Questions & Follow-ups
- Feature flag to toggle new vs. old path? Default: off (no flag). Can add app config gate if desired.
- Future API exposure: module API supports potential HTTP endpoints if product needs.
- Default page size (All pages): keep 5 for parity; consider config.

## 17. References
- Phoenix Contexts — Guide · https://hexdocs.pm/phoenix/contexts.html · Accessed 2025-09-12
- Phoenix LiveView — Handling Events · https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-handling-events · Accessed 2025-09-12
- Ecto Multi and Transactions · https://hexdocs.pm/ecto/Ecto.Multi.html · Accessed 2025-09-12
- Erlang/OTP Design Principles — Processes, Errors · https://www.erlang.org/doc/design_principles/des_princ · Accessed 2025-09-12
- Telemetry Guide · https://hexdocs.pm/telemetry/readme.html · Accessed 2025-09-12
