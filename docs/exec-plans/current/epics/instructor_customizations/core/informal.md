# Instructor Customizations Informal Technical Design

## Intent

Instructor customizations allow an instructor to tailor the questions that students encounter in a specific course section without changing authored course content or the section resource model.

The first feature slice focuses on basic pages. In instructor preview mode, instructors should be able to remove and restore:

- embedded activity references on a page
- entire activity bank selections on a page
- individual banked activities that are eligible for a specific activity bank selection on a page

The behavior is section-specific and page-specific. Removing a question or bank candidate from one section, page, or selection must not affect any other section, page, or selection, even when the underlying authored page content or selection logic is identical.

## Goals

- Keep instructor customization state outside section resources.
- Avoid mutating authored page revisions or published content.
- No reliance on SectionResource records.
- Support both practice and graded basic pages.
- Apply customization before new activity attempts are created.
- Read all customization state for a page with one query during delivery-time attempt creation.
- Make instructor toggle operations simple and individually addressable.
- Preserve enough structure to support future queries such as "where is this banked activity excluded across this course section?"
- Be robust when authored content changes, questions are deleted, bank logic changes, or previously customized candidates no longer match a selection.

## Non-Goals

- This feature does not apply to adaptive pages in the initial design.
- This feature does not create a new publication or revise source project content.
- This feature does not alter historical attempts that already exist.
- This feature does not define final UI layout details beyond the data and interaction requirements needed by the UI.

## Functional Requirements

Instructor preview mode needs controls that let an instructor toggle individual page-level activity resources off and back on.

For embedded activities, the instructor is customizing one activity reference on one page in one section.

For activity bank selections, the instructor can disable the entire selection on that page. When a selection is disabled, no activity attempts should be realized for that selection and the selection should not render as available content for new attempts.

For activity bank selection candidates, the instructor can review all banked activities that currently match the selection logic and can disable or restore individual candidates for that selection on that page. A candidate disabled for one selection should remain eligible for a different selection, even on the same page.  Instructors must not be able to disable questions to the point that the selection "count" cannot be fulfilled.

Customization state should affect new attempt creation. Existing attempts should remain stable because they already store their transformed content and activity attempts.

## Core Design

Introduce a new delivery-side schema and context for section/page activity resource exclusions. The central table should model one exclusion per row rather than storing lists of excluded ids.

A working name is `section_page_activity_exclusions` or perhaps just `activity_exclusions`. The context will live under `Oli.Delivery.InstructorCustomizations` namespace.

The table represents section-specific exclusions scoped to a page resource. It does not extend section resources and does not participate in publication. It is mutable instructor-owned delivery configuration.

### Context Boundary

All application logic for instructor customizations should live behind `Oli.Delivery.InstructorCustomizations`. The Instructor Preview UI, student delivery attempt creation, and Oli.Scenarios tests should all call this context instead of duplicating validation, exclusion lookup, or activity bank candidate rules.

This context owns:

- section/page/activity validation
- authorization checks for instructor/admin writes
- activity enable/disable writes
- activity bank selection enable/disable writes
- bank candidate enable/disable writes
- the "do not disable below selection count" rule
- page-level exclusion read models for delivery
- selection-level exclusion read models for Instructor Preview UI
- stale-row tolerance when authored content changes

Controllers, LiveViews, scenario handlers, and delivery lifecycle code should be thin callers of this context.

### Public Context API

Use Elixir names in implementation even when the client event is named with JavaScript conventions. The Preview component can dispatch `setActivityEnabled(enabled: boolean)`, and the server should route that to `set_activity_enabled/5`.

#### Instructor Preview Writes

Primary embedded-activity API:

```elixir
set_activity_enabled(section_or_id, page_resource_id, activity_resource_id, enabled, opts \\ [])
exclude_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ [])
restore_activity(section_or_id, page_resource_id, activity_resource_id, opts \\ [])
```

Arguments:

- `section_or_id`: `%Oli.Delivery.Sections.Section{}` or section id. Prefer a section struct when the caller already has one.
- `page_resource_id`: resource id of the page being customized. This is not a revision id or slug.
- `activity_resource_id`: resource id of the embedded activity to enable or disable.
- `enabled`: boolean. `true` restores/enables the activity; `false` excludes/disables it.
- `opts[:actor]`: current user or author performing the write. It is required for every write, including scenario calls, and must be authorized for the target section.

Behavior:

- `set_activity_enabled(..., false, opts)` inserts the `:embedded_activity` exclusion row.
- `set_activity_enabled(..., true, opts)` deletes the matching row.
- `exclude_activity/4` and `restore_activity/4` are semantic wrappers used by scenario directives and tests.
- Repeated disable/enable operations should be idempotent.

Selection-level API:

```elixir
set_bank_selection_enabled(section_or_id, page_resource_id, selection_id, enabled, opts \\ [])
exclude_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ [])
restore_bank_selection(section_or_id, page_resource_id, selection_id, opts \\ [])
```

Arguments:

- `selection_id`: authored selection element id from the page content model.
- Other arguments match `set_activity_enabled/5`.

Behavior:

- `set_bank_selection_enabled(..., false, opts)` inserts the `:bank_selection` exclusion row.
- `set_bank_selection_enabled(..., true, opts)` deletes the matching row.
- Disabling an entire bank selection is allowed even though disabling individual candidates below the selection count is not; the instructor is explicitly removing the selection from the page.

Bank candidate API:

```elixir
set_bank_candidate_enabled(
  section_or_id,
  page_resource_id,
  selection_id,
  candidate_activity_resource_id,
  enabled,
  opts \\ []
)

exclude_bank_candidate(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id, opts \\ [])
restore_bank_candidate(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id, opts \\ [])
```

Arguments:

- `candidate_activity_resource_id`: activity resource id of a banked activity that can currently satisfy the selection.
- Other arguments match the selection-level API.

Behavior:

- `set_bank_candidate_enabled(..., false, opts)` inserts the `:bank_candidate` exclusion row only if the selection can still satisfy its configured count after the candidate is disabled.
- `set_bank_candidate_enabled(..., true, opts)` deletes the matching row.
- The context must resolve the current page revision for the section, find the selection, parse its selection logic, determine the current matching candidate set, read existing candidate exclusions for that selection, and enforce that active candidate count remains at least the selection count.
- The UI must not perform this rule itself except for optimistic presentation. The context is the authority.
- Repeated candidate disable/enable operations should be idempotent.

Suggested return shape for all writes:

```elixir
{:ok, %Oli.Delivery.InstructorCustomizations.PageExclusions{}}
{:error, reason}
```

Returning the page exclusion view after each successful write lets the Instructor Preview UI refresh local state from the same read model that delivery uses.

Expected error atoms/tuples:

- `{:unauthorized, :customize_section}`
- `{:not_found, :section}`
- `{:not_found, :page}`
- `{:not_found, :activity}`
- `{:not_found, :selection}`
- `{:invalid_page_type, :adaptive}`
- `{:invalid_selection_candidate, candidate_activity_resource_id}`
- `{:insufficient_selection_candidates, %{selection_id: selection_id, count: count, active_candidates: active_count}}`
- `{:validation_failed, changeset}`

#### Delivery And Scenario Reads

Page-level read API:

```elixir
get_page_exclusions(section_or_id, page_resource_id)
get_page_exclusion_view(section_or_id, page_resource_id)
```

`get_page_exclusions/2` returns raw active exclusion rows for the page. This is useful for admin/debug views and tests that need to assert persistence.

`get_page_exclusion_view/2` returns a compact value object used by delivery and scenario assertions:

```elixir
%Oli.Delivery.InstructorCustomizations.PageExclusions{
  section_id: section_id,
  page_resource_id: page_resource_id,
  excluded_activity_ids: MapSet.t(activity_resource_id),
  excluded_selection_ids: MapSet.t(selection_id),
  excluded_bank_candidate_ids_by_selection: %{selection_id => MapSet.t(activity_resource_id)}
}
```

This is the object `PageLifecycle.Hierarchy.create/1` or the activity provider boundary should load once per page attempt and pass into realization. Delivery code should not query the table directly.

Selection-level read API:

```elixir
get_selection_exclusion_view(section_or_id, page_resource_id, selection_id)
list_bank_selection_candidates(section_or_id, page_resource_id, selection_id, opts \\ [])
```

`get_selection_exclusion_view/3` returns the current selection exclusion state:

```elixir
%{
  section_id: section_id,
  page_resource_id: page_resource_id,
  selection_id: selection_id,
  selection_enabled?: boolean(),
  excluded_candidate_ids: MapSet.t(activity_resource_id)
}
```

`list_bank_selection_candidates/4` is the UI-facing candidate review function. It should resolve the current matching bank activities for the selection and annotate each candidate with enabled/excluded state:

```elixir
{:ok,
 %{
   selection_id: selection_id,
   count: count,
   selection_enabled?: boolean(),
   candidates: [
     %{
       activity_resource_id: id,
       revision_slug: slug,
       title: title,
       enabled?: boolean(),
       disable_allowed?: boolean()
     }
   ]
 }}
```

`disable_allowed?` should be `false` when disabling that candidate would make the active candidate count drop below the selection count.

Predicate helpers:

```elixir
activity_enabled?(%PageExclusions{}, activity_resource_id)
bank_selection_enabled?(%PageExclusions{}, selection_id)
bank_candidate_enabled?(%PageExclusions{}, selection_id, candidate_activity_resource_id)
```

These helpers are pure functions over the read model and should be used by delivery, UI rendering, and scenario assertions when they already have the page exclusion view.

#### Validation Helpers

The context can expose explicit validation helpers for UI preflight and scenario diagnostics, but write functions must still run the same validation internally:

```elixir
validate_activity_customization_target(section_or_id, page_resource_id, activity_resource_id)
validate_bank_selection_customization_target(section_or_id, page_resource_id, selection_id)
validate_bank_candidate_customization_target(section_or_id, page_resource_id, selection_id, candidate_activity_resource_id)
```

These should return `:ok` or the same `{:error, reason}` shapes as writes.

### Callers

Instructor Preview UI:

- Use `set_activity_enabled/5` when the upper-right question button dispatches `setActivityEnabled(enabled)`.
- Use `set_bank_selection_enabled/5` for whole-selection enable/disable UI.
- Use `set_bank_candidate_enabled/6` for candidate management UI.
- Use `get_page_exclusion_view/2` to render page-level enabled/disabled state.
- Use `list_bank_selection_candidates/4` to render bank candidate management.

Student delivery:

- Use `get_page_exclusion_view/2` once while creating a new resource attempt.
- Pass the returned `PageExclusions` read model into the activity realization path.
- Use pure predicate helpers or the read model fields to filter embedded activities, whole selections, and selection-local candidates.

Oli.Scenarios:

- Use `exclude_activity/4`, `restore_activity/4`, `exclude_bank_selection/4`, `restore_bank_selection/4`, `exclude_bank_candidate/5`, and `restore_bank_candidate/5` in scenario directive handlers.
- Use `get_page_exclusion_view/2` and predicate helpers for assertions.
- Do not duplicate count validation or page/selection lookup logic in scenario infrastructure.

### Proposed Table

Suggested fields:

- `id`
- `section_id`
- `page_resource_id`
- `selection_id`
- `kind`
- `excluded_resource_id`
- `inserted_at`
- `updated_at`

Field meanings:

- `section_id` is the delivery section where the customization applies.
- `page_resource_id` is the page resource id, not the page revision id. This lets the customization survive page republishing when the same page resource receives a new revision.
- `selection_id` is the authored selection element id when the exclusion is selection-scoped. It is `NULL` for embedded activity exclusions.
- `kind` is an enum such as `:embedded_activity`, `:bank_selection`, or `:bank_candidate`.
- `excluded_resource_id` is the resource being excluded. For embedded activities and bank candidates, this is an activity resource id. For an entire bank selection, this will be `NULL` because the excluded thing is the bank itself and is identified by `page_resource_id + selection_id + kind`.

Restore is modeled as deletion of the matching exclusion row. There does not need to be an `excluded` boolean unless product later needs to preserve a historical record of previous instructor choices in the active table.

Suggested uniqueness constraints:

- Embedded activity: unique on `section_id, page_resource_id, kind, excluded_resource_id` where `kind = 'embedded_activity'`.
- Entire bank selection: unique on `section_id, page_resource_id, kind, selection_id` where `kind = 'bank_selection'`.
- Bank candidate: unique on `section_id, page_resource_id, kind, selection_id, excluded_resource_id` where `kind = 'bank_candidate'`.

Suggested indexes:

- `section_id, page_resource_id` for the single delivery-time page read.
- `section_id, page_resource_id, kind` for UI summary and page-level grouping.
- `section_id, excluded_resource_id` for future "where is this activity excluded?" queries.
- `section_id, page_resource_id, selection_id` for bank selection preview and candidate toggling.

## Why Row-Per-Exclusion

The main alternative is a denormalized record per section/page/selection with an `excluded_resource_ids` list. That has a smaller row count and can make a page-level read compact, but it weakens the rest of the design.

Row-per-exclusion is preferred because:

- toggling one item maps to a simple insert or delete
- uniqueness constraints prevent duplicate exclusions
- future cross-course and cross-section reporting can query `excluded_resource_id` directly
- stale exclusions are harmless and can be ignored when the referenced resource no longer exists or no longer matches current selection logic
- bank selection exclusions and bank candidate exclusions can be represented uniformly

The list-based design remains viable only if we optimize solely for page reads and accept more complicated update logic, more difficult reporting, and weaker database constraints. That does not match the expected UI behavior, where instructors toggle individual items.

## Delivery-Time Application

Customization should be applied during activity realization, before activity attempts are created.

The relevant current path is:

- `Oli.Delivery.Attempts.PageLifecycle.Hierarchy.create/1`
- audience filtering of page content
- `Oli.Delivery.ActivityProvider.provide/6`
- static activity reference resolution and activity bank selection fulfillment
- transformed page content and attempt prototypes returned to page lifecycle
- resource attempt and activity attempts created

The customization step should be introduced at the activity provider boundary because that module already understands:

- embedded `activity-reference` elements
- `selection` elements
- selection fulfillment
- transformed content that replaces selections with realized activity references
- `selection_id` on activity attempt prototypes

The page lifecycle should load exclusions once for the current `section_id + page_resource_id` and pass the result into activity realization. That can be done either by extending the provider function signature or by adding an optional field to `Oli.Activities.Realizer.Query.Source`.

The cleaner low-level design is to pass an exclusion set into `Source`, for example:

- `excluded_activity_ids`
- `excluded_selection_ids`
- `excluded_bank_candidate_ids_by_selection`

Those values can be built from the row-per-exclusion records after the single page-level query.

### Embedded Activity Filtering

When `ActivityProvider` encounters an `activity-reference`, it should check whether that activity resource id is excluded for the current page.

If excluded:

- no attempt prototype is created
- the activity reference is removed from the transformed content for new attempts
- the activity contributes no score/out-of value

This filtering should happen before `reference_to_prototype/3` and before transformed content is persisted in the new resource attempt. The current provider only transforms content when selections are present, so implementation should introduce a generalized content filtering/transform pass that can remove excluded embedded `activity-reference` elements even when the page has no activity bank selections.

### Entire Bank Selection Filtering

When `ActivityProvider` encounters a `selection`, it should check whether the selection id is excluded for the current page.

