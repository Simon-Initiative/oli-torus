# Instructor Expanded LO Visualization - Product Requirements Document

## 1. Overview

MER-5814 replaces the existing expanded Learning Objective (LO) visualization in the instructor
dashboard's Insights / Learning Objectives tab with a two-dimensional Student Distribution matrix.
The current visualization plots students along a single axis (proficiency only). The new
visualization plots each enrolled student as a dot positioned by Learning Proficiency (x-axis) and
Activity Completion (y-axis), grouping students into three actionable categories — Needs Support,
Excelling, and Limited Activity — so an instructor can identify who needs intervention and what
action to take, directly from the expanded row.

## 2. Background & Problem Statement

Instructors currently see a one-dimensional proficiency distribution when they expand a Learning
Objective row: a horizontal bar with dots layered on top, split into `Not enough data`, `Low`,
`Medium`, and `High` proficiency segments. This view answers "how proficient are my students on
this objective" but not "are students who are struggling actually engaging with the material," and
it gives no explicit next-action guidance per segment.

Combining proficiency with activity completion lets an instructor distinguish, for example,
students who are working hard but still struggling (Needs Support) from students who have not yet
engaged enough to have a reliable proficiency signal (Limited Activity) — two groups that require
different instructor responses but look identical in the current one-dimensional view.

The technical investigation for this ticket is recorded in `informal.md` in this same directory
(feature slug `instructor_viz`, per Jira comment from Darren Siegel) and a Figma-derived UI brief is
recorded in `design/instructor_viz_ui_brief.md`. Both are treated as source material for this PRD
and for the FDD that follows it.

## 3. Goals & Non-Goals

### Goals
- Replace the current one-dimensional expanded LO visualization with a two-dimensional Student
  Distribution matrix (proficiency x activity completion).
- Group every enrolled student into exactly one of three categories: Needs Support, Excelling, or
  Limited Activity.
- Let an instructor select a group to see a student table with group-specific guidance, a suggested
  action, and the ability to email selected students.
- Preserve existing instructor workflows this feature depends on: email-selected-students, and the
  sub-objectives table below the expanded row.
- Meet the ticket's explicit keyboard-accessibility requirements for group selection and table
  controls.

### Non-Goals
- This ticket does not change how proficiency itself is computed (`Oli.Delivery.Metrics.student_proficiency_for_objective/2` and its High/Medium/Low labeling stay as-is).
- This ticket does not redesign the sub-objectives table that renders below the expanded
  visualization; it is expected to remain in place unchanged.
- This ticket does not introduce a new activity-completion signal beyond what is already computed by
  `Metrics.student_activities_attempted_count/3`, unless the Open Questions below are resolved in
  favor of a stricter definition before implementation begins.
- This ticket does not address responsive/mobile layout for this surface; no responsive variant was
  provided in the linked Figma designs (see Open Questions).
- This ticket does not introduce a feature flag; see Feature Flagging, Rollout & Migration.

## 4. Users & Use Cases

- Instructor viewing the Insights / Learning Objectives tab: expands a Learning Objective to
  understand how students are distributed across proficiency and activity completion, so they can
  decide who to support, encourage, or nudge toward more engagement.
- Instructor triaging a "Needs Support" group: reviews the guidance text, filters/sorts by
  proficiency, selects some or all listed students, and emails them.
- Instructor checking a "Limited Activity" group: understands that some of these students may not
  yet have a reliable proficiency estimate, and can filter the group by proficiency label (including
  "Not enough info") before deciding whether to nudge them toward completing more activities.
- Instructor scanning a large section roster: uses Load More to page through a group's student list
  without losing previously loaded rows.

## 5. UX / UI Requirements

Source of truth: Figma file `Learning Objectives Updates` (`iVKgFJwC1iKP7jmJBGILOK`), nodes
`346:6145`, `358:11956`, `349:11077`, `349:11526`, `349:11974`. Full mapping detail (tokens, icons,
component reuse, exact per-group guidance copy) lives in `design/instructor_viz_ui_brief.md` in this
same directory; this section states only the product-level UX requirements.

