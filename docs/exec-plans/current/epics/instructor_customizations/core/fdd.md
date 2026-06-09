# Instructor Activity Customization Core - Functional Design Document

## 1. Executive Summary
This design introduces delivery-owned instructor customization state for basic-page activities without changing authored revisions, publications, or section resources. A new `Oli.Delivery.InstructorCustomizations` context owns persistence, validation, authorization, read models, and toggle semantics for embedded activities, whole activity bank selections, and selection-local activity bank candidates.

New attempt creation loads a compact page exclusion view once for the current section and page, passes it into activity realization, and lets `Oli.Delivery.ActivityProvider` skip excluded embedded activities, skip excluded selections, and apply selection-local candidate exclusions during selection fulfillment. Existing attempts remain unchanged because their transformed content and activity attempts are already persisted. This satisfies the core implementation requirements for `FR-001` through `FR-009` and acceptance criteria `AC-001` through `AC-022`.

## 2. Requirements & Assumptions
- Functional requirements:
  - Persist one row per active exclusion outside authored content, publications, and section resources (`FR-001`, `AC-001`, `AC-002`, `AC-003`).
  - Expose a centralized delivery context for write APIs, read APIs, validation helpers, and pure read-model predicates (`FR-002`, `FR-007`, `AC-004`, `AC-005`, `AC-006`, `AC-016`, `AC-017`, `AC-018`).
  - Support embedded activity, whole bank selection, and bank candidate customization on basic pages (`FR-003`, `FR-004`, `FR-005`, `AC-007`, `AC-008`, `AC-009`, `AC-010`, `AC-011`, `AC-012`).
  - Apply customization only during new attempt creation and preserve active or historical attempts (`FR-006`, `AC-013`, `AC-014`, `AC-015`).
  - Tolerate stale rows from republishing or content edits and cover the behavior through scenario tests (`FR-008`, `FR-009`, `AC-019`, `AC-020`, `AC-021`, `AC-022`).
- Non-functional requirements:
  - Delivery-time page customization lookup must be one query per section and page before activity realization (`AC-013`).
  - Writes must enforce instructor or admin-equivalent authorization and target validation in the context (`AC-004`).
  - The schema must support idempotent toggles and future reporting by activity resource id (`AC-003`).
- Assumptions:
  - `MER-5639` covers the core backend and scenario-testable infrastructure; complete Instructor Preview UI behavior belongs to later tickets.
  - Embedded activity exclusions are keyed by activity resource id, not activity-reference element id.
  - Selection ids are authored element ids stored in page content and are stable enough to scope selection and candidate exclusions.
  - Adaptive pages remain out of scope and return `{:error, {:invalid_page_type, :adaptive}}` from write validation.
  - Instructor Preview has both LiveView and legacy controller-backed paths; this design keeps preview integration behind the context API.

## 3. Repository Context Summary
- What we know:
  - Torus delivery uses published resources and revisions; sections reference publications, so customization must live outside authored resources and publication snapshots.
  - New attempt creation flows through `Oli.Delivery.Attempts.PageLifecycle.Hierarchy.create/1`, which audience-filters page content, calls `context.activity_provider`, persists transformed content, and bulk-creates activity attempts.
  - `Oli.Delivery.ActivityProvider.provide/6` already owns basic-page `activity-reference` and `selection` realization, including transformed content and attempt prototype generation.
  - `Oli.Activities.Realizer.Query.Source` carries selection fulfillment state such as publication id, section slug, global blacklisted activity ids, and the populated bank.
  - `Oli.Activities.Realizer.Selection.fulfill/2` already honors `Source.blacklisted_activity_ids`.
  - `OliWeb.ActivityBankController.preview/2` currently parses a selection and queries candidate bank activities for preview; it should become a thin caller of the new context for candidate state when this ticket touches that surface.
  - Oli.Scenarios supports YAML-driven integration tests and can be extended with new directives when core workflow coverage needs new operations.
- Unknowns to confirm:
  - The exact existing authorization helper for "instructor or admin can customize this section" should be selected during implementation.
  - Future UI integration should confirm the active Instructor Preview owner before wiring read or toggle calls.
  - The exact migration naming convention should follow the repository's migration sequence at implementation time.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`Oli.Delivery.InstructorCustomizations` is the only application boundary for this feature. It owns the Ecto schema, changesets, toggle functions, validation helpers, candidate-count guardrail, page and selection read models, and pure predicate helpers. Controllers, LiveViews, delivery lifecycle modules, and scenario handlers must not duplicate target lookup or selection-count logic (`AC-004`, `AC-005`, `AC-006`, `AC-012`, `AC-018`, `AC-021`).

