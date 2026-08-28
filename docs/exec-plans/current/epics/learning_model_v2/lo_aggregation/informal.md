# MER-5821: Aggregate Child Learning Objective Proficiency into Parent Learning Objectives

This work item is the second of the three `learning_model_v2` "usage" concerns identified in
`docs/exec-plans/current/epics/learning_model_v2/usage/informal.md`: parent-LO/sub-objective
aggregation. It is tracked in Jira as `MER-5821`, linked under epic `MER-5843`
("Learning Proficiency Model Improvements").

## Why the original Jira ticket text is stale

The Jira description for `MER-5821` originally asked for "equal weighting" across Sub-LOs and
was ambiguous about whether aggregation should move from a runtime projection to a persisted,
write-time calculation. Darren Siegel's review comments on the ticket (2026-07-29 through
2026-08-04) resolved both points:

- Timing does not change. Aggregation stays a **runtime projection** computed when proficiency
  is read (e.g. the Instructor Dashboard Learning Objectives tab, or a student-facing page),
  not persisted when a learner submits an attempt.
- The formula changes from equal-weighting to a **weighted average, weighted by the amount of
  evidence available per Sub-LO** (Darren: "weighted by the number of completed attempts
  present in each Sub Objective attached activity"). This matches epic `MER-5843`'s own
  "Learning Objective Aggregation" section ("weighted by number of attempts"), though that
  epic's Scope section still has a stale "equal-weight aggregation" line that should be
  disregarded in favor of the more specific and more recent aggregation section.
- Darren also asked that the ticket audit and update **every** place in the system, both
  authoring and delivery, that performs this rollup today, rather than patching a single call
  site.

## Decoupling from the algorithm (naive vs. LKT-AOA)

Epic `MER-5843` is running two parallel tracks: `MER-5846` implements the new LKT-AOA learner
model (an "Implement the LKT-AOA Learner Model" story whose own Negative AC states "Learning
Objective proficiency aggregation is not implemented as part of this ticket"), and `MER-5845`
adds a `learning_model_version` switch (already implemented in code today, see
`Oli.LearningModel.ModelVersion` and the `learning_model_version` field on
`Oli.Authoring.Course.Project` / `Oli.Delivery.Sections.Section`) that lets a project/section
run on `:naive` or `:lkt_aoa`.

`MER-5821` owns the aggregation layer used by **both** algorithms. It must not assume which
algorithm computed a given child's proficiency; the aggregation function only combines already-
computed `(proficiency, evidence_count)` pairs into a parent score. This was confirmed directly
with the ticket owner during PRD drafting.

## Confirmed weighting semantics per algorithm

- **Naive/legacy** (`lib/oli/delivery/metrics.ex`): a Sub-LO's own score is computed from first
  attempts only (`num_first_attempts` / `num_first_attempts_correct`), never `num_attempts`
  total. Therefore the weight passed into the shared aggregation function for a naive child
  **must** be `num_first_attempts` — using total attempts here would weight by evidence that
  never contributed to that child's score.
- **LKT-AOA**: `docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`
  section 6 ("Learning Objective Aggregation") is the authoritative technical definition
  referenced by `usage/informal.md`. Section 6.2 states the rule directly: "Sub-objective
  scores aggregate to the LO level using a weighted average, weighted by number of tagged
  opportunities per sub-objective," i.e. `LO_score = Σ(sub_objective_score × opportunities) /
  Σ opportunities`, where "opportunities" is the sub-objective's total attempt count (section
  6.1 defines the sub-objective score itself as the mean over all attempts, not just the
  first). This **confirms** — rather than merely assumes — that the LKT-AOA caller must pass
  total attempt count as `count`, resolving what was an open question earlier in PRD drafting.
  The exact API Torus will expose to read that count is a dependency on `MER-5846`, which is
  still in progress; the aggregation *rule* is settled, the concrete data access is not yet
  built.
- Section 6.4 of the same technical notes ("Tagging Hierarchy: Double-Counting Prevention")
  defines the same de-duplication rule already present in the original Jira AC: an activity
  tagged to both a parent LO and one of its Sub-LOs counts only at the more specific
  (Sub-LO) level.
- Section 6.3 ("Coverage Gaps") describes a **coverage gap indicator** shown alongside the
  score for thin Sub-LOs, rather than suppressing the parent score outright. The visual
  treatment of that indicator needs UX design (per the notes, "UX support needed from Jess")
  and is out of scope for this ticket; this PRD only needs the aggregation function to avoid
  silently dropping low-evidence children from the weighted average, consistent with both the
  original Jira AC ("reflects the incomplete coverage") and this technical note.
- `docs/exec-plans/current/epics/learning_model_v2/usage/informal.md` separately notes that a
  single shared `proficiency_range/2`-style bucketing function is **not** sufficient across both
  models ("The shared current `proficiency_range/2` cannot determine both models from a score
  and naive attempt count alone"), because each model's "not enough data" eligibility rule
  differs. This work item's shared function therefore returns a weighted **score** (and the
  total evidence count), and leaves bucketing/eligibility to the caller — the naive caller
  continues to call the existing `proficiency_range/2`; a future LKT-AOA caller applies its own
  rule (section 6.5).

## Data model

- `Oli.Resources.Revision`: `children` (objective revisions) is the LO → Sub-LO hierarchy;
  `objectives` (activity revisions) maps `part_id => [objective_ids]`, i.e. which LO/Sub-LO an
  activity part is tagged to.
- `Oli.Analytics.Summary.ResourceSummary`: per `(project_id, section_id, user_id, resource_id,
  part_id)` counts — `num_attempts`, `num_correct`, `num_first_attempts`,
  `num_first_attempts_correct`. No row is created for a parent LO purely because its Sub-LO has
  activity — a parent only has its own row if an activity is tagged to it directly.
- Bucket thresholds for the naive model live in `Metrics.proficiency_range/2`
  (`lib/oli/delivery/metrics.ex:1180-1184`): `< 3` first attempts or nil score → "Not enough
  data"; `<= 0.4` → "Low"; `<= 0.8` → "Medium"; else "High".

## Call sites audited (must all consume the new shared function)

1. **`Metrics.aggregate_raw_proficiency/1` + `proficiency_for_student_per_learning_objective/3`**
   (`lib/oli/delivery/metrics.ex:761-823`) — delivery, student-facing: `prologue_live.ex:634`,
   `lesson_live.ex:1660`, `review_live.ex:131`. Already pools numerator/denominator across
   children before dividing, so it already behaves like a weighted average — but it is coded
   directly against naive first-attempt semantics and needs to be generalized/extracted behind
   the new shared function rather than reimplemented per algorithm.
2. **`Sections.get_objectives_and_subobjectives/2`** (`lib/oli/delivery/sections.ex:5914-6185`,
   backed by `Metrics.proficiency_per_student_for_objective/3`,
   `lib/oli/delivery/metrics.ex:1509-1556`) — Instructor Dashboard Learning Objectives tab
   (`instructor_dashboard_live.ex:120`), the instructor's per-student view
   (`student_dashboard_live.ex:54`), and the CSV export
   (`delivery_controller.ex:471`, `download_learning_objectives/2`). Today a parent LO's
   proficiency comes **only** from its own direct `ResourceSummary` row; Sub-LOs are never
   combined in. Test `test/oli/delivery/sections_test.exs:3450-3498` documents and asserts this
   gap today and must be updated once the aggregation lands.
3. **`Oli.Delivery.LearningObjectives.PageElement.maybe_proficiency/5`**
   (`lib/oli/delivery/learning_objectives/page_element.ex:135-147`), consumed by
   `lib/oli/rendering/content/learning_objectives.ex` (the new `"learning_objectives"` page
   element). Also does not combine Sub-LOs today.

Useful fixture: `setup_objectives_and_activities_test/0`
(`test/oli/delivery/sections_test.exs:3711`) already builds a 2-level hierarchy with activities
tagged at both parent and Sub-LO level.

Out of scope / adjacent, noted but not touched by this ticket:

- Whole-class ("Average Class Proficiency") aggregation in
  `lib/oli/instructor_dashboard/data_snapshot/projections/summary/projector.ex` and
  `csv_export/serializers/helpers.ex` — these aggregate proficiency across *students*, not
  across a LO hierarchy, and use two different bucket-to-score weight scales (30/60/90 vs.
  20/60/100) that are already an inconsistency independent of this ticket.
- `Oli.InstructorDashboard.Oracles.ProgressProficiency`
  (`lib/oli/instructor_dashboard/oracles/progress_proficiency.ex`) computes page/container-scoped
  proficiency directly against `ResourceSummary`, not LO parent/Sub-LO rollup; it is flagged
  elsewhere in the epic as a naive-model shortcut to remove, but that is `learning_model_v2`
  dispatch work, not this ticket's aggregation-function scope.

## Agreed function contract

A single algorithm-agnostic weighted-average function. Conceptually:

```elixir
@doc """
Aggregates a parent Learning Objective's proficiency from the proficiency
estimates of its Sub-LOs (and, optionally, its own directly-tagged evidence),
producing a single weighted average.

Each child is passed as `{proficiency, count}`, where `count` is a measure
of how much evidence backs that child's proficiency estimate. This function
is agnostic to which learner model produced `proficiency` — it is the
CALLER's responsibility to supply a `count` that is consistent with how
that proficiency value was calculated:

  * Legacy (naive, first-attempt-only) algorithm: `count` MUST be the
    number of FIRST attempts (`num_first_attempts`), since only first
    attempts contribute to that model's proficiency estimate. Passing a
    total attempt count here would over-weight children whose score was
    computed from a smaller subset of evidence than their attempt count
    implies.

  * Learning Proficiency Framework v2 (LKT-AOA): `count` must reflect the
    total evidence count used by that model (all attempts / "tagged
    opportunities"), per the LKT-AOA technical definition
    (`docs/exec-plans/current/epics/learning_model_v2/lkt_technical_notes.docx.md`,
    section 6.2), since LKT-AOA's own Sub-LO score is a mean over every
    attempt rather than only the first.

Mismatching `count` semantics across children (e.g. mixing first-attempt
counts with total-attempt counts within the same aggregation call) will
silently skew the weighted average — this function has no way to detect
that on its own.
"""
```

This `@doc` text must be preserved as written (not rewritten) when this function is implemented.

Functional rules the function/its callers must preserve:

- No double-counting: an activity tagged to both a parent LO and one of its Sub-LOs is counted
  once, at the Sub-LO.
- Incomplete coverage: a Sub-LO with insufficient evidence is not silently excluded from the
  denominator — it must still be represented so the parent reflects incomplete coverage rather
  than behaving as if only the attempted Sub-LOs existed.
- The weighted score is what downstream bucketing (naive: `proficiency_range/2`; a future
  LKT-AOA provider: its own rule) consumes — the aggregation function does not bucket.

## Explicit scope boundary

In scope: the shared aggregation function and its documented contract; auditing and updating
call sites 1–3 above to consume it instead of duplicating or omitting the rollup; updating the
existing test(s) that assert today's non-aggregating behavior.

Out of scope: changing aggregation timing (stays a runtime projection); implementing LKT-AOA
itself (`MER-5846`); implementing/changing the `learning_model_version` switch (`MER-5845`,
already implemented); implementing the Confidence metric (`MER-5847`); the coverage-gap-indicator
UI treatment (needs UX design); the whole-class "Average Class Proficiency" aggregation and its
weight-scale inconsistency; `ProgressProficiency`'s page/container-scoped calculation.
