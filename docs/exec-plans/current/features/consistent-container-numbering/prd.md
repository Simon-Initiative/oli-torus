# Consistent Suppressed Unit Numbering Across Course Views - Product Requirements Document

## 1. Overview
Sections can suppress numbering for one or more top-level units (`section.unnumbered_unit_ids`), which shifts the visible numbers of the remaining, numbered units. The student Learn view already computes this "display numbering" correctly. Twelve other instructor-, student-, and system-facing surfaces instead show the raw, unsuppressed canonical numbering for the same units, modules, and sections, so the same container carries two different numbers depending on which screen an instructor or student is looking at (for example, a unit shown as "Unit 1" on Learn appears as "Unit 2" in Student Exceptions). This work item makes container numbering (unit/module/section labels) consistent everywhere a section's course structure is rendered, replaces every remaining raw-numbering read path with the suppression-aware "display numbering," and corrects the numbering already cached for sections that have suppressed units in production today.

## 2. Background & Problem Statement
`Oli.Delivery.Sections.DisplayNumbering.decorate_hierarchy/2` is the one function in the codebase that knows how to recompute unit/module/section numbers when a section's `unnumbered_unit_ids` excludes one or more top-level units from numbering. It produces a `display_numbering` value on each hierarchy node while leaving the canonical `numbering` untouched, and the student Learn view (and student Schedule) already consume `display_numbering` correctly.

Reported symptom (MER-5871 / TRIAGE-2413): in a section that excludes an introductory unit from numbering, Learn correctly shows the next unit as "Unit 1," but the Student Exceptions / Assessment Settings assessment selector shows the same unit's checkpoint as "Unit 2," because `AssessmentSettings.get_assessments/2` builds its labels from raw `SectionResource.numbering_index` via `Sections.get_parent_containers_map/2` and `Sections.name_with_container_label/3`, bypassing `DisplayNumbering` entirely. Instructors looking for "Unit 1" cannot find it, because the same content is labeled "Unit 2" elsewhere.

A linked triage ticket and a prior LLM-assisted code analysis (attached as a Jira comment, independently verified against the current codebase) identified this same raw-numbering pattern in ten additional surfaces spanning Grade Sync, the section Scheduling editor, several Instructor Dashboard views (scored/practice/survey pages and their CSV export, the Content "Order" column, and container navigators/selectors reused across Content, Learning Objectives, Student Insights, and the Intelligent Dashboard), the Student Insights container heading, the Intelligent Dashboard assessment context, the AI Dialogue course-layout context, Student Progress breadcrumbs, and the legacy Course Content / page-delivery navigation hierarchy. All eleven locations were confirmed by direct code inspection; no false positives were found in the prior analysis, and two additional occurrences of the same bug pattern (a sibling function in the AI Dialogue module, and the resolution mechanism underlying the legacy Course Content hierarchy) were found during verification. Locations that only use raw numbering for sorting, or that belong to the authoring side of the product (where `unnumbered_unit_ids` does not apply), are explicitly out of scope.

A twelfth surface was found while resolving open questions during technical design: `Oli.Delivery.Hierarchy.thin_hierarchy/3`, a shared helper that reduces a decorated hierarchy to a fixed allowlist of fields for two callers, omits `display_numbering` from both allowlists. One caller feeds the Instructor Page Preview outline; the other feeds the student Lesson page's own table-of-contents drawer (`outline_component.ex`), which already contains the correct suppression-aware rendering logic but silently falls back to raw numbering because the field it needs was stripped before it ever saw the data. This is the same root-cause family as the other eleven (decorated data computed correctly upstream, then lost before rendering), located through the same "trace to the actual render path" discipline applied to the rest of this work item, and is treated as a single functional requirement covering both call sites since the fix is one shared change.

One of these locations is more than a code defect: `Hierarchy.build_navigation_link_map/1` builds the data that gets persisted on `section.previous_next_index`, a cached structure rebuilt only when explicitly invalidated. Sections that already have suppressed units in production today have this cache populated with the old, incorrect numbers, and fixing the code path alone will not correct their cached data until something else happens to invalidate it. A one-time, narrowly targeted data correction is required so currently affected sections are fixed without waiting for an unrelated content edit to happen to invalidate their cache.

