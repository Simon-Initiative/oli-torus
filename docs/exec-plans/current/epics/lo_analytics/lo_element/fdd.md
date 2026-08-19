# Learning Objectives Page Element - Functional Design Document

## 1. Executive Summary
This design adds a new terminal basic-page content element, `learning_objectives`, that authors can place at the top level of a page to render either a Learning Objective Introduction or a Learning Objective Summary. The authored element stores display mode, Include Sub-Objectives, per-objective suppression, and advisory recommendation page IDs. It does not store objective metadata, proficiency, or the authoritative delivery Learning Objective set.

The authoring implementation follows the existing Activity Bank Selection pattern for terminal `ResourceContent` nodes. The delivery implementation keeps page rendering thin by scanning for the element first, precomputing included objectives once per render, and passing a render-ready payload through `Oli.Rendering.Context`. Objective discovery uses `SectionResourceDepot` for section schedule and objective metadata, with one narrow `revisions` query to read descendant page `activity_refs`.

This satisfies FR-001 through FR-010 while preserving existing page rendering for pages without the new element.

## 2. Requirements & Assumptions
### Requirement Mapping
The design covers:

- FR-001, FR-002, FR-003, FR-004, FR-005: authoring model, insertion, menu, editor, advisory state refresh, and persistence.
- FR-006, FR-007: delivery-time objective discovery and page-render precomputation.
- FR-008, FR-009: student Introduction and Summary rendering.
- FR-010: backwards compatibility for all existing content.

Acceptance criteria AC-001 through AC-030 are covered explicitly in the Testing Strategy.

### Assumptions
- The scope covers MER-5802, MER-5803, MER-5804, and MER-5807.
- The delivery objective set is defined as Learning Objectives attached to activities on descendant pages in the current container scope.
- Learning Objectives attached directly to pages are not included in the first implementation.
- Activity Bank Selection candidate activities do not contribute objectives in the first implementation.
- `practice_pages` and `revisit_pages` store page resource IDs unless product later introduces another practice-opportunity resource model.
- Summary proficiency is student-specific and uses the current delivery user when one is available.
- No new feature flag or migration is required because existing page content does not contain `learning_objectives`.

## 3. Repository Context Summary
The page content model lives in `assets/src/data/content/resource.ts`. `ResourceContent` currently includes terminal nodes such as `ActivityBankSelection` and container nodes such as groups, surveys, reports, alternatives, and alternatives' children. The same file owns `ResourceGroup`, `allElements`, `allowedContentItems`, `canInsert`, default factories, display names, and type guards.

The authoring insert menu for non-activity content is under `assets/src/components/content/add_resource_content/`, with the Activity Bank Selection entry using `createDefaultSelection()`. Editor dispatch and content-outline integration are under `assets/src/components/resource/editors/`, including `createEditor.tsx`, `ContentBlock.tsx`, `ContentOutline.tsx`, and the existing selection editor components.

Delivery basic-page rendering flows through `lib/oli_web/controllers/page_delivery_controller.ex`. `render_page_body/3` builds `Oli.Rendering.Context`, chooses `attempt_content`, and calls `Page.render(render_context, attempt_content, Page.Html)`. The renderer dispatch path uses `lib/oli/rendering/content.ex` and writer callbacks implemented in `lib/oli/rendering/content/html.ex`.

`lib/oli/delivery/sections/section_resource_depot.ex` caches section resources for containers, pages, and objectives. It exposes `retrieve_schedule/2`, `get_section_resource/2`, `get_resources_by_ids/2`, and `objectives_with_effective_children/2`. Section resources carry `children`, `revision_id`, `resource_id`, `resource_type_id`, `title`, `hidden`, and objective `related_activities`. Page revision rows carry `activity_refs`.

Existing contained-objective infrastructure in `lib/oli/delivery/sections.ex` is useful context but is not the primary runtime source for this feature because its current semantics include page-attached objectives, its public helper returns limited data, and the requirement is to use the depot where possible.

## 4. Proposed Design
### 4.1 Component Roles & Interactions
`assets/src/data/content/resource.ts` becomes the source of the new authored content shape:

```ts
export type LearningObjectivesContentMode = 'introduction' | 'summary';

export interface LearningObjectiveConfig {
  resource_id: number;
  enabled: boolean;
  revisit_pages: number[];
  practice_pages: number[];
}

export interface LearningObjectivesContent {
  type: 'learning_objectives';
  id: string;
  mode: LearningObjectivesContentMode;
  include_sub_objectives: boolean;
  learning_objectives: LearningObjectiveConfig[];
}
```

