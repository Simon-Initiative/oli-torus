# MER-5855 LearningObjectiveCoverage Data Source - Functional Design Document

## 1. Executive Summary

Implement `Oli.Authoring.ObjectiveCoverage` as a plain, read-only application module. The module will execute one Ecto projection against the project's current unpublished publication, then transform compact rows into a deterministic model containing objective hierarchy, direct attachments, page/activity details, curriculum scope, coverage summaries, and searchable text. The workspace LiveView and later objective-editor features consume this model; they do not own its query or data-shaping rules.

The design deliberately uses working-publication mappings rather than historical unpublished revisions, excludes deleted revisions, avoids page/activity `content`, and limits initial activity coverage to static embedded activities represented by page `activity_refs`.

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001`: expose a focused application-level coverage module and reusable read-only model.
  - `FR-002`: load one compact, project-scoped working-publication projection.
  - `FR-003`: build normalized hierarchy, attachment, page/activity, and curriculum indexes.
  - `FR-004`: calculate direct and inherited coverage with deduplication and assessment classification.
  - `FR-005`: expose detail and normalized search projections.
  - `FR-006`: support embedded-only initial activity coverage without writes.
  - `FR-007`: enforce project scope, deleted-row exclusion, safe optional-data handling, and deterministic output.
- Non-functional requirements:
  - No N+1 queries, full page/activity content selection, GenServer, cache process, schema migration, or database full-text search.
  - Domain logic remains under `lib/oli/`; LiveView code only invokes and presents the model.
  - Query/build duration and row counts may be observed without logging content bodies.
- Assumptions:
  - `published_resources` identifies the authoritative revision for each resource in the working publication.
  - `project_working_publication/1` or an equivalent project-scoped query resolves the single unpublished publication.
  - `Revision.activity_refs` is the maintained page-to-embedded-activity boundary.
  - Objective maps contain lists of objective resource ids under one or more keys, and activity objective tags are read from all map values.
  - Missing `activity_refs` means no discoverable embedded activities for this model; repairing stale indexes is separate work.

## 3. Repository Context Summary

- What we know:
  - `OliWeb.Workspaces.CourseAuthor.ObjectivesLive` currently builds objective rows and asynchronously calls `Publishing.find_attached_objectives/1`.
  - `Oli.Publishing.project_working_publication/1` resolves an unpublished project publication by slug.
  - `Oli.Publishing.PublishedResource` maps a publication/resource to its selected revision.
  - `Oli.Resources.Revision` stores `resource_id`, `resource_type_id`, `title`, `slug`, `deleted`, `children`, `objectives`, `graded`, `activity_refs`, `scope`, and `activity_type_id`.
  - `Oli.Resources.ResourceType` supplies resource-type ids for pages, activities, containers, and objectives.
  - `Oli.Authoring.LearningObjectives.PageElement` demonstrates narrow working-publication queries and uses `activity_refs` instead of scanning page JSON.
  - `Publishing.find_attached_objectives/1` is a useful regression reference but does not return enough fields for the new model.
  - `AuthoringResolver` and delivery depots solve related delivery/runtime problems but are not the authoring data-source boundary for this work.
- Unknowns to confirm:
  - The exact shape of existing objective `children` data when an objective has multiple parent associations.
  - The exact JSON keys used for formative/summative objective attachment lists; the implementation must flatten all objective-map values rather than assume one key.
  - The canonical curriculum path representation expected by the CSV and course-content filter consumers.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

Use one module with a small public boundary and private transformation stages:

1. `Oli.Authoring.ObjectiveCoverage` accepts a project or project slug and obtains the working publication id.
2. A private Ecto query selects compact rows from `published_resources` joined to `revisions`, scoped through `publications` and `projects`, with `published IS NULL` and `deleted IS FALSE`.
3. A row-normalization stage converts database values into a small internal row shape and normalizes nullable arrays/maps/enums.
4. An index-building stage partitions rows by resource type and creates lookup maps/MapSets.
5. A coverage stage derives direct attachments, parent-expanded attachments, assessment buckets, page-first details, and searchable text.
6. Public read functions expose the model to the workspace LiveView and future filtering/export consumers.

Do not place this logic in `ObjectivesLive`, `Publishing.find_attached_objectives/1`, or a supervised process. The existing LiveView can be migrated by replacing its attachment task with a single model load in a follow-up consumer change; this FDD only defines the data-source implementation.

### 4.2 State & Data Flow

```text
project slug/id
    -> working publication id
    -> compact projection rows
    -> typed/normalized row partitions
    -> relationship indexes
    -> coverage/detail/search model
    -> LiveView, filters, CSV, and tests
