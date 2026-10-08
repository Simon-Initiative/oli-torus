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

- Proficiency is hidden only when successfully loaded scope content confirms no
  applicable learning objectives.
- Score is hidden only when successfully loaded scope content confirms no graded
  assessments.
- Progress remains visible.
- Missing, loading or failed dependencies do not establish that content is absent.

A course can contain LOs and assessments while a particular unit contains neither.
That unit should show only Progress and AI Recommendation in the summary.

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

When absence of activity is confirmed in the selected scope, retain the fixed
initial copy from Figma:

> Students haven’t started yet. This dashboard will surface progress, proficiency, and areas needing attention as soon as activity begins.

With activity, retain the existing recommendation generation and insufficient-data
behavior. Recommendation `no_signal` alone does not prove absence of activity.

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
- Preserve initial AI copy, asynchronous recommendation updates, metric calculations,
  CSV absence semantics and uniform padding for every card count.
