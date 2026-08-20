# UpGrade Data-Capture Parity - Functional Design Document

## 1. Executive Summary

Implement two small, independent data paths:

- Focused producer enrichment attaches existing experiment attribution shapes to evaluated
  attempt and media xAPI statements when scoped assignment plus selected-branch content proves the
  relationship.
- Raw activity projection preserves every evaluated activity needed for v0.33.0 UpGrade-compatible
  analysis, whether or not the event has experiment attribution.

The design intentionally avoids a public universal resolver. Producer-specific modules operate on
authoritative data they already own and return an empty attribution list on no match or safe
failure. The host statement is always built and emitted independently.

## 2. Current Boundaries

- `Oli.Analytics.XAPI.StatementFactory` builds evaluated part/activity/page statements from an
  `Oli.Analytics.Summary.AttemptGroup`.
- `Oli.Delivery.Experiments.AttemptAttributions` owns attribution for those attempt statements.
- `Oli.Analytics.XAPI.construct_bundle/2` and
  `Oli.Delivery.Experiments.MediaAttributions` own video/media statement enrichment.
- `Oli.Experiments.XAPI.Attributions` owns the existing wire shape and host-role transformations.
- `Oli.Analytics.XAPI.ClickhouseUploader`, the Python Lambda, and backfill/replay own analytical
  projection.

### 2.1 Integration baseline

This work is temporarily stacked on two open pull requests that target `hotfix-v0.34.1`:

- [PR #6786](https://github.com/Simon-Initiative/oli-torus/pull/6786) is the current branch base and
  supplies weighted-random assignment scope, placement-specific exposure evidence, and the related
  xAPI/ClickHouse contracts.
- [PR #6784](https://github.com/Simon-Initiative/oli-torus/pull/6784) is incorporated into this
  branch and supplies the corrected Lambda parsing and ClickHouse insertion behavior for existing
  experiment attribution fields.

Both dependencies are expected to be squash-merged into `hotfix-v0.34.1`. Their current individual
commits are an implementation baseline, not commits that belong in the final PR for this work. The
final branch must be reconciled onto the updated hotfix branch after both squash merges, retaining
only changes unique to this work. Phase 3 may extend the Lambda contract for the new raw parity
fields, but must not reimplement or regress PR #6784's attribution mapping.

## 3. Design A: Focused Non-Page Attribution

### 3.1 Attempt statements

`AttemptAttributions` receives the persisted attempt hierarchy through `AttemptGroup`:

- For attempts created through experiment-aware delivery, `resource_attempts.content` stores the
  transformed realized page content after experiment decisions are applied. Each
  experiment-controlled Alternatives placement remains present but contains only its selected
  child branch.
- The page resource/revision and activity/part attempt identities are already present.
- Section, project, user, and current publication context are already present.

The persisted content establishes which branch the learner received; it does not independently
establish experiment, assignment, condition, or intervention identity. Those identities must come
from durable, scoped experiment records. In-memory `experiment_decisions` and
`experiment_attributions` fields on a resource-attempt struct are not treated as persisted evidence.
Historical attempts or attempts created outside the experiment-aware delivery path must fail safe
when this realized-content guarantee cannot be established.

The module performs one focused scoped query only when realized content contains a relevant
experiment-controlled Alternatives placement. The query returns the matching assignment,
condition, experiment, and actual intervention for the selected placement. The module then:

- attaches direct outcome attribution to the part statement;
- attaches the existing rollup form to activity/page statements;
- preserves the existing Thompson reward and policy evidence unchanged;
- returns no causal attribution for out-of-branch activities.

No attribution lookup is required to emit the underlying activity statement or preserve it in the
section-wide stream.

### 3.2 Media statements

`MediaAttributions` continues to use a focused helper:

- attempt-based video events inspect persisted realized page content;
- resource-only video events inspect the server-resolved deployed page revision;
- a single tailored query matches selected Alternatives resource/option pairs to scoped assignments
  and interventions.

The existing `media_interaction/assignment` role remains sufficient. No generic `interaction` role
is introduced.

### 3.3 Failure behavior

- No matching placement or assignment: attach nothing.
- Invalid or unavailable authoritative content: attach nothing and retain the host statement.
- Attribution construction failure: emit a bounded failure signal/log without learner identity and
  retain the host statement.

## 4. Design B: Section-Wide UpGrade-Compatible Outcomes

Every evaluated activity attempt must project one logical raw host row containing:

- section and project identifiers;
- enrollment identifier;
- activity resource/revision and attempt GUID/number;
- page attempt identity where already available;
- evaluation timestamp;
- raw score and denominator;
- stable raw-event hash.

This row is written even when `experiment_attributions` is absent. Assignment/exposure evidence
already contains enrollment, experiment, and condition identity. The compatibility query joins the
raw activity stream to the applicable durable assignment/exposure evidence by section, enrollment,
and time, without requiring branch containment.

Correctness is computed in the query as `score / out_of`, with `0.0` for zero values or invalid
division to match the prior UpGrade behavior. Missing raw values remain visible as a data-quality
state rather than being rewritten at ingestion.

## 5. Projection And Replay

- Direct upload, Lambda, and replay/backfill use the same small field mapping for required activity
  and attribution columns.
- Hashing remains based on the exact persisted statement bytes where the existing pipeline requires
  it for deduplication and joins.
- Historical events without new raw columns remain accepted with nulls.
- No migration populates historical rows.

## 6. Performance And Security

- Do not introduce a general 1,000-event API or materialize dozens of optional fields.
- Skip assignment queries when realized content has no relevant Alternatives placement.
- Use a scalar query projection rather than preloading full schemas.
- Scope assignment matches by project, section, user, and enrollment; verify the enrollment belongs
  to the section/user rather than echoing caller values.
- Never serialize realized page content, raw responses, learner identity, or policy-state blobs into
  attribution evidence or telemetry.

## 7. Testing

- Attempt attribution: both weighted-random scopes, Thompson, in/out-of-branch, multiple concrete
  placements, realized-content reconstruction, and unchanged reward/policy behavior.
- Media attribution: attempt and deployed-revision paths, selected/unselected content, and host
  preservation.
- Raw parity: every evaluated activity remains projected with enrollment, score, denominator, and
  evaluation time regardless of attribution.
- Cross-path parity: direct, Lambda, and replay/backfill normalize the same required fields.
- Compatibility proof: expected v0.33.0 enrollment/condition/timestamp/correctness rows.

## 8. Deferred Work

- Navigation or nested-content producers not currently present.
- A generic interaction role or universal attribution API.
- Broad missing-evidence diagnostics and allocation monitoring.
- Exact attempt-time publication provenance (MER-5889).
- User-facing export and statistical analysis.

## Acceptance-Criteria Coverage

Implementation and verification preserve traceability for AC-001, AC-002, AC-003, AC-004,
AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-011, AC-012, AC-013, and AC-014.

## Decision Log

### 2026-08-19 - Replace Universal Resolver With Producer-Specific Enrichment
- Change: Replaced the generic event-provenance/resolution architecture with focused attempt and
  media helpers and a separate unconditional raw activity path.
- Reason: Concrete producers already own authoritative context, while the generic boundary added
  queries and security claims without being necessary for v0.33.0 parity.
- Evidence: Current producer boundaries under `lib/oli/analytics/xapi*` and
  `lib/oli/delivery/experiments/`; historical behavior in
  `v0.33.0:lib/oli/delivery/experiments/log_worker.ex`.
- Impact: Smaller interfaces, fewer queries, no speculative producers, and independent acceptance
  of causal attribution and section-wide outcome capture.

### 2026-08-19 - Clarify Realized Attempt Content Guarantee
- Change: Defined `resource_attempts.content` as the transformed realized page content whose
  experiment-controlled Alternatives placements retain only the selected child branch.
- Reason: Saying the field "contains the realized selected branch" was imprecise and could imply
  that branch selection also proves assignment or condition identity.
- Evidence: `lib/oli/delivery/experiments/activity_provider.ex`,
  `lib/oli/resources/alternatives.ex`, `lib/oli/delivery/attempts/page_lifecycle/hierarchy.ex`, and
  `test/oli/delivery/attempts/page_lifecycle_test.exs`.
- Impact: Phase 2 may use persisted realized content to prove branch receipt, but must obtain
  experiment, assignment, condition, and intervention identity from durable scoped records and
  fail safe for attempts without the guarantee.

### 2026-08-19 - Record Stacked Hotfix Dependencies
- Change: Documented PR #6786 as the temporary branch base and PR #6784 as an incorporated ETL
  prerequisite, with `hotfix-v0.34.1` as the eventual target.
- Reason: Both prerequisites will be squash-merged, so their current commit identities cannot remain
  in the final feature history without creating duplicate or confusing changes.
- Evidence: GitHub PRs
  [#6786](https://github.com/Simon-Initiative/oli-torus/pull/6786) and
  [#6784](https://github.com/Simon-Initiative/oli-torus/pull/6784); local branch ancestry and the
  incorporated PR #6784 commits.
- Impact: Implementation builds on both behaviors now, then reconciles onto the updated hotfix
  branch and retains only patch-unique MER-5885 work before opening the final PR.