`Oli.Delivery.Attempts.PageLifecycle.Hierarchy.create/1` loads `%PageExclusions{}` once after audience filtering context is available and before invoking `context.activity_provider`. It passes the read model through `%Oli.Activities.Realizer.Query.Source{}` so the provider can realize content without querying the customization table directly (`AC-013`).

`Oli.Delivery.ActivityProvider` remains the realization boundary. For basic pages, it skips excluded embedded `activity-reference` elements, skips excluded `selection` elements, and uses selection-local candidate exclusions only while fulfilling the matching selection. Advanced delivery pages are not customized by this slice (`AC-007`, `AC-009`, `AC-011`).

`OliWeb.ActivityBankController.preview/2` or the active Instructor Preview LiveView should call `list_bank_selection_candidates/4` for candidate review state instead of independently querying and annotating exclusions. Toggle endpoints or events are thin transport adapters over context functions and are only implemented in this slice when needed to expose the core behavior to an existing preview surface.

Oli.Scenarios directive handlers call semantic wrappers such as `exclude_activity/4` and `restore_bank_candidate/5` with an actor authorized for the target section, using the same authorization, target validation, and count guardrail as normal writes (`AC-021`, `AC-022`).

### 4.2 State & Data Flow
For writes:
1. Caller invokes a context API with section, page resource id, target identifier, enabled flag, and actor.
2. Context normalizes the section, checks authorization, resolves the current page revision for the section publication, rejects unsupported page types, validates the target, and for candidate disables checks active candidates after the proposed exclusion.
3. `enabled == false` inserts the matching exclusion row with conflict-safe idempotency; `enabled == true` deletes the matching row.
4. Context returns `{:ok, %PageExclusions{}}` for the page or `{:error, reason}`.

For new attempts:
1. `Hierarchy.create/1` receives the visit context and current page revision.
2. Audience filtering runs as it does today.
3. `get_page_exclusion_view(section, page_resource_id)` loads all rows for `section_id + page_resource_id` once and builds MapSet-backed lookup fields.
4. `Source` carries that view or equivalent fields into `ActivityProvider.provide/6`.
5. Provider skips excluded references and selections before prototypes are created.
6. Provider fulfills non-excluded selections using a temporary source with candidate exclusions merged into `blacklisted_activity_ids` only for the current selection.
7. Transformed content omits excluded embedded references and replaces excluded selections with no realized activity references.
8. `Hierarchy.create/1` persists resource attempt content and bulk-creates activity attempts from the filtered prototypes.

For reads:
1. Page-level UI and delivery use `get_page_exclusion_view/2`.
2. Candidate review uses `list_bank_selection_candidates/4`, which resolves the current selection logic, queries matching bank activities, overlays exclusion state, and returns action availability (`AC-016`, `AC-017`).

### 4.3 Lifecycle & Ownership
Exclusion rows are mutable delivery configuration owned by instructors for a section. They are not part of authoring, publication, or section resource lifecycle (`AC-002`). Rows survive page republishing when the same page resource receives a new revision. Rows that no longer match current page content are stale but harmless; reads ignore them when the referenced activity or selection is not present (`AC-019`, `AC-020`).

Existing active and historical attempts are immutable for this feature. The system does not rewrite stored transformed content or activity attempts after an instructor changes customization rows (`AC-014`). Practice and graded pages both apply current rows when a new attempt is created (`AC-015`).

### 4.4 Alternatives Considered
- Row-per-exclusion table: selected. It supports simple insert/delete toggles, database uniqueness, future reporting by excluded resource id, stale-row tolerance, and uniform modeling of embedded activities, selections, and candidates (`AC-001`, `AC-003`).
- Denormalized list of excluded ids per page or selection: rejected. It optimizes row count but makes concurrent toggles, uniqueness, stale-row handling, and reporting harder.
- Add a seventh argument to `ActivityProvider.provide/6`: rejected for initial design. Extending `Source` keeps realization inputs grouped with existing bank and blacklist state and reduces signature churn across tests.
- Apply candidate exclusions by permanently merging them into page-wide `blacklisted_activity_ids`: rejected. That would incorrectly affect other selections on the same page and violate `AC-011`.
- Rebuild active attempts when rows change: rejected. It would affect fairness, grading, review consistency, and stored attempt content, contrary to `AC-014`.