- The matrix is drawn as three regions, not a strict 4-quadrant grid: the low-proficiency/high-activity
  region (Needs Support) and high-proficiency/high-activity region (Excelling) sit side by side above
  the 50% activity-completion line; the entire area below that line — both proficiency sides — renders
  as one merged Limited Activity region. This is confirmed directly from the Figma layout geometry,
  not inferred from the ticket text alone.
- Each student is one dot; the current one-dimensional chart's "6+ same-value students collapse into
  one larger dot" behavior is not evidenced in the new matrix mocks at the sample data sizes shown,
  and whether that behavior still applies at scale is an open question (see below).
- Selecting a group opens a student table **beside** the chart (not below it, unlike the current
  implementation), with a header block containing: a group icon/badge, the group title, a close ("X")
  control, one to two sentences of guidance copy, an Email button, and a proficiency-filter dropdown.
  This header structure, and the specific guidance copy per group, is confirmed identical across all
  three group states in Figma.
- Table columns are: student (avatar + name + selection checkbox), Proficiency (sortable, reuses the
  existing proficiency chip presentation), and Activities (activity completion).
- A Load More affordance sits below the table.
- The sub-objectives table continues to render below the visualization/table area, unchanged.
- Accessibility: every group region must be keyboard-selectable, every table control (checkboxes,
  Email, Load More, Close) must be keyboard-navigable, and all interactive controls need a visible
  focus indicator. None of this is depicted in the static Figma frames and must be designed as part
  of implementation, following the repository's existing keyboard-interaction patterns in
  `DotDistributionChart`.

## 6. Functional Requirements
Requirements are found in requirements.yml

## 7. Acceptance Criteria (Testable)
Requirements are found in requirements.yml

## 8. Non-Functional Requirements

- Accessibility: WCAG 2.1.1 (Keyboard) for group selection and all table controls; WCAG 2.4.7 (Focus
  Visible) for all interactive controls in the visualization and table.
- Performance: the expanded-row data load must not introduce new runtime scans of
  `revisions.objectives`, `published_resources`, or `section_resources` JSONB. Per `informal.md`, the
  linked-activity denominator must be derived from `SectionResourceDepot` cached section-resource
  reads (a zero-database-query path once the section depot is initialized), and the per-student
  activity numerator must remain a single aggregate query
  (`Metrics.student_activities_attempted_count/3` or its adapted equivalent) that returns only
  `{student_id, count}` pairs, never raw `resource_summary` rows.
- Data integrity: group assignment must be computed from one centralized, pure function so the chart
  and the student table cannot disagree about which group a student belongs to; every enrolled
  student must resolve to exactly one group.
- Consistency with existing proficiency presentation: the Low/Medium/High proficiency chip and its
  color tokens (`lib/oli_web/components/delivery/learning_objectives/proficiency.ex`) must not change
  as part of this ticket; only how students are grouped into matrix regions is new.

## 9. Data, Interfaces & Dependencies

- `Oli.Delivery.Sections.enrolled_student_ids/1` — enrolled student universe (unchanged dependency).
- `Oli.Delivery.Metrics.student_proficiency_for_objective/2` — numeric proficiency per student
  (unchanged dependency).
- `Oli.Delivery.Metrics.student_activities_attempted_count/3` — aggregate attempted-activity counts
  per student; the linked-activity ID list passed into this function must be widened for top-level
  objectives to include the union of the parent objective's and its sub-objectives' `related_activities`,
  not just the parent's direct array (see `informal.md`, "Derive Linked Activities From Depot Only").
- `SectionResourceDepot.get_resources_by_ids/2` and
  `SectionResourceDepot.objectives_with_effective_children/1` — cached section-resource reads used to
  resolve the unique linked-activity denominator without a database round trip.
- New: a centralized group-assignment helper (pure Elixir function) producing a `distribution_group`
  field (`:needs_support | :excelling | :limited_activity`) per student, consumed by both the chart
  data and the student table filter.
- `OliWeb.Components.Delivery.Students.EmailButton` and the existing email-modal forwarding path
  through `LearningObjectives` / `DraftEmailModal` — reused, not replaced.
