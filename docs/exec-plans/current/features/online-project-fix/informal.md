# Online Project Repair Tool Informal Requirements

## Intent

Build a manually invoked admin/developer repair tool for course projects. The tool should inspect a single authoring project, report structural problems in page activity references, and optionally apply safe repairs after an explicit admin confirmation.

The initial repair scope is intentionally narrow:

- pages that share the same embedded activity resource
- pages that reference missing activity resources, for reporting only

The tool must only consider Basic pages. Adaptive pages are out of scope for both analysis and repair.

The tool should be accessible from a project-scoped route so an admin can navigate directly to a URL such as `/workspaces/course_author/<project_slug>/repair_tool`. It should not include a project picker.

## Problem Background

Some older projects were affected by a now-fixed duplication bug. When a page was duplicated, not every referenced activity was duplicated with it. As a result, multiple pages can point at the same activity resource. That is structurally wrong for these projects because editing or repairing one page's activity can unintentionally affect another page that shares the same activity resource.  Torus has a hard schema requirement that pages cannot share the same activity references.

Separately, some Basic pages contain `activity-reference` entries for activities that no longer exist in the project. Those references should be reported to the admin, but this tool must not remove them.

## Goals

- Provide a robust project repair tool that can be run manually by a system admin.
- Run in two phases:
  - read-only analysis and preview
  - explicit opt-in repair
- Analyze and repair Basic pages only.
- Detect Basic pages that share activity resources.
- Detect Basic pages that reference missing activity resources.
- Report missing activity references without removing them.
- Avoid cloning shared activity references when the shared activity resource is missing.
- Keep memory usage bounded by streaming page/revision content and retaining only the minimal IDs and issue summaries needed for detection and reporting.
- Keep the core implementation outside `OliWeb` in a dedicated non-web context.
- Keep the LiveView thin: it should invoke the context, display the analysis results, link to affected page editors, and trigger the repair phase.
- Include unit tests for the repair context.
- Restrict access to system admins.
- Keep the implementation of this tool as simple as possible, to make it trivial to code review and to reduce the risk of using this tool.

## Non-Goals

- No automatic scheduled/background repair.
- No project picker UI.
- No LiveView test requirement for the initial implementation.
- No attempt to repair arbitrary page schema problems beyond the two issue types listed here.
- No removal of missing activity references.
- No analysis or repair of Adaptive pages.
- No repair of published delivery section state. This tool targets authoring project structure and operates directly on the unpublished revisions of these resources (that is, those resources resolved via AuthoringResolver)
- No requirement to optimize for all-project/global scans; invocation is scoped to one project.

## Basic Page Scope

The tool must only inspect and repair Basic pages.

Adaptive pages are identified by page content with a top-level flag:

```elixir
%{"advancedDelivery" => true}
```

If the top-level `advancedDelivery` flag is missing or set to `false`, the page is a Basic page and is in scope.

If the top-level `advancedDelivery` flag is set to `true`, the page is Adaptive and must be skipped entirely:

- do not include it in page/activity maps
- do not report its missing activity references
- do not report its shared activity references
- do not clone activity resources for it
- do not update its page revision

Implementation note: confirm the exact content key spelling against existing page content code. This requirement uses `advancedDelivery` because that is the concrete content pattern for Adaptive pages.

## Access And Route

Add a project-scoped LiveView route:

```text
/workspaces/course_author/<project_slug>/repair_tool
```

Only system admins may access this route. Non-admin users must be denied using the existing project/admin authorization conventions.

The LiveView should resolve the project from the route slug and pass the project to the repair context.

## Two-Phase Workflow

### Phase 1: Analyze / Preview

The initial phase must be read-only. It scans the project, detects issues, and returns a report that the LiveView can render.

The preview should include:

- missing activity references
  - page resource id
  - page title
  - missing activity resource id
  - link to the affected page editor
- shared activity references
  - shared activity resource id
  - count of pages referencing it
  - affected page resource ids
  - affected page titles
  - links to each affected page editor
  - whether the shared activity exists and is repairable
