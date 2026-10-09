# MER-5709: summary metric states

Status: accepted product decision, 2026-10-08. Implemented in the MER-5709 fix;
projector, projection and component tests cover the decision below.

## Decision and rationale

Average Assessment Score and Average Class Proficiency display `--` whenever the
metric is applicable but no value can be calculated. This includes a newly created
course with no student activity. A displayed `0%` must represent a calculated zero,
not the absence of responses.

This supersedes the earlier proposal to display `0%` for all applicable cards
before any activity. Whether students have worked elsewhere in the selected scope
must not determine the placeholder for an individual metric.

Average Student Progress can display `0%` when no students have progressed and the
progress data has loaded successfully. Loading or failed data must not be converted
to zero.

## Applicability and selected scope

Apply these rules to the dashboard's selected scope: the whole course for Entire
Course, or only the selected unit/module and its descendants when filtered.
This selects applicable LOs and assessments; it does not restrict every metric's
evidence to responses within that container.

- Proficiency is hidden only when successfully loaded scope content confirms no
  applicable learning objectives.
- Score is hidden only when successfully loaded scope content confirms no graded
  assessments.
- Progress remains visible.
- Missing, loading or failed dependencies do not establish that content is absent.

A course can contain LOs and assessments while a particular unit contains neither.
That unit should show only Progress and AI Recommendation in the summary.

### Metric evidence scope

Average Class Proficiency represents the class's proficiency on the learning
objectives present in the selected scope. The Summary uses objective aggregates,
not container proficiency. For both naive and LKT-AOA, those objective aggregates
use evidence throughout the section, including responses in other units that share
the same LO. Filtering by container selects the objectives to aggregate; it does
not restrict their evidence to that container's pages. This is consistent with the
Learning Objectives tab and recognizes proficiency demonstrated elsewhere in the
course.

Average Student Progress and Average Assessment Score instead use pages in the
selected container and its descendants. Therefore, a unit can have zero progress
and no assessment score while showing a calculated proficiency from shared LOs.

The naive provider also offers a separate container proficiency calculation that
uses only the selected container's page summaries. That calculation is not the
source of the Summary's Average Class Proficiency card. See
`lib/oli/instructor_dashboard/oracles/objectives_proficiency.ex` and
`lib/oli/delivery/proficiency/naive.ex` for the two paths.

Retain the existing tooltip copy; this explanation belongs in this documentation.

## Display rules

| Card | Applicable, no calculable value | Calculated zero | Calculated nonzero | Content absent |
| --- | --- | --- | --- | --- |
| Average Assessment Score | `--`, including no assessments answered yet | `0%` | Calculated percentage | Hidden |
| Average Class Proficiency | `--`, including no responses or insufficient evidence | `0%`, if returned by the calculation | Calculated percentage | Hidden |
| Average Student Progress | `0%` when loaded data confirms no progress; `--` if unknown | `0%` | Calculated percentage | Remains visible |

Each metric keeps its existing calculation and evidence requirements. Placeholders
do not create numeric values for calculations or CSV exports.

For example, answering a practice question without generating any assessment score
leaves Score at `--`. It also stays `--` before that practice question is answered.

## AI Recommendation and Figma

When all three metric oracles have loaded successfully and no summary metric signal
is available, retain the fixed initial copy from Figma:

> Students haven’t started yet. This dashboard will surface progress, proficiency, and areas needing attention as soon as activity begins.

For this presentation decision, a signal means any of the following:

- Average Class Proficiency has a calculated value, including `0%`.
- Average Assessment Score has a calculated value, including `0%`.
- Average Student Progress has a calculated value greater than zero.

Use the same aggregates and oracle readiness as the displayed cards. Attempt counts,
completed assessment counts without a mean score, and individual learner proficiency
that does not produce a Summary proficiency value do not establish a signal. This
criterion describes metric availability, not proof that no response ever occurred.
Shared-LO evidence that produces a Summary proficiency value counts as a signal even
when the selected unit has no responses of its own. Insufficient shared-LO evidence
that leaves proficiency at `--` does not.

Unsubmitted responses do not independently suppress the initial copy. A submitted
and evaluated part of an otherwise incomplete activity can also leave Progress at
zero, Proficiency at `--` and Score at `--`. Showing the initial copy in that case
is an accepted consequence of using available metrics rather than every response
as the presentation criterion.

A ready recommendation retains priority, whether retrieved from storage or newly
generated. Do not replace it with the initial or loading copy because other metrics
are empty, loading or failed. The existing generation and fallback behavior stays
unchanged.

Recommendation `no_signal` alone does not distinguish zero activity from insufficient
evidence. Resolve its presentation on every component update:

- No metric signal and all metric oracles ready: show the initial copy above.
- At least one metric signal: retain the insufficient-data message, without waiting
  for the other metric oracles to finish.
- No metric signal and at least one metric oracle loading: show
  `Generating a scoped recommendation for this selection.` until the state resolves.
- No metric signal and failed dependencies after loading ends: retain the
  insufficient-data message; do not claim that students have not started or stay
  loading indefinitely.

The initial [Figma node 1074:22892](https://www.figma.com/design/2DZreln3n2lJMNiL6av5PP/Instructor-Intelligent-Dashboard?node-id=1074-22892&m=dev)
shows initial zeros. The agreed `--` presentation for Score and Proficiency is an
intentional product decision that differs from that node. The placeholder was
proposed during MER-5709 discussion; it was not specified by the reviewed Figma
nodes. Component visibility and uniform padding remain as previously agreed.

## Verification expectations

- For a scope with no activity, cover all four combinations of LOs and assessments:
  both present (`--`, `--`, `0%`), only LOs (`--`, `0%`), only assessments (`--`,
  `0%`), and neither (Progress `0%`).
- Cover both no enrolled learners and enrolled learners without activity.
- Confirm activity elsewhere does not replace missing Score or Proficiency with zero.
- Confirm insufficient proficiency evidence keeps the card visible with `--`.
- Confirm actual calculated zeros remain visible as `0%`.
- Confirm unit/module applicability uses that scope, even when the course contains
  additional LOs or assessments elsewhere.
- Confirm loading and failures neither hide applicable cards nor manufacture zeros.
- Confirm shared-LO attempt counts alone do not suppress the initial AI copy, while
  calculated shared-LO proficiency does.
- Confirm calculated proficiency or score of zero and positive progress individually
  suppress the initial AI copy; progress of zero alone does not.
- Confirm cached `no_signal` copy waits for unresolved metric oracles, then updates
  to the initial copy or insufficient-data copy according to the displayed signals.
- Confirm one ready metric signal can resolve that copy while other metrics load.
- Confirm a ready recommendation is preserved with empty, loading or failed metrics.
- Preserve initial AI copy, asynchronous recommendation updates, metric calculations,
  CSV absence semantics and uniform padding for every card count.
