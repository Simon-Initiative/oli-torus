# Parent LO Proficiency: How Should a Parent's Own Directly-Tagged Evidence Be Combined With Its Sub-LOs?

## Context

When a parent Learning Objective has one or more Sub-LOs, how should proficiency be aggregated at
the parent level? Depending on how we choose to weigh the effect of tagging an activity directly to
the parent (rather than to one of its Sub-LOs), we arrive at different possible results — and each
approach carries its own difficulties and/or trade-offs, laid out below.

This question specifically matters for **existing** course content. A separate, already-filed
ticket will restrict authors from tagging activities directly to a parent LO once it has Sub-LOs,
for newly authored course packages going forward. That upcoming restriction does not apply
retroactively, so any course that has already tagged activities directly to a parent LO will keep
that tagging as-is. This discussion is about how proficiency should be aggregated for that existing
content, not about the tagging rules for new courses.

All four options below rely on `Oli.Analytics.Summary.ResourceSummary`, which stores one row per
`(project_id, section_id, user_id, resource_id, resource_type_id, part_id)`, with running totals
(`num_attempts`, `num_correct`, `num_first_attempts`, `num_first_attempts_correct`) incremented as
attempts occur. Critically, **this row does not retain which specific activity contributed to a
given increment** — counts from every activity ever tagged to that `resource_id` are folded
together at write time. As the options below show, this is the central constraint driving the
difficulty and trade-offs of each approach.

## Option A — Exact reconciliation (activity-level exclusion)

**Logic:** For the parent, determine which activities are tagged *only* to the parent (not to any
of its Sub-LOs), and compute the parent's own contribution using only attempts on those activities.
Any activity tagged to both the parent and a Sub-LO is attributed entirely to the Sub-LO and
excluded from the parent's own contribution. The parent's final proficiency is then the weighted
average of:
- Attempts on activities tagged only to the parent, and
- Each Sub-LO's own proficiency (computed normally, since a Sub-LO is always the most specific tag
  and never needs this exclusion itself).

**Implementation difficulty:** This cannot be computed from the existing `ResourceSummary` rows,
because those rows have already summed every contributing activity's counts together with no way
to subtract out a specific activity's contribution after the fact. Reconciling at the activity
level requires abandoning the pre-aggregated `ResourceSummary` read for the parent's own
contribution and instead querying the much larger raw attempt tables
(`ResourceAttempt` / `ActivityAttempt` / `PartAttempt`) directly, filtered down to the specific set
of activity resource_ids tagged only to the parent (a set difference computed from each
objective's tagged-activity list, e.g. the existing `related_activities` field). This is a
materially larger and more expensive computation than reading one pre-summed row per objective,
and is the only option of the four that cannot reuse the aggregation this ticket's other call
sites already rely on.

## Option B — Always combine parent and children (unconditional sum) — ✅ CHOSEN

**Decision:** Darren Siegel confirmed on Slack (2026-09-01) that this is "the simplest thing that
we can (and should) do." This is the option implemented.

**Logic:** Always include the parent's own full `ResourceSummary` row alongside every Sub-LO's row
in the weighted average, regardless of whether any Sub-LO has evidence and regardless of whether
any activity is tagged to both levels.

**Risk:** If an activity is tagged to both the parent and a Sub-LO, its evidence is double-counted
— it contributes once via the parent's row and again via the Sub-LO's row, inflating (or
deflating) the parent's evidence weight relative to what those attempts actually represent.

## Option C — Prefer children; fall back to the parent's own evidence only when children have none

**Logic:** Compute the weighted average of the Sub-LOs' evidence first. If that produces zero total
evidence (i.e., not a single Sub-LO has any attempts at all), fall back to using the parent's own
evidence alone instead. If any Sub-LO has evidence, use only the Sub-LOs' combined evidence — never
blended with the parent's own row.

**Behavior:** Because this is an either/or choice (never a blend of parent + children), it carries
no double-counting risk: the parent's own evidence is only ever used in the one situation where
there is no Sub-LO evidence to double-count against.

**Trade-off:** The moment any Sub-LO accumulates even a single attempt, the parent's own evidence —
however substantial — stops contributing entirely, and the parent's proficiency is driven solely by
that (possibly much thinner) Sub-LO evidence.

For example: Activity A is tagged only to the parent, and is answered by 20 students with 18
correct first attempts (a strong, well-evidenced signal — on its own, this would show as **High**).
Activity B is tagged to Sub-LO A.1 (1 of 3 first attempts correct) and Activity C is tagged to
Sub-LO A.2 (0 of 3 first attempts correct). Once all three activities have been completed, both
Sub-LOs now have evidence, so the parent's proficiency is computed from A.1 and A.2 alone: a
combined score of 0.33 from just 6 thin attempts, displaying as **Low**. Activity A's 20 attempts —
a much larger and stronger body of evidence — no longer contribute to the parent's displayed
proficiency at all, permanently, once every Sub-LO has any evidence of its own.

## Option D — Always use children only, with no fallback

**Logic:** The parent's proficiency is always the weighted average of its Sub-LOs' evidence. The
parent's own directly-tagged evidence never contributes once the parent has any Sub-LOs, regardless
of how much (or how little) evidence those Sub-LOs have accumulated.

**Behavior:** If none of a parent's Sub-LOs have ever been tagged to any activity, the parent shows
"Not enough data" indefinitely, even if the parent itself has substantial directly-tagged evidence.

---

## Worked Examples

### Example 1: A Sub-LO has evidence, and one activity is tagged to both the parent and that Sub-LO

Setup:
- Parent LO, with Sub-LO A.1 and Sub-LO A.2.
- Activity 1: tagged **only** to the parent. Result: 8 of 10 first attempts correct.
- Activity 2: tagged **only** to Sub-LO A.1. Result: 10 of 10 first attempts correct.
- Activity 3: tagged to **both** the parent and Sub-LO A.1. Result: 0 of 40 first attempts correct.
- Sub-LO A.2: no activity ever tagged to it.

| Option | How it's computed | Score | Displayed proficiency |
|---|---|---|---|
| A — Exact reconciliation | Parent's exclusive evidence (Activity 1 only) + A.1 (Activity 2 + Activity 3) + A.2 (none) | 0.44 | **Medium** |
| B — Always combine | Parent's full row (Activity 1 + Activity 3) + A.1's full row (Activity 2 + Activity 3) | 0.344 | **Low** (Activity 3 is counted twice, pulling the score down) |
| C — Prefer children, fallback if empty | A.1 has evidence, so only A.1 + A.2 are used | 0.36 | **Low** |
| D — Always children | Only A.1 + A.2 are used (same as C here, since A.1 has evidence) | 0.36 | **Low** |

### Example 2: Neither Sub-LO has ever been tagged to any activity

Setup:
- Same parent LO, with Sub-LO A.1 and Sub-LO A.2, neither ever used.
- Activity 1: tagged **only** to the parent. Result: 8 of 10 first attempts correct.

| Option | How it's computed | Score | Displayed proficiency |
|---|---|---|---|
| A — Exact reconciliation | Parent's exclusive evidence (Activity 1, nothing to exclude) + A.1/A.2 (none) | 0.84 | **High** |
| B — Always combine | Same as A here, since there is no overlapping activity to double-count | 0.84 | **High** |
| C — Prefer children, fallback if empty | Both Sub-LOs have zero evidence, so falls back to the parent's own evidence | 0.84 | **High** |
| D — Always children | Both Sub-LOs have zero evidence, and there is no fallback | — | **Not enough data** |