## 3. Goals & Non-Goals
### Goals
- A given unit, module, or section carries exactly one visible number across every course view a section exposes it in, matching what the student Learn view shows for that same container.
- Every identified raw-numbering read path (see Section 6 / `requirements.yml`) is replaced with the suppression-aware display numbering already produced by `DisplayNumbering.decorate_hierarchy/2`.
- Sections that already have suppressed units in production are corrected without requiring an instructor to make an unrelated edit to trigger a cache rebuild.
- The fix generalizes: a new surface that needs to render container numbering can reuse an established, tested pattern instead of re-implementing raw-numbering lookups.

### Non-Goals
- Changing how instructors configure `unnumbered_unit_ids` (the suppression feature's configuration UI/workflow is unchanged).
- Changing canonical/authoring-side numbering, which is unaffected by delivery-time suppression.
- Introducing new instructor-facing numbering controls or display options.
- Changing frontend TypeScript behavior for the Scheduling editor; the fix is server-side only because the client already renders whatever numbering the server sends.
- Correcting raw-numbering usages that only affect sort order rather than a displayed label.

## 4. Users & Use Cases
- Instructor configuring assessment exceptions or scheduling: sees the same unit number in Assessment Settings, Student Exceptions, Grade Sync, and the Scheduling editor as they see (or as students see) on Learn, so they can locate the right unit without cross-referencing.
- Instructor reviewing the Instructor Dashboard (Content, Learning Objectives, Student Insights, Intelligent Dashboard, scored/practice/survey page views, CSV exports): sees container numbers and navigators that match Learn.
- Student viewing Course Content in the Student Dashboard, or viewing per-student progress breadcrumbs: sees unit/module numbers consistent with what they see elsewhere in the course.
- Student or instructor interacting with the AI dialogue assistant: receives references to units/modules that match the numbers they see on screen, rather than numbers that don't exist from their point of view.
- Student reading a lesson page: the table-of-contents drawer they open mid-lesson shows the same unit/module numbers as the Learn page they navigated from.
- Instructor previewing course content before or during delivery: the preview outline shows the same numbers students will see, so preview accurately represents the learner experience.
- Platform operator: existing sections with suppressed units self-correct once, without manual per-section intervention.

## 5. UX / UI Requirements
- No new UI elements, controls, or visual patterns are introduced. Every affected screen keeps its current layout and interaction model; only the numeric/label value shown for a unit, module, or section container changes to match Learn.
- Where a container's numbering is fully suppressed (i.e., the container itself is an unnumbered top-level unit or a descendant of one), the affected surfaces must omit the number the same way Learn does (title only, no "Unit N" prefix), rather than showing a stale or placeholder number.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements
- Correctness/reliability: numbering shown for a given container must be deterministic and identical across all in-scope surfaces for the same section state; this is a data-correctness fix, not a UI redesign.
- Performance: surfaces that move from a narrow, page-scoped SQL lookup to a full decorated course hierarchy must not introduce materially higher latency for typical course sizes; reuse an existing proven hierarchy-decoration pattern (`DisplayNumbering`, sourced through the `SectionResourceDepot` cache per `.review/performance.md`'s Torus-specific delivery-caching rule) rather than re-deriving a new, unproven hierarchy-walking approach per surface.
- Data safety: the targeted data correction for `section.previous_next_index` must only touch sections where `unnumbered_unit_ids` is non-empty, must not delete or corrupt any other section data, and must be safe to run against production (idempotent, resumable if interrupted).
- Backward compatibility: sections without any suppressed units must render identically before and after this change; this work must not alter numbering for the common case where no unit numbering is suppressed.

## 9. Data, Interfaces & Dependencies
- Core dependency: `Oli.Delivery.Sections.DisplayNumbering.decorate_hierarchy/2` and the `display_numbering` field it adds to hierarchy nodes; this work reuses that existing mechanism rather than introducing a second numbering system.
- Reference implementation pattern to reuse/extend: `Sections.fetch_ordered_container_labels/2` (`MinimalHierarchy.full_hierarchy/1` + `DisplayNumbering.decorate_hierarchy/2`, consumed via `node.display_numbering` with fallback to `node.numbering` when `:not_set`), and `display_numbering_or_numbering/1` as already used in `learn_live.ex` and `outline_component.ex`.
- Data touched: no schema changes are anticipated. The data correction affects only the existing `previous_next_index` column on `Section` (set to `nil` for qualifying sections to trigger the existing just-in-time rebuild in `PreviousNextIndex.retrieve/2,3`).
- External interfaces: the Scheduling editor API response (`scheduling_controller.ex`) changes its served `numbering_index`/`numbering_level` values for affected sections; the existing frontend (`ScheduleLine.tsx`, `ScheduleSlideout.tsx`) already renders whatever the server sends, so no frontend contract change is needed.
- CSV export interface (`delivery_controller.ex` page-title CSV export) changes the container label text it emits for affected sections.
- `Oli.Delivery.Hierarchy.thin_hierarchy/3` is a shared field-allowlist helper with exactly two callers (Instructor Page Preview, student Lesson table-of-contents drawer); both allowlists must retain `display_numbering` so the existing `display_numbering_or_numbering/1` consumer pattern (already correct) receives the field it looks for instead of silently matching its raw-numbering fallback clause.

## 10. Repository & Platform Considerations
- Backend-only change set, entirely within `lib/oli/delivery/` (domain logic: `Sections`, `Settings`, `Hierarchy`, `PreviousNextIndex`, `MinimalHierarchy`, `DisplayNumbering`), `lib/oli/instructor_dashboard/`, and `lib/oli_web/` (LiveViews, controllers, and view helpers that render the affected surfaces), consistent with the existing domain-context boundaries described in `docs/BACKEND.md`.
- No `assets/src/` changes are required per the current analysis; if implementation work later finds a surface that computes numbering client-side rather than rendering a server-provided value, that finding should be reconciled against this PRD's scope before proceeding.
- The data correction should be implemented as a standard Ecto data migration under the existing migration workflow, scoped by a `WHERE unnumbered_unit_ids <> '{}'`-style predicate (or the section-level equivalent), not a blanket rewrite of all sections.
- Because the underlying fix touches several independent LiveViews, controllers, and one context module cluster, implementation should be organized into discrete, independently testable phases (see `plan.md`) rather than a single monolithic change, to keep review and regression risk manageable per `docs/CODEREVIEW.md`.

## 11. Feature Flagging, Rollout & Migration
No feature flags present in this work item.

Migration: a targeted Ecto data migration invalidates (`nil`s out) `previous_next_index` for sections where `unnumbered_unit_ids` is non-empty, so those sections rebuild their cached navigation index (via the existing just-in-time mechanism in `PreviousNextIndex.retrieve/2,3`) using the corrected numbering on next access. The migration must not touch sections with no suppressed units.

## 12. Telemetry & Success Metrics
- No new telemetry instrumentation is required beyond what already exists; rely on standard AppSignal/Phoenix error and latency monitoring (`docs/OPERATIONS.md`) for the affected controllers and LiveViews during and after rollout.
- Success signal: zero open reports of unit/module/section numbering mismatches between Learn and any other in-scope surface for sections using `unnumbered_unit_ids`, and no AppSignal error-rate or latency regression on the affected endpoints/LiveViews after deployment.
- The data migration's own execution (number of sections updated) should be visible in its migration output/logs for operational confirmation that it ran and touched the expected scope.

## 13. Risks & Mitigations
- Risk: replacing narrow, page-scoped SQL lookups with a full decorated hierarchy build (Group B surfaces) could add latency for very large courses. Mitigation: `Sections.decorated_numbering_map/1` sources its data through the `SectionResourceDepot` cache (not a fresh query) and reuses the already-proven `DisplayNumbering` decoration mechanism; verify latency is acceptable during implementation and QA rather than introducing an unproven new query shape.
- Risk: the `previous_next_index` data correction is a production data migration; an overly broad predicate could force unnecessary rebuilds across sections that do not have the bug. Mitigation: scope the migration strictly to sections with non-empty `unnumbered_unit_ids`, and treat the rebuild as safe/idempotent since it is the same just-in-time mechanism already used whenever this cache is naturally invalidated today.
- Risk: because the same root-cause fix is applied independently across ~11 call sites in three different code patterns (Group A/B/C), a partial implementation could leave some surfaces fixed and others not, re-creating the original inconsistency in a new form. Mitigation: track each surface as its own requirement/acceptance criterion in `requirements.yml` so completion is explicit and verifiable per surface, not just "the ticket is done."
- Risk: the AI Dialogue course-layout context change affects what the AI assistant tells students/instructors about course structure; an error here is harder to notice than a UI label. Mitigation: cover this surface with an explicit automated test asserting the generated course-layout text matches Learn's numbering.

## 14. Open Questions & Assumptions
### Open Questions
- None outstanding; scope, the migration approach, and the harness lane were explicitly confirmed with the requester before this PRD was drafted.

### Assumptions
- The eleven surfaces and root-cause groupings (A: shared `get_parent_containers_map`/`name_with_container_label`; B: independent raw SQL/container queries; C: already-decorated hierarchies read via the wrong field) identified through direct code inspection are the complete set of user-visible, in-scope locations; any further location discovered during implementation should be evaluated against this PRD's scope criteria (displayed container label, not sort-only, not authoring-side) and added as a new requirement rather than silently folded in or silently dropped.
- `display_numbering` surviving unmodified through `Numbering.renumber_hierarchy/1` (verified by code inspection) means the legacy Course Content / `previous_next_index` fix does not require changing the renumbering algorithm itself, only which field `build_navigation_link_map/1` reads.
- No section currently relies on the raw (non-suppressed) numbering being shown in any of the eleven identified surfaces as intentional behavior; all are treated as defects relative to Learn's behavior.

## 15. QA Plan
- Automated validation:
  - ExUnit unit tests for the shared/reused numbering-resolution helper(s) (Group A and any new Group B helper), covering: no suppressed units (unchanged behavior), a suppressed top-level unit with numbered siblings, and a page/module nested under a suppressed unit.
  - ExUnit/Phoenix.LiveViewTest coverage for each affected LiveView (Assessment Settings, Student Exceptions, Grade Sync, Instructor Dashboard scored/practice/survey pages, Content, Student Insights, Intelligent Dashboard) asserting the rendered label matches Learn's for the same container in a section with suppressed units.
  - Controller tests for the Scheduling editor API response and the CSV export endpoint asserting suppression-aware numbering.
  - A test for the AI Dialogue course-layout context asserting generated text uses suppression-aware numbering.
  - A migration test verifying only sections with non-empty `unnumbered_unit_ids` have `previous_next_index` invalidated, and that other sections are untouched.
  - An `Oli.Scenarios` integration test exercising authoring -> publish -> section with `unnumbered_unit_ids` set -> verifying numbering consistency across at least Learn, Assessment Settings, and one Instructor Dashboard surface, per `docs/TESTING.md` guidance for workflow-level regression risk.
- Manual validation:
  - Reproduce the exact reported scenario (a section with an unnumbered introductory unit, e.g. the Chem 102 section referenced in the ticket) and visually confirm matching unit numbers across Learn, Student Exceptions, Assessment Settings, Grade Sync, Scheduling, Instructor Dashboard (Content, scored/practice/survey pages, Student Insights, Intelligent Dashboard), Student Dashboard Course Content, Student Progress, and the AI dialogue assistant's course references.
  - Confirm a section with no suppressed units renders unchanged across all of the above surfaces.

## 16. Definition of Done
- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
