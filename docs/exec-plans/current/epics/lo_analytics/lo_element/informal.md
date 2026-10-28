# Learning Objectives Page Element Authoring And Delivery

## Ticket Context

Jira scope:

- MER-5802: add a Learning Objectives content element to the authoring Insert menu.
- MER-5803: authoring configuration for the Learning Objective Introduction view.
- MER-5804: authoring configuration for the Learning Objective Summary view.
- MER-5807: student rendering for the Learning Objective Introduction view.

This note captures the authoring and delivery technical direction for the page element. The
delivery-side Summary rendering can remain thin by reusing existing SectionResourceDepot and
Learning Objectives analytics infrastructure instead of introducing a new persistence model.

The feature adds a new basic-page content element that an author can place directly into a page to
render either:

- a Learning Objective Introduction, or
- a Learning Objective Summary.

The element is configured during authoring, but it is not the source of truth for which Learning
Objectives exist in the course. At delivery time, the page renderer must rediscover the Learning
Objectives associated with the current container and its descendants, then use the authored element
configuration only to decorate or suppress matching Learning Objectives where applicable.

## Page Model Direction

The right model boundary is the existing basic-page `ResourceContent` union in
`assets/src/data/content/resource.ts`.

Add a new terminal `ResourceContent` member:

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
  learning_objectives: LearningObjectiveConfig[];
}
```

The intent is similar to `ActivityBankSelection`:

- both are terminal page-model nodes,
- both carry additional author-managed state,
- both need a corresponding editor UX,
- both require special render-time handling outside ordinary rich-content rendering.

Unlike `StructuredContent`, the Learning Objectives element does not contain Slate or markdown
children. Unlike `PurposeGroupContent`, `SurveyContent`, `ReportContent`, `AlternativesContent`, or
`AlternativeContent`, it is not a container and must not be included in `ResourceGroup`.

The implementation should wire `LearningObjectivesContent` into:

- `ResourceContent`
- `isResourceContent`
- `getResourceContentName`
- the top-level insertable content list used by `canInsert`
- default factory creation, likely `createDefaultLearningObjectivesContent`
- editor dispatch in `assets/src/components/resource/editors/createEditor.tsx`
- outline dispatch in `assets/src/components/resource/editors/ContentOutline.tsx`

The current provisional type name in the starting point has a typo:
`LearnignObjectivesContentMode`. The implementation should use the corrected
`LearningObjectivesContentMode` name unless compatibility with already-saved draft data requires a
temporary alias.

## Insertion Rules

The new `learning_objectives` content type should be insertable only at the top level of a page.
Authors should not be able to place it inside a group, survey, alternative, report, or any other
nested content container.

This should be enforced in the same model-level insertion policy that already controls drag/drop and
nesting:

- include `learning_objectives` in the root/top-level insertable set,
- do not include it in `allowedContentItems` for any `ResourceGroup`,
- keep it out of `ResourceGroup` so it cannot have children,
- ensure drag/drop checks through `canInsert(content, parents)` reject it whenever `parents.length`
  is greater than zero.

The Insert menu should also avoid offering the element from nested add controls. That UI guard is
important for clarity, but the model-level `canInsert` restriction is still required because content
can move through drag/drop, duplication, import, or legacy saved data paths.

## Authoring Insert Menu

MER-5802 expects the new element to appear in the Content Types section of the page editor Insert
menu with the approved icon, label, and hover description:

```text
Render a learning objective introduction or summary.
```

The closest current authoring entry point is the non-activity content picker under
`assets/src/components/content/add_resource_content/NonActivities.tsx`, where the Activity Bank
Selection entry calls `createDefaultSelection()`.

The Learning Objectives entry should follow that shape:

- add a factory that creates a `learning_objectives` node with a generated `id`,
- default `mode` to `introduction`,
- default `learning_objectives` to an empty array until the editor has resolved the current
  container's Learning Objectives,
- close the popover after insertion the same way existing content items do,
- only show or enable the entry for top-level insertion positions.

MER-5802 also asks for standardized hover description behavior across Insert menu items. That is a
shared Insert menu refinement and should be implemented around the existing `ResourceChoice`
tip/hover pattern rather than special-casing this element.

## Editor UX Direction

Follow the `ActivityBankSelection` authoring pattern:

- a dedicated editor component owns the specialized controls for the terminal node,
- a wrapper editor places it in the normal removable page content block,
- `createEditor` dispatches on the content `type`,
- the content outline has a dedicated outline item with an icon, title, and compact description.

Likely new files:

- `assets/src/components/resource/editors/LearningObjectivesEditor.tsx`
- optional `LearningObjectivesEditor.scss` or module styles if needed by the design

The authoring editor should support:

- an element type dropdown with `Learning Objective Introduction` and `Learning Objective Summary`,
- description copy that changes with the selected mode,
- an `Include Sub-Objectives` control if that remains part of the final schema,
- a resolved list of Learning Objectives for the current container and descendants,
- parent-before-child ordering,
- visual indentation for Sub-Objectives,
- remove/restore state per displayed Learning Objective,
- Summary-mode configuration for review page recommendations,
- Summary-mode configuration for practice recommendations.

The provided starting schema captures per-objective enabled state and Summary recommendations:

- `enabled: false` means the author suppressed that Learning Objective in this element,
- `revisit_pages` stores recommended course page resource IDs,
- `practice_pages` stores recommended course page or practice opportunity resource IDs.

The schema as written does not yet include `include_sub_objectives`. Because that is an explicit
requirement in MER-5803 and MER-5804, the implementation should add a field such as:

```ts
include_sub_objectives: boolean;
```

The default should be `true`.

## Advisory State And Drift

The `learning_objectives` array inside `LearningObjectivesContent` is advisory. It records author
configuration for Learning Objectives the editor knew about when the author configured the element.
It must not become the authoritative list of Learning Objectives rendered to students.

Expected drift scenario:

1. An author places a Learning Objectives element on a page inside a unit.
2. The editor resolves Learning Objectives from that unit and its nested modules.
3. The author suppresses one Learning Objective and adds review/practice recommendations to another.
4. Later, the author attaches a new Learning Objective to an activity on another page in the same
   unit.
5. The author publishes the project and a student visits the page containing the Learning Objectives
   element.

The student should see the full delivery-time Learning Objective set, including the later-added
Learning Objective. The later-added Learning Objective will not have authored recommendations or a
suppressed state because no matching `LearningObjectiveConfig` exists in the element state.

Delivery should therefore merge two sources:

- authoritative Learning Objective discovery from the current container and descendants,
- optional decoration from `LearningObjectivesContent.learning_objectives` matched by
  `resource_id`.

If an objective is discovered at delivery time and has no matching advisory config, delivery should
render it with defaults:

- enabled,
- no revisit page recommendations,
- no practice recommendations.

If an advisory config references a Learning Objective that is no longer discovered in the current
container, delivery should ignore it for rendering. Authoring can still keep the stale entry unless a
later cleanup pass chooses to prune it.

## Authoring Data Resolution

The authoring editor needs to display the current effective Learning Objective list for the
container where the page lives. That should be resolved from project/course authoring data, not from
the element's stored `learning_objectives` array.

The useful authoring response shape is:

- objective resource ID,
- title,
- description when available,
- parent resource ID when it is a Sub-Objective,
- hierarchy/order metadata sufficient to render parent-before-child,
- whether the objective is in the current effective container set.

The editor should merge that resolved list with the stored advisory config by `resource_id`:

- use stored `enabled`, `revisit_pages`, and `practice_pages` when present,
- apply defaults when absent,
- preserve stored config for objectives that are temporarily not in the visible resolved list unless
  product decides stale config should be pruned.

This merge should be local to the editor state/update path and should not write inferred default rows
for every discovered Learning Objective unless the author actually changes configuration. Keeping
the persisted state sparse makes the advisory nature clear and avoids unnecessary page JSON churn as
objectives are added elsewhere in the container.

## Page Reference Controls

Summary mode needs controls to associate review pages and practice opportunities with each Learning
Objective.

The important constraint is that these are recommendations only:

- adding a revisit page does not tag that page to the Learning Objective,
- adding a practice opportunity does not tag that activity or page to the Learning Objective,
- removing a chip only removes the recommendation from this element's advisory config.

Selectors should only allow resources from the current course/project. If the implementation
distinguishes review pages from practice opportunities, the editor should use the course structure
and page metadata to filter those choices rather than accepting arbitrary resource IDs.

## Removal Semantics

The element itself should behave like any other page element: authors can remove it from the page
through the normal content block remove affordance.

Within the element, removing a Learning Objective means setting advisory state for this element, not
deleting or untagging the Learning Objective:

- removing a parent hides that parent and its displayed Sub-Objectives for this element,
- removing a Sub-Objective does not remove its parent,
- restoring reverses the local advisory state,
- no course-level objective data or activity objective tags are modified.

## Delivery Context

Basic page delivery renders through `PageDeliveryController.render_page_body/3`, builds an
`Oli.Rendering.Context`, and passes the page attempt content to:

```elixir
Page.render(render_context, attempt_content, Page.Html)
```

Page-level content element dispatch goes through `Oli.Rendering.Content.render/3` and
`Oli.Rendering.Elements.Html`. Activity bank selections already use this route:

- `Oli.Rendering.Content.render/3` matches `%{"type" => "selection"}`.
- `Oli.Rendering.Elements.Html.selection/3` calls either the instructor-preview selection renderer
  or `Oli.Rendering.Content.Selection.render/3`.

The Learning Objectives element should follow the same shape:

- add a `%{"type" => "learning_objectives"}` render clause in `Oli.Rendering.Content`,
- add a writer callback and `Oli.Rendering.Elements.Html.learning_objectives/3`,
- delegate actual HTML construction to a focused module such as
  `Oli.Rendering.Content.LearningObjectives`.

The expensive discovery work should run once before `Page.render/3`, not once for every element. The
page render path should first scan `attempt_content` with `PageContent.flat_filter/2` for
`%{"type" => "learning_objectives"}`. If the page has no Learning Objectives element, skip all new
work.

When at least one element is present, extend `Oli.Rendering.Context` with a `learning_objectives`
field and put the precomputed payload there, for example:

```elixir
%Context{
  learning_objectives: %{
    container_resource_id: container_resource_id,
    objectives: included_objectives,
    objectives_by_id: objectives_by_id,
    performance_by_objective_id: performance_by_objective_id
  }
}
```

`performance_by_objective_id` should be populated only when the page contains a Summary-mode
Learning Objectives element. Introduction-only pages should not pay the analytics-query cost.

## Container Scope

The delivery helper needs a container resource ID and section context. The page render path already
has the `%Section{}` and current page resource ID, but it does not currently place the parent
container resource ID into `Oli.Rendering.Context`.

The scope resolution should use the most specific non-root parent container of the current page:

- if a page is directly under a unit, use the unit resource ID,
- if a page is inside a module, use the module resource ID,
- if a page is directly under the course root, use `nil` or the root section resource as the course
  scope, depending on the helper contract.

There are two ways to resolve this:

- reuse `Sections.get_parent_containers_map(section.id, [page_resource_id])`, which reads the
  existing `contained_pages` relation and returns the highest-numbering-level parent;
- or avoid that query by deriving the parent during the same SectionResourceDepot schedule traversal
  described below.

The second path is preferable for this feature because the discovery helper already needs to walk
the cached page/container hierarchy. The public helper can still accept a `container_resource_id`
directly so callers that already know the scope do not repeat parent resolution.

Recommended API shape:

```elixir
Oli.Delivery.LearningObjectives.PageElement.included_objectives(section, container_resource_id)
```

Accepting `%Section{}` is preferable in page delivery because it avoids refetching the section just
to read `root_section_resource_id`. A `section_id` wrapper can be added if another caller truly only
has the ID.

## Included Objective Discovery

The standalone discovery function should return all Learning Objectives attached to activities on
pages recursively contained by the selected container.

Important existing data:

- `SectionResourceDepot` caches section resources for containers, pages, and objectives.
- Section resource records include `children`, `revision_id`, `resource_id`, `resource_type_id`,
  `title`, `hidden`, and objective `related_activities`.
- `SectionResourceDepot` does not cache activity section resources.
- Page revisions maintain `activity_refs`, an array of embedded activity resource IDs populated by
  the page editor when content is saved.
- Objective section resources maintain `related_activities`, a precomputed direct
  objective-to-activity resource ID array populated by `Oli.Delivery.Sections.PostProcessing`.

The efficient runtime algorithm is:

1. Initialize/read the section resource depot through `SectionResourceDepot`.
2. Read cached page/container section resources once:

   ```elixir
   SectionResourceDepot.retrieve_schedule(section.id)
   ```

3. Build an in-memory map of `section_resource.id => section_resource`.
4. Find the starting container section resource:
   - if `container_resource_id` is present, use
     `SectionResourceDepot.get_section_resource(section.id, container_resource_id)`;
   - if it is absent, use `section.root_section_resource_id` against the schedule map.
5. Traverse `children` recursively in memory.
   - For page children, collect the page section resource.
   - For container children, continue traversal.
   - Skip hidden resources so hidden pages do not introduce Learning Objectives into the student
     element.
6. From the collected page section resources, collect their `revision_id`s.
7. Run one direct DB query against `revisions` for those page revision IDs, selecting only
   `resource_id` and `activity_refs`.
8. Flatten and de-duplicate all page `activity_refs` into `activity_ids_in_scope`.
9. Read objective section resources from the depot:

   ```elixir
   SectionResourceDepot.objectives_with_effective_children(section.id)
   ```

10. Filter objectives in memory by testing whether each objective's `related_activities` intersects
    `activity_ids_in_scope`.
11. Add parent objectives for matched Sub-Objectives so hierarchy can be rendered correctly.
12. Return a stable ordered list with parent objectives before children.

This keeps runtime direct DB access to one narrow page-revision query. Containers, pages, objective
metadata, objective hierarchy, and objective-to-activity relationships all come from the depot.

The algorithm intentionally avoids:

- JSONB scans over page `content` during page render,
- querying all activity revisions in the section,
- querying the whole `contained_objectives` table as the source of truth,
- resolving page recommendation titles one at a time.

## Existing Contained Objectives Relation

There is an existing `contained_objectives` relation and
`Sections.get_learning_objectives_for_container_id/2`, backed by
`Sections.build_contained_objectives/3`.

That path is useful context, but it should not be the primary source for this feature as currently
implemented:

- it is rebuilt by scanning page content and all activity objective maps as maintenance work,
- it includes objectives attached directly to pages as well as objectives attached to activities,
- `get_learning_objectives_for_container_id/2` currently returns only titles,
- the runtime read is a direct DB query rather than depot-first.

If product later confirms that page-attached objectives should be included exactly like
activity-attached objectives, the contained-objectives relation becomes more attractive as a thin
read path. For the current direction, the requested source set is activity-attached Learning
Objectives, so filtering depot objective `related_activities` against page `activity_refs` is more
precise.

## Discovery Result Shape

The discovery helper should return data that is ready for render-time merge with the authored
element state, not raw section resources.

Recommended result fields:

```elixir
%{
  resource_id: objective_resource_id,
  title: title,
  parent_resource_id: parent_resource_id_or_nil,
  children: child_objective_resource_ids,
  related_activity_ids: related_activity_ids_in_scope,
  directly_matched?: boolean
}
```

`directly_matched?` distinguishes an objective directly attached to an in-scope activity from a
parent objective included only because one of its Sub-Objectives matched. That flag is useful for
debugging and for possible future copy, but the renderer can treat both as displayable objectives.

Current objective infrastructure primarily exposes objective titles. If the final design requires a
separate Learning Objective description, that field will need to be added to the objective data
source and carried through this payload.

Ordering should be deterministic:

- top-level parent objectives first,
- each parent's Sub-Objectives immediately after the parent,
- child ordering from the objective `children` array when available,
- title/resource ID fallback ordering for orphaned or malformed objective data.

When `include_sub_objectives` is false, the renderer should display only parent rows. If only a
Sub-Objective matched an in-scope activity, its parent should still be displayed so the objective is
not silently lost when Sub-Objectives are hidden.

## Summary Performance Data

Summary mode needs student-specific performance for the included objectives. This should be queried
only when the page contains at least one Learning Objectives element with `"mode" => "summary"`.

Use the existing metrics function with the included objective IDs and current student:

```elixir
Oli.Delivery.Metrics.proficiency_per_student_for_objective(
  section.id,
  included_objective_ids,
  student_id: user.id
)
```

That returns a map shaped like:

```elixir
%{objective_resource_id => %{student_id => proficiency_label}}
```

The renderer should normalize missing entries to the product's "Not Enough Information" state.
Existing metrics labels are currently "Not enough data", "Low", "Medium", and "High"; the
student-facing element should map those to the approved labels/icons:

- Not Enough Information
- Beginning Proficiency
- Growing Proficiency
- Strong Proficiency

The Introduction mode must not display proficiency estimates or recommendations.

## Render-Time Merge

When `Oli.Rendering.Content.LearningObjectives.render/2` receives a
`%{"type" => "learning_objectives"}` element, it should not rediscover objectives. It should read the
precomputed payload from `context.learning_objectives`.

For that specific element:

1. Normalize the element config:
   - default `mode` to `"introduction"`,
   - default `include_sub_objectives` to `true`,
   - default `learning_objectives` to `[]`.
2. Build `config_by_objective_id` from `learning_objectives`.
3. Filter the precomputed included objectives:
   - omit objectives whose matching config has `"enabled" => false`,
   - apply `include_sub_objectives`,
   - when a parent is disabled, omit its displayed Sub-Objectives for that element.
4. For Summary mode, collect recommendation page IDs from the remaining matching configs:
   - `revisit_pages`,
   - `practice_pages`.
5. Resolve all recommendation page IDs in one depot call:

   ```elixir
   SectionResourceDepot.get_resources_by_ids(section.id, recommendation_page_ids)
   ```

6. Render the element from:
   - filtered included objectives,
   - per-objective config,
   - resolved recommendation page titles/slugs,
   - optional student proficiency map for Summary mode.

Any recommendation resource ID that does not resolve in the current section should be ignored. This
keeps stale authored config from breaking delivery after course edits or publication updates.

If the precomputed included objective list is empty, delivery should render nothing for the element.
That matches MER-5807's negative requirement for the Introduction component and avoids showing empty
cards to students.

## Page Recommendation Resolution

Recommendation page references are advisory decorations, just like the objective config itself.

Resolution rules:

- collect recommendation IDs only from objectives that are still included and enabled for this
  element,
- de-duplicate IDs across `revisit_pages` and `practice_pages`,
- resolve with `SectionResourceDepot.get_resources_by_ids/2`,
- render only resources that are pages in the current section,
- use section-resource titles and slugs for links,
- preserve the authored chip ordering after resolution where practical.

This keeps Summary rendering to a single depot lookup per Learning Objectives element. If a page
contains multiple Learning Objectives elements, a small render-context cache keyed by sorted
recommendation IDs can avoid repeating the same depot lookup, but that optimization is probably not
needed initially.

## Activity Bank Selection Caveat

The proposed discovery algorithm uses page revision `activity_refs`, which captures embedded static
activity references. It does not include the candidate set for an Activity Bank Selection, because
those activities are realized dynamically at attempt time and `SectionResourceDepot` does not cache
activity resources.

For the first implementation, treat Activity Bank Selection candidates as out of scope for Learning
Objective discovery unless product explicitly expects banked candidate objectives to appear in this
element. If that expectation changes, add a second discovery branch that resolves selection
candidate objectives through the existing ActivityProvider/Realizer infrastructure and merges those
activity IDs into `activity_ids_in_scope`.

That expansion should be designed carefully because it can turn a cheap depot-plus-one-query path
into per-selection bank realization work.

## Delivery Tests

Focused coverage should live close to the new delivery helper and renderer:

- a unit/integration test for `included_objectives/2` where a container contains nested pages and
  only objectives attached to descendant page activities are returned;
- a test that objectives attached to activities outside the container are excluded;
- a test that a parent objective is included when only a Sub-Objective is directly attached to an
  in-scope activity;
- a test that hidden descendant pages do not contribute objectives;
- a render test for Introduction mode showing titles and hierarchy without proficiency data;
- a render test for Summary mode resolving `revisit_pages` and `practice_pages` through
  SectionResourceDepot in one batch;
- a render test proving an objective discovered at delivery time but absent from advisory element
  config still appears with default enabled/no-recommendation state.

## Non-Goals For This Note

This note does not specify DOT AI explain integration or the final visual styling of the
student-facing Summary layout. It also does not add a new persisted delivery table for this element;
the intended delivery contract is depot-first rediscovery plus advisory authored decoration.
