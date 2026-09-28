# Independent Course Copy - Informal Feature Context

Last updated: 2026-09-28

This feature delivers one-time Course Copy from an instructor's existing course section. It is intentionally independent from Blueprint synchronization.

## Source tickets

- `MER-5831` Course Copy: Rules — **implemented and merged** (PR #6855). Delivered the
  `Oli.Delivery.Sections.CopyOptions` / `SectionCopy` / `SectionResourceCopy` engine with
  five allowlisted groups (`:content`, `:schedule`, `:section_settings`,
  `:assessment_settings`, `:ai_settings`), plus a first-pass inline checkbox UI at the
  bottom of the "Name your course" wizard step (`lib/oli_web/live/new_course/name_course.ex`).
  That inline UI is superseded by MER-5832's modal — see below.
- `MER-5832` Course Builder: Selecting a section to copy — **in progress**. Also delivered:
  the My Course Sections tab, its hover state, and the shared source-card grid (all via
  MER-5828, see `../course_builder_sources/`). Remaining scope is the copy-choice **modal**
  described below.
- Epic context: `../informal.md`
- Parent lane plan: `../plan.md`

## Product outcome

An instructor can use the current state of an eligible course section as the starting point for a new, independent section. The instructor may copy the entire course or a supported subset of settings, then customize the result without affecting or receiving updates from the source.

## Functional scope

- Define eligible My Course Sections for the current instructor. — done (MER-5828).
- Support full-course point-in-time copying. — done (MER-5831 backend).
- Support selected-settings copying, via four instructor-facing categories: content/curriculum,
  schedule, assessment settings, and course features (AI Assistant, Notes, Course
  Discussions, Cover image, and the rest of instructor-owned section settings — see
  "Copy-modal category mapping" below for the exact backend correlation).
- Create a new independent section with no parent/child or live synchronization relationship.
- Keep source and copy independently editable after creation.
- Exclude rosters, enrollments, attempts, progress, grades, submissions, discussion participation, analytics, and all other learner-generated data.
- Provide clear copy success, validation, stale-source, and failure messaging.

## MER-5832 scope: the copy-choice modal

Selecting a My Course Sections card must open a modal (not advance directly into the wizard)
that lets the instructor choose the copy scope before continuing. Design references (Figma,
`ZAfwBt1ek94xAyriR6wy8S`):

- Light, "Copy entire course" selected (checkboxes disabled): node `40:2695`
- Light, "Choose what to copy" selected (checkboxes enabled): node `40:2747`
- Dark, "Copy entire course": node `40:2506`
- Dark, "Choose what to copy": node `40:2623`
- Card hover state: node `44:1311`
- Additional reference: node `40:1106`

Implementation constraints:

- Reuse Torus's existing modal component/convention (`OliWeb.Common.Modal`, already used by
  `overview_view.ex`/`details_view.ex` in this codebase) — do not hand-roll a modal. Centered,
  backdrop-blurred, matching every other Torus modal.
- Visual fidelity to the four Figma nodes above is the primary bar for this ticket — this is
  the one substantial piece of new UI work; the supporting logic is mostly wiring.
- Radio choice ("Copy entire course" / "Choose what to copy") is a **new** UI concept — it does
  not exist in MER-5831's current inline checkboxes, which expose the groups as independently
  toggleable checkboxes with no "entire course" shortcut.

### Copy-modal category mapping

Figma's modal shows exactly four checkboxes, one fewer than MER-5831's current five. Verified
against `section_copy.ex` / `section_resource_copy.ex` (not assumed) that **no backend change
is required** — the existing five `CopyOptions` groups stay as-is; only the UI-layer mapping
from checkbox to group(s) changes:

| Modal checkbox (Figma) | `CopyOptions` group(s) selected |
|---|---|
| Content / curriculum (mandatory, always checked) | `:content` |
| Schedule | `:schedule` |
| Assessment settings (includes availability & due dates) | `:assessment_settings` |
| Course features (AI Assistant, Notes, Course Discussions) | `:section_settings` **and** `:ai_settings` together |

Notes on why "Course features" maps to two groups instead of being its own group:

- Martin's original tech note anticipated this: "This allows the initial UI to offer broader
  choices while keeping the backend extensible as those groups are refined." Coarsening at the
  UI layer while keeping the backend's five groups granular/separate was chosen over renaming or
  merging `:section_settings` + `:ai_settings` into one backend group, to avoid touching the
  already-shipped, already-tested MER-5831 backend without a concrete need.
- "Notes" and "Course Discussions" are not standalone `Section` boolean fields — both derive
  from per-page `collab_space_config`, and `section_resource_copy.ex` gates that column
  explicitly on `:section_settings` (`@section_settings_revision_derived`), not `:content`.
  So `:content` alone (even though it's always copied) does **not** carry Notes/Discussions
  state — `:section_settings` must also be selected, confirming it belongs under "Course
  features" rather than being left out.
- `:section_settings`'s field list (`@section_settings_fields` in `section_copy.ex`) already
  includes `:cover_image`, so "Course features" naturally covers the ticket's "Cover image"
  mention without further changes. It also carries fields the modal's label doesn't explicitly
  name — `description`, custom unit/module numbering, `welcome_title`/`encouraging_subtitle`,
  `agenda`, `brand_id`, and certificate settings — treated as included under the same
  "instructor-owned section settings" umbrella (open decision #1 below asks the PO to confirm
  this reading).

### Default checkbox state (when "Choose what to copy" is selected)

Only **Content / curriculum** is checked by default; Schedule, Assessment settings, and Course
features start unchecked (matches Figma node `40:2747`). This is a real behavior change from
MER-5831's current inline UI, which defaults every optional checkbox to checked. See open
decision #2.

### Wizard steps after the modal

Current best reading (backed by code, not yet confirmed with the PO — see open decision #3):
selecting a copy scope in the modal does **not** skip the wizard's "Name your course" /
"Course details" steps. `@course_destination_fields` in `section_copy.ex` (title,
course_section_number, class_modality, class_days, start_date, end_date,
preferred_scheduling_time, timezone, context_id) is explicitly documented as "owned by the new
course rather than copied from the source" — no `CopyOptions` group touches them, so the
backend already assumes they're always filled fresh via the wizard. The AC's "Default name of
copy should be 'course name (copy)' **in course setup wizard**" supports this: the wizard still
runs, only the suggested title defaults to `"<source title> (copy)"` instead of blank. The
open question is specifically about the modal's Figma button being labeled "Create Section"
rather than "Next step", which could (but is not currently believed to) mean the modal
short-circuits straight to creation.

## Technical guidance

Use an explicit source-data allowlist and learner-data denylist. Validate selected categories server-side; do not accept arbitrary client-selected fields. Recheck source eligibility and authorization when the copy request is submitted.

Use existing Resource/Revision/Publication conventions where appropriate, but ensure no Blueprint metadata or source relationship is retained. The operation should be transactional or expose durable operation status and resumable/retryable behavior so partial copies are not presented as valid courses. Define how identifiers, names, dates, integrations, external LMS/LTI settings, publication state, and section metadata are generated or retained.

## Out of scope

- Blueprint source/child synchronization; see `../blueprint_lifecycle/`.
- Shared course-builder filtering and card layout; see `../course_builder_sources/`.

## Dependencies and handoff

- Hard dependency on `../replication_contracts/` for copy boundaries and learner-data exclusion.
- `../course_builder_sources/` consumes the My Course Sections query and copy initiation contract.
- Coordinate terminology and shared card primitives with the Blueprint features without sharing relationship semantics.

## Verification expectations

- Full and selective copy integration tests.
- Tests proving source/copy independence after both are edited.
- Tests proving no learner-generated data crosses the boundary.
- Authorization and eligibility tests for My Course Sections.
- Failure, retry, stale-source, and partial-copy tests.
- Accessible copy modal and keyboard workflow tests.

## Open decisions

- Whether “created by the current instructor” means creator, owner, institution, or permission-based eligibility.
- Exact selective-copy categories and the meaning of content/curriculum.
- Treatment of external integrations, identifiers, dates, and publication state.
- Whether large copies require background operations and progress status.
