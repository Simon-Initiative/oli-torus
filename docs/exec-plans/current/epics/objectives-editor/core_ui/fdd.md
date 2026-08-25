# MER-5794 Learning Objective Coverage UI - Functional Design Document

## 1. Executive Summary

Extend the workspace Learning Objectives LiveView to consume `Oli.Authoring.ObjectiveCoverage` and render objective coverage summaries, page-first attachment details, assessment-bucket toggles, and read-only navigation.

The implementation keeps domain/data shaping in `lib/oli/authoring/`, keeps interaction state in `lib/oli_web/live/workspaces/course_author/`, and keeps the existing objective listing component responsible for presentation. The current `Publishing.find_attached_objectives/1` attachment task becomes obsolete for this feature. One request-scoped coverage model is loaded for the project and reused for all visible rows, expansion state, and bucket changes.

## 2. Requirements & Assumptions

- Functional requirements:
  - `FR-001` / `AC-001` / `AC-002`: render parent and Sub-Objective summaries with the required direct versus descendant semantics.
  - `FR-002` / `AC-003` / `AC-004`: own per-row expansion and formative/summative filtering.
  - `FR-003` / `AC-005`: render deterministic page-first details and page empty states.
  - `FR-004` / `AC-006` / `AC-007`: provide read-only page and embedded-activity navigation.
  - `FR-005` / `AC-008` / `AC-009`: implement Figma-aligned visual and accessible behavior.
  - `FR-006` / `AC-010`: exclude Activity Bank selections and standalone banked activities from v35.
  - `FR-007` / `AC-011`: preserve the ObjectiveCoverage boundary and compact query posture.
- Non-functional requirements:
  - Maintain project and working-publication scoping, existing author authorization, deterministic ordering, bounded telemetry, and no authored-content logging.
  - Avoid full page/activity content loads and repeated per-row queries.
  - Preserve keyboard, ARIA, visible-focus, responsive, and screen-reader behavior.
- Assumptions:
  - `MER-5855` is available and its public API remains `load/1`, `objectives/1`, `coverage/2`, and `details/3`.
  - The workspace route is the only target; `OliWeb.ObjectivesLive.Objectives` is not migrated in this slice.
  - Existing objective mutation events remain available and trigger a coverage refresh after successful mutation.
  - Figma remains authoritative for visual details, while Jira comments define the v35 Activity Bank exclusion.

## 3. Repository Context Summary

- What we know:
  - `lib/oli_web/live/workspaces/course_author/objectives_live.ex` owns the workspace route, LiveView state, objective mutation events, and URL-backed expanded objective slugs.
  - `lib/oli_web/live/workspaces/course_author/objectives/listing.ex` renders the current objective cards, metadata pills, expansion button, and Sub-Objective rows.
  - The current LiveView starts a task that calls `Publishing.project_working_publication/1` and `Publishing.find_attached_objectives/1`, then merges legacy attachment rows into card counts.
  - `lib/oli/authoring/objective_coverage.ex` already builds a compact working-publication model and exposes stable summaries, page-first details, curriculum paths, and search projections.
  - `ObjectiveCoverage.details/3` returns page groups keyed by `:formative` or `:summative`; each group contains a page summary and embedded activity summaries.
  - The existing listing already uses `aria-expanded`, `aria-controls`, keyboard-focus styles, and URL parameters for expansion state.
  - Page authoring links use resource slugs and the workspace route conventions. A separate activity-focus URL contract is not yet established in the waypointed code.
  - The platform uses Phoenix LiveView, Ecto, React authoring surfaces, Tailwind-style utility classes, ExUnit, Phoenix LiveView tests, Jest, and existing AppSignal/Telemetry conventions.
- Unknowns to confirm:
  - The exact page-editor URL/query/hash contract for focusing a particular embedded activity.
  - Whether the existing hierarchy component from `MER-5793` must land before coverage cards can be updated, or whether the current row hierarchy is sufficient.
  - Final empty-state copy and any loading/error visual states not specified by the linked Figma nodes.