- Frontend: LiveReact-mounted React/SVG component (new, superseding or replacing
  `assets/src/components/misc/DotDistributionChart.tsx`), following the existing Vega-Lite (stable
  chart scaffolding) + React/SVG (interactive overlay) hybrid pattern, registered in
  `assets/src/apps/Components.tsx`.

## 10. Repository & Platform Considerations

- Surface is `mixed`: Elixir/LiveView (`OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView`
  and the student table component) plus a React/TypeScript chart mounted via
  `OliWeb.Common.React.component/4`.
- Follows the existing expanded-row lifecycle: analytics load only when a row is expanded, async
  loading forwarded through the root instructor dashboard LiveView via `send_update/3`.
- No new shared `design_tokens/` primitive is proposed; `lib/oli_web/components/design_tokens/`
  currently contains only a `Button` primitive, and this feature's new pieces (matrix chart,
  group-based table) are specific to this analytics surface rather than generic cross-feature UI, per
  `design/instructor_viz_ui_brief.md`.
- Token, color, spacing, and typography needs are already covered by existing design tokens (see the
  UI brief's Token Mapping section); no new tokens are required.
- Test layers per `docs/TESTING.md`: ExUnit for the new pure group-assignment function and any
  changed `Metrics` query behavior; `Phoenix.LiveViewTest` for `ExpandedObjectiveView` state
  transitions (select/switch/close/load-more); Jest for the new React chart component's client-side
  logic (dot layout, group hit-testing, keyboard handling).

## 11. Feature Flagging, Rollout & Migration

No feature flags present in this work item. This is a full replacement of the current expanded
visualization; the ticket does not request staged exposure, and `harness.yml` defaults feature flags
to excluded unless a work item specifically calls for one. Rollout follows the normal deployment
pipeline (merge to `master` promotes to the test environment; a tagged release promotes to
production), per `docs/OPERATIONS.md`.

## 12. Telemetry & Success Metrics

- Emit telemetry (AppSignal-visible, per `docs/OPERATIONS.md`) for: group-selection events (which
  group, section, objective), Email-from-group usage, and Load More usage, to understand whether
  instructors act on the new grouping.
- Instrument the expanded-row data-load path (depot reads + the student activity aggregate query)
  with existing Phoenix/Ecto telemetry so a performance regression relative to the current
  `DotDistributionChart` load path would be visible in AppSignal.
- Success signal: instructors who expand a Learning Objective go on to select at least one group and
  either email students or open a sub-objective, at a rate comparable to or better than current usage
  of the existing proficiency-segment selection and student table.

## 13. Risks & Mitigations

- Risk: the "Medium proficiency can live in either Needs Support or Excelling" nuance from Jess
  Fortunato's Jira comment is easy to implement inconsistently between the chart and the table.
  Mitigation: centralize group assignment in one pure function (Non-Functional Requirements,
  Data/Interfaces) so both surfaces read the same computed `distribution_group`.
- Risk: replacing a visualization instructors already rely on, with no feature flag, means any defect
  ships directly to all instructors. Mitigation: rely on the layered test plan (QA Plan) and the
  repository's normal code-review gate (`docs/CODEREVIEW.md`, `.review/ui.md` and
  `.review/requirements.md` specifically) before merge.
- Risk: the activity-completion definition (attempted-at-least-once vs. a stricter "completed" signal)
  is unresolved; shipping against the wrong definition would misclassify students into the wrong
  group. Mitigation: this PRD adopts the existing attempted-activity proxy as the MVP definition (see
  Open Questions & Assumptions) and calls it out explicitly so the FDD and plan can revisit it if
  product disagrees before implementation starts.
- Risk: no Figma frame documents the empty-state, keyboard-focus, or responsive states the ticket's
  own acceptance criteria and accessibility guidelines require. Mitigation: these are called out as
  explicit open questions rather than silently implemented from guesswork.

## 14. Open Questions & Assumptions

### Open Questions
- What is the approved, final definition of "Activity Completion": attempted at least once (current
  proxy), submitted, page-completed, or scored completion? (Carried over from `informal.md`.)
- Where should a student with "Not enough data" proficiency (fewer than 3 first attempts) but high
  activity completion (>= 50%) be classified — Needs Support, or somewhere else? The ticket and Figma
  designs do not address this combination.
