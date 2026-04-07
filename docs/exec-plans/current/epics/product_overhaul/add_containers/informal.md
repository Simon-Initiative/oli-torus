# Add Containers (Informal Spec)

Source ticket: `MER-4057`
Feature name: `add_containers`

## Intent

Support creating course structure containers (units/modules/sections) directly inside templates/products while preserving resource lineage and strict scope isolation.

## Core Technical Direction

When a new container is created in a template/product:

1. Create a new `resource` in the base project.
2. Create a new `revision` for that container resource.
3. Create a `section_resource` pointing at that revision for the template section.

Edits to container title (even if out of immediate ticket scope) should follow existing revision model:

- New revision captures the change.
- `section_resource.title` reflects current title as needed, and the `revision_id` of the SR record is updated to point to that new revision.

## Required Data Model Extension

Add a new revision attribute: `container_scope`, an Ecto.Enum.

- Default: `project`
- Additional values: `blueprint`, `section`

> **Naming note:** The field is named `container_scope` (not `scope`) because `Revision` already has a `scope` field (`lib/oli/resources/revision.ex:69`) with values `:embedded | :banked` used for activity scoping. Using the same name would collide.

Scope rules:

- Containers created in products/templates use `container_scope = :blueprint`.
- Instructor remix-created containers use `container_scope = :section`.

No `section_resource` schema changes are required for this behavior.

## Critical Constraints

- New template-created containers must not appear as project-level containers in authoring/project-wide lists.
- Project-level listing/query behavior must filter to `container_scope = :project`.
- Contextual listing/query behavior (template/section) must include:
  - `container_scope = :project`
  - plus scope belonging to the active section/template context

## Areas Requiring Careful Audit

- Authoring curriculum and any "all resources/containers" queries.
- Publishing flows and publication-time container selection.
- Remix/instructor dashboard and section creation code paths.
- Any analytics/filter UI fed by project container lists.

Goal of audit:

- Prevent leakage where one product/section can see containers belonging to other products/sections.

## Validation Focus

- Template-scoped containers (`container_scope = :blueprint`) appear only in intended template context plus inherited project scope.
- Remix-created section containers (`container_scope = :section`) remain section-scoped and isolated.
- Instructor dashboard and related views never show containers from unrelated products.
- Publishing and curriculum operations continue to behave correctly with `container_scope` filters applied.
