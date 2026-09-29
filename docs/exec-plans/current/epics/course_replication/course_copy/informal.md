# Independent Course Copy - Informal Feature Context

Last updated: 2026-09-29

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
| Content / curriculum **(Required)** — locked checked | `:content` |
| Schedule | `:schedule` |
| Assessment settings (includes availability & due dates) | `:assessment_settings` |
| Course features (AI Assistant, Notes, Course Discussions) | `:section_settings` **and** `:ai_settings` together |

**Resolved 2026-09-29** (Slack, Laura Delince — PO, standing in for Jess): Content/curriculum
is mandatory by product decision, not just as a side effect of the backend constraint — "there
is nothing to copy over as everything else is content-dependent-or-related." The checkbox label
must read **"Content / curriculum (Required)"** so it's visually clear it can't be unchecked and
why (currently reads just "Content / curriculum" with no such annotation — label text change
needed, not yet implemented).

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
  "instructor-owned section settings" umbrella (see "Open decisions" below — still unconfirmed
  with the PO).

### Default checkbox state (when "Choose what to copy" is selected)

**Resolved 2026-09-29** (Slack, Laura Delince): only **Content / curriculum** is checked by
default; Schedule, Assessment settings, and Course features start unchecked (matches Figma node
`40:2747`, and matches the already-implemented interim default). This is a real behavior change
from MER-5831's original inline UI, which defaulted every optional checkbox to checked.

Additional requirement confirmed in the same reply, already implemented but now confirmed
intentional rather than interim: when **"Copy entire course"** is selected, all four checkboxes
(box, border, checkmark, and label text) must render visually muted/disabled — "these options
should not be enabled until [Choose what to copy] is selected." No further change needed here.

### Wizard steps after the modal

**Resolved 2026-09-29** (Slack, Laura Delince) — reverses the previous "best reading" below:
clicking **"Create Section"** in the modal must end the workflow right there. It does **not**
proceed into wizard steps "Name your course" / "Course details" — it creates the new section
immediately, carrying over the source section's own details (Laura's examples: "starting and
ending date and title, but with a Copy on the course title"). Rationale: "an instructor wanting
to copy a course section is not the same as an instructor wanting to go and set up a new course
section then and there" — the copy flow should let the instructor finish without being routed
through unrelated setup screens.

This was a real scope/architecture change, not just a button-label swap — **implemented
2026-09-29**:

- `@course_destination_fields` in `section_copy.ex` (title, course_section_number,
  class_modality, class_days, start_date, end_date, preferred_scheduling_time, timezone,
  context_id) was documented as "owned by the new course rather than copied from the source" —
  no `CopyOptions` group touches them, and the wizard used to be the only thing that ever filled
  them in. For a section-source copy this no longer holds: every one of those fields except
  `context_id` (LTI-specific, not part of "the source section's own details") now comes straight
  from the source section, via `attrs_from_source_section/1` in `new_course.ex`. `title` gets a
  `"(copy)"` suffix; everything else (`course_section_number` included, per an explicit decision
  to copy it verbatim rather than leave it ambiguous or blank, given it isn't system-enforced as
  unique and isn't displayed anywhere in the app today — see the resolved item below) carries
  over unchanged.
- `confirm_copy_modal` no longer advances to `current_step: 1` for a section source — it loads
  the source section (`Sections.get_section!/1`) and calls section creation directly (the same
  `do_create_section/2` path the final wizard step already used), passing those source-derived
  attrs instead of the (never-filled, for this flow) wizard changeset.
- Template/Project sources are unaffected — they never open this modal and still go through the
  full wizard as before; this change is scoped entirely to the My Course Sections copy flow.

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
- Treatment of external integrations, identifiers, and publication state.
- Whether large copies require background operations and progress status.
- Whether "Course features" can implicitly cover the rest of `:section_settings`'s field list
  that the modal's label doesn't explicitly name (custom unit/module numbering, welcome
  message, agenda, certificate settings) — not yet asked/confirmed with the PO.

Resolved 2026-09-29 (Slack, Laura Delince — PO, standing in for Jess, who returns week of the
12th): default checkbox state when "Choose what to copy" is selected (only Content checked);
all four checkboxes visually muted/disabled when "Copy entire course" is selected; Content /
curriculum is mandatory by product decision and its label must read "Content / curriculum
(Required)"; and "Create Section" ends the workflow immediately for a section-source copy
rather than continuing into wizard steps 2/3 (Template/Project sources are unaffected).

Resolved 2026-09-29 (follow-up decision, pending final PO sign-off but implemented in the
interim): `course_section_number` is not required or unique-enforced anywhere in the system
(no DB constraint, optional in the changeset) and isn't displayed anywhere in the app after
creation — so, consistent with "copy the source as closely as possible," it copies verbatim
from the source along with every other course-destination field, same as `class_modality`,
`class_days`, `preferred_scheduling_time`, and `timezone`.