The type is added to `ResourceContent`, `isResourceContent`, `getResourceContentName`, `allElements`, and a new `createDefaultLearningObjectivesContent()` factory. It is not added to `ResourceGroup` and does not expose `children`.

Insertion policy is enforced by `canInsert(content, parents)`. `learning_objectives` is allowed only when `parents.length === 0`. It is not present in `allowedContentItems` for any container node, so nested add controls, drag/drop, duplication, and import paths all converge on the same rule.

Authoring UI adds a Learning Objectives entry in the Content Types section of the insert menu. The entry creates the default terminal node, uses the approved label and icon, and only appears or enables at top-level insertion positions.

The editor follows the Activity Bank Selection pattern:

- `createEditor.tsx` dispatches `learning_objectives` to a dedicated editor.
- `ContentBlock.tsx` accepts `LearningObjectivesContent` as a removable terminal content block.
- `LearningObjectivesEditor.tsx` owns mode selection, Include Sub-Objectives, objective remove/restore, and Summary recommendation controls.
- `ContentOutline.tsx` renders a dedicated outline item with compact mode state.

Authoring objective data resolution should be encapsulated behind a small read service rather than inferred from saved element state. The service returns objective resource ID, title, optional description if available, parent resource ID, child IDs, and display order for objectives in the page's current container and descendant containers. Every time the authoring page editor loads a basic page containing one or more `learning_objectives` elements, it calls this resolver, recursively finds the current objective set for the page's container scope, and reconciles each element's advisory state by `resource_id`.

That authoring-load reconciliation:

- preserves mode, Include Sub-Objectives, enabled state, and recommendations for objectives that are still found;
- adds newly found objectives with default advisory values;
- removes objective config rows for objectives no longer found in the current nested container scope;
- does not change objective metadata, objective hierarchy, activity objective tags, or recommendation page resources.

Delivery adds a focused domain module, `Oli.Delivery.LearningObjectives.PageElement`, for objective discovery and render payload preparation. `PageDeliveryController.render_page_body/3` calls it only when `attempt_content` contains a `learning_objectives` element.

Rendering adds:

- `:learning_objectives` field on `Oli.Rendering.Context`.
- `@callback learning_objectives(%Context{}, next, %{})` in `Oli.Rendering.Content`.
- A `%{"type" => "learning_objectives"}` dispatch in `Oli.Rendering.Content.render/3`.
- `learning_objectives/3` writer implementation in `Oli.Rendering.Content.Html`.
- `Oli.Rendering.Content.LearningObjectives` for HTML assembly and config merge logic.

### 4.2 State & Data Flow
Authoring flow:

1. The author inserts a top-level `learning_objectives` node.
2. The node starts with `mode: 'introduction'`, `include_sub_objectives: true`, and `learning_objectives: []`.
3. On each authoring page-editor load for a basic page containing a `learning_objectives` element, the editor resolves the effective objective hierarchy for the page's container and descendant containers from project/course data.
4. The editor reconciles each element's stored advisory state with the resolved objective set: matching objectives keep their existing config, newly found objectives are added with defaults, and objectives no longer found are removed from that element's config.
5. User changes update advisory fields for the current element only.
6. Normal page save or autosave writes the reconciled page revision content JSON. No objective tags are changed.

Delivery flow:

1. `render_page_body/3` obtains `attempt_content`.
2. The controller scans `attempt_content` with `PageContent.flat_filter/2` for `type == "learning_objectives"`.
3. If no element exists, the existing render path is unchanged.
4. If an element exists, delivery resolves the current container scope and calls the page-element helper.
5. The helper returns the included objective list and, only when a Summary element exists, student proficiency.
6. The payload is stored in `render_context.learning_objectives`.
7. Each rendered element merges its authored config with the precomputed objective payload.
8. Summary-mode recommendation page IDs are resolved in one depot batch lookup per element.

### 4.3 Lifecycle & Ownership
The authored element belongs to the page revision content. It is copied, duplicated, imported, published, and attempted through the existing resource/revision lifecycle.

The authoritative delivery Learning Objective set belongs to the section's published content and section-resource post-processing. Delivery rediscovery intentionally allows authored config to drift. If an objective is added elsewhere in the container after the element was configured, the next published section render includes it by default. If a stored config references an objective or recommendation page no longer in scope, the renderer ignores that stale reference.