## 4. Proposed Design

### 4.1 Component Roles & Interactions

#### `Oli.Authoring.ObjectiveCoverage`

Remains the sole coverage data boundary. It owns the compact projection and pure transformations, including parent scope, direct page/activity relationships, assessment buckets, deterministic details, and safe omission of missing references. The UI must not add SQL or parse page content.

#### `OliWeb.Workspaces.CourseAuthor.ObjectivesLive`

Owns request lifecycle and UI orchestration:

- Start one asynchronous `ObjectiveCoverage.load(project)` operation on initial mount and after a successful objective mutation.
- Store the resulting model or a tagged load failure in assigns.
- Derive objective rows from `ObjectiveCoverage.objectives/1` and `ObjectiveCoverage.coverage/2`.
- Track expanded objective slugs in the existing URL-backed `MapSet`.
- Track the selected assessment bucket per objective id in a local map, defaulting to `:formative` for newly expanded rows unless the Figma/product decision specifies another default.
- Pass the model-derived rows and state to `Objectives.Listing`.
- Convert page/activity resource metadata into safe navigation targets without performing writes.

#### `OliWeb.Workspaces.CourseAuthor.Objectives.Listing`

Owns rendering only:

- Render summary pills and objective/sub-objective detail cards.
- Render per-row expansion controls with `aria-expanded` and `aria-controls`.
- Render the bucket toggle with an explicit selected state.
- Render page groups before activity links and the selected bucket's empty state.
- Render page/activity links generated by the LiveView adapter.
- Use existing icon components and Figma-aligned utility classes.

If the detail markup becomes large, extract focused function components under the existing `objectives/` component boundary rather than moving data shaping into the template.

#### Navigation adapter

Add a small private or focused helper at the web boundary that accepts a project slug, page summary, and optional activity summary and returns a page-editor path. The page target is derived from the page slug. The activity target must use the confirmed page-editor focus contract; until that contract is confirmed, the implementation should not invent a query parameter and the open question must block completion of `AC-006` rather than silently degrade to a page-only link.

### 4.2 State & Data Flow

Initial load:

1. `mount/3` initializes the existing objective editing state plus `coverage_model: nil`, `coverage_status: :loading`, and `assessment_buckets: %{}`.
2. The LiveView starts one task for `ObjectiveCoverage.load(project)` and renders the existing hierarchy with a loading state for coverage metadata.
3. The task sends a tagged message containing either `{:ok, model}` or `{:error, reason}`. The LiveView handles only messages associated with the current project/load generation.
4. On success, the LiveView derives rows from the model, assigns `coverage_model`, marks status `:ready`, and preserves the URL expansion set.
5. On failure, it assigns `coverage_status: {:error, reason}` and renders the existing authoring error convention without exposing query details or authored content.

Rendering:

1. For each top-level objective, obtain summary counts with `ObjectiveCoverage.coverage(model, objective_id)`.
2. For each child, obtain its own summary with the same accessor; do not derive child counts from the parent summary.
3. For an expanded objective, call `ObjectiveCoverage.details(model, objective_id, bucket)` and render the returned page groups in their stable order.
4. When a bucket changes, update only `assessment_buckets[objective_id]` and rerender from the existing model. No database operation occurs.
5. For navigation, use page/activity summaries from the detail group to build links. Link activation leaves the coverage model and associations unchanged.

Refresh after mutation:

1. Existing create/edit/delete/add-existing-sub-objective events continue to use their current domain operations.
2. After a successful mutation, invalidate the old coverage model and start one replacement `ObjectiveCoverage.load(project)` task.
3. Preserve valid expansion and selected-bucket state by resource id/slug where possible; remove state for deleted objectives.
4. Do not merge stale legacy attachment rows into the refreshed model.

### 4.3 Lifecycle & Ownership