- Should a student with `total_related_activities == 0` be placed in Limited Activity (this PRD's
  working assumption), or should that be a distinct "no linked activities" empty/edge state?
- Are the 50% boundaries for proficiency and activity completion inclusive or exclusive at exactly
  50% (`>= 50%` vs `> 50%`)? Low product risk, but needs a definitive answer before writing boundary
  tests.
- Should the group-based student table page from the server, or is loading all students for the
  expanded objective (then paging client-side via Load More) acceptable for expected section sizes?
- Does the current `DotDistributionChart` behavior of collapsing 6+ same-value students into one
  larger dot still apply to the new matrix, or does the new design always render one dot per student
  regardless of density?
- Does the per-group header badge icon actually differ by group, or only its color/background — the
  Figma component instance name (`Badge/Unread-Messages`) is identical across all three group states
  at the metadata level, and this was not confirmed with a rendered screenshot.
- Is there a responsive/narrow-viewport variant expected for this surface? No such Figma frame was
  linked or found nearby the linked nodes.

### Assumptions
- Group assignment on the chart's x-axis split uses the student's continuous numeric proficiency
  percentage against a 50% threshold (Needs Support = below 50%, Excelling = 50% or above), which is
  a distinct axis from the existing Low/Medium/High proficiency *label* thresholds (Low <= 40%, Medium
  <= 80%, High > 80%, per Jess Fortunato's comment). This reconciles the ticket's literal "Proficiency
  above/below 50%" group definition with her comment that "Medium proficiency can be included in
  Needs Support or Excelling as well," and with the ticket's own filter language ("since medium & low
  proficiencies can live here" for Needs Support, "since medium & high" for Excelling) — both can only
  be true if the group split is on the raw percentage, not the display label.
- A student with `total_related_activities == 0` is treated as 0% activity completion and therefore
  falls into Limited Activity, pending confirmation (see Open Questions).
- Activity Completion for MVP purposes is the existing "attempted at least one first attempt on a
  linked activity" proxy already implemented by `Metrics.student_activities_attempted_count/3`, i.e.
  `activities_attempted_count / total_linked_activity_count`, pending confirmation (see Open
  Questions).
- No feature flag is required for this rollout (see Feature Flagging, Rollout & Migration).
- The sub-objectives table's current position, data, and behavior are unaffected by this ticket.

## 15. QA Plan

- Automated validation:
  - ExUnit coverage for the new group-assignment helper: boundary tests at the 50% proficiency and
    50% activity-completion thresholds, the `total_related_activities == 0` case, and the "Not enough
    data" + high-activity case once the corresponding open question is resolved.
  - `Phoenix.LiveViewTest` coverage for `ExpandedObjectiveView` (or its adapted successor) covering:
    default state, group selection, switching groups without closing, closing via "X", closing via
    re-clicking the selected group, empty-group selection, and Load More append behavior.
  - Jest coverage for the new React/SVG chart component: dot placement by proficiency/activity input,
    group hit-area selection, keyboard activation of group regions, and the `pushEventTo` payload
    shape sent back to LiveView.
  - `Oli.Analytics.Summary.Metrics`-level tests confirming the widened linked-activity denominator
    (parent + sub-objectives, deduplicated) and that the aggregate attempted-count query still returns
    only `{student_id, count}` pairs.
- Manual validation:
  - Keyboard-only walkthrough of group selection and all table controls, confirming visible focus
    indicators, against `.review/ui.md`.
  - Visual comparison against the five linked Figma nodes for the default state and each of the three
    group states, including guidance copy accuracy.
  - Email-selected-students flow from a group table, confirming the existing modal plumbing still
    works unchanged.
- Code review: per `docs/CODEREVIEW.md`, `.review/security.md` and `.review/performance.md` always
  apply; `.review/elixir.md`, `.review/typescript.md`, `.review/ui.md`, and `.review/requirements.md`
  apply given this ticket's LiveView, React, UI, and PRD-traceability surface area.

## 16. Definition of Done

- [ ] PRD sections complete
- [ ] requirements.yml captured and valid
- [ ] validation passes