The delivery helper owns objective discovery and payload shaping. The renderer owns per-element filtering, label mapping, and HTML. The page delivery controller owns only orchestration.

### 4.4 Alternatives Considered
Use `contained_objectives` as the primary source: rejected for the first implementation because it includes page-attached objectives, its current public helper returns only titles, and the user request explicitly called for depot-first discovery with minimal direct DB work.

Scan page JSON content during delivery to find activity references: rejected because page revisions already maintain `activity_refs`, which gives the helper a narrow, indexed read target and avoids JSONB traversal during render.

Query activity revisions directly: rejected because `SectionResourceDepot` does not cache activity section resources and the objective depot records already expose `related_activities`.

Render the element through a separate React delivery component: rejected for the first implementation because the existing server-side rendering extension points are enough and keep delivery behavior close to normal page content.

Include Activity Bank Selection candidate objectives immediately: deferred because bank candidates are realized dynamically and would require a separate ActivityProvider/Realizer path.

## 5. Interfaces
### TypeScript Content Model
`assets/src/data/content/resource.ts` adds:

- `LearningObjectivesContentMode`
- `LearningObjectiveConfig`
- `LearningObjectivesContent`
- `createDefaultLearningObjectivesContent()`

Default output:

```ts
{
  type: 'learning_objectives',
  id: guid(),
  mode: 'introduction',
  include_sub_objectives: true,
  learning_objectives: []
}
```

### Authoring Objective Resolution
Add a small authoring read boundary for the editor, either as an existing page-editor data payload extension or a focused JSON endpoint under the current project/page authorization path.

Recommended response shape:

```ts
interface ResolvedLearningObjective {
  resource_id: number;
  title: string;
  description?: string;
  parent_resource_id?: number;
  children: number[];
  related_activity_ids: number[];
  directly_matched: boolean;
}
```

The editor should not persist this full response. It persists the reconciled advisory config rows for the current objective set, while objective titles, hierarchy, related activity IDs, and delivery proficiency remain resolved data rather than stored element data.

### Delivery Discovery API
Add `lib/oli/delivery/learning_objectives/page_element.ex`:

```elixir
@spec included_objectives(Oli.Delivery.Sections.Section.t(), integer() | nil) ::
        {:ok, [included_objective()]} | {:error, term()}

@spec prepare_render_payload(
        Oli.Delivery.Sections.Section.t(),
        integer(),
        map(),
        Oli.Accounts.User.t() | nil
      ) :: map() | nil
```

`prepare_render_payload/4` accepts section, current page resource ID, attempt content, and current user. It returns `nil` when no Learning Objectives element exists. Otherwise it returns:

```elixir
%{
  container_resource_id: integer() | nil,
  objectives: [included_objective()],
  objectives_by_id: %{integer() => included_objective()},
  performance_by_objective_id: %{integer() => String.t()}
}
```

`included_objective()` is a map or struct with:

```elixir
%{
  resource_id: integer(),
  title: String.t(),
  parent_resource_id: integer() | nil,
  children: [integer()],
  related_activity_ids: [integer()],
  directly_matched?: boolean()
}
```

### Rendering API
`Oli.Rendering.Context` adds:

```elixir
learning_objectives: nil
```

`Oli.Rendering.Content.LearningObjectives.render(context, element)` returns iodata and handles:

- defaulting malformed or older element fields,
- advisory config merge,
- Introduction/Summary branching,
- proficiency label normalization,
- recommendation page batch resolution.

## 6. Data Model & Storage
No relational schema change is required.

The persisted page JSON schema gains a new terminal element shape:

- `type`: `"learning_objectives"`
- `id`: string
- `mode`: `"introduction"` or `"summary"`
- `include_sub_objectives`: boolean, default true for new content and missing legacy values
- `learning_objectives`: array of advisory config objects reconciled during authoring page-editor load

Each config object contains:

- `resource_id`: objective resource ID
- `enabled`: boolean
- `revisit_pages`: page resource ID array
- `practice_pages`: page resource ID array

Schema validation under `priv/schemas/v0-1-0/` should add this element to valid page content while keeping it out of container child schemas where top-level-only content is represented. If the JSON schema cannot encode the full top-level-only rule cleanly, TypeScript `canInsert` and backend normalization still enforce it.