- The LiveView process owns the request-scoped coverage model and UI maps.
- The task owns only the duration of the single load operation; it must not become a supervised cache or long-lived process.
- The ObjectiveCoverage module owns no UI state and performs no writes.
- The browser owns only transient focus and normal link navigation; it does not become a source of coverage truth.
- A later LiveView refresh replaces the model atomically at the assign level. Existing renders continue using the prior model until the replacement succeeds.
- If the LiveView terminates, the task result is ignored and no persistent cleanup is needed beyond normal task supervision semantics.

### 4.4 Alternatives Considered

- Keep `Publishing.find_attached_objectives/1` and add UI-specific queries: rejected because it duplicates coverage logic, lacks page/activity grouping and assessment semantics, and risks per-objective queries.
- Load ObjectiveCoverage synchronously in `mount/3`: simpler, but rejected for the initial path because the current screen already uses asynchronous attachment loading and a large project could block the LiveView mount.
- Add a persistent authoring coverage table or cache: rejected because the core-data design is a request-scoped compact projection, no migration is required, and cache invalidation would introduce unnecessary consistency complexity.
- Build a new React objective editor: rejected because the existing workspace route is a LiveView with working mutation and URL state; the feature needs focused interaction changes, not a new client shell.

## 5. Interfaces

### ObjectiveCoverage consumer contract

```elixir
{:ok, model} = Oli.Authoring.ObjectiveCoverage.load(project_or_slug)

objectives = Oli.Authoring.ObjectiveCoverage.objectives(model)
summary = Oli.Authoring.ObjectiveCoverage.coverage(model, objective_id)
groups = Oli.Authoring.ObjectiveCoverage.details(model, objective_id, :formative)
```

The UI relies on these model invariants:

- `objectives/1` returns stable top-level objective summaries.
- `coverage/2` returns `page_count`, `formative_activity_count`, `summative_activity_count`, and `sub_objective_count`.
- `details/3` returns stable page groups shaped as `%{page: page_summary, activities: [activity_summary]}`.
- A missing objective or bucket returns an empty detail list, not a new query.
- Activity summaries are embedded-only and carry resource id/title/slug metadata sufficient for navigation.

### LiveView events and messages

The existing `toggle_objective` event remains the expansion event and continues to update the URL. Add a bucket event with a stable payload, for example:

```text
set_assessment_bucket: %{objective_id: "123", bucket: "formative" | "summative"}
```

The handler must validate the objective id and bucket against the loaded model, then update only the local bucket map. Invalid payloads should leave state unchanged and emit no query.

Use a dedicated load message, for example:

```text
{:objective_coverage_loaded, load_ref, {:ok, model} | {:error, reason}}
```

`load_ref` prevents a stale task result from overwriting a newer model after a mutation or rapid navigation.

### Navigation contract

- Page link: existing authoring page editor path generated from `project.slug` and `page.slug`.
- Embedded activity link: page editor path plus the confirmed activity focus parameter or fragment, using the activity resource id.
- No link may invoke a mutation event or carry a destructive action.

## 6. Data Model & Storage

No schema, migration, or new persistent storage is required.

The in-memory UI projection should be a small map or struct around the ObjectiveCoverage model:

```elixir
%{
  model: objective_coverage_model | nil,
  status: :loading | :ready | {:error, reason},
  expanded_objective_slugs: MapSet.t(String.t()),
  assessment_buckets: %{optional(pos_integer()) => :formative | :summative}
}
```

Rendered objective rows should preserve:

- objective resource id, slug, title, and child summaries;
- summary counts from `coverage/2`;
- page resource id, slug, title, and `graded` classification;
- embedded activity resource id, slug, title, and containing page id;
- navigation target metadata only, not revision content.

ObjectiveCoverage continues to read revisions mapped into the project's current unpublished working publication. It excludes deleted revisions and selects compact fields only. The UI must not add a fallback query for missing activity references or Activity Bank selections.

## 7. Consistency & Transactions