If excluded:

- `Selection.parse/1` and fulfillment should be skipped
- no existing or new prototypes should be added for that selection
- transformed content should replace the selection with an empty list
- the selection contributes no score/out-of value

For retake and migration behavior, constraining prototypes for an excluded selection should not be carried forward into the new attempt. The exclusion should win for new attempts.

### Bank Candidate Filtering

When fulfilling a non-excluded selection, the provider must also honor candidate-level exclusions for that exact selection id.

The existing `Source.blacklisted_activity_ids` already excludes activities from selection fulfillment. Instructor candidate exclusions can be merged into the blacklist for the duration of that selection.

This needs to be selection-specific. A candidate excluded for selection `A` should not be added to the global source blacklist before selection `B` is fulfilled. The provider can derive a temporary source for the current selection:

- start from the current fulfillment source
- append `excluded_bank_candidate_ids_by_selection[selection_id]` to `blacklisted_activity_ids`
- call `Selection.fulfill/2` with that temporary source
- after fulfillment, continue to merge realized rows into the normal global blacklist so duplicate realization prevention still works

This preserves the existing "do not select the same banked activity twice on the page" behavior while making instructor exclusions selection-local.

## Instructor Preview And Candidate Review

The bank selection preview endpoint currently finds the selection element by `revision_slug + selection_id`, parses its logic, and queries matching bank activities. That endpoint should use the same customization context.

For candidate review:

- query all activities matching the selection logic
- load exclusions for `section_id + page_resource_id + selection_id`
- annotate each candidate as excluded or active
- allow toggle actions that insert/delete `bank_candidate` rows

For embedded page activities and entire selections:

- the instructor preview page should load all exclusions for the page
- render toggle state for each embedded activity reference and selection
- insert/delete `embedded_activity` or `bank_selection` rows as the instructor toggles

The UI does not need to physically delete stale rows when content changes. Stale exclusions can remain invisible until the referenced activity or selection id appears again. A later cleanup task can remove exclusions for pages, sections, or resources that are permanently deleted if operationally useful.

## Data Integrity And Authorization

All writes must require instructor permission for the target section or an admin-equivalent permission.

Writes should validate:

- the section exists
- the page resource belongs to the section's current publication/deployment
- the selected page is a basic page
- `selection_id` exists on the current page content for selection-scoped exclusions
- `excluded_resource_id` resolves to an activity resource when required

For `bank_candidate` writes, the resource does not necessarily need to match the selection logic at write time, but the UI should normally only offer candidates that do. Allowing stale rows keeps the system robust across edits and republishes.

## Attempt And Historical Behavior

Customization is applied when a new resource attempt is created. Already-created attempts should continue to render from their stored transformed content and existing activity attempts.

This gives predictable behavior:

- a student who already started a page keeps the activities assigned to that attempt
- a later attempt can reflect updated instructor exclusions
- historical review remains consistent with what the student actually saw

If product requirements later demand that instructor changes invalidate or update in-progress attempts, that should be designed as a separate attempt lifecycle policy because it affects grading, review, and fairness.

## Student Preview Behavior

There are two relevant instructor-facing preview paths today:

- The static instructor page preview route, `/sections/:section_slug/preview/page/:revision_slug`, renders `PageDeliveryController.page_preview/2`. For basic pages this uses `render_page_preview/3`, builds an `:instructor_preview` rendering context, resolves embedded activity references, and renders the current revision content directly. It does not create a resource attempt.
- The "Open as student" path from instructor-facing course content uses the normal student page route, `/sections/:section_slug/page/:revision_slug`. That route is redirected through the lesson/prologue flow and uses `PageContext.create_for_visit/4`, `PageLifecycle.visit/6`, and the normal attempt lifecycle for the instructor's user id.