## 7. Consistency & Transactions
Authoring changes use the existing page editor save transaction. The element does not create or delete Learning Objectives and does not modify activity objective tags.

Authoring reconciliation runs during basic-page editor load when a page contains a `learning_objectives` element. It is a page-content normalization step: objective config rows are aligned to the current recursively resolved container objective set, but objective tags and recommendation target pages are not modified. Persistence still occurs through the normal page save or autosave path.

Delivery is read-only. It uses the current section-resource depot state plus current page revisions from the published section. Because authored config is advisory, consistency rules are tolerant:

- unknown objective config rows are ignored;
- unknown recommendation page IDs are ignored;
- newly discovered objectives render enabled with no recommendations when they appear in delivery before an author has reloaded and saved the page editor;
- missing proficiency renders as Not Enough Information.

No cross-table transaction is required for render-time discovery.

## 8. Caching Strategy
Use `SectionResourceDepot` as the primary cache for containers, pages, objectives, and recommendation page titles/slugs.

No new persistent cache is required initially. The render payload is request-local on `Oli.Rendering.Context`. If a page contains multiple Summary elements, the renderer can keep a small in-memory map inside the payload for recommendation-resolution results keyed by sorted page IDs, but the first implementation can perform one depot batch lookup per Summary element.

Existing depot invalidation through section-resource update paths remains the cache invalidation mechanism.

## 9. Performance & Scalability Posture
Pages without `learning_objectives` pay only a cheap content scan and otherwise follow the current render path.

Pages with the element perform bounded work:

- one `SectionResourceDepot.retrieve_schedule/1` read for page/container hierarchy,
- one in-memory traversal from the selected container,
- one `revisions` query selecting only `resource_id` and `activity_refs` for descendant pages,
- one `SectionResourceDepot.objectives_with_effective_children/1` read,
- one proficiency query only if a Summary element exists,
- one `SectionResourceDepot.get_resources_by_ids/2` batch read per Summary element with recommendations.

The implementation should avoid per-page, per-objective, and per-recommendation DB queries. Hidden pages are skipped during traversal so their activity refs do not expand the objective set.

## 10. Failure Modes & Resilience
Malformed element content defaults to Introduction mode, Include Sub-Objectives enabled, and an empty advisory config.

If the current page's container cannot be resolved, the helper falls back to course-root scope using the section root resource where possible. If the depot cannot produce a valid schedule, the helper returns an empty objective payload and rendering emits no empty cards.

Stale objective config and stale recommendation page IDs are ignored. Missing student proficiency is normalized to Not Enough Information. Unsupported future objective hierarchy shapes are ordered deterministically by parent-child data when present, with title/resource ID fallback ordering.

Delivery should not raise because an authored element references data outside the current section.

## 11. Observability
Add bounded telemetry or debug logging only around the delivery helper if implementation needs visibility:

- operation name,
- section ID,
- page resource ID,
- objective count,
- descendant page count,
- activity ref count,
- duration,
- success or fallback reason.

Do not log student names, emails, raw responses, authored page content, objective text, or recommendation titles.

## 12. Security & Privacy
Authoring data resolution must use existing project/page authorization. Recommendation selectors must only offer project resources and must reject arbitrary out-of-course resource IDs on save or normalize them away before persistence.

Delivery reads must remain section-scoped through `SectionResourceDepot` and the current section ID. Summary mode may read the current user's proficiency, but it must not expose another student's proficiency in learner delivery. Instructor/review modes should use the existing render context user semantics and avoid widening data access.

Telemetry and logs must not include PII, raw student responses, or authored page content.

## 13. Testing Strategy
TypeScript model tests:

- Validate `ResourceContent`, default factory, display name, and helper recognition for AC-001.
- Validate `learning_objectives` is absent from `ResourceGroup`, has no `children`, and cannot act as a container for AC-002.
- Validate `canInsert` accepts root insertion and rejects nested insertion for AC-003.
- Validate drag/drop/import/duplication insertion paths consult the same rule for AC-004.
- Validate advisory persistence shape and authoring-load reconciliation for AC-016, including adding newly found objectives and removing no-longer-found objectives from the element config.

Authoring UI tests:

- Insert menu placement, label, icon, description, hover/focus/selected behavior for AC-005.
- Insert action appends a top-level element without mutating sibling content for AC-006.
- Editor defaults for Introduction and Include Sub-Objectives for AC-007.
- Keyboard-accessible mode switching without losing shared config for AC-008.
- Objective resolution and parent-before-child display for AC-009.
- Element-local Include Sub-Objectives behavior for AC-010.
- Remove/restore advisory-only behavior for AC-011.
- Parent/subobjective hide semantics for AC-012.
- Review page recommendation add/remove and course scoping for AC-013.
- Practice recommendation add/remove and course scoping for AC-014.
- Recommendation changes do not tag pages or activities to objectives for AC-015.

Delivery helper tests:

- Pre-scan skips all new delivery work when no element exists for AC-017.
- Discovery uses depot reads and at most one narrow page-revision query for AC-018.
- Descendant-page activity-attached objectives are included and out-of-container objectives are excluded for AC-019.
- Parent objective inclusion when only a Sub-Objective directly matches for AC-020.
- Hidden descendant pages do not contribute objectives for AC-021.
- Stale advisory config is ignored for AC-022.
- Delivery-discovered objectives absent from config render enabled with no recommendations for AC-023.
- Summary recommendation IDs resolve through one depot batch lookup and out-of-section IDs are ignored for AC-028.

Render tests:

- Introduction mode renders heading, hierarchy, optional Sub-Objectives, and proficiency explanation accordion without estimates or recommendations for AC-024.
- No discovered objectives renders no empty cards and no Introduction component for AC-025.
- Summary mode queries proficiency only when a Summary element is present and defaults missing values for AC-026.
- Proficiency labels map from metrics internals to approved icon/label states for AC-027.
- Long objective and Sub-Objective titles wrap without truncation across supported viewports for AC-029.
- Existing content types, questions, pages, attempts, and delivery output are unchanged without the element for AC-030.

Scenario coverage should exercise authoring an element, publishing, adding a later objective elsewhere in the container, publishing again, and verifying delivery renders the newly discovered objective with default enabled/no-recommendation state.

## 14. Backwards Compatibility
The change is additive. Existing pages do not contain `learning_objectives` and should render exactly as they do now. Existing content unions, group types, page attempts, activity references, selection rendering, and delivery text-cache rendering remain valid.

Older or malformed `learning_objectives` JSON should be normalized defensively at render time. The corrected TypeScript name is `LearningObjectivesContentMode`; no runtime compatibility is needed for the earlier misspelled type name because TypeScript type aliases do not affect saved JSON.

## 15. Risks & Mitigations
Risk: authoring UI shows stale objective membership after course edits. Mitigation: fetch objective membership from project/course data every time the page editor loads a basic page containing the element, then reconcile each element by adding newly found objectives and removing no-longer-found objectives before normal save/autosave persistence.

Risk: delivery performance regresses in large sections. Mitigation: skip work when absent, use depot schedule/objective data, query only page `activity_refs`, and batch recommendation lookups.

Risk: top-level-only restrictions are enforced only in the visible menu. Mitigation: enforce the rule in `canInsert` and keep the type out of `ResourceGroup`.

Risk: Summary labels diverge from analytics internals. Mitigation: centralize mapping from `"Not enough data"`, `"Low"`, `"Medium"`, and `"High"` to approved student-facing labels.

Risk: product later expects page-attached objectives or banked candidates. Mitigation: document both as follow-up expansions with clear discovery branches.

## 16. Open Questions & Follow-ups
- Should authoring Summary preview show sample proficiency states or stay as a configuration preview?
- Which final icon should be used for the Insert menu item?
- Should page-attached objectives be included in a future phase?
- Should Activity Bank Selection candidates contribute objectives in a future phase?
- Can `practice_pages` remain page resource IDs, or will practice recommendations need a distinct resource/reference model?

## 17. References
- `docs/exec-plans/current/epics/lo_analytics/lo_element/prd.md`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/requirements.yml`
- `docs/exec-plans/current/epics/lo_analytics/lo_element/informal.md`
- `assets/src/data/content/resource.ts`
- `assets/src/components/content/add_resource_content/NonActivities.tsx`
- `assets/src/components/resource/editors/createEditor.tsx`
- `assets/src/components/resource/editors/ContentBlock.tsx`
- `assets/src/components/resource/editors/ContentOutline.tsx`
- `lib/oli_web/controllers/page_delivery_controller.ex`
- `lib/oli/rendering/context.ex`
- `lib/oli/rendering/content.ex`
- `lib/oli/rendering/content/html.ex`
- `lib/oli/delivery/sections/section_resource_depot.ex`
- `lib/oli/delivery/metrics.ex`