- Coverage loading is read-only and does not require a transaction.
- Objective mutations continue to use their existing domain operations and transaction boundaries.
- A coverage model is a snapshot: it may become stale after an objective mutation, so the LiveView discards it and reloads after successful mutation.
- The UI must never combine rows from a new objective hierarchy with attachment details from an old model.
- If a refresh fails, retain the last ready model only if the existing UI convention supports stale read-only display; otherwise show the explicit error state and prevent misleading navigation. This choice should be made consistently in implementation tests.

## 8. Caching Strategy

No persistent or process cache. The LiveView holds one request/session-scoped model in assigns for reuse during the current screen lifecycle. Reload after successful mutations is the invalidation mechanism. Do not add Cachex or a GenServer for this feature.

## 9. Performance & Scalability Posture

- Initial and refresh loads use the single compact ObjectiveCoverage projection query.
- Expansion and bucket selection are pure in-memory lookups.
- Rendering must not call Ecto, Publishing, or content parsers.
- The projection must not select page/activity `content` and must not load full revision structs or preloads.
- Summary and detail derivation should be O(1) lookup plus the size of the visible detail groups; repeated activity occurrences remain page-local while summary ids are deduplicated by the core model.
- The LiveView should not reload coverage for a cosmetic event such as expansion or bucket selection.
- Review query count, model-build duration, and render responsiveness on representative small and large projects using existing ObjectiveCoverage telemetry and AppSignal.

## 10. Failure Modes & Resilience

- `:project_not_found`, `:working_publication_not_found`, and `:multiple_working_publications`: render an explicit load failure using existing authoring error handling; do not fabricate zero counts.
- Empty working publication: render the valid empty state with no toggles or detail links.
- Missing/malformed activity reference: omit the unresolved activity while retaining the valid page group.
- Deleted/out-of-scope resource: rely on ObjectiveCoverage filtering; never issue an ad hoc content fallback.
- Stale async task result: ignore using `load_ref`.
- Mutation during load: accept the mutation result, invalidate the model, and only apply the latest matching refresh.
- Missing activity-focus route: block the activity-navigation acceptance criterion until the page editor contract is defined; a page-only link is not equivalent behavior.
- Telemetry failure: ObjectiveCoverage's bounded telemetry helper must not make a successful read fail.

## 11. Observability

- Reuse ObjectiveCoverage aggregate telemetry for load/build duration, row counts, project/publication identifiers, and tagged status metadata.
- Add UI-level telemetry only if the existing LiveView convention supports it, limited to load success/failure and user-visible refresh duration; do not include titles, page bodies, activity bodies, or objective content.
- Log only bounded reason atoms or exception classes for coverage-load failures.
- Use AppSignal/LiveDashboard for latency and error investigation; no new alert is required unless production measurements show a regression.

## 12. Security & Privacy

- Keep the existing workspace authorization and author/project assignment checks.
- Pass the current project to ObjectiveCoverage; do not accept an arbitrary project id from the browser event payload.
- Validate objective ids and buckets against the loaded model before rendering or creating links.
- Generate navigation paths from server-owned project/resource metadata, not client-provided slugs.
- Do not expose page/activity revision content in assigns or telemetry.
- Preserve project and working-publication isolation supplied by ObjectiveCoverage.

## 13. Testing Strategy

### LiveView/component tests

- Render parent and Sub-Objective counts for direct and descendant attachments (`AC-001`, `AC-002`).
- Verify expansion is independent, no-content rows hide the toggle, and URL expansion state remains shareable (`AC-003`).
- Verify formative/summative changes use the correct page/activity groups and do not trigger a new coverage load (`AC-004`).
- Verify page-first ordering and page empty-state rendering (`AC-005`).
- Verify page and embedded activity hrefs, activity focus/anchor context, and no mutation events on link activation (`AC-006`, `AC-007`).
- Verify Figma-aligned icon classes/layout states and loading/empty/error rendering (`AC-008`).
- Verify keyboard operation, `aria-expanded`, `aria-controls`, selected bucket semantics, and visible focus styles (`AC-009`).
- Verify Activity Bank selections and standalone banked activities do not appear (`AC-010`).
- Verify the LiveView calls ObjectiveCoverage once per initial load/refresh and does not use legacy attachment queries (`AC-011`).