```

Recommended internal model shape:

```elixir
%{
  project_id: project_id,
  publication_id: publication_id,
  objectives_by_id: %{objective_id => objective_summary},
  parents_by_child: %{child_id => MapSet.t(parent_id)},
  children_by_parent: %{parent_id => [child_id]},
  pages_by_id: %{page_id => page_summary},
  activities_by_id: %{activity_id => activity_summary},
  curriculum_by_id: %{container_or_page_id => curriculum_node},
  coverage_by_objective: %{objective_id => coverage_summary},
  details_by_objective: %{objective_id => [page_detail_group]},
  search_by_objective: %{objective_id => search_projection}
}
```

The exact public struct may be chosen during implementation, but maps must preserve stable resource ids, display titles/slugs, assessment classification, activity type, page location, and match metadata. Build relationships with `MapSet`; sort ids/details by a documented stable key before returning them.

Attachment flow:

- For each page, flatten objective ids from `page.objectives` and add the page to each objective's direct page set.
- For each activity, flatten and deduplicate objective ids from `activity.objectives`; retain only `scope == :embedded` activities for this initial model.
- For each page's `activity_refs`, resolve activity summaries from the projection and attach them to the page group. The activity inherits the page's `graded` bucket.
- For each objective, derive its transitive parent/child expansion from the objective hierarchy. Parent summaries union direct and descendant sets; Sub-Objective summaries use only their own direct sets.
- Count pages and activities per assessment bucket from deduplicated resource ids. Preserve repeated activity occurrences in detail only when needed to represent distinct page groups.
- Build search text from the objective title plus titles reachable through its detail/hierarchy projection. Store normalized text separately from original display values.

### 4.3 Lifecycle & Ownership

The module is called by the parent LiveView process or another request-scoped consumer. It owns no mutable process state and has no supervision tree entry. Each model is an immutable request/load snapshot. The caller owns lifecycle and may discard or replace the model after objective edits or publication changes.

The model is not a cross-request cache. A later optimization may add an explicit, measured cache boundary, but that is outside this ticket.

### 4.4 Alternatives Considered

- Extend `Publishing.find_attached_objectives/1`: rejected because its result lacks resource ids, page grading, activity scope/type, page-to-activity grouping, and curriculum data; extending it would mix a legacy attachment helper with a broader model contract.
- Query each objective/page/activity on demand: rejected because it creates N+1 behavior and makes filtering/search paths inconsistent.
- Load full revisions and parse page `content`: rejected because content is large, the data source does not need it for static embedded coverage, and it repeats work already avoided by `activity_refs`.
- Copy delivery `SectionResourceDepot`: rejected because authoring must read mutable working-publication mappings and has different lifecycle/consistency requirements.
- Add a GenServer/cache: rejected because the requirement is a testable request-scoped snapshot and no cross-request invalidation strategy is needed yet.

## 5. Interfaces

- Proposed public constructor:
  - `load(project_or_slug) :: {:ok, coverage_model} | {:error, :project_not_found | :working_publication_not_found | :multiple_working_publications | term()}`
- Proposed pure builder for focused tests:
  - `build(rows, publication_context) :: {:ok, coverage_model} | {:error, reason}`
- Proposed consumer queries over the model:
  - `objectives(model)` returns stable top-level objective summaries.
  - `coverage(model, objective_id)` returns summary counts and assessment buckets.
  - `details(model, objective_id, assessment_bucket)` returns page-first groups.
  - `search(model, query)` returns matching objective ids plus match metadata.
  - `curriculum_pages(model, selected_ids)` returns page ids in selected curriculum scope.
- Row projection fields:
  - `revision_id`, `resource_id`, `resource_type_id`, `slug`, `title`, `deleted`, `objectives`, `children`, `graded`, `activity_refs`, `scope`, and `activity_type_id`.
- Error contract:
  - Missing project/publication is explicit.
  - Malformed optional objectives/children/activity_refs values normalize to empty collections and may produce an aggregate diagnostic, but must not crash the request.
  - Query failures propagate as tagged errors suitable for LiveView error handling and telemetry.

## 6. Data Model & Storage

- No schema or migration changes.
- The database remains the source of truth; the coverage model is an ephemeral derived projection.
- Query joins should use `published_resources.publication_id = publications.id`, `published_resources.revision_id = revisions.id`, and project/publication scope. Prefer the mapping's selected revision and resource id together so historical revision rows are not accidentally selected.
- Resource types included in the projection are objective, page, activity, and container. Other types are excluded or ignored.
- Exclude `revisions.deleted = true` in SQL. Keep a defensive post-query check for test doubles or future query changes.
- Activity bank selections and standalone banked activities are excluded by `scope`; page detail includes only activities referenced by a page's `activity_refs`.

## 7. Consistency & Transactions

- The read consists of one query outside a write transaction. No transaction is needed because the module performs no writes.
- The projection is a point-in-time database read; concurrent author edits may produce a snapshot that is immediately stale, which is acceptable for a request-scoped authoring view.
- Publication mapping and revision selection must come from the same query snapshot so a resource is not resolved through a different historical revision during post-processing.
- After an objective/page/activity edit, the consumer must explicitly reload the model rather than mutate internal indexes incrementally.

## 8. Caching Strategy

No cache. The model is built once per consumer load and held by the caller. This avoids invalidation bugs when working-publication revisions change. If performance measurements justify caching later, cache keys must include project and working-publication identity and invalidation must follow revision/publication changes.

## 9. Performance & Scalability Posture

- One SQL/Ecto projection is the required initial database path; no per-objective, per-page, per-activity, or per-filter queries.
- Never select `revisions.content`. The selected fields are compact maps/arrays and should be projected into maps rather than `%Revision{}` with preloads.
- Use `MapSet` for relationship construction and convert to sorted lists at the model boundary. Avoid repeated `Enum.find` over all revisions by indexing every resource type by `resource_id` first.
- Keep only compact row data and derived metadata after model construction. Do not retain full Ecto structs or query dumps.
- Instrument or measure query duration, row count, and build duration in representative large projects before wiring the model into initial render. AppSignal/telemetry should receive aggregate values only.
- If the projection becomes memory-bound, the next design step is a measured compact struct or bounded projection strategy; do not introduce a process cache speculatively.

## 10. Failure Modes & Resilience

- Project not found: return a tagged error; caller renders its existing authorization/not-found path.
- No working publication: return a tagged error or an empty model according to the existing authoring convention; implementation should choose one and test it consistently.
- Multiple working publications: return a tagged error rather than merging rows from ambiguous snapshots.
- Query timeout/database error: propagate a tagged error, log aggregate context, and avoid partial model publication.
- Deleted revision/stale mapping: filter it before indexing so deleted pages/activities cannot appear in counts or links.
- Missing objective referenced by content: retain the content row only if a valid objective consumer exists; otherwise ignore the dangling objective id and record a bounded diagnostic if diagnostics are included.
- Missing activity in `activity_refs`: omit that activity from detail/counts; do not fetch page content as a fallback.
- Cyclic or malformed objective hierarchy: protect ancestor traversal with a visited set and return a deterministic finite model; add a diagnostic for the invalid cycle.
- Duplicate objective tags/activity references: deduplicate ids before counting.
- Unexpected enum/null values: normalize safely and classify unknown assessment state as excluded from the relevant bucket rather than guessing.

## 11. Observability

- Emit an optional module-scoped telemetry event around load/build with project id, publication id, row counts by type, duration, and success/failure category.
- Log failures with project/publication identifiers and counts, never page/activity content, objective body JSON, or learner data.
- Do not add product analytics events for this data source. Consumer UI success and filter/search behavior are measured by their own work items.
- A useful operational success signal is that the initial consumer requires one projection load and does not issue follow-up content queries.

## 12. Security & Privacy

- Accept a project already authorized by the caller, but keep the query explicitly scoped to that project's id/slug and working publication. Do not trust an arbitrary publication id supplied by the client.
- Return only authoring data belonging to the project. No learner attempts, grades, or delivery-section state are loaded.
- Treat titles and course structure as project content; do not place full content maps or raw objective JSON in logs/telemetry.
- Consumers remain responsible for route/session authorization; this module must not widen access by allowing cross-project lookup.

## 13. Testing Strategy

- Unit tests for the pure builder with compact row fixtures:
  - `AC-003`: partitioning, hierarchy, direct maps, `activity_refs`, and curriculum indexes.
  - `AC-004`: direct versus inherited parent/Sub-Objective counts and deduplication.
  - `AC-005`: graded classification, inherited activity bucket, page-first details, and empty page groups.
  - `AC-006`: normalized partial search and hierarchy match metadata.
  - `AC-007`: embedded-only scope, bank exclusion, and no-write behavior.
  - `AC-008`: deleted/out-of-scope rows, malformed optional data, cycle protection, and stable ordering.
- Ecto/DataCase query tests:
  - `AC-002`: current working publication scope, selected compact fields, deleted filtering, and revision mapping behavior.
  - `AC-001`: consumer-facing load contract can produce a model without coverage logic in the LiveView.
- Static/code inspection and query-plan review:
  - `AC-009`: one projection rather than N+1 queries, no `content` selection, targeted `mix test`, and `mix format`.
- Run targeted tests first, then broader relevant `mix test` coverage as implementation risk warrants. Run `mix format --check-formatted` or `mix format` on changed Elixir files.
- No scenario test is required for this isolated read model unless the consumer integration exposes a cross-domain regression that unit/DataCase tests cannot cover.

## 14. Backwards Compatibility

- Existing `Publishing.find_attached_objectives/1` behavior remains unchanged in this work item unless a separate migration explicitly replaces its consumer.
- The older objectives editor route remains unchanged; the workspace editor is the intended first consumer.
- No persisted data, API endpoint, publication format, or revision schema changes are introduced.
- Projects with legacy parent-on-activity or child-on-page associations remain readable; the model reports what is present and does not enforce the later well-formed-project rules.

## 15. Risks & Mitigations

- Query projection accidentally selects large content: keep an explicit field list and add query-level regression coverage for the selected shape.
- Multiple parent associations create incorrect hierarchy expansion: represent parents as sets, traverse with visited ids, and test shared Sub-Objectives.
- Duplicate activity occurrences inflate counts: separate deduplicated summary sets from page-grouped detail occurrences.
- Working publication is resolved inconsistently: select the publication and mapped revisions in the same scoped query and return publication context with the model.
- In-memory model is too large: retain compact maps, avoid Ecto structs/content, measure representative projects, and defer caching until evidence exists.
- Consumers depend on unstable internal maps: expose documented read functions/structs and add consumer-contract tests before UI work begins.

## 16. Open Questions & Follow-ups

- Decide whether the missing-working-publication result is an error or an empty model based on the workspace LiveView's existing loading/error convention.
- Confirm the canonical resource-type helper names and exact enum values for `scope` in the implementation branch.
- Confirm the curriculum path shape required by `MER-5800` and `MER-5801`; keep the initial model extensible without loading additional content.
- Decide whether malformed-data diagnostics are returned in the model, emitted only through telemetry, or both.
- Follow up separately on deterministic bank-selection indexing/backfill; do not expand this implementation to parse page content.
- Follow up separately on `MER-5794` consumer integration and on the blocked proficiency work represented by `MER-5821`.

## 17. References

- `docs/exec-plans/current/epics/objectives-editor/core_data/prd.md`
- `docs/exec-plans/current/epics/objectives-editor/core_data/requirements.yml`
- `docs/exec-plans/current/epics/objectives-editor/plan.md`
- `lib/oli_web/live/workspaces/course_author/objectives_live.ex`
- `lib/oli/publishing.ex`
- `lib/oli/publishing/mappings/published_resource.ex`
- `lib/oli/resources/revision.ex`
- `lib/oli/authoring/learning_objectives/page_element.ex`
- Jira `MER-5855` (data source), `MER-5784` (parent epic), and consumer tickets `MER-5794`, `MER-5797`, `MER-5799`, `MER-5800`, `MER-5801`