- summary counts
  - scanned page count
  - skipped Adaptive page count
  - missing activity reference count
  - affected page count for missing activities
  - repairable shared activity resource count
  - non-repairable shared missing activity resource count, if any
  - affected page count for shared activities

The preview must not mutate page revisions, activity revisions, resources, or project state.

### Phase 2: Make Changes

After reviewing the analysis report, the admin can click a "Make Changes" button. This action applies repairs to the same project.

The repair phase should either rerun analysis immediately before applying changes or otherwise protect against stale preview state. The implementation should not blindly apply an old report if project content may have changed between preview and repair.

The repair phase must only repair shared references to existing activity resources. It must not remove missing activity references.

If two or more Basic pages share the same missing activity resource id, the tool should report those missing references but must not attempt to clone that activity. A missing activity cannot be used as the source for a repair.

## Issue 1: Pages Sharing Activities

### Detection

For each page in the project:

1. stream or otherwise incrementally read the page's current revision content
2. skip the page if its content is Adaptive, identified by top-level `%{"advancedDelivery" => true}`
3. extract all embedded `activity-reference` activity resource ids.  There are existing functions to use to correctly find ALL nested activity-reference instances.  Use the same approach that the current "page duplication" logic uses.
4. build a minimal in-memory map of:

```text
page_resource_id -> Set(activity_resource_id)
```

Then build an inverted map:

```text
activity_resource_id -> Set(page_resource_id)
```

Any `activity_resource_id` whose page set has cardinality greater than one is a shared activity issue candidate.

Before repair, the tool must resolve the activity resource through the authoring resolver for the project:

- if the activity resolves, it is a repairable shared activity issue
- if the activity does not resolve, it is a missing activity reference and must not be cloned

The report should group shared activity issues by activity resource id and clearly distinguish repairable shared activities from shared missing activity ids.

### Repair

For each shared existing activity resource, preserve one Basic page's reference to the original activity resource and repair the other Basic page references.

For each additional page that references the shared activity:

1. create a new activity resource
2. create a complete copy of the original activity revision/content for that new resource
3. update that page's content so its `activity-reference` points to the new activity resource id
4. create/update the page revision with the repaired page content

The resulting state should be that no two pages in the project share the same embedded activity resource as a result of these duplicated-page artifacts.

The implementation should be deterministic about which page keeps the original activity resource, for example the first page in ascending resource id order.

If the shared activity resource is missing, do not attempt repair for that group.

There is existing, well tested code for "Duplicating" or "Copying" an activity.  This Repair must use that existing impl, and
not create some impl anew.

## Issue 2: Missing Activities

### Detection

Use the Basic-page-only page-to-activity map from the analysis pass:

```text
page_resource_id -> Set(activity_resource_id)
```

For each activity resource id referenced by each page, attempt to resolve its current revision using the authoring resolver for the project.

If the resolver returns `nil`, the activity is missing from the project and the Basic page has a missing activity reference.

### Reporting Only

Missing activity references are report-only in this tool.

The tool must not remove missing `activity-reference` entries from page content. It should report enough detail for an admin or later tool to understand which Basic pages contain missing activity references.

If the same missing activity resource id appears on multiple Basic pages, the tool should report it as missing and ensure the shared-activity repair phase skips it.

## Streaming And Memory Requirements

This tool may be run on large course projects, so the implementation must avoid loading full project content into memory at once.

Expected approach:

- stream or batch page/revision reads
- skip Adaptive pages after reading only the page content needed to identify `advancedDelivery`
- parse one page content payload at a time
- retain only compact maps and summaries:
  - page resource id to activity resource id set
  - activity resource id to page resource id set
  - page metadata required for display, such as title and editor link target
  - issue summaries
- avoid retaining full page JSON/content after each page has been processed, except when actively repairing that specific page

The implementation can keep ID sets in memory because the detection algorithm needs global relationships across pages and activity references. It should not keep every full page revision body in memory.

## Safety Requirements

This tool must be safe to run manually in production-like environments.