## 5. Interfaces
- Context module:
  - `Oli.Delivery.InstructorCustomizations`
- Schema module:
  - `Oli.Delivery.InstructorCustomizations.ActivityExclusion`
- Read model:
  - `Oli.Delivery.InstructorCustomizations.PageExclusions`

Write APIs:

```elixir
set_activity_enabled(section_or_id, page_resource_id, activity_resource_id, enabled, opts \\ [])
exclude_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ [])
restore_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ [])

set_bank_selection_enabled(section_or_id, page_resource_id, selection_id, enabled, opts \\ [])
exclude_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ [])
restore_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ [])

set_bank_candidate_enabled(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id, enabled, opts \\ [])
exclude_bank_candidate(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id, opts \\ [])
restore_bank_candidate(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id, opts \\ [])
```

Read APIs:

```elixir
get_page_exclusions(section_or_id, page_resource_id)
get_page_exclusion_view(section_or_id, page_resource_id)
get_selection_exclusion_view(section_or_id, page_resource_id, selection_id)
list_bank_selection_candidates(section_or_id, page_resource_id, selection_id, opts \\ [])
```

Predicate helpers:

```elixir
activity_enabled?(%PageExclusions{}, activity_resource_id)
bank_selection_enabled?(%PageExclusions{}, selection_id)
bank_candidate_enabled?(%PageExclusions{}, selection_id, candidate_activity_resource_id)
```

Validation helpers:

```elixir
validate_activity_customization_target(section_or_id, page_resource_id, activity_resource_id)
validate_bank_selection_customization_target(section_or_id, page_resource_id, selection_id)
validate_bank_candidate_customization_target(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id)
```

Expected write returns:

```elixir
{:ok, %Oli.Delivery.InstructorCustomizations.PageExclusions{}}
{:error, {:unauthorized, :customize_section}}
{:error, {:not_found, :section}}
{:error, {:not_found, :page}}
{:error, {:not_found, :activity}}
{:error, {:not_found, :selection}}
{:error, {:invalid_page_type, :adaptive}}
{:error, {:invalid_selection_candidate, candidate_activity_resource_id}}
{:error, {:insufficient_selection_candidates, %{selection_id: selection_id, count: count, active_candidates: active_count}}}
{:error, {:validation_failed, changeset}}
```

`Source` extension:

```elixir
%Oli.Activities.Realizer.Query.Source{
  publication_id: integer(),
  section_slug: String.t(),
  blacklisted_activity_ids: [integer()],
  activity_resource_ids: [integer()] | nil,
  bank: list() | nil,
  page_exclusions: %Oli.Delivery.InstructorCustomizations.PageExclusions{} | nil
}
```

The exact field may be either `page_exclusions` or the three denormalized exclusion fields. Prefer a single `page_exclusions` field so provider logic can use the pure predicates and future read-model additions do not churn `Source`.

## 6. Data Model & Storage
Create `section_page_activity_exclusions`:

- `id`: primary key.
- `section_id`: required foreign key to delivery sections.
- `page_resource_id`: required page resource id.
- `selection_id`: nullable string authored selection element id.
- `kind`: required enum/string with `embedded_activity`, `bank_selection`, `bank_candidate`.
- `excluded_resource_id`: nullable activity resource id.
- `inserted_at` and `updated_at`.

Use `Ecto.Enum` if local conventions support it cleanly; otherwise use a string field with changeset inclusion validation. The schema should expose Elixir atoms in context code and keep database values stable.

Constraints and indexes:

- Unique embedded activity exclusion: `section_id, page_resource_id, kind, excluded_resource_id` where `kind = 'embedded_activity'` (`AC-003`).
- Unique whole selection exclusion: `section_id, page_resource_id, kind, selection_id` where `kind = 'bank_selection'` (`AC-003`).
- Unique bank candidate exclusion: `section_id, page_resource_id, kind, selection_id, excluded_resource_id` where `kind = 'bank_candidate'` (`AC-003`).
- Index `section_id, page_resource_id` for delivery read (`AC-013`).
- Index `section_id, page_resource_id, selection_id` for selection review.

Indexes for kind-specific page summaries or future reporting by excluded resource id should be added with the queries that require them rather than increasing write cost speculatively.

Changeset validations:

- `section_id`, `page_resource_id`, and `kind` required for every row.
- `excluded_resource_id` required for `embedded_activity` and `bank_candidate`.
- `selection_id` required for `bank_selection` and `bank_candidate`.
- `selection_id` absent for `embedded_activity`.
- `excluded_resource_id` absent for `bank_selection`.

No `excluded` boolean or audit fields are included in this slice. Restore is deletion of the matching active row.

## 7. Consistency & Transactions
Each write should run in a transaction when it needs read-then-write validation. Candidate disable requires transactionally reading current matching candidates, reading existing candidate exclusions, checking enabled count after the proposed change, and inserting the exclusion. This prevents a pair of concurrent disables from both passing the count guardrail (`AC-012`).

For idempotency, use conflict-safe inserts or gracefully handle unique constraint conflicts as success for disable operations. Restore operations should delete zero or one row and still return `{:ok, %PageExclusions{}}` when the row was already absent (`AC-005`).

Delivery read consistency is best-effort at attempt creation time. The attempt uses the page exclusion view loaded before provider realization; later writes affect later attempts, not the attempt currently being created.

## 8. Caching Strategy
No persistent cache is required. The only caching-like behavior is per-attempt in-memory use of `%PageExclusions{}` after a single page-level query. Do not use Cachex or process-level storage for this slice because rows are mutable instructor configuration and the read path is already scoped to one section and page.

## 9. Performance & Scalability Posture
The hot delivery path must make one customization query for `section_id + page_resource_id`, then use MapSet membership checks during traversal (`AC-013`, `AC-016`, `AC-018`). Filtering embedded activities and selections should be linear in page model size, matching existing provider traversal.

Candidate listing may query matching bank activities for a single selection. It is not on the student attempt hot path, but it should reuse existing bank query patterns and pagination where current preview surfaces paginate results.

The new table can grow with instructor toggles, but row counts are bounded by section customizations rather than learner attempts. Indexes support delivery reads and later reporting queries.

## 10. Failure Modes & Resilience
- Missing section: return `{:error, {:not_found, :section}}`.
- Page not in current section publication: return `{:error, {:not_found, :page}}`.
- Adaptive page target: return `{:error, {:invalid_page_type, :adaptive}}`.
- Missing embedded activity target: return `{:error, {:not_found, :activity}}`.
- Missing selection target: return `{:error, {:not_found, :selection}}`.
- Candidate no longer matches selection logic: write may return `{:error, {:invalid_selection_candidate, id}}` for active UI operations, while existing stale rows are ignored during reads and delivery (`AC-019`).
- Candidate disable would drop active candidates below count: return the explicit insufficient-candidates error and do not write (`AC-012`).
- Exclusion references content removed by republishing: ignore during page view construction and delivery (`AC-019`, `AC-020`).
- Selection fulfillment remains partial after valid candidate filtering due to unrelated bank/content state: preserve existing provider error behavior for partial fulfillment.

## 11. Observability
Add lightweight telemetry for successful and failed customization writes if this fits existing Torus telemetry conventions:

- `[:oli, :delivery, :instructor_customizations, :write]`
- metadata: section id, page resource id, kind, selection-present flag, action enable or disable, result success or error reason class

Do not emit activity titles, content, student data, or full changesets. Existing provider errors should continue to be stored on resource attempts as they are today. If new telemetry is deferred, implementation should at minimum keep explicit error returns and targeted test coverage; this remains an open implementation choice from the PRD.

## 12. Security & Privacy
All write APIs require an authorized `opts[:actor]`, including scenario/test callers. The context selects the canonical instructor/admin authorization helper during implementation and returns `{:error, {:unauthorized, :customize_section}}` on failure (`AC-004`).

Read APIs used by UI should also be called only from already-authorized preview contexts. Context-level raw read functions may remain internal or documented as requiring caller authorization if exposing read authorization would add unnecessary overhead for delivery lifecycle.

The table stores only section id, page resource id, selection id, activity resource id, kind, and timestamps. It stores no learner response data, no activity content, and no authored content snapshots.

## 13. Testing Strategy
- Schema and context ExUnit tests:
  - changeset required fields and kind-specific validations (`AC-001`).
  - uniqueness/idempotent disable and restore behavior (`AC-003`, `AC-005`).
  - authorization and target validation errors (`AC-004`).
  - page and selection read model construction (`AC-006`, `AC-016`, `AC-018`).
  - candidate count guardrail including concurrent or repeated disables where practical (`AC-012`).