### Core-model contract tests

Continue using `test/oli/authoring/objective_coverage_test.exs` for the data-source invariants. Add or update only consumer-facing tests in the UI work item; do not duplicate projection fixtures unnecessarily.

### Verification commands

- `mix test` for the targeted workspace/objectives LiveView test module.
- `cd assets && yarn test` for any extracted React/component tests.
- `mix format --check-formatted` and frontend formatting/linting for changed files.
- `python3 /Users/raph/.local/share/harness/skills/requirements/scripts/requirements_trace.py docs/exec-plans/current/epics/objectives-editor/core_ui --action verify_fdd`.
- `python3 /Users/raph/.local/share/harness/skills/validate/scripts/validate_work_item.py docs/exec-plans/current/epics/objectives-editor/core_ui --check fdd`.

## 14. Backwards Compatibility

- Existing objective creation, editing, deletion, and Sub-Objective association workflows remain unchanged.
- The older `OliWeb.ObjectivesLive.Objectives` route remains unchanged unless explicitly added to scope.
- Existing URL expansion parameters remain supported, including the legacy `selected` parameter while it is normalized into `expanded`.
- Existing authoring page links remain valid; embedded activity navigation adds only the confirmed focus context.
- No database or publication format changes are introduced.
- Existing projects with no coverage rows render an empty state rather than failing because the new UI model is empty.

## 15. Risks & Mitigations

- `MER-5793` is a real prerequisite: confirm the dependency before implementation and move only required hierarchy behavior into this slice if necessary.
- Legacy attachment data and ObjectiveCoverage disagree: remove the legacy merge path and use model contract tests to establish one source of truth.
- Large model held in LiveView memory: use the already compact model, measure representative projects, and avoid duplicate row copies in assigns.
- Activity focus navigation is underspecified: inspect the PageEditorApp/page editor DOM and define one tested route/fragment contract before coding `AC-006`.
- UI tests overfit Figma classes: assert semantic state and behavior first; keep visual assertions focused on stable component/icon/layout contracts.
- Async refresh races with mutations: tag loads with a reference and discard stale results.

## 16. Open Questions & Follow-ups

- Confirm whether `MER-5793` must land first or whether its blocker link can be narrowed.
- Confirm the exact PageEditorApp/page-editor mechanism for focusing an embedded activity from a page link.
- Confirm default bucket selection on first expansion and the exact empty/loading/error copy from Figma/product.
- Decide whether stale coverage should remain visible with a warning when a refresh fails, or whether the UI should replace it with an error state.
- Follow-up work may add Activity Bank coverage, search, filters, CSV export, and other Objectives Editor lanes without changing the core UI model boundary.

## 17. References

- `docs/exec-plans/current/epics/objectives-editor/core_ui/informal.md`
- `docs/exec-plans/current/epics/objectives-editor/core_ui/prd.md`
- `docs/exec-plans/current/epics/objectives-editor/core_ui/requirements.yml`
- `docs/exec-plans/current/epics/objectives-editor/plan.md`
- `docs/exec-plans/current/epics/objectives-editor/core_data/informal.md`
- `lib/oli/authoring/objective_coverage.ex`
- `lib/oli_web/live/workspaces/course_author/objectives_live.ex`
- `lib/oli_web/live/workspaces/course_author/objectives/listing.ex`
- `test/oli/authoring/objective_coverage_test.exs`
- `docs/design-docs/high-level.md`
- `docs/design-docs/publication-model.md`
- [Jira MER-5794](https://eliterate.atlassian.net/browse/MER-5794)
- [Figma Learning Objectives Updates](https://www.figma.com/design/iVKgFJwC1iKP7jmJBGILOK/Learning-Objectives-Updates)
