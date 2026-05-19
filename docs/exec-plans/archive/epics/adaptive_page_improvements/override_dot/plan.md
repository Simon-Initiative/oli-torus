# Override DOT Per Page — Delivery Plan

Scope and guardrails reference:
- PRD: `docs/epics/adaptive_page_improvements/override_dot/prd.md`
- FDD: `docs/epics/adaptive_page_improvements/override_dot/fdd.md`

## Scope
Implement page-level DOT override (`ai_enabled`) for basic and adaptive pages, including authoring controls, delivery gating, section-resource propagation, and import/export compatibility.

## Non-Functional Guardrails
- Keep section-level assistant enablement as a hard prerequisite.
- Preserve legacy behavior through graded-aware fallback when `ai_enabled` is nil.
- No dedicated performance/load/benchmark test work.
- Avoid adding new runtime services or broad schema rewrites.

## Clarifications & Default Assumptions
- Darren technical guidance is authoritative for this feature scope.
- Page-level toggle applies to scored and practice pages, basic and adaptive.
- Default behavior is scored=false, practice=true unless explicitly overridden.
- Existing test fixtures that omit `ai_enabled` should continue to work through fallback logic.

## Phase Gate Summary
- Gate A: Data model and propagation complete (`AC-001`, `AC-002`, `AC-010`).
- Gate B: Authoring controls persist correctly (`AC-003`, `AC-004`, `AC-005`).
- Gate C: Delivery/trigger gating behavior verified (`AC-006`, `AC-007`, `AC-008`, `AC-009`).

## Phase 1: Data Model and Propagation
- Goal: Add `ai_enabled` to revision/section-resource models and propagate it through all creation/update/migration/import/export paths.
- Tasks:
  - [ ] Add migration for `revisions.ai_enabled` and `section_resources.ai_enabled` with graded-aware backfill.
  - [ ] Update `Oli.Resources.Revision` schema/changeset/encoder and revision lineage copy path.
  - [ ] Update section-resource schemas and all section-resource build/update pipelines.
  - [ ] Update section-resource migration module to sync `ai_enabled` from pinned revisions.
  - [ ] Update import/export and authoring creation defaults (`basic/adaptive`, scored/practice).
- Testing Tasks:
  - [ ] Add/adjust tests validating defaults and migration propagation (`AC-001`, `AC-002`, `AC-010`).
  - [ ] Command(s): `mix test test/oli/delivery/sections/section_resource_migration_test.exs test/oli_web/live/workspaces/course_author/pages_live_test.exs`
- Definition of Done:
  - New columns exist and are wired through revision + section-resource propagation.
  - Create/update/import/export paths preserve `ai_enabled` semantics.
- Gate:
  - Gate A passes when data model paths are complete and targeted tests pass.
- Dependencies:
  - None.
- Parallelizable Work:
  - Import/export updates and section-resource migration updates can run in parallel after schema additions.

## Phase 2: Authoring Controls
- Goal: Expose and persist page-level DOT toggle from both options modal and adaptive lesson panel.
- Tasks:
  - [ ] Add `Enable AI Assistant (DOT)` control in options modal for page revisions with graded-aware default rendering.
  - [ ] Ensure save/validate handlers preserve and persist `revision[ai_enabled]`.
  - [ ] Extend adaptive lesson schema/transformers/page state to edit and persist top-level `ai_enabled`.
  - [ ] Ensure `/api/resource` update payload and context typings include `ai_enabled`.
- Testing Tasks:
  - [ ] Add/adjust options modal and authoring flow tests (`AC-003`, `AC-004`, `AC-005`).
  - [ ] Command(s): `mix test test/oli_web/live/curriculum/entries/options_modal_content_test.exs test/oli_web/live/curriculum/container_test.exs test/oli_web/live/all_pages_live_test.exs`
- Definition of Done:
  - Both authoring surfaces show/persist the toggle correctly.
  - Defaults are correct for scored/practice pages when value is missing.
- Gate:
  - Gate B passes when authoring persistence tests are green.
- Dependencies:
  - Phase 1.
- Parallelizable Work:
  - Options modal and adaptive authoring TypeScript work can be done concurrently after backend accepts `ai_enabled`.

## Phase 3: Delivery and Trigger Gating
- Goal: Enforce section+page gating for DOT rendering and page-trigger auto-fire behavior.
- Tasks:
  - [ ] Add delivery helper for effective page AI enablement (`ai_enabled` fallback + section gate).
  - [ ] Update lesson layout DOT render condition to use helper for all page types.
  - [ ] Update `LessonLive.possibly_fire_page_trigger/2` to skip fire when page AI disabled.
  - [ ] Ensure helper usage preserves section-disabled behavior.
- Testing Tasks:
  - [ ] Add/adjust lesson delivery tests for scored/practice override matrix and trigger behavior (`AC-006`, `AC-007`, `AC-008`, `AC-009`).
  - [ ] Command(s): `mix test test/oli_web/live/delivery/student/lesson_live_test.exs`
- Definition of Done:
  - DOT visibility and page trigger auto-fire obey both gates.
  - Existing scored/practice expectations remain stable except for explicit page override behavior.
- Gate:
  - Gate C passes when delivery tests are green.
- Dependencies:
  - Phase 1 and Phase 2.
- Parallelizable Work:
  - Delivery helper and lesson layout changes can proceed in parallel with final authoring test updates once data model work is merged.

## Parallelisation Notes
- Phase 1 must land first because all downstream phases depend on `ai_enabled` persistence.
- In Phase 2, modal and adaptive authoring work can proceed in separate tracks.
- Phase 3 can begin after Phase 1, but final verification should wait until Phase 2 is complete to validate end-to-end behavior.