- Activity provider tests:
  - excluded embedded activity produces no prototype and is removed from transformed content (`AC-007`).
  - embedded exclusion is section/page scoped (`AC-008`).
  - excluded selection is skipped and transformed to no realized activity references (`AC-009`, `AC-010`).
  - bank candidate exclusion applies only to the matching selection and does not pollute global blacklist (`AC-011`).
  - practice and graded page attempts apply filtering on newly created attempts (`AC-015`).
- Attempt lifecycle tests:
  - `Hierarchy.create/1` loads page exclusions once and passes them to provider (`AC-013`).
  - existing active/historical attempts remain unchanged after rows change (`AC-014`).
  - republish with same page resource preserves prior exclusions and renders new non-excluded activity (`AC-020`).
- Activity bank candidate listing tests:
  - candidates are annotated with enabled state and disable availability (`AC-017`).
  - stale candidate rows do not break listing (`AC-019`).
- Oli.Scenarios:
  - add directives for exclude/restore embedded activity, bank selection, and bank candidate (`AC-021`).
  - add assertions using page exclusion predicates.
  - scenario with two pages sharing a bank candidate proves page isolation (`AC-022`).
  - scenario with republished page proves stale/new-content behavior (`AC-020`).

## 14. Backwards Compatibility
The migration is additive and starts with no rows, so existing delivery behavior is unchanged until instructors create exclusions. The provider must behave exactly as today when `Source.page_exclusions` is nil or empty. Existing attempts are not modified (`AC-014`).

The design avoids `SectionResource` dependencies and does not change publication records (`AC-002`). Preview transport ownership can change independently from the context, provider, lifecycle, and scenario contracts.

## 15. Risks & Mitigations
- Risk: A candidate exclusion leaks across selections through global blacklist mutation. Mitigation: derive a temporary source only for the active selection, then merge only realized rows into the normal global blacklist (`AC-011`).
- Risk: Embedded exclusions do not transform pages without selections because current provider only transforms when selections exist. Mitigation: replace the `has_selection` optimization with a generalized "content changed by exclusions or selections" transform pass (`AC-007`, `AC-009`).
- Risk: Concurrent candidate disables violate the count guardrail. Mitigation: use a transaction and, if needed, lock matching exclusion rows or recheck after insert before commit (`AC-012`).
- Risk: UI or scenario code duplicates validation. Mitigation: scenario handlers and transport adapters call context wrappers exclusively (`AC-004`, `AC-021`).
- Risk: Stale rows confuse future maintainers. Mitigation: document stale tolerance and defer cleanup until an operational need exists (`AC-019`).
- Risk: Instructor Preview ownership changes integration points. Mitigation: keep preview calls transport-independent and wire through the active preview owner.

## 16. Open Questions & Follow-ups
- Confirm the canonical authorization helper for instructor/admin customization writes.
- Decide during implementation whether to add a dedicated telemetry event family or rely on explicit return values and existing instrumentation.
- Decide whether candidate writes should reject candidates that no longer match selection logic or allow inserting stale rows for robustness. The recommended initial behavior is to reject active UI writes for non-matching candidates while tolerating existing stale rows.
- For future UI work, identify the active Instructor Preview owner and wire read/toggle calls there if that slice includes preview transport integration.
- Future cleanup of stale rows is intentionally out of scope unless operational evidence shows the table needs pruning.

## 17. References
- `docs/exec-plans/current/epics/instructor_customizations/core/informal.md`
- `docs/exec-plans/current/epics/instructor_customizations/core/prd.md`
- `docs/exec-plans/current/epics/instructor_customizations/core/requirements.yml`
- `docs/exec-plans/current/epics/instructor_customizations/overview.md`
- `docs/exec-plans/current/epics/instructor_customizations/plan.md`
- `ARCHITECTURE.md`
- `harness.yml`
- `docs/BACKEND.md`
- `docs/FRONTEND.md`
- `docs/TESTING.md`
- `docs/OPERATIONS.md`
- `docs/design-docs/publication-model.md`
- `docs/design-docs/page-model.md`
- `lib/oli/delivery/attempts/page_lifecycle/hierarchy.ex`
- `lib/oli/delivery/activity_provider.ex`
- `lib/oli/activities/realizer/query/source.ex`
- `lib/oli/activities/realizer/selection.ex`
- `lib/oli_web/controllers/activity_bank_controller.ex`
- `test/support/scenarios/README.md`