Note: Instructor Preview may be served by LiveView or legacy controller-backed paths. The instructor customization core should remain transport-layer independent. Future preview read and toggle calls should be wired through the active Instructor Preview owner rather than assuming `PageDeliveryController.page_preview/2` remains the integration point.

Instructor customizations do not need to appear immediately inside an already-active Student Preview attempt. The Student Preview attempt should behave consistently with student delivery: once an attempt has been created, its stored transformed content remains stable.

For practice pages, an instructor can use the existing reset-activities flow to get a new page attempt. That new attempt should apply the current customization state during activity realization.

For graded pages, an instructor can finish the current graded attempt and start a new one. The new attempt should apply the current customization state.

The implementation should therefore not add special freshness checks that invalidate or replace active instructor Student Preview attempts when customization rows change. Customizations are applied at new attempt creation time only. This keeps instructor Student Preview aligned with the way students experience page attempts.

The static instructor page preview route should still be considered separately because it does not create attempts. If this route displays instructor customization controls or filtered preview content, it should read the same customization state directly during rendering.

## Robustness

This feature must be robust against a host of changing things:

- It must correctly handle new publications that add and remove activities and selections
- It must correctly handle when a page is removed and readded to a course section via remix. In this case any previous exclusions would be restored.


## Design for Scenario Testing

This feature MUST be designed in a way that ALL of the non-UI application code is directly exposed
and testable via an Oli.Scenarios style unit test.  Several YAML scenario tests will be written
that will validate the correct functioning of this feature.   This work must extend the Oli.Scenarios
YAML directive set to add a directive to allow enable/disabling of activities, selections
and activity bank selection candidate activities on a section and page basis.

The design of this feature should center on testability.  Before we even get to the part of the work
that builds and delivers the UI portion of this feature, we want to have extremely high confidence
that the application level (the non-UI) impl of this feature works end to end.

### Some Key scenarios to test

1. Have two pages each with an activity bank selection.  We need to ensure that disabling a bank selection candidate on page A does not disable it on page B.
2. Have a page with exclusions, then publish a new revision of that page that adds a new activity, verify a new attempt maintains the previous exclusion but renders the new activity.


## Open Questions

- Should embedded activity exclusions be per activity resource id on the page or per authored activity-reference element id? ANSWER: you MUST use activity resource id
- Should instructor customizations apply immediately inside an already-active Student Preview attempt? ANSWER: No. Student Preview should remain attempt-consistent. Customizations apply when a new attempt is created. On practice pages, instructors can use reset activities to create a new attempt. On graded pages, instructors can finish the current attempt and start a new one.

- Should excluding all candidates for a bank selection behave differently from excluding the entire selection? ANSWER:  One CANNOT exlude all activities from a bank selection.  One can only exclude down to the configured COUNT of the selection.  So if a selection exist with a count of 2 (meaning it chooses two questions) an instructor cannot disable any more if only two remain.
- Should there be an audit trail of who made each exclusion? If needed, add `created_by_id` and possibly a separate event/audit table.  ANSWER:  No audit trail requirement
- Should product define minimum availability rules, such as preventing an instructor from excluding so many bank candidates that a graded selection can no longer fulfill?  ANSWER: YES, hard requirement to never let less than COUNT questions be enabled

## Suggested Implementation Shape

1. Add the schema, migration, changeset validations, and context functions for listing and toggling exclusions.
2. Add a compact value object that converts page exclusion rows into lookup sets used by delivery.
3. Load page exclusions once in `PageLifecycle.Hierarchy.create/1` or immediately before invoking `ActivityProvider.provide/6`.
4. Update `ActivityProvider` to skip excluded embedded activities, skip excluded selections, and merge selection-local candidate exclusions into selection fulfillment.
5. Update transformed content handling so excluded references and selections are removed from stored attempt content.
6. Update activity bank preview to annotate candidate exclusion state and expose toggle endpoints/events.
7. Add scenario or integration coverage for practice and graded basic pages, including embedded activity exclusion, entire selection exclusion, and selection-specific bank candidate exclusion.