- The default action is analysis only.
- No changes occur until the admin clicks "Make Changes".
- The repair phase should rerun or validate analysis before mutating content.
- Missing activity references must be reported only, not removed.
- Shared activity repair must only clone activity resources that resolve through the authoring resolver.
- Adaptive pages must be skipped and never updated.
- Updates should be scoped to the selected project only.
- Activity resolution must use the authoring resolver for the selected project.
- Page revision updates must use established authoring/project revision mechanisms rather than ad hoc database writes.
- Shared activity cloning must perform a complete activity copy, including the activity revision content needed for the new resource to behave like the original.
- Repair operations should be idempotent where practical. Running the tool again after a successful repair should report no instances of the same repairable shared-activity issues. Missing activity references may still be reported because they are intentionally not repaired by this tool.
- Failures should be surfaced clearly in the LiveView rather than silently ignored.
- The context should return structured results that are easy to log, test, and render.

## Context Design

Create a new non-`OliWeb` context for the repair implementation. A working namespace could be:

```elixir
Oli.Authoring.ProjectRepair
```

The exact name can change during implementation, but the responsibilities should stay outside the LiveView.

Suggested public API shape:

```elixir
analyze_project(project_or_slug, opts \\ [])
repair_project(project_or_slug, opts \\ [])
```

The analysis function should return a structured read model, for example:

```elixir
{:ok,
 %ProjectRepair.Report{
   project_id: project.id,
   project_slug: project.slug,
   scanned_pages_count: integer,
   missing_activity_references: [%MissingActivityReference{}],
   shared_activity_references: [%SharedActivityReference{}],
   summary: %ProjectRepair.Summary{}
 }}
```

The repair function should return a structured repair result, for example:

```elixir
{:ok,
 %ProjectRepair.RepairResult{
   report_before_repair: %ProjectRepair.Report{},
   cloned_activity_count: integer,
   updated_page_count: integer,
   report_after_repair: %ProjectRepair.Report{}
 }}
```

The context should own:

- project resolution
- page/revision enumeration
- page content streaming/batching
- Basic page filtering using the top-level `advancedDelivery` flag
- activity-reference extraction
- missing activity detection
- shared activity detection
- skipping missing activity ids during shared-activity repair
- page content transformations
- activity cloning
- page revision updates
- structured reporting for the LiveView and tests

## LiveView Requirements

The LiveView should be simple and project-scoped.

It should:

- require system-admin access
- resolve the project from `project_slug`
- call the context to analyze the project
- render summary counts
- render missing activity references
- render shared activity groups
- render affected page titles as clickable hyperlinks to the page editor
- provide a "Make Changes" button when repairable shared-activity issues exist
- disable or hide "Make Changes" when no repairable shared-activity issues exist
- show repair success/failure results after the repair action

The LiveView should not duplicate detection or repair logic.

## Testing Requirements

Add unit tests for the non-web repair context.

Required coverage:

- detects no issues in a valid project
- skips Adaptive pages identified by `%{"advancedDelivery" => true}`
- treats missing or false `advancedDelivery` as Basic page content
- detects missing activity references in Basic page content
- reports missing activity references without removing them
- detects one shared activity referenced by multiple pages
- clones shared activities and updates all but one page to point at new activity resources
- does not clone a shared activity id that is missing
- rerunning analysis after repair reports the repaired shared-activity issues as gone
- handles pages with no activity references
- handles multiple references in one page
- handles multiple independent shared activity groups

LiveView tests are not required for the initial implementation.

## Open Implementation Details

- Confirm the exact existing route helper/path for linking from the repair LiveView to a page editor.
- Confirm the best existing authoring API for creating a complete activity resource/revision copy.
- Confirm the correct project revision update API to use when writing repaired page content.
- Confirm the exact persisted content key for Adaptive pages if existing code differs from `advancedDelivery`.
- Decide whether repair should be one transaction per page/activity group or a larger transaction. The design should favor safe partial failure reporting if a full-project transaction is not practical.
